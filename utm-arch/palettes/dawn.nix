# dawn: Rosé Pine Dawn (rosepinetheme.com, MIT), the light variant of Rosé Pine.
# Warm paper (surface and overlay), the purple-grey `text` as ink, and `love` as
# the one accent, darkened a little so paper text on it reaches 4.5:1.
# Rosé Pine keeps its colours soft on purpose, so this is the most adapted
# palette here: nine of the 16 ANSI colours and the accent are "fitted" (OKLCH lightness
# moved until WCAG 2 reaches 4.5, or 3 for bright ones; palettes/contrast.clj).
# Contrast: utm-arch wiki/colour-schemes.md.
{
  mode = "light";
  source = "Rosé Pine Dawn, rosepinetheme.com/palette (MIT); ANSI after Ghostty's bundled Rose Pine Dawn";
  colours = {
    linen = "#f2e9e1";      # overlay
    white = "#fffaf3";      # surface
    ink = "#575279";        # text
    rust = "#ab5b72";       # love #b4637a, fitted to 4.5 under paper text
    graphite = "#6a6683";   # subtle #797593, fitted to 4.5 under the ground colour
    dim = "#cecacd";        # highlight high: quiet text on the purple bar
    muted = "#6a6683";      # subtle, fitted (4.2 on the card, 3.7 on the ground as it is)
    teal = "#286983";       # pine, split indicator
    rustLight = "#f0c1bf";  # Rosé Pine (main) rose #ebbcba, fitted to 4.5 on the bar
    rustBright = "#f0c1bf"; # (no surface uses this token today)
  };
  # Mixed from the card towards love, pine and the accent (contrast.clj mix).
  tints = {
    linenDeep = "#e6ddd9";
    rustPale = "#f2dfdd";
    rustPaler = "#f8ece8";
    rustWord = "#e3c1c5";
    olivePale = "#d8e0df";
    olivePaler = "#ecede9";
    oliveWord = "#adc3c8";
    selection = "#edd7d7";
  };
  # The port's mapping (pine in the green slot, foam in blue, rose in cyan); 0 and
  # 15 are `text` (the port's 0 is the pale overlay, invisible on paper).
  ansi = [
    "#575279" "#ab5b72" "#286983" "#ab6200" "#3e7c87" "#806b99" "#ad5c59" "#74708e"
    "#948fa1" "#b4637a" "#286983" "#cc8100" "#56949f" "#907aa9" "#ce7a76" "#575279"
  ];
  # fitted: 1 #b4637a, 3 #ea9d34, 4 #56949f, 5 #907aa9, 6 #d7827e, 7 #797593,
  # 8 #9893a5, 11 #ea9d34, 14 #d7827e
}
