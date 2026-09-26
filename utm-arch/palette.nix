# The house palette for the utm-arch VM desktop, in one place (Omarchy's trick: one
# colours file drives every surface). The house style is invariant I23 of the
# assistant repo: linen, white, ink, one rust accent, 1.5px black borders, the HN
# faces, uppercase letter-spaced labels. Which colour goes where, and why:
# ~/common/projects/utm-arch/wiki/utm-theme.md.
#
# utm-home.nix imports this and fills the @token@ placeholders in the files under
# utm-arch/ (i3-config, rofi-theme.rasi, ghostty-config, i3status-config) and the
# configs it writes itself (dunst, btop, the Claude Code theme, the bar). Change a
# colour here, switch, reload: every surface follows.
rec {
  colours = {
    linen = "#EEE7E1";    # the ground: desktop, gaps, input rows, message backgrounds
    white = "#ffffff";    # cards: rofi list, notifications, the agent terminal
    ink = "#111111";      # text on light, borders, the bar, the shell terminal
    rust = "#a9431e";     # the one accent: "here" (focus, selection, critical)
    graphite = "#333333"; # focused-but-inactive windows, bar separators
    dim = "#8c8580";      # quiet text on ink (unfocused titles, idle workspaces)
    muted = "#6b645e";    # quiet text on white or linen (dim is too light there)
    teal = "#02789C";     # kept from the M3800 theme: i3's split indicator only
    rustLight = "#d9825f"; # rust tint that reads on ink (warnings on the bar)
    rustBright = "#e2572a"; # brighter rust on ink (errors on the bar)
  };

  # 16 ANSI colours. Modelled on Omarchy's flexoki-light and flexoki (muted red,
  # ochre, olive, teal, blue, plum), with red swapped for the house rust.
  ansi = {
    # On the white agent terminal (the Claude Code light theme needs a light ground).
    light = [
      "#111111" "#a9431e" "#5e700a" "#9a6a00" "#205ea6" "#8e2f63" "#1f7a72" "#6b645e"
      "#8c8580" "#c4562e" "#768a2a" "#b8860b" "#3f78b0" "#b24d82" "#2f9a90" "#EEE7E1"
    ];
    # On the ink shell terminal.
    dark = [
      "#333333" "#d9825f" "#99ab4a" "#d8ae3a" "#5e97c9" "#d576a6" "#4fb5ab" "#cfc8c2"
      "#6b645e" "#e2572a" "#b0c25c" "#e6c25a" "#7fb0dc" "#e391ba" "#6fcbc1" "#ffffff"
    ];
  };

  # One border width everywhere, Omarchy's 2 (the nearest whole number to the house
  # 1.5px). i3 counts its border and gap sizes in logical pixels and doubles them
  # at the VM's 2x (Xft.dpi 192): `border` is for i3. rofi and dunst count real
  # pixels: `borderPx` is the same line for them.
  border = 2;
  borderPx = 4;
  # Omarchy's gaps: 5 between windows, 10 at the screen edge (i3 adds the outer gap
  # to the inner one there: 5 + 5). Logical pixels, as border.
  gaps = {
    inner = 5;
    outer = 5;
  };

  fonts = {
    sans = "HN";                      # the house Helvetica Neue (build/hn-fonts.sh)
    mono = "RobotoMono Nerd Font";    # every mono surface, and the bar's icons
  };

  # Colours without the '#', for configs that want bare hex.
  bare = builtins.mapAttrs (_: c: builtins.substring 1 6 c) colours;
}
