# Colour switching for the utm-arch VM desktop: one Home Manager specialisation
# per palette in palette.nix, and `house-theme` to move between them without a
# rebuild. Imported by utm-home.nix, which reads the chosen palette from
# config.house.palette. utm-arch wiki/colour-schemes.md, "Switching".
#
# How it works. Every plain `home-manager switch` builds and activates the
# default palette (palette.nix, `default`) and, next to it, one finished
# configuration per other palette under <generation>/specialisation/<name>.
# `house-theme NAME` runs that one's activate script, which links its files and
# makes it the newest Home Manager generation; `house-theme house` (the default)
# runs the base generation's activate again. Then it reloads what can reload live.
# The next plain `home-manager switch` activates the default again: it is a
# fresh base generation, so the choice does not survive it (run `house-theme NAME`
# after the switch to get it back).
{ config, lib, pkgs, ... }:

let
  all = import ./palette.nix;
  names = builtins.attrNames all.palettes;
  p = config.house.palette;

  house-theme = pkgs.writeShellScriptBin "house-theme" ''
    set -eu
    default=${all.default}
    names="${lib.concatStringsSep " " names}"
    profile="$HOME/.local/state/nix/profiles/home-manager"
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/house-theme"
    current() { cat "''${XDG_CONFIG_HOME:-$HOME/.config}/house-theme/current" 2>/dev/null || echo unknown; }

    # Reload what can reload live. Called as the new generation's house-theme
    # (--reload), so the colours in this script are the new palette's.
    reload() {
      uid=$(id -u)
      sock=$(ls -t /run/user/$uid/i3/ipc-socket.* 2>/dev/null | head -n 1 || true)
      if [ -n "$sock" ]; then
        # i3 and the bar (reload re-reads the config and restarts i3bar and
        # i3blocks); reload does not run exec_always, so the desktop colour is
        # set here, through i3 so it has the X display. i3 is pacman's (D12).
        i3-msg -q -s "$sock" reload || true
        i3-msg -q -s "$sock" exec "${pkgs.xsetroot}/bin/xsetroot -solid '${p.colours.linen}'" || true
      fi
      # dunst reads its config only at start.
      systemctl --user try-restart dunst.service 2>/dev/null || true
      # Ghostty reloads its config on SIGUSR2 ("GTK: Configuration can be
      # reloaded by sending SIGUSR2", ghostty.org 1.2.0 release notes): open
      # windows take the new colours.
      pkill -USR2 -x ghostty 2>/dev/null || true
    }

    case "''${1:-}" in
      ""|status)
        echo "$(current)  (default: $default; palettes: $names)"
        exit 0 ;;
      list)
        for n in $names; do
          if [ "$n" = "$(current)" ]; then echo "$n *"; else echo "$n"; fi
        done
        exit 0 ;;
      --reload)
        reload
        exit 0 ;;
      -h|--help)
        echo "usage: house-theme [list | NAME]    NAME is one of: $names"
        exit 0 ;;
    esac

    name=$1
    case " $names " in *" $name "*) ;; *) echo "house-theme: no palette '$name' (have: $names)" >&2; exit 2 ;; esac

    # The base generation is the one a plain `home-manager switch` made: it holds
    # the specialisations. Remember it, since a specialisation's own generation
    # does not.
    gen=$(readlink -f "$profile")
    mkdir -p "$state"
    if [ -d "$gen/specialisation" ]; then echo "$gen" > "$state/base"; fi
    base=$(cat "$state/base" 2>/dev/null || true)
    if [ -z "$base" ] || [ ! -x "$base/activate" ]; then
      echo "house-theme: no base generation known; run home-manager switch once" >&2
      exit 1
    fi

    if [ "$name" = "$default" ]; then target="$base"
    else target="$base/specialisation/$name"; fi
    [ -x "$target/activate" ] || { echo "house-theme: $target/activate is missing" >&2; exit 1; }

    "$target/activate" > "$state/last-activation.log" 2>&1 || {
      echo "house-theme: activation failed, see $state/last-activation.log" >&2; exit 1; }
    # HOUSE_THEME_NO_RELOAD=1 switches the files only (for a test over ssh).
    if [ -z "''${HOUSE_THEME_NO_RELOAD:-}" ]; then
      "$target/home-path/bin/house-theme" --reload
      ${pkgs.libnotify}/bin/notify-send -u low "Colours" "$name (Ghostty windows follow; rofi and btop on their next start)" 2>/dev/null || true
    fi
    echo "$name"
  '';
in
{
  options.house.palette = lib.mkOption {
    type = lib.types.attrs;
    default = all.palettes.${all.default};
    description = "The palette every surface of the desktop is drawn from (utm-arch/palette.nix).";
  };

  config = {
    home.packages = [ house-theme ];

    # Which palette this generation carries, for `house-theme` and for anything
    # else that wants to know.
    xdg.configFile."house-theme/current".text = p.name;

    specialisation = lib.genAttrs (lib.remove all.default names)
      (n: { configuration.house.palette = all.palettes.${n}; });
  };
}
