# flexoki-dark: Flexoki's dark side (stephango.com/flexoki, MIT). The house turned
# over: a black desk, base-950 cards, bone ink (base-200) for text and lines, and
# orange-400 as the one accent. The tokens keep their roles, so the bar and the
# unfocused title bars (which are `ink`) are bone strips with dark text, as the
# house's are ink strips with light text.
# Adapted to the house tokens; changes from the source are marked "fitted"
# (palettes/contrast.clj). Contrast: utm-arch wiki/colour-schemes.md.
{
  mode = "dark";
  source = "Flexoki dark, stephango.com/flexoki (MIT); ANSI after Ghostty's bundled Flexoki Dark, with Flexoki's 300s for bright";
  colours = {
    linen = "#100F0F";      # black: the desk, gaps, input rows
    white = "#1C1B1A";      # base-950: cards, the terminal; text on the accent
    ink = "#CECDC3";        # base-200: text, lines, the bar
    rust = "#DA702C";       # orange-400, the accent
    graphite = "#B7B5AC";   # base-300: focused-but-inactive title bars
    dim = "#6F6E69";        # base-600: quiet text on the bone bar
    muted = "#878580";      # base-500: quiet text on the cards
    teal = "#3AA99F";       # cyan-400, split indicator
    rustLight = "#9c3400";  # orange-600 #BC5215, fitted to 4.5 on the bone bar
    rustBright = "#9c3400"; # (no surface uses this token today)
  };
  # The card mixed towards red-600, green-600 (contrast.clj mix); hover is base-900,
  # selection base-800 as in the Ghostty port.
  tints = {
    linenDeep = "#282726";
    rustPale = "#41201e";
    rustPaler = "#2f1e1c";
    rustWord = "#662622";
    olivePale = "#2f3416";
    olivePaler = "#262818";
    oliveWord = "#414e13";
    selection = "#403E3C";
  };
  # 400s for normal, 300s for bright (the port swaps in the darker 600s, which are
  # dim on black); 7 base-300, 8 base-600, 15 paper. 0 is base-800, the "black"
  # of a dark terminal: a ground for programs that paint with it, not a text colour.
  ansi = [
    "#403E3C" "#dc574a" "#879A39" "#D0A215" "#4688c1" "#CE5D97" "#3AA99F" "#B7B5AC"
    "#6F6E69" "#E8705F" "#A0AF54" "#DFB431" "#66A0C8" "#E47DA8" "#5ABDAC" "#FFFCF0"
  ];
  # fitted: 1 #D14D41, 4 #4385BE (a hair short of 4.5 on base-950)
}
