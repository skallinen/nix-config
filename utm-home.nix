# Home Manager for sakalli in the utm-arch VM: Arch Linux ARM (aarch64) in UTM on
# the Mac. Standalone Home Manager, `homeConfigurations."sakalli@utm"` in flake.nix,
# on top of shared-home.nix. The pacman side (kernel, Xorg, i3, PAM, audio, guest
# tools) is ~/common/projects/utm-arch/pacman.txt; this file is everything else.
#
# Switch inside the VM:  home-manager switch --flake ~/nix-config#sakalli@utm
{ config, pkgs, lib, ... }:

let
  # The house palette (utm-arch/palette.nix): every surface reads its colours,
  # border width, gaps and fonts from there. `themed` fills a file's @token@
  # placeholders (@ink@, @border@, @gap_inner@, @font_sans@ ...) from it.
  palette = import ./utm-arch/palette.nix;
  tokens = palette.colours // {
    border = toString palette.border;
    border_px = toString palette.borderPx;
    gap_inner = toString palette.gaps.inner;
    gap_outer = toString palette.gaps.outer;
    font_sans = palette.fonts.sans;
    font_mono = palette.fonts.mono;
  }
  # @ansi_dark_0@ to @ansi_dark_15@, @ansi_light_0@ to @ansi_light_15@
  // builtins.listToAttrs (lib.imap0 (i: c: { name = "ansi_dark_${toString i}"; value = c; }) palette.ansi.dark)
  // builtins.listToAttrs (lib.imap0 (i: c: { name = "ansi_light_${toString i}"; value = c; }) palette.ansi.light);
  themed = file: builtins.replaceStrings
    (map (n: "@${n}@") (builtins.attrNames tokens))
    (builtins.attrValues tokens)
    (builtins.readFile file);
