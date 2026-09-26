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

  # Pale tints for backgrounds on white (Claude Code's diffs, selections, hover):
  # the olive and rust of the ANSI set, mixed towards white.
  tints = {
    linenDeep = "#e2d9d1";     # linen one step darker: hover
    rustPale = "#f5dcd2";      # removed lines
    rustPaler = "#f9ece6";     # removed lines, dimmed
    rustWord = "#e9b39c";      # removed words
    olivePale = "#e4ebcf";     # added lines
    olivePaler = "#f0f3e5";    # added lines, dimmed
    oliveWord = "#c9d79c";     # added words
    selection = "#f0d5c9";     # mouse selection
  };

  # 16 ANSI colours for the terminal, which is white with ink text (a light ground,
  # as the house pages, and the one the Claude Code light theme is drawn for).
  # Modelled on Omarchy's flexoki-light (muted red, ochre, olive, teal, blue,
  # plum), with red swapped for the house rust; white and bright white are dark
  # enough to read on white.
  ansi = [
    "#111111" "#a9431e" "#5e700a" "#9a6a00" "#205ea6" "#8e2f63" "#1f7a72" "#6b645e"
    "#8c8580" "#c4562e" "#768a2a" "#b8860b" "#3f78b0" "#b24d82" "#2f9a90" "#111111"
  ];

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
