# Home Manager for sakalli in the utm-arch VM: Arch Linux ARM (aarch64) in UTM on
# the Mac. Standalone Home Manager, `homeConfigurations."sakalli@utm"` in flake.nix,
# on top of shared-home.nix. The pacman side (kernel, Xorg, i3, PAM, audio, guest
# tools) is ~/common/projects/utm-arch/pacman.txt; this file is everything else.
#
# Switch inside the VM:  home-manager switch --flake ~/nix-config#sakalli@utm
{ config, pkgs, lib, unstable, ... }:

let
  # The palette (utm-arch/palette.nix, chosen by utm-arch/theme.nix: the default
  # here, another one in each specialisation): every surface reads its colours,
  # border width, gaps and fonts from there. `themed` fills a file's @token@
  # placeholders (@ink@, @border@, @gap_inner@, @font_sans@ ...) from it.
  palette = config.house.palette;
  tokens = palette.colours // {
    border = toString palette.border;
    border_px = toString palette.borderPx;
    gap_inner = toString palette.gaps.inner;
    gap_outer = toString palette.gaps.outer;
    font_sans = palette.fonts.sans;
    font_mono = palette.fonts.mono;
  }
  # @ansi_0@ to @ansi_15@
  // builtins.listToAttrs (lib.imap0 (i: c: { name = "ansi_${toString i}"; value = c; }) palette.ansi);
  # The Claude Code theme (house.json), Omarchy's claude.json.tpl idea in the house
  # colours. Format: code.claude.com/docs/en/terminal-config, "Create a custom
  # theme": a file in ~/.claude/themes/, selected as "custom:house". The light
  # preset underneath, so tokens not set here fall back to it. build/agent-desktop.sh
  # in utm-arch copies the same file to agent.
  claudeTheme = with palette.colours; with palette.tints; builtins.toJSON {
    name = if palette.name == "house" then "House" else "House (${palette.name})";
    base = palette.mode;        # "light" or "dark", from the palette
    overrides = {
      claude = rust;              # the accent: spinner, assistant label
      claudeShimmer = rustLight;
      text = ink;
      inverseText = white;
      inactive = muted;
      inactiveShimmer = dim;
      subtle = dim;
      suggestion = rust;
      permission = ink;           # dialog borders: the house's black line
      permissionShimmer = muted;
      promptBorder = ink;
      promptBorderShimmer = muted;
      success = builtins.elemAt palette.ansi 2;   # olive
      warning = builtins.elemAt palette.ansi 3;   # ochre, also the auto mode tag
      error = rust;
      userMessageBackground = linen;
      userMessageBackgroundHover = linenDeep;
      bashMessageBackgroundColor = linen;
      memoryBackgroundColor = linen;
      selectionBg = selection;
      diffAdded = olivePale;
      diffRemoved = rustPale;
      diffAddedDimmed = olivePaler;
      diffRemovedDimmed = rustPaler;
      diffAddedWord = oliveWord;
      diffRemovedWord = rustWord;
      rate_limit_fill = rust;
      rate_limit_empty = linen;
      briefLabelYou = ink;
      briefLabelClaude = rust;
    };
  };
  themed = file: builtins.replaceStrings
    (map (n: "@${n}@") (builtins.attrNames tokens))
    (builtins.attrValues tokens)
    (builtins.readFile file);
  # Sami's files live on the Mac, in ~/mac/utm-arch (the share, D16): the VM disk
  # can be rebuilt, and the Mac backs them up. Lowercase names.
  files = "/home/sakalli/mac/utm-arch";
  userDirs = [ "documents" "downloads" "music" "pictures" "screenshots" "videos" ];
