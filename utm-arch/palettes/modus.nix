# modus: Protesilaos Stavrou's Modus Operandi Tinted (protesilaos.com/emacs/modus-themes,
# GPL-3.0 as software; built for WCAG AAA, 7:1 between foreground and
# background). Warm paper, black ink, and Modus green as the one accent: the
# ledger green in place of the house rust.
# Adapted to the house tokens; changes from the source are marked "fitted"
# (palettes/contrast.clj). Contrast: utm-arch wiki/colour-schemes.md.
{
  mode = "light";
  source = "Modus Operandi Tinted, protesilaos.com/emacs/modus-themes; ANSI after Ghostty's bundled Modus Operandi Tinted";
  colours = {
    linen = "#efe9dd";      # bg-dim
    white = "#fbf7f0";      # bg-main
    ink = "#000000";        # fg-main
    rust = "#006800";       # green, the accent
    graphite = "#595959";   # fg-dim
    dim = "#a6a6a6";        # the port's ANSI 7: quiet text on the black bar
    muted = "#595959";      # fg-dim
    teal = "#721045";       # magenta, split indicator
    rustLight = "#44bc44";  # Modus Vivendi's green, the accent on the black bar
    rustBright = "#44bc44"; # (no surface uses this token today)
  };
  # Mixed from the card towards red, green and the accent (contrast.clj mix).
  tints = {
    linenDeep = "#dcd6cb";
    rustPale = "#eccbc5";
    rustPaler = "#f3e1da";
    rustWord = "#db9995";
    olivePale = "#ceddc5";
    olivePaler = "#e4eada";
    oliveWord = "#9cc195";
    selection = "#c4d8bb";
  };
  # The port's colours; 7 is fg-dim (the port's #a6a6a6 is 2.3 on the card) and
  # 15 is black (the port's #595959), so both read on paper.
  ansi = [
    "#000000" "#a60000" "#006800" "#6f5500" "#0031a9" "#721045" "#005e8b" "#595959"
    "#8f8f8f" "#972500" "#00663f" "#884900" "#3548cf" "#531ab6" "#005f5f" "#000000"
  ];
  # 8: the port has #595959 (the same as 7); here the port's #a6a6a6, fitted to 3.
}
