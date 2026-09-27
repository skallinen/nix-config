;; macbridge: the Mac half of the utm-arch bridge (utm-arch wiki/macbridge.md).
;;
;; Serves a Unix socket. The launchd tunnel (macbridge-tunnel) forwards it into the
;; VM as /home/sakalli/.local/run/macbridge.sock, reachable only by sakalli there.
;; One JSON request line per connection, one JSON answer line back:
;;
;;   {"op":"ping"}                                   -> {"ok":true,"value":"pong"}
;;   {"op":"read","ref":"op://Vault/Item/field"}     -> {"ok":true,"value":"..."}
;;   {"op":"inject","template":"... op://... ..."}   -> {"ok":true,"value":"..."}
;;   {"op":"approve","reason":"...","nonce":"hex"}   -> {"ok":true,"approved":true,
;;                                                       "signature":"base64"}
;;
;; read and inject run the real 1Password CLI, so 1Password shows its own Touch ID
;; prompt. approve shows a Touch ID sheet (touchid-approve) with the reason and, when
;; approved, signs "macbridge-approve-v1\n<nonce>\n<reason>\n" with an Ed25519 key
;; kept in the login keychain. The VM's sudo helper checks that signature with the
;; public key in /etc/macbridge, so a fake socket planted by a process running as
;; sakalli cannot answer "yes" for it.
;;
;; Only vaults named in the allowlist (an EDN file in the Nix store, so the VM cannot
;; edit it through the shared home) can be read. Every request is logged, never a
;; secret. Configuration comes from the environment, set by utm-arch/macbridge/darwin.nix.
(ns macbridge
  (:require [babashka.fs :as fs]
            [babashka.process :as p]
            [cheshire.core :as json]
            [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.string :as str])
  (:import [java.net StandardProtocolFamily UnixDomainSocketAddress]
           [java.nio.channels Channels ServerSocketChannel]
           [java.security KeyFactory KeyPairGenerator Signature]
           [java.security.spec PKCS8EncodedKeySpec]
           [java.time LocalDateTime]
           [java.time.format DateTimeFormatter]
           [java.util Base64]))

(defn env [k default] (or (System/getenv k) default))

(def home (System/getProperty "user.home"))
(def socket-path (env "MACBRIDGE_SOCKET" (str home "/.local/run/macbridge/bridge.sock")))
(def op-bin (env "MACBRIDGE_OP" "op"))
(def approve-bin (env "MACBRIDGE_APPROVE" "touchid-approve"))
(def allow-file (env "MACBRIDGE_ALLOW" (str home "/.config/macbridge/allow.edn")))
(def log-file (env "MACBRIDGE_LOG" (str home "/Library/Logs/macbridge.log")))
(def pub-file (env "MACBRIDGE_PUBKEY_OUT" (str home "/.config/macbridge/approve.pub.pem")))
(def keychain-service "macbridge-approve")

;; ---------------------------------------------------------------- log

(def log-lock (Object.))

