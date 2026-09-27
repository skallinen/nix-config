# flexoki: Steph Ango's Flexoki (stephango.com/flexoki, MIT), "inky colour
# scheme for prose and code", light side. Paper cards, base-100 ground, black ink,
# and blue-600 as the one accent: a fountain-pen blue in place of the house rust.
# Adapted to the house tokens; changes from the source are marked "fitted"
# (OKLCH lightness moved until WCAG 2 reaches 4.5 for normal ANSI colours, 3 for
# bright ones, by palettes/contrast.clj). Contrast: utm-arch wiki/colour-schemes.md.
{
  mode = "light";
  source = "Flexoki light, stephango.com/flexoki (MIT); ANSI after Ghostty's bundled Flexoki Light";
  colours = {
    linen = "#E6E4D9";      # base-100
    white = "#FFFCF0";      # paper
    ink = "#100F0F";        # black
    rust = "#205EA6";       # blue-600, the accent
    graphite = "#403E3C";   # base-800
    dim = "#878580";        # base-500
    muted = "#575653";      # base-700 (base-600 is 4.0 on the ground)
    teal = "#BC5215";       # orange-600, split indicator
    rustLight = "#4385BE";  # blue-400, the accent on the black bar
    rustBright = "#4385BE"; # blue-400 (no surface uses this token today)
  };
  # Mixed from the card towards red-600, green-600 and the accent (contrast.clj mix).
  tints = {
    linenDeep = "#d5d3c9";
    rustPale = "#f1d7cc";
    rustPaler = "#f8eade";
    rustWord = "#e1aea4";
    olivePale = "#e3e6c7";
    olivePaler = "#f1f1db";
    oliveWord = "#c5cd99";
    selection = "#ced9e0";
  };
  # 600s for normal, 400s for bright; 7 and 8 are base-600 and base-500, 15 is
  # black, so every colour reads on paper.
  ansi = [
    "#100F0F" "#AF3029" "#647e06" "#976d00" "#205EA6" "#A02F6F" "#218179" "#6F6E69"
    "#878580" "#D14D41" "#879A39" "#b98b00" "#4385BE" "#CE5D97" "#31a298" "#100F0F"
  ];
  # fitted: 2 #66800B, 3 #AD8301, 6 #24837B, 11 #D0A215, 14 #3AA99F
}
