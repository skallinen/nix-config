;; op for the utm-arch VM: a stand-in for the 1Password CLI that asks the Mac.
;; Part of the utm-arch macbridge (utm-arch wiki/macbridge.md).
;;
;; The Mac runs the real `op` (so 1Password shows its own Touch ID prompt) and only
;; for the vaults its allowlist names. This shim speaks the bridge's JSON line
;; protocol over ~/.local/run/macbridge.sock, which the Mac's ssh tunnel forwards.
;;
;;   op read [-n|--no-newline] [--account X] op://Vault/Item/field
;;   op inject [-i FILE] [-o FILE] [-f|--force] [--account X]
;;   op run [--account X] [--no-masking] -- COMMAND ARGS...
;;   op bridge-status
;;
;; --account is accepted and ignored: the Mac has one 1Password account.
(ns op-shim
  (:require [babashka.process :as p]
            [cheshire.core :as json]
            [clojure.java.io :as io]
            [clojure.string :as str])
  (:import [java.net StandardProtocolFamily UnixDomainSocketAddress]
           [java.nio.channels Channels SocketChannel]))

(def sock (or (System/getenv "MACBRIDGE_SOCK")
              (str (System/getProperty "user.home") "/.local/run/macbridge.sock")))

(defn die [code & msg]
  (binding [*out* *err*] (println (str "op (macbridge): " (apply str msg))))
  (System/exit code))

(defn ask [req]
  (let [ch (try (doto (SocketChannel/open StandardProtocolFamily/UNIX)
                  (.connect (UnixDomainSocketAddress/of ^String sock)))
                (catch Exception _
                  (die 2 "the bridge to the Mac is down (" sock "). "
                       "It needs the Mac awake and its macbridge-tunnel agent running; "
                       "see utm-arch wiki/macbridge.md.")))]
    (with-open [out (io/writer (Channels/newOutputStream ch))
                in (io/reader (Channels/newInputStream ch))]
      (.write out (str (json/generate-string req) "\n"))
      (.flush out)
      (let [line (.readLine ^java.io.BufferedReader in)
            ans (when line (json/parse-string line true))]
        (cond (nil? ans) (die 1 "the Mac closed the connection without an answer")
              (not (:ok ans)) (die 1 (:error ans))
              :else ans)))))

(defn parse
  "Splits ARGS into a map of flags and a vector of the rest. VALUED names the
  flags that take a value."
  [args valued]
  (loop [[a & more :as args] args, flags {}, rest []]
    (cond (nil? args) [flags rest]
          (= a "--") [flags (into rest more)]
          (valued a) (recur (next more) (assoc flags a (first more)) rest)
          (str/starts-with? a "--") (let [[k v] (str/split a #"=" 2)]
                                      (recur more (assoc flags k (or v true)) rest))
          (and (str/starts-with? a "-") (> (count a) 1)) (recur more (assoc flags a true) rest)
          :else (recur more flags (conj rest a)))))

(defn cmd-read [args]
  (let [[flags [ref & extra]] (parse args #{"--account" "--out-file" "-o"})]
    (when (or (nil? ref) extra) (die 64 "usage: op read [-n] op://Vault/Item/field"))
    (let [v (:value (ask {:op "read" :ref ref}))
          v (if (or (flags "-n") (flags "--no-newline")) v (str v "\n"))]
      (if-let [f (or (flags "--out-file") (flags "-o"))]
        (spit f v)
        (do (print v) (flush))))))

(defn cmd-inject [args]
  (let [[flags _] (parse args #{"--account" "-i" "--in-file" "-o" "--out-file" "--file-mode"})
        in (or (flags "-i") (flags "--in-file"))
        out (or (flags "-o") (flags "--out-file"))
        template (if in (slurp in) (slurp *in*))
        v (:value (ask {:op "inject" :template template}))]
    (if out (spit out v) (do (print v) (flush)))))

(defn cmd-run [args]
  (let [[_ cmd] (parse args #{"--account" "--env-file"})
        _ (when (empty? cmd) (die 64 "usage: op run -- COMMAND ARGS..."))
        refs (into {} (filter (fn [[_ v]] (str/starts-with? v "op://"))) (System/getenv))
        vals (if (empty? refs)
               {}
               (json/parse-string (:value (ask {:op "inject"
                                                :template (json/generate-string refs)}))))
        proc (p/process cmd {:inherit true :extra-env vals})]
    (System/exit (:exit @proc))))

(let [[sub & args] *command-line-args*]
  (case sub
    "read" (cmd-read args)
    "inject" (cmd-inject args)
    "run" (cmd-run args)
    "bridge-status" (do (ask {:op "ping"}) (println "macbridge: the Mac answers on" sock))
    ("--version" "-v" "version") (println "macbridge op shim (utm-arch)")
    (die 64 "this is the macbridge op shim; it knows read, inject, run and bridge-status"
         (when sub (str ", not " sub)))))
