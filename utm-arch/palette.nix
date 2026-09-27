# The palettes for the utm-arch VM desktop, in one place (Omarchy's trick: one
# colours file drives every surface). The house style is invariant I23 of the
# assistant repo: linen, white, ink, one rust accent, 1.5px black borders, the HN
# faces, uppercase letter-spaced labels. Which colour goes where, and why:
# ~/common/projects/utm-arch/wiki/utm-theme.md; the alternatives, their sources and
# their contrast: wiki/colour-schemes.md.
#
# Each palette is a file in palettes/ with the same tokens, so every surface works
# with any of them. The token names are roles, named after the house colours: in a
# dark palette `white` (the card) is dark and `ink` (text and lines) is light.
#
#   linen      the ground: desktop, gaps, input rows, message backgrounds
#   white      cards: the terminal, rofi's list, notifications; text on the accent
#   ink        text on cards and ground, borders, the bar, unfocused title bars
#   rust       the one accent: "here" (focus, selection, critical)
#   graphite   focused-but-inactive windows, bar separators
#   dim        quiet text on ink (unfocused titles, idle workspaces)
#   muted      quiet text on white or linen
#   teal       i3's split indicator only
#   rustLight  the accent as it reads on ink (warnings on the bar)
#   rustBright a brighter accent on ink (errors on the bar)
#   tints      pale grounds for Claude Code's diffs, selection and hover
#   ansi       the terminal's 16 colours, all readable on `white`
#   mode       "light" or "dark": the Claude Code theme's base preset
#
# This file selects the default (`default` below), which every plain
# `home-manager switch` applies; the others are Home Manager specialisations,
# switched with `house-theme` (utm-arch/theme.nix). utm-home.nix fills the
# @token@ placeholders in the files under utm-arch/ and the configs it writes
# itself from the chosen palette. Hex values live only in palettes/*.nix.
let
  default = "house";

  # The same for every palette.
  shared = {
    # One border width everywhere, Omarchy's 2 (the nearest whole number to the
    # house 1.5px). i3 counts its border and gap sizes in logical pixels and doubles
    # them at the VM's 2x (Xft.dpi 192): `border` is for i3. rofi and dunst count
    # real pixels: `borderPx` is the same line for them.
    border = 2;
    borderPx = 4;
    # Omarchy's gaps: 5 between windows, 10 at the screen edge (i3 adds the outer
    # gap to the inner one there: 5 + 5). Logical pixels, as border.
    gaps = {
      inner = 5;
      outer = 5;
    };
    fonts = {
      sans = "HN";                      # the house Helvetica Neue (build/hn-fonts.sh)
      mono = "RobotoMono Nerd Font";    # every mono surface, and the bar's icons
    };
  };

  make = name: p: shared // p // {
    inherit name;
    # Colours without the '#', for configs that want bare hex.
    bare = builtins.mapAttrs (_: c: builtins.substring 1 6 c) p.colours;
  };

  palettes = builtins.mapAttrs make {
    house = import ./palettes/house.nix;
    flexoki = import ./palettes/flexoki.nix;
    modus = import ./palettes/modus.nix;
    dawn = import ./palettes/dawn.nix;
    flexoki-dark = import ./palettes/flexoki-dark.nix;
  };
in
# The default palette itself, plus every palette by name.
palettes.${default} // { inherit palettes default; }