in
{
  home.username = "sakalli";
  home.homeDirectory = "/home/sakalli";

  # Nix programs on a non-NixOS host: XDG_DATA_DIRS for launchers, terminfo, and
  # targets.genericLinux.gpu (on by default here), which links Nix's mesa to
  # /run/opengl-driver. That one step needs root: the first switch prints
  #   sudo /nix/store/...-non-nixos-gpu/bin/non-nixos-gpu-setup
  # and it must run again whenever a nixpkgs bump changes mesa.
  targets.genericLinux.enable = true;

  # Fonts from home.packages are only found by fontconfig with this on.
  fonts.fontconfig.enable = true;
  # The Mac's pair (myinit.org): RobotoMono Nerd Font for code, Helvetica for
  # prose. Helvetica here is HN, the house Helvetica Neue from the assistant repo,
  # which build/hn-fonts.sh copies in (not from Nix: licensed to Sami, and this
  # repo is public). Until it runs, sans-serif falls back to fontconfig's default.
  fonts.fontconfig.defaultFonts = {
    monospace = [ "RobotoMono Nerd Font" ];
    sansSerif = [ "HN" ];
  };
  xdg.configFile."fontconfig/conf.d/60-hn.conf".source = ./utm-arch/fontconfig-hn.conf;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ghostty                  # Super+Return; ALARM has no ghostty package
    rofi                     # Super+D, `rofi -show run` as on Margaret
    nerd-fonts.roboto-mono   # same as the Macs' fonts.packages
    nerd-fonts.meslo-lg      # alacritty's font in shared-home.nix
    fira-code-symbols        # fira-code-mode in myinit.org (Linux only)
    xkblayout-state          # the Emacs mode line shows the layout (Linux branch)
    xsetroot                 # i3 paints the linen desktop with it
    # Session half of the SPICE agent, run from ~/.xinitrc (the daemon stays the
    # pacman one). Patched: 0.23.0 gives the modes it creates a pixel clock 1000
    # times too low, and since Linux 6.19 virtio-gpu paces vblank by that clock, so
    # one frame takes about 17 s and Xorg freezes on a window resize (vd_agent
    # issue 52; utm-arch wiki/utm-display.md). GTK 3 as in Arch's build.
    (spice-vdagent.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./utm-arch/spice-vdagent-dotclock-hz.patch ];
      buildInputs = old.buildInputs ++ [ gtk3 ];
    }))
    # Restart the session agent by hand (after a switch, say) from anywhere, ssh
    # included. It must run in the tty1 login session: spice-vdagentd talks only to
    # the agent of the active logind session, and with none there it closes the
    # virtio port, so UTM sees no agent and sends no size or clipboard. Started from
    # ssh it lands in the ssh session (that happened 2026-09-26), so go through i3.
    (writeShellScriptBin "vdagent-restart" ''
      # ~/.xinitrc imports the X session's DISPLAY into the systemd user manager.
      eval "export $(systemctl --user show-environment | grep '^DISPLAY=')"
      pkill -x spice-vdagent
      sleep 1
      i3-msg -q exec "$HOME/.nix-profile/bin/spice-vdagent"
    '')
  ];

  # btop in the house colours on the ink terminal: linen text, rust for "here" and
  # for the hot end of every graph, graphite box lines.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "house";
      theme_background = false;   # the terminal's own ink ground
      rounded_corners = false;    # square, as every other surface
    };
    themes.house = with palette.colours; ''
      theme[main_bg]="${ink}"
      theme[main_fg]="${linen}"
      theme[title]="${linen}"
      theme[hi_fg]="${rustLight}"
      theme[selected_bg]="${rust}"
      theme[selected_fg]="${white}"
      theme[inactive_fg]="${muted}"
      theme[graph_text]="${dim}"
      theme[meter_bg]="${graphite}"
      theme[proc_misc]="${dim}"
      theme[cpu_box]="${graphite}"
      theme[mem_box]="${graphite}"
      theme[net_box]="${graphite}"
      theme[proc_box]="${graphite}"
      theme[div_line]="${graphite}"
      theme[temp_start]="${dim}"
      theme[temp_mid]="${linen}"
      theme[temp_end]="${rust}"
      theme[cpu_start]="${dim}"
      theme[cpu_mid]="${linen}"
      theme[cpu_end]="${rustLight}"
      theme[free_start]="${muted}"
      theme[free_mid]="${dim}"
      theme[free_end]="${linen}"
      theme[cached_start]="${muted}"
      theme[cached_mid]="${dim}"
      theme[cached_end]="${linen}"
      theme[available_start]="${muted}"
      theme[available_mid]="${dim}"
      theme[available_end]="${linen}"
      theme[used_start]="${dim}"
      theme[used_mid]="${rustLight}"
      theme[used_end]="${rust}"
      theme[download_start]="${muted}"
      theme[download_mid]="${dim}"
      theme[download_end]="${linen}"
      theme[upload_start]="${muted}"
      theme[upload_mid]="${dim}"
      theme[upload_end]="${rustLight}"
      theme[process_start]="${dim}"
      theme[process_mid]="${linen}"
      theme[process_end]="${rustLight}"
    '';
  };

  programs.emacs = {
    enable = true;
    package = pkgs.emacs;    # X11 (GTK) build: the guest runs i3 on X11 (D3)
    # vterm with its compiled module; myinit.org tells straight not to clone it
    # on Linux (straight-built-in-pseudo-packages).
    extraPackages = epkgs: [ epkgs.vterm ];
  };

  # The Emacs daemon as the systemd user service emacs.service (D19). Its first
  # start clones and builds every straight.el package, which takes far longer
  # than systemd's default 90 s start timeout.
  services.emacs = {
    enable = true;
    client.enable = true;
  };
  systemd.user.services.emacs.Service.TimeoutStartSec = "30min";

  # Login shell is bash (from pacman). Home Manager owns ~/.profile, ~/.bash_profile
  # and ~/.bashrc so the Nix and session variables reach X and i3.
  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    # Autologin lands on tty1 (D20); start X there and nowhere else.
    profileExtra = ''
      if [ -z "$DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
        exec startx
      fi
    '';
  };

  home.file.".xinitrc" = {
    source = ./utm-arch/xinitrc;
    executable = true;
  };
  home.file.".Xresources".source = ./utm-arch/Xresources;
  xdg.configFile."i3/config".text = themed ./utm-arch/i3-config;
  xdg.configFile."ghostty/config.ghostty".text = themed ./utm-arch/ghostty-config;
  xdg.configFile."i3status/config".text = themed ./utm-arch/i3status-config;
  xdg.configFile."rofi/house.rasi".text = themed ./utm-arch/rofi-theme.rasi;
  # rofi ignores Xft.dpi, and rofi 2.0's dpi 1 (the monitor's size) gave 96 on
  # 2026-09-26 (screenshot in utm-arch research/theme/), so the 2x of
  # utm-arch/Xresources is given as a number. The theme is the house style
  # (utm-arch/rofi-theme.rasi); the prompt is an uppercase label.
  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
      dpi: 192;
      display-run: "RUN";
      display-drun: "APPS";
      display-window: "WINDOWS";
    }
    @theme "house"
  '';
}