in
{
  # Colour switching: the palette option, one specialisation per palette,
  # `house-theme`.
  imports = [ ./utm-arch/theme.nix ];

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
    # Without an emoji font, web pages showed emoji as text glyphs and empty boxes.
    emoji = [ "Noto Color Emoji" ];
  };
  xdg.configFile."fontconfig/conf.d/60-hn.conf".source = ./utm-arch/fontconfig-hn.conf;

  # Where apps put downloads, documents and pictures (user-dirs.dirs, read by
  # browsers, file dialogs, GTK and Qt): on the Mac, see `files` above. The share
  # is about 36 MB/s and 2.5 ms per file (utm-arch wiki/utm-file-sharing.md,
  # measured 2026-09-30): fine for these, too slow for code and caches, which stay
  # on the VM disk. Desktop is the folder itself; templates, public and projects
  # are not used.
  xdg.userDirs = {
    enable = true;
    desktop = files;
    documents = "${files}/documents";
    download = "${files}/downloads";
    music = "${files}/music";
    pictures = "${files}/pictures";
    videos = "${files}/videos";
    publicShare = null;
    templates = null;
    projects = null;
    extraConfig.SCREENSHOTS = "${files}/screenshots";
  };
  # The folders are made only when the share is mounted. Home Manager's own
  # createDirectories would make them on the VM disk under an unmounted ~/mac,
  # where the Mac never sees them and the mount later hides them.
  home.activation.userDirsOnMac = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ${pkgs.util-linux}/bin/mountpoint -q /home/sakalli/mac; then
      run mkdir -p ${lib.concatMapStringsSep " " (d: "${files}/${d}") userDirs}
    else
      echo "~/mac is not mounted: ${files} not created" >&2
    fi
  '';
  # Short names in the VM home: ~/downloads and so on lead to the Mac folders.
  home.file."documents".source = config.lib.file.mkOutOfStoreSymlink "${files}/documents";
  home.file."downloads".source = config.lib.file.mkOutOfStoreSymlink "${files}/downloads";
  home.file."music".source = config.lib.file.mkOutOfStoreSymlink "${files}/music";
  home.file."pictures".source = config.lib.file.mkOutOfStoreSymlink "${files}/pictures";
  home.file."screenshots".source = config.lib.file.mkOutOfStoreSymlink "${files}/screenshots";
  home.file."videos".source = config.lib.file.mkOutOfStoreSymlink "${files}/videos";

  programs.home-manager.enable = true;

  # Chrome (home.packages) opens links and web pages. Set by hand in the VM on
  # 2026-09-27; Home Manager now owns ~/.config/mimeapps.list.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };

  home.packages = with pkgs; [
    ghostty                  # Super+Return; ALARM has no ghostty package
    rofi                     # Super+D, `rofi -show run` as on Margaret
    nerd-fonts.roboto-mono   # same as the Macs' fonts.packages
    nerd-fonts.meslo-lg      # alacritty's font in shared-home.nix
    fira-code-symbols        # fira-code-mode in myinit.org (Linux only)
    noto-fonts-color-emoji   # fonts.fontconfig.defaultFonts.emoji
    xkblayout-state          # the Emacs mode line shows the layout (Linux branch)
    xsetroot                 # i3 paints the linen desktop with it
    jq                       # utm-arch build/agent-desktop.sh edits agent's settings.json with it
    libnotify                # notify-send, for scripts and the agent's notifications
    i3blocks                 # the bar's status line (i3-config, bar block)
    google-chrome            # the browser; nixpkgs builds it for aarch64-linux (Sami: Nix before pacman or AUR)
    xrandr                   # manual screen settings; moved from pacman (utm-arch D24)
    alsa-utils               # amixer, aplay; moved from pacman (utm-arch D24)
    # OpenAI Codex CLI from nixos-unstable: nixos-26.05 had 0.146.0 (2026-07-29),
    # two months and 12 releases behind; unstable had 0.157.0 against upstream 0.158.0
    # (2026-09-28). Update: `nix flake update nixpkgs-unstable`, then switch. It
    # does not replace itself; its startup update notice can be ignored (utm-arch D25).
    unstable.codex
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
    # Do not disturb (Super+Shift+N): dunst holds notifications while paused and
    # shows them when it resumes. The bar's bell block refreshes on signal 10.
    (writeShellScriptBin "house-dnd" ''
      ${dunst}/bin/dunstctl set-paused toggle
      pkill -RTMIN+10 -x i3blocks || true
    '')
    # Show the keys being pressed, for screencasts and demos (Super+Shift+Y turns
    # screenkey on or off). Nix wraps it, so match the command line, not the name.
    (writeShellScriptBin "house-keys" ''
      if pkill -f '/bin/.screenkey-wrapped|/bin/screenkey' ; then exit 0; fi
      exec ${screenkey}/bin/screenkey --position bottom --font-size medium \
        --bg-color '${palette.colours.ink}' --font-color '${palette.colours.linen}' --opacity 0.85
    '')
    # The agent on one key (Omarchy's omarchy-agent): Super+Shift+A picks one of
    # agent's clones with rofi and opens Claude Code there as agent, in auto mode
    # (D21), in its own Ghostty window; Super+Shift+T also asks for the task.
    # agent-claude runs as agent through a one-command sudoers rule
    # (utm-arch build/agent-desktop.sh).
    (writeShellScriptBin "agent-open" ''
      set -eu
      run() { sudo -n -u agent /usr/local/bin/agent-claude "$@"; }
      projects=$(run --list) || {
        ${libnotify}/bin/notify-send -u critical "Agent" "agent-claude is not installed: run utm-arch build/agent-desktop.sh"
        exit 1
      }
      proj=$(printf '%s\n' "$projects" | ${rofi}/bin/rofi -dmenu -i -no-custom -p AGENT) || exit 0
      [ -n "$proj" ] || exit 0
      task=
      if [ "''${1:-}" = --task ]; then
        task=$(${rofi}/bin/rofi -dmenu -p TASK -l 0 -theme-str 'entry { placeholder: "what should the agent do?"; }' < /dev/null) || exit 0
        [ -n "$task" ] || exit 0
      fi
      exec ${ghostty}/bin/ghostty --class=house.agent -e sudo -n -u agent /usr/local/bin/agent-claude "$proj" ''${task:+"$task"}
    '')
    # Screenshots (Super+Shift+S or the menu): a region, or the whole screen with
    # --screen, to the clipboard and to ~/screenshots (on the Mac, see `files`).
    # With the share not mounted it goes to the clipboard only.
    (writeShellScriptBin "house-shot" ''
      set -eu
      dir="${files}/screenshots"; where="and in ~/screenshots"
      if ! ${util-linux}/bin/mountpoint -q /home/sakalli/mac; then
        dir=$(mktemp -d); where="only: ~/mac is not mounted, nothing saved"
      fi
      mkdir -p "$dir"
      f="$dir/$(date +%Y-%m-%d-%H%M%S).png"
      if [ "''${1:-}" = --screen ]; then ${maim}/bin/maim -u "$f"
      else ${maim}/bin/maim -s -u "$f" || exit 0; fi
      ${xclip}/bin/xclip -selection clipboard -t image/png < "$f"
      ${libnotify}/bin/notify-send -u low "Screenshot" "On the clipboard $where"
    '')
    # Text from the screen (Super+Ctrl+S or the menu; Omarchy's OCR): select a
    # region, tesseract reads it (English and Finnish), the text goes to the
    # clipboard.
    (writeShellScriptBin "house-ocr" ''
      set -eu
      text=$(${maim}/bin/maim -s -u | ${tesseract.override { enableLanguages = [ "eng" "fin" ]; }}/bin/tesseract -l eng+fin stdin stdout 2>/dev/null) || exit 0
      [ -n "''${text//[[:space:]]/}" ] || { ${libnotify}/bin/notify-send -u low "Text from screen" "No text found"; exit 0; }
      printf '%s' "$text" | ${xclip}/bin/xclip -selection clipboard
      ${libnotify}/bin/notify-send -u low "Text from screen" "$(printf '%s' "$text" | head -c 120)"
    '')
    # The menu (Super+Shift+D; Omarchy's Super+Space menu, but that key is i3's
    # focus mode_toggle here): the house actions and every app, filtered as you
    # type. rofi's combi mode over a script mode ("house") and drun. Each action
    # runs through i3, so it outlives rofi.
    (writeShellScriptBin "house-menu-actions" ''
      actions=(
        "Agent: open a project|agent-open"
        "Agent: start with a task|agent-open --task"
        "Terminal|ghostty"
        "Emacs|emacsclient -c"
        "System monitor (btop)|ghostty -e btop"
        "Screenshot: region|house-shot"
        "Screenshot: whole screen|house-shot --screen"
        "Text from screen (OCR)|house-ocr"
        "Keys on screen (screenkey): on or off|house-keys"
        "Notifications: show the last one|dunstctl history-pop"
        "Notifications: close all|dunstctl close-all"
        "Notifications: do not disturb on or off|house-dnd"
        "Lock the screen|i3lock -c ${palette.bare.linen}"
        "Reload i3|i3-msg reload"
        # One entry per palette (utm-arch/theme.nix; the default is the house style).
        ${lib.concatMapStringsSep "\n        " (n: "\"Colours: ${n}|house-theme ${n}\"") (builtins.attrNames (import ./utm-arch/palette.nix).palettes)}
        "Restart the SPICE agent (clipboard, resize)|vdagent-restart"
      )
      if [ $# -eq 0 ]; then
        for a in "''${actions[@]}"; do printf '%s\n' "''${a%%|*}"; done
        exit 0
      fi
      for a in "''${actions[@]}"; do
        if [ "''${a%%|*}" = "$1" ]; then
          i3-msg -q exec "''${a#*|}" >/dev/null
          exit 0
        fi
      done
    '')
    (writeShellScriptBin "house-menu" ''
      exec ${rofi}/bin/rofi -show combi -modi "combi,house:house-menu-actions,drun" \
        -combi-modi "house,drun" -display-combi MENU -combi-hide-mode-prefix
    '')
    (writeShellScriptBin "vdagent-restart" ''
      # ~/.xinitrc imports the X session's DISPLAY into the systemd user manager.
      eval "export $(systemctl --user show-environment | grep '^DISPLAY=')"
      pkill -x spice-vdagent
      sleep 1
      i3-msg -q exec "$HOME/.nix-profile/bin/spice-vdagent"
    '')
  ];

  # btop in the house colours on the white terminal: ink text, rust for "here" and
  # for the hot end of every graph, quiet grey box lines.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "house";
      theme_background = false;   # the terminal's own white ground
      rounded_corners = false;    # square, as every other surface
    };
    themes.house = with palette.colours; ''
      theme[main_bg]="${white}"
      theme[main_fg]="${ink}"
      theme[title]="${ink}"
      theme[hi_fg]="${rust}"
      theme[selected_bg]="${rust}"
      theme[selected_fg]="${white}"
      theme[inactive_fg]="${dim}"
      theme[graph_text]="${muted}"
      theme[meter_bg]="${linen}"
      theme[proc_misc]="${muted}"
      theme[cpu_box]="${dim}"
      theme[mem_box]="${dim}"
      theme[net_box]="${dim}"
      theme[proc_box]="${dim}"
      theme[div_line]="${dim}"
      theme[temp_start]="${muted}"
      theme[temp_mid]="${ink}"
      theme[temp_end]="${rust}"
      theme[cpu_start]="${dim}"
      theme[cpu_mid]="${muted}"
      theme[cpu_end]="${rust}"
      theme[free_start]="${dim}"
      theme[free_mid]="${muted}"
      theme[free_end]="${ink}"
      theme[cached_start]="${dim}"
      theme[cached_mid]="${muted}"
      theme[cached_end]="${ink}"
      theme[available_start]="${dim}"
      theme[available_mid]="${muted}"
      theme[available_end]="${ink}"
      theme[used_start]="${muted}"
      theme[used_mid]="${rustLight}"
      theme[used_end]="${rust}"
      theme[download_start]="${dim}"
      theme[download_mid]="${muted}"
      theme[download_end]="${ink}"
      theme[upload_start]="${dim}"
      theme[upload_mid]="${rustLight}"
      theme[upload_end]="${rust}"
      theme[process_start]="${dim}"
      theme[process_mid]="${muted}"
      theme[process_end]="${rust}"
    '';
  };

  # Notifications (Omarchy's mako, as dunst on X11): top right, a white card in a
  # square ink frame, rust only for critical ones, which also stay until closed.
  # Sizes are Omarchy's at 1x; `scale = 2` doubles them for the VM's 2x.
  # D-Bus starts dunst on the first notification (its service file is in
  # ~/.local/share/dbus-1/services); i3 also starts it with the session.
  # Keys (i3-config): Super+N closes the top one, Super+Shift+N toggles do not
  # disturb, the menu (Super+Shift+D) has the history.
  services.dunst = {
    enable = true;
    settings = with palette.colours; {
      global = {
        scale = 2;
        origin = "top-right";
        offset = "(20, 20)";
        width = 420;
        height = "(0, 300)";
        notification_limit = 5;
        # No gaps between cards: without a compositor the gap is drawn black. One
        # frame-coloured rule between them instead.
        gap_size = 0;
        separator_height = palette.border;
        padding = 12;
        horizontal_padding = 16;
        text_icon_padding = 0;
        frame_width = palette.border;
        frame_color = ink;
        separator_color = "frame";
        corner_radius = 0;
        progress_bar_corner_radius = 0;
        progress_bar_frame_width = 0;
        highlight = rust;
        font = "${palette.fonts.sans} Medium 10";
        markup = "full";
        # The summary as a house label (bold, uppercase, letter-spaced), then the body.
        format = "<span weight='bold' size='small' text_transform='uppercase' letter_spacing='1100'>%s</span>\\n%b";
        alignment = "left";
        vertical_alignment = "top";
        word_wrap = true;
        ellipsize = "end";
        icon_position = "off";
        show_indicators = false;
        mouse_left_click = "close_current";
        mouse_right_click = "close_all";
        mouse_middle_click = "do_action, close_current";
        follow = "none";
        sticky_history = true;
        history_length = 30;
      };
      urgency_low = {
        background = white;
        foreground = muted;
        frame_color = ink;
        timeout = 4;
      };
      urgency_normal = {
        background = white;
        foreground = ink;
        frame_color = ink;
        timeout = 6;
      };
      urgency_critical = {
        background = white;
        foreground = ink;
        frame_color = rust;
        timeout = 0;
      };
    };
  };

  # The bar (Omarchy's "hide what has nothing to say"): i3blocks, one script per
  # block. Only the clock is always there; every other block prints nothing, and
  # so takes no room, until it has something to say. Icons from the Nerd Font,
  # labels uppercase and letter-spaced, linen on the ink bar, the rust tint (the
  # plain rust is too dark on ink) for anything that wants attention.
  xdg.configFile."i3blocks/config".text =
    let
      c = palette.colours;
      label = t: "<span letter_spacing='1100'>${t}</span>";
      block = name: text: pkgs.writeShellScript "bar-${name}" text;
    in ''
      separator=false
      separator_block_width=36
      markup=pango

      # agent's Claude plan: 5-hour and 7-day use, from the file agent's status line
      # writes (build/agent-desktop.sh). Hidden when there is no file or both
      # windows have reset. The file is agent's, so only digits are taken from it.
      [agent]
      interval=30
      command=${block "agent" ''
        f=/var/lib/agent-status/usage
        [ -r "$f" ] || exit 0
        read -r line < "$f" || true
        five= five_reset= seven= seven_reset=
        for kv in $line; do
          v=''${kv#*=}
          [[ $v =~ ^[0-9]+$ ]] || continue
          case $kv in
            five=*) five=$v ;; five_reset=*) five_reset=$v ;;
            seven=*) seven=$v ;; seven_reset=*) seven_reset=$v ;;
          esac
        done
        now=$(date +%s); out=; hot=
        if [ -n "$five" ] && [ "''${five_reset:-0}" -gt "$now" ]; then
          out="$out ${label "5H"} $five%"; [ "$five" -ge 80 ] && hot=1
        fi
        if [ -n "$seven" ] && [ "''${seven_reset:-0}" -gt "$now" ]; then
          out="$out  ${label "7D"} $seven%"; [ "$seven" -ge 80 ] && hot=1
        fi
        [ -n "$out" ] || exit 0
        echo "󰚩$out"; echo "󰚩"
        [ -n "$hot" ] && echo "${c.rustLight}"
        exit 0
      ''}

      # Do not disturb (Super+Shift+N, house-dnd sends signal 10), with how many
      # notifications wait.
      [dnd]
      interval=once
      signal=10
      command=${block "dnd" ''
        [ "$(${pkgs.dunst}/bin/dunstctl is-paused)" = true ] || exit 0
        n=$(${pkgs.dunst}/bin/dunstctl count waiting)
        [ "''${n:-0}" -gt 0 ] || n=
        echo "󰂛 ${label "DND"}''${n:+ $n}"
      ''}

      # The keyboard layout, only when it is not US (both Shift keys switch, D17).
      [layout]
      interval=2
      command=${block "layout" ''
        l=$(${pkgs.xkblayout-state}/bin/xkblayout-state print %s)
        [ "$l" = us ] || echo "󰌌 ${label "\${l^^}"}"
      ''}

      [offline]
      interval=10
      command=${block "offline" ''
        [ -n "$(ip route show default 2>/dev/null)" ] && exit 0
        echo "󰌙 ${label "OFFLINE"}"; echo; echo "${c.rustLight}"
      ''}

      # Disk, memory and load only when they run short.
      [disk]
      interval=60
      command=${block "disk" ''
        read -r pct avail < <(df --output=pcent,avail -h / | tail -n 1)
        [ "''${pct%\%}" -ge 90 ] || exit 0
        echo "󰋊 ${label "DISK"} $avail"; echo; echo "${c.rustLight}"
      ''}

      [memory]
      interval=10
      command=${block "memory" ''
        total=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
        avail=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
        used=$(( (total - avail) * 100 / total ))
        [ "$used" -ge 85 ] || exit 0
        echo "󰍛 ${label "MEM"} $used%"; echo; echo "${c.rustLight}"
      ''}

      [load]
      interval=10
      command=${block "load" ''
        read -r load _ < /proc/loadavg
        [ "''${load%.*}" -ge "$(nproc)" ] || exit 0
        echo "󰓅 ${label "LOAD"} $load"
      ''}

      [clock]
      interval=5
      command=${block "clock" ''
        echo "${label "$(date '+%a %d %b' | tr a-z A-Z)"}  $(date +%H:%M)"
      ''}
    '';

  # agent's half of the desktop, staged here for utm-arch build/agent-desktop.sh,
  # which copies it (as root) to /usr/local/lib/house-agent and agent's home:
  # agent cannot read Nix files in sakalli's home, and the palette lives here.
  home.file.".local/share/house-agent/claude-notify" = {
    source = ./utm-arch/agent/claude-notify;
    executable = true;
  };
  home.file.".local/share/house-agent/claude-statusline" = {
    source = ./utm-arch/agent/claude-statusline;
    executable = true;
  };
  home.file.".local/share/house-agent/agent-claude" = {
    source = ./utm-arch/agent/agent-claude;
    executable = true;
  };
  # The desktop skill (Omarchy's omarchy skill, our own): where the config lives,
  # the house style, the decisions not to reopen. For agent (copied by
  # build/agent-desktop.sh) and for a Claude Code run as sakalli.
  home.file.".local/share/house-agent/skills/utm-desktop/SKILL.md".source =
    ./utm-arch/agent/skills/utm-desktop/SKILL.md;
  home.file.".claude/skills/utm-desktop/SKILL.md".source =
    ./utm-arch/agent/skills/utm-desktop/SKILL.md;

  # Always-loaded instructions for a Claude Code run as sakalli (agent gets the
  # utm-desktop skill above).
  home.file.".claude/CLAUDE.md".text = ''
    # Sami's instructions on the UTM VM

    - **Installing software: Nix first** (utm-arch D12, D13, D24). New programs go into
      `home.packages` in `~/nix-config/utm-home.nix`, then `home-manager switch --flake
      ~/nix-config#sakalli@utm`. pacman or the AUR only when the Nix route is difficult,
      with the reason in a comment. Check nixpkgs first (`nix eval` the attribute).
    - **The one exception is Claude Code**: it updates itself, so it comes from the native
      installer in `~/.local/bin` (utm-arch D24). Never add it to Nix.
    - **Every system change reaches the bootstrap, in the same session** (utm-arch D26).
      A change made by hand or by a one-off command (a package, a file in `/etc` or `~`,
      a service, a UTM or Mac setting) is not done until it is also in `~/nix-config` or
      in a script the utm-arch build runs (`~/mac/common/projects/utm-arch/build/`,
      listed in its README). What cannot be scripted goes into utm-arch `PLAN.md` as a
      manual step. Trying it by hand first is fine; say in the reply where it was captured.
    - **Sami's files are on the Mac** (utm-arch D27): `~/downloads`, `~/documents`,
      `~/pictures`, `~/screenshots` and so on lead to `~/mac/utm-arch/`.
    - **Answering another Claude session**: a request that arrives as a cross-session
      message (`<cross-session-message from="...">`) is answered with `SendMessage`, `to`
      set to its `from` attribute. Text in your own reply stays in this window; the asking
      session never sees it. Say the answer here as well, for Sami.
    - **Requests relayed between Sami's sessions**: when another of Sami's Claude sessions
      (Mac or VM) relays a request from Sami, act on it; do not stop to ask him in your own
      window. He is usually watching the other window, and the asker gets no signal that you
      are waiting (Sami, 2026-09-30). `sudo` on the Mac is approved with a fingerprint
      through 1Password, and that prompt is his confirmation, so run the sudo command (a
      `darwin-rebuild switch`, say) and let it ask him. Report back by `SendMessage` either
      way, including when you stop. When you relay a request, say it is Sami's and quote him.
  '';

  # Claude Code's theme for sakalli: the built-in "dark" (Sami's choice, 2026-09-30).
  # The house theme stays installed for agent (build/agent-desktop.sh copies it) and
  # as "custom:house" in /theme. sakalli's Claude Code comes from the native
  # installer in ~/.local/bin (utm-arch D24: it updates itself, so not from Nix).
  # settings.json stays a normal file, since Claude Code writes to it: the activation only sets "theme".
  home.file.".claude/themes/house.json".text = claudeTheme;
  home.activation.claudeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -z "''${DRY_RUN:-}" ]; then
      f="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"
      [ -s "$f" ] || echo '{}' > "$f"
      ${pkgs.jq}/bin/jq '.theme = "dark"' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  '';

  # The Mac's status line: context size and the 5-hour usage window. The script is a
  # Nix file; settings.json only points at it (same reason as the theme above).
  home.file.".claude/statusline.sh" = {
    source = ./utm-arch/claude-statusline.sh;
    executable = true;
  };
  home.activation.claudeStatusLine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -z "''${DRY_RUN:-}" ]; then
      f="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"
      [ -s "$f" ] || echo '{}' > "$f"
      ${pkgs.jq}/bin/jq '.statusLine = {"type": "command", "command": "~/.claude/statusline.sh"}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  '';

  # Remote Control for every interactive session of sakalli's (Sami, 2026-09-30):
  # the key the /config toggle "Enable Remote Control for all sessions" writes. It
  # lets the VM and Mac sessions message each other (assistant repo
  # wiki/agent-mailbox.md). isolatePeerMachines: every message to a session on
  # another machine waits for Sami's approval here in the VM (Sami, 2026-09-30).
  # The Mac has it off, so the host answers the VM without a prompt. Not for
  # agent, which stays off Remote Control (build/agent-desktop.sh leaves it out).
  # The Mac's settings.json is hand-kept: utm-arch PLAN.md step 24.
  home.activation.claudeRemoteControl = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -z "''${DRY_RUN:-}" ]; then
      f="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"
      [ -s "$f" ] || echo '{}' > "$f"
      ${pkgs.jq}/bin/jq '.remoteControlAtStartup = true | .isolatePeerMachines = true' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  '';

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

  # GitHub over port 443. From the VM, port 22 to github.com hangs at key exchange:
  # something on the path drops packets over about 1230 bytes without a word (ping
  # -M do -s 1200 passes, -s 1400 does not; suspect the Mac's VPN), and ssh.github.com
  # :443 gets through (utm-arch wiki/macbridge.md, 2026-09-27). The host key is pinned
  # here under the alias github.com: GitHub's published ED25519 key, fingerprint
  # SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU.
  # Every ssh from the VM that uses a 1Password key (through the macbridge agent)
  # asks 1Password for approval on the Mac, and its prompt pulls macOS out of the
  # VM's space. One multiplexed connection per host means one approval, then none
  # until it has been idle for ControlPersist (seen 2026-09-27: a watcher polling the
  # Mac every minute kept switching spaces).
  programs.ssh.extraConfig = ''
    Host mac 192.168.64.1
      HostName 192.168.64.1
      User samikallinen
      ControlMaster auto
      ControlPath ~/.ssh/cm-%C
      ControlPersist 4h
    Host github.com
      ControlMaster auto
      ControlPath ~/.ssh/cm-%C
      ControlPersist 30m
      HostName ssh.github.com
      Port 443
      HostKeyAlias github.com
      UserKnownHostsFile ~/.ssh/known_hosts ~/.ssh/known_hosts_github
  '';
  home.file.".ssh/known_hosts_github".text = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';

  home.file.".xinitrc" = {
    source = ./utm-arch/xinitrc;
    executable = true;
  };
  home.file.".Xresources".source = ./utm-arch/Xresources;
  xdg.configFile."i3/config".text = themed ./utm-arch/i3-config;
  xdg.configFile."ghostty/config.ghostty".text = themed ./utm-arch/ghostty-config;
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
