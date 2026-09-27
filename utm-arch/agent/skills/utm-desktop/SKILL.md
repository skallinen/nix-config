---
name: utm-desktop
description: How the utm-arch VM desktop (i3 on X11, bar, rofi, dunst, Ghostty, btop, the Claude Code theme) is configured and changed. Use when asked to restyle, fix or extend the desktop of this VM, add a key, a bar block, a menu entry or a notification.
---

# The utm-arch desktop

This VM is Arch Linux ARM in UTM on Sami's Mac. `sakalli` is Sami's desktop user;
you run as `agent`, which cannot read his home (D16) and has no sudo. So you never
apply a desktop change yourself: you edit a clone of `skallinen/nix-config` on a
branch, push the branch, and Sami reviews and applies it. Plan first, then edit.

## Where things live

Everything is in `nix-config` (public on GitHub: no secrets, no licensed fonts).

| What | File |
|---|---|
| Colours, border width, gaps, fonts, ANSI colours, tints | `utm-arch/palette.nix` (the only place colours are written) |
| i3: keys, borders, gaps, bar block, window rules | `utm-arch/i3-config` (`@token@` placeholders filled from the palette) |
| rofi theme | `utm-arch/rofi-theme.rasi`; its settings in `utm-home.nix` (`rofi/config.rasi`) |
| Ghostty | `utm-arch/ghostty-config` |
| dunst (notifications), btop, the bar blocks (i3blocks), house scripts (`agent-open`, `house-menu`, `house-menu-actions`, `house-shot`, `house-ocr`, `house-dnd`, `vdagent-restart`) | `utm-home.nix` |
| The Claude Code theme | `claudeTheme` in `utm-home.nix`, written to `~/.claude/themes/house.json` |
| agent's side: notification hook, status line, launcher, this skill | `utm-arch/agent/`; installed as root by `build/agent-desktop.sh` in the `utm-arch` repo |

`utm-home.nix` fills `@token@` in the files above with `themed`; a new colour goes into
`palette.nix` first, then is used by name. Never write a hex value anywhere else.

## The house style (invariant I23 of Sami's assistant repo)

Linen `#EEE7E1` ground, white cards, ink `#111111` text and lines, **one** accent,
rust `#a9431e`, which means "here" (focus, selection, critical). One border width
everywhere (`border` for i3, which doubles it at 2x; `borderPx` for rofi and dunst).
Square corners, no shadows, no blur, no gradients, no animation. HN (Helvetica Neue)
for labels, uppercase and letter-spaced; RobotoMono Nerd Font for anything mono and for
icons. The bar hides every block that has nothing to say. No em dashes in any text.

## How Sami applies a change

```sh
cd ~/nix-config && git pull --ff-only mac main
home-manager switch --flake ~/nix-config#sakalli@utm
i3-msg reload                              # i3, the bar
systemctl --user restart dunst             # notifications
sudo bash ~/mac/common/projects/utm-arch/build/agent-desktop.sh   # agent's side
```

## Traps already found

- i3 counts border and gap sizes in logical pixels and doubles them (Xft.dpi 192);
  rofi and dunst do not.
- Ghostty is single instance: a new window of a running Ghostty keeps the old config.
  New colours show after all Ghostty windows are closed, or in a window with its own
  `--class` (the agent window uses `house.agent`).
- dunst without a compositor draws gaps between cards black: keep `gap_size = 0`.
- Claude Code hooks have no controlling terminal: `/dev/tty` fails, write to the
  pty of the Claude Code process (see `claude-notify`).
- Never restart Xorg, never stop or suspend the VM, never quit UTM. Restart the SPICE
  session agent only with `vdagent-restart`.

## Decisions not to reopen (utm-arch `DECISIONS.md`)

- D3: i3 on X11 (not Sway, Hyprland or Omarchy itself).
- D1, D17: Super (the Mac's Command) belongs to i3 only; apps use Ctrl and Alt; no
  key remapper; layouts `us,fi` switched with both Shift keys. Do not rebind existing
  keys (Super+Space is `focus mode_toggle`).
- D7, D16, D21: agent runs Claude Code, in auto mode, behind the egress firewall;
  agent never reads sakalli's home; no bypass mode outside the firewall.
- D9, D10: no GL, 8 GB, 4 cores: no compositor (picom), no local models.
- D12, D13, D24: pacman only for the base (Xorg, i3, i3lock, PAM, audio, guest tools);
  everything else from Nix through Home Manager. A new program goes into `home.packages`
  in `utm-home.nix`; pacman or the AUR only when the Nix route is difficult, with the
  reason in a comment. Check nixpkgs first (`nix eval` the attribute).
  Claude Code is the exception: it updates itself, so it comes from the native installer
  in `~/.local/bin`, never from Nix.
- D20: autologin, `startx`, session setup in `~/.xinitrc`.
- The house style above: one accent, no image wallpapers, no rounded corners.

Background: `~/common/projects/utm-arch/wiki/utm-theme.md` (Sami's side of the share)
and `research/omarchy-looks-and-ai.md` in the utm-arch repo, which `agent` has cloned
at `~/src/utm-arch`.
