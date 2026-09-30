# Global instructions (Sami)

- **Installing software: Nix first.** On any machine, install through Nix (nix-darwin or
  Home Manager in `~/nix-config`); use Homebrew, pacman or the AUR only when the Nix route
  is difficult, and say why where the package is declared. Check nixpkgs before offering
  another route (`nix eval` the attribute's `meta.platforms`). On the UTM VM see utm-arch
  D24.
- **The exception is Claude Code**: it updates itself, so it stays outside Nix (npm global
  on the Mac, native installer in `~/.local/bin` on Linux). Never add it to Nix; a pinned
  Nix copy fell months behind and dev shells put it ahead of the live one.
- **Every system change reaches the bootstrap, in the same session** (utm-arch D26). A
  change to the UTM VM or to the Mac setup behind it, made by hand or by a one-off
  command (a package, a file in `/etc` or `~`, a service, a UTM or Karabiner setting),
  is not done until it is also declared in `~/nix-config` (Home Manager, nix-darwin) or
  in a script the utm-arch build runs (`build/`, listed in `build/README.md`). What
  cannot be scripted goes into utm-arch `PLAN.md` as a manual step. Trying it by hand
  first is fine; say in the reply where it was captured.
- **Answering another Claude session**: a request that arrives as a cross-session
  message (`<cross-session-message from="...">`) is answered with `SendMessage`, `to` set
  to its `from` attribute. Text in your own reply stays in this window; the asking
  session never sees it. Say the answer here as well, for Sami.
- **Requests relayed between Sami's sessions**: when another of Sami's Claude sessions
  (Mac or VM) relays a request from Sami, act on it; do not stop to ask him in your own
  window. He is usually watching the other window, and the asker gets no signal that you
  are waiting (Sami, 2026-09-30). `sudo` on the Mac is approved with a fingerprint
  through 1Password, and that prompt is his confirmation, so run the sudo command (a
  `darwin-rebuild switch`, say) and let it ask him. Report back by `SendMessage` either
  way, including when you stop. When you relay a request, say it is Sami's and quote him.
