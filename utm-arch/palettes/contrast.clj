#!/usr/bin/env bb
;; Contrast of every text/ground pair of the utm-arch palettes, computed, not
;; guessed: WCAG 2 contrast ratio and APCA Lc (APCA-W3 0.0.98G constants).
;; Reads the palettes from palette.nix with `nix eval`, so it checks exactly what
;; Home Manager builds. The figures are copied into utm-arch wiki/colour-schemes.md.
;;
;;   bb contrast.clj              every palette, every pair
;;   bb contrast.clj flexoki      one palette
;;   bb contrast.clj mix A B T    A mixed T (0 to 1) of the way towards B
;;   bb contrast.clj fit HEX BG R the nearest colour of HEX's hue and chroma (OKLCH)
;;                                with WCAG ratio >= R on BG (lightness moved only)
(require '[babashka.process :refer [shell]]
         '[cheshire.core :as json]
         '[clojure.string :as str])

(defn rgb [hex]
  (let [h (str/replace hex "#" "")]
    (mapv #(Integer/parseInt (subs h % (+ % 2)) 16) [0 2 4])))

(defn hex [[r g b]]
  (let [c #(-> % Math/round (max 0) (min 255))]
    (format "#%02x%02x%02x" (c r) (c g) (c b))))

;; WCAG 2.x relative luminance and ratio
(defn lin [c] (let [c (/ c 255.0)] (if (<= c 0.04045) (/ c 12.92) (Math/pow (/ (+ c 0.055) 1.055) 2.4))))
(defn lum [h] (let [[r g b] (map lin (rgb h))] (+ (* 0.2126 r) (* 0.7152 g) (* 0.0722 b))))
(defn ratio [a b]
  (let [[x y] (sort > [(lum a) (lum b)])] (/ (+ x 0.05) (+ y 0.05))))

;; APCA-W3 0.0.98G
(defn apca-y [h]
  (let [[r g b] (map #(Math/pow (/ % 255.0) 2.4) (rgb h))
        y (+ (* 0.2126729 r) (* 0.7151522 g) (* 0.0721750 b))]
    (if (< y 0.022) (+ y (Math/pow (- 0.022 y) 1.414)) y)))
(defn apca [txt bg]
  (let [yt (apca-y txt) yb (apca-y bg)]
    (if (< (Math/abs (- yb yt)) 0.0005) 0.0
        (if (> yb yt)
          (let [s (* 1.14 (- (Math/pow yb 0.56) (Math/pow yt 0.57)))]
            (if (< s 0.1) 0.0 (* 100 (- s 0.027))))
          (let [s (* 1.14 (- (Math/pow yb 0.65) (Math/pow yt 0.62)))]
            (if (> s -0.1) 0.0 (* 100 (+ s 0.027))))))))

;; OKLab / OKLCH (Björn Ottosson), for `fit`
(defn ->oklab [h]
  (let [[r g b] (map lin (rgb h))
        l (Math/cbrt (+ (* 0.4122214708 r) (* 0.5363325363 g) (* 0.0514459929 b)))
        m (Math/cbrt (+ (* 0.2119034982 r) (* 0.6806995451 g) (* 0.1073969566 b)))
        s (Math/cbrt (+ (* 0.0883024619 r) (* 0.2817188376 g) (* 0.6299787005 b)))]
    [(+ (* 0.2104542553 l) (* 0.7936177850 m) (* -0.0040720468 s))
     (+ (* 1.9779984951 l) (* -2.4285922050 m) (* 0.4505937099 s))
     (+ (* 0.0259040371 l) (* 0.7827717662 m) (* -0.8086757660 s))]))
(defn unlin [c] (* 255 (if (<= c 0.0031308) (* 12.92 c) (- (* 1.055 (Math/pow c (/ 1 2.4))) 0.055))))
(defn oklab-> [[L a b]]
  (let [l (Math/pow (+ L (* 0.3963377774 a) (* 0.2158037573 b)) 3)
        m (Math/pow (- L (* 0.1055613458 a) (* 0.0638541728 b)) 3)
        s (Math/pow (- L (* 0.0894841775 a) (* 1.2914855480 b)) 3)]
    (hex (map (comp unlin #(-> % (max 0.0) (min 1.0)))
              [(+ (* 4.0767416621 l) (* -3.3077115913 m) (* 0.2309699292 s))
               (+ (* -1.2684380046 l) (* 2.6097574011 m) (* -0.3413193965 s))
               (+ (* -0.0041960863 l) (* -0.7034186147 m) (* 1.7076147010 s))]))))
(defn fit [h bg target]
  (let [[L a b] (->oklab h)
        step (if (> (lum bg) 0.18) -0.002 0.002)]
    (loop [L L]
      (let [c (oklab-> [L a b])]
        (if (or (>= (ratio c bg) target) (<= L 0) (>= L 1)) c (recur (+ L step)))))))
(defn mix [a b t] (hex (map #(+ %1 (* t (- %2 %1))) (rgb a) (rgb b))))

(def here (str (fs/parent (fs/absolutize *file*))))

(defn palettes []
  (let [dir here
        out (:out (shell {:out :string} "nix" "eval" "--json" "--file"
                         (str dir "/../palette.nix") "palettes"))]
    (json/parse-string out true)))

;; [label text ground minimum], the minimum being WCAG 2's 4.5 for text, 3 for
;; large or bold text and for lines and other non-text parts.
;; ANSI colours on the terminal ground: 4.5 for the normal eight, 3 for the bright
;; eight; a dark palette's colour 0 is the terminal's black ground, not text.
(defn pairs [{c :colours t :tints}]
  [["terminal text: ink on white" (:ink c) (:white c) 4.5]
   ["rofi input, Claude messages: ink on linen" (:ink c) (:linen c) 4.5]
   ["bar text, rofi prompt: linen on ink" (:linen c) (:ink c) 4.5]
   ["focused title, selected row: white on rust" (:white c) (:rust c) 4.5]
   ["unfocused titles, idle workspaces: dim on ink" (:dim c) (:ink c) 3]
   ["focused-inactive title: linen on graphite" (:linen c) (:graphite c) 4.5]
   ["quiet text: muted on white" (:muted c) (:white c) 4.5]
   ["quiet text: muted on linen" (:muted c) (:linen c) 4.5]
   ["accent as text: rust on white" (:rust c) (:white c) 4.5]
   ["urgent workspace: rust on linen" (:rust c) (:linen c) 3]
   ["bar warnings: rustLight on ink" (:rustLight c) (:ink c) 4.5]
   ["Claude diff: ink on added line" (:ink c) (:olivePale t) 4.5]
   ["Claude diff: ink on removed line" (:ink c) (:rustPale t) 4.5]
   ["Claude selection: ink on selection" (:ink c) (:selection t) 4.5]
   ["line: ink border on linen desktop" (:ink c) (:linen c) 3]
   ["line: rust border on linen desktop" (:rust c) (:linen c) 3]
   ["line: rust border next to ink title bars" (:rust c) (:ink c) 1]])

(defn fmt [x] (format "%.1f" (double x)))

(defn report [[name p]]
  (println (str "\n## " (clojure.core/name name) " (" (:mode p) ")\n"))
  (println "| Pair | Text | Ground | WCAG 2 | APCA Lc | Needs |")
  (println "|---|---|---|---|---|---|")
  (doseq [[label fg bg need] (pairs p)]
    (let [r (ratio fg bg)]
      (println (format "| %s | `%s` | `%s` | %s%s | %s | %s |" label fg bg (fmt r)
                       (if (< r need) " FAIL" "") (fmt (apca fg bg)) need))))
  (let [bg (get-in p [:colours :white])]
    (println (str "\nANSI on the terminal ground `" bg "` (WCAG 2 / APCA Lc):\n"))
    (println "| | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |")
    (println "|---|---|---|---|---|---|---|---|---|")
    (doseq [[row cs] [["normal" (take 8 (:ansi p))] ["bright" (drop 8 (:ansi p))]]]
      (println (str "| " row " | "
                    (str/join " | " (map-indexed (fn [i h] (let [r (ratio h bg)] (str "`" h "` " (fmt r) (cond (and (= i 0) (= row "normal") (= (:mode p) "dark")) " (ground)" (< r (if (= row "normal") 4.5 3)) " FAIL") " / " (fmt (apca h bg))))) cs))
                    " |")))))

(when (= *file* (System/getProperty "babashka.file"))
 (let [[cmd & args] *command-line-args*]
  (case cmd
    "mix" (let [[a b t] args] (println (mix a b (parse-double t))))
    "fit" (let [[h bg r] args] (let [c (fit h bg (parse-double r))] (println c (fmt (ratio c bg)))))
    (doseq [e (cond->> (palettes) cmd (filter #(= (name (key %)) cmd)))] (report e)))))
