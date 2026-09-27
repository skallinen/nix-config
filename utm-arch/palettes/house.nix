# house: the house style itself (invariant I23 of the assistant repo, after
# 8-bit-sheep.com): linen ground, white cards, ink, one rust accent. The default.
# Token roles are described in ../palette.nix; contrast figures in utm-arch
# wiki/colour-schemes.md.
{
  mode = "light";
  source = "8-bit-sheep.com and the assistant repo's I23; ANSI after Omarchy's flexoki-light";
  colours = {
    linen = "#EEE7E1";
    white = "#ffffff";
    ink = "#111111";
    rust = "#a9431e";
    graphite = "#333333";
    dim = "#8c8580";
    muted = "#6b645e";
    teal = "#02789C";
    rustLight = "#d9825f";
    rustBright = "#e2572a";
  };
  tints = {
    linenDeep = "#e2d9d1";
    rustPale = "#f5dcd2";
    rustPaler = "#f9ece6";
    rustWord = "#e9b39c";
    olivePale = "#e4ebcf";
    olivePaler = "#f0f3e5";
    oliveWord = "#c9d79c";
    selection = "#f0d5c9";
  };
  # Modelled on Omarchy's flexoki-light (muted red, ochre, olive, teal, blue,
  # plum), with red swapped for the house rust; white and bright white are dark
  # enough to read on white.
  ansi = [
    "#111111" "#a9431e" "#5e700a" "#9a6a00" "#205ea6" "#8e2f63" "#1f7a72" "#6b645e"
    "#8c8580" "#c4562e" "#768a2a" "#b8860b" "#3f78b0" "#b24d82" "#2f9a90" "#111111"
  ];
}