(defn clean [s n]
  (let [s (str/replace (str s) #"[\p{Cntrl}]" " ")]
    (if (> (count s) n) (str (subs s 0 n) "...") s)))

(defn log! [kind detail result]
  (locking log-lock
    (spit log-file
          (str (.format (LocalDateTime/now) (DateTimeFormatter/ofPattern "yyyy-MM-dd HH:mm:ss"))
               "\t" kind "\t" (clean detail 300) "\t" (clean result 200) "\n")
          :append true)))

;; ---------------------------------------------------------------- allowlist

(defn allowed-vaults []
  (->> (:vaults (edn/read-string (slurp allow-file)))
       (map str/lower-case)
       set))

(def ref-re #"(?i)op://[^\s\"'{}<>`\\]+")

(defn ref-vault
  "The vault segment of an op:// reference, or nil when the reference is not plain
  text (1Password expands $VAR and ${VAR} inside references)."
  [ref]
  (when-let [[_ v] (re-matches #"(?i)op://([^/$]+)/[^$]+" ref)]
    v))

(defn check-refs!
  "Throws unless every op:// reference in TEXT names an allowed vault."
  [text]
  (let [vaults (allowed-vaults)
        refs (re-seq ref-re text)
        n-op (count (re-seq #"(?i)op:/" text))]
    (when (not= n-op (count refs))
      (throw (ex-info "a reference could not be parsed" {:refs refs})))
    (doseq [r refs]
      (let [v (ref-vault r)]
        (when-not (and v (contains? vaults (str/lower-case v)))
          (throw (ex-info (str "vault not allowed by macbridge: " (or v r)) {:ref r})))))
    refs))

;; ---------------------------------------------------------------- rate limit

(def recent (atom []))            ; times (ms) of recent requests
(def approving (atom false))      ; one Touch ID sheet at a time

(defn rate-ok? [kind]
  (let [now (System/currentTimeMillis)
        limit (if (= kind "approve") 6 30)
        [_ kept] (swap-vals! recent (fn [xs] (conj (filterv #(< (- now (:t %)) 60000) xs)
                                                   {:t now :kind kind})))]
    (<= (count (filter #(= kind (:kind %)) kept)) limit)))

;; ---------------------------------------------------------------- 1Password

(defn run-op [args stdin]
  (let [proc (p/process (into [op-bin] args)
                        {:in (or stdin "") :out :string :err :string
                         :extra-env {"HOME" home}})
        res (deref proc 120000 ::timeout)]
    (if (= res ::timeout)
      (do (p/destroy-tree proc) (throw (ex-info "1Password did not answer in 120 s" {})))
      (if (zero? (:exit res))
        (:out res)
        (throw (ex-info (str "op: " (clean (str/trim (:err res)) 300)
                             (when (re-find #"(?i)firewall|network|connect" (:err res))
                               " (is NordLayer connected on the Mac?)"))
                        {}))))))

(defn op-read [{:keys [ref]}]
  ;; one argument, so spaces in item names are fine here (not in inject)
  (when-not (and (string? ref) (re-matches #"(?i)op://[^$\p{Cntrl}]+" ref))
    (throw (ex-info "read needs one op:// reference" {})))
  (check-refs! ref)
  (run-op ["read" "--no-newline" ref] nil))

(defn op-inject [{:keys [template]}]
  (when-not (string? template) (throw (ex-info "inject needs a template" {})))
  (when (> (count template) 65536) (throw (ex-info "template too large" {})))
  (check-refs! template)
  (run-op ["inject"] template))

;; ---------------------------------------------------------------- approve

(defn keychain-get [account]
  (let [r (p/shell {:out :string :err :string :continue true}
                   "/usr/bin/security" "find-generic-password" "-s" keychain-service
                   "-a" account "-w")]
    (when (zero? (:exit r)) (str/trim (:out r)))))

(defn keychain-put! [account value]
  (p/shell {:out :string :err :string}
           "/usr/bin/security" "add-generic-password" "-U" "-s" keychain-service
           "-a" account "-w" value))

(def b64e #(.encodeToString (Base64/getEncoder) %))
(def b64d #(.decode (Base64/getDecoder) ^String %))

(defn pem [der]
  (str "-----BEGIN PUBLIC KEY-----\n" (b64e der) "\n-----END PUBLIC KEY-----\n"))

(defn signing-key
  "The Ed25519 private key from the login keychain; made on first use. Writes the
  public half to pub-file each start, for build/macbridge-setup.sh to install in
  the VM."
  []
  (when-not (keychain-get "ed25519-private")
    (let [kp (.generateKeyPair (KeyPairGenerator/getInstance "Ed25519"))]
      ;; base64 on one line: `security -w` prints a value with newlines as hex
      (keychain-put! "ed25519-public" (b64e (.getEncoded (.getPublic kp))))
      (keychain-put! "ed25519-private" (b64e (.getEncoded (.getPrivate kp))))))
  (fs/create-dirs (fs/parent pub-file))
  (spit pub-file (pem (b64d (keychain-get "ed25519-public"))))
  (.generatePrivate (KeyFactory/getInstance "Ed25519")
                    (PKCS8EncodedKeySpec. (b64d (keychain-get "ed25519-private")))))

(def private-key (delay (signing-key)))

(defn sign [^String msg]
  (b64e (.sign (doto (Signature/getInstance "Ed25519")
                 (.initSign @private-key)
                 (.update (.getBytes msg "UTF-8"))))))

(defn approve [{:keys [reason nonce]}]
  (when-not (and (string? reason) (re-matches #"[\x20-\x7e]{1,300}" reason))
    (throw (ex-info "reason must be 1 to 300 printable ASCII characters" {})))
  (when-not (and (string? nonce) (re-matches #"[0-9a-f]{32,64}" nonce))
    (throw (ex-info "nonce must be 32 to 64 hex digits" {})))
  (when-not (compare-and-set! approving false true)
    (throw (ex-info "another approval is already waiting" {})))
  (try
    (let [r (p/shell {:out :string :err :string :continue true}
                     approve-bin "--timeout" "30" reason)]
      (case (:exit r)
        0 {:approved true
           :signature (sign (str "macbridge-approve-v1\n" nonce "\n" reason "\n"))}
        2 {:approved false :why "timed out"}
        3 {:approved false :why (str "no Touch ID or password available: " (clean (:err r) 200))}
        {:approved false :why "denied"}))
    (finally (reset! approving false))))

;; ---------------------------------------------------------------- server

(defn handle [req]
  (let [kind (:op req)]
    (when-not (rate-ok? kind)
      (throw (ex-info "rate limit: too many requests in the last minute" {})))
    (case kind
      "ping" {:value "pong"}
      "read" {:value (op-read req)}
      "inject" {:value (op-inject req)}
      "approve" (approve req)
      (throw (ex-info (str "unknown op: " kind) {})))))

(defn detail [req]
  (case (:op req)
    "read" (:ref req)
    "inject" (str/join " " (re-seq ref-re (str (:template req))))
    "approve" (:reason req)
    ""))

(defn serve-one [ch]
  (future
    (let [killer (future (Thread/sleep 180000) (.close ch))]
      (try
        (with-open [in (io/reader (Channels/newInputStream ch))
                    out (io/writer (Channels/newOutputStream ch))]
          (let [line (.readLine ^java.io.BufferedReader in)
                req (try (json/parse-string line true) (catch Exception _ nil))
                answer (if-not (map? req)
                         {:ok false :error "bad request: one JSON object per line"}
                         (try (assoc (handle req) :ok true)
                              (catch Exception e {:ok false :error (ex-message e)})))]
            (log! (if (map? req) (:op req) "?")
                  (if (map? req) (detail req) "")
                  (cond (not (:ok answer)) (str "error: " (:error answer))
                        (contains? answer :approved) (if (:approved answer) "approved" (str "refused: " (:why answer)))
                        :else "ok"))
            (.write out (str (json/generate-string answer) "\n"))
            (.flush out)))
        (catch Exception e
          (log! "?" "" (str "connection error: " (ex-message e))))
        (finally
          (future-cancel killer)
          (.close ch))))))

(defn -main []
  (let [dir (fs/parent socket-path)]
    (fs/create-dirs dir)
    (fs/set-posix-file-permissions dir "rwx------")
    (fs/delete-if-exists socket-path)
    @private-key                       ; fail at start, not at the first sudo
    (let [server (ServerSocketChannel/open StandardProtocolFamily/UNIX)]
      (.bind server (UnixDomainSocketAddress/of ^String socket-path))
      (fs/set-posix-file-permissions socket-path "rw-------")
      (log! "start" socket-path (str "vaults " (str/join "," (sort (allowed-vaults)))))
      (loop []
        (serve-one (.accept server))
        (recur)))))

(when (= *file* (System/getProperty "babashka.file"))
  (-main))
