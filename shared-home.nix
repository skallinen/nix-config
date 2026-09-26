{ pkgs, lib, ... }:

{
  # --- Shared Packages (CLI tools, languages, utilities) ---
  home.packages = with pkgs; [
    # Core CLI Essentials (Safe for macOS)
    bat
    coreutils
    curl
    diff-so-fancy
    fd
    fzf
    gh           # GitHub CLI — auth lives in the login keyring, not here
    gnupg
    jq
    ripgrep
    tldr
    tokei
    tree
    wget
    pngpaste
    dotnet-sdk_8

    # CLI Tools for Flutter & Clojure
    flutter
    cocoapods
    clojure
    clj-kondo
    clojure-lsp
    babashka     # runtime for clojure-mcp-light bbin scripts

    # JS/TS Development Toolchain
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.prettier
    prettierd
    tailwindcss-language-server

    # CLI Tools (moved from Homebrew)
    # mpv — kept in Homebrew (nixpkgs build fails versionCheckPhase on macOS)
    sox
    yt-dlp
    ollama
    syncthing
    w3m
    pandoc
    mu
    isync

    # AI Tools
    # claude-code is deliberately NOT here. It is installed as an npm global
    # under Homebrew's node prefix (/opt/homebrew/bin/claude ->
    # ../lib/node_modules/@anthropic-ai/claude-code), which is what its own
    # auto-updater maintains. nixpkgs cannot keep up: this list pinned 2.1.81
    # while the CLI had auto-updated itself to 2.1.224, and because a
    # `nix develop` shell puts /etc/profiles/per-user/<user>/bin ahead of
    # /opt/homebrew/bin, entering any project dev shell silently downgraded
    # `claude` by four months — against a ~/.claude.json already migrated by
    # the new version. Removed 2026-08-07.
    #
    # Note this is NOT the "claude" Homebrew cask in darwin-configuration.nix;
    # that is the desktop app (/Applications/Claude.app) and ships no CLI.
  ];

  # --- Shared Program Configurations ---

  programs.bat = {
    enable = true;
    config.theme = "TwoDark";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza.enable = true;
  programs.git = {
    enable = true;
    settings.user.name  = "Sami Kallinen";
    # Identity follows the directory tree, so the right address is used without
    # a per-repo setting and without depending on remembering to set one.
    includes = [
      {
        condition = "gitdir:~/common/geomatikk/";
        contents.user.email = "sami@kpsystem.se";
      }
    ];
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.alacritty = {
    enable = true;
    settings.font.normal.family = "MesloLGS Nerd Font Mono";
    settings.font.size = 16;
  };

  programs.ssh = {
    enable = true;
    extraConfig = if pkgs.stdenv.isDarwin then ''
      Host *
        IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

      # utm-arch VM (Arch Linux ARM in UTM, Shared network). Address from UTM's DHCP,
      # stable across reboots (checked 2026-09-26).
      Host utm
        HostName 192.168.64.7
        User sakalli
        IdentityFile ~/.ssh/utm_ed25519
        IdentitiesOnly yes

      Host vm
        HostName 192.168.64.2
        User sakalli
        IdentityFile ~/.ssh/id_ed25519_vm_access
        IdentitiesOnly yes
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        ForwardAgent yes
        RemoteForward /home/sakalli/.1password/agent.sock "/Users/samikallinen/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '' else '''';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = if pkgs.stdenv.isDarwin then {
      aerospace = "/opt/homebrew/bin/aerospace"; # the CLI; the app binary rejects list-windows and mode
    } else {};
    initContent = ''
      # Docker Context Switching (macOS only - Docker Desktop)
      if [ "$(uname)" = "Darwin" ] && command -v docker >/dev/null 2>&1; then
        if [ -z "''${DOCKER_HOST:-}" ] && docker context ls >/dev/null 2>&1; then
          cur="$(docker context show 2>/dev/null || true)"
          [ "$cur" != "desktop-linux" ] && docker context use desktop-linux >/dev/null 2>&1 || true
        fi
      fi

      # --- UNIVERSAL NIX SWITCH ---
      # Works on macOS (darwin-rebuild) and NixOS (nixos-rebuild)
      nix-switch() {
        # Local flake path (override with $NIX_SWITCH_LOCAL_FLAKE if you like)
        local local_flake="''${NIX_SWITCH_LOCAL_FLAKE:-$HOME/nix-config}"
        local remote_flake="''${NIX_SWITCH_REMOTE_FLAKE:-github:skallinen/nix-config}"
        local origin="local"
        local host=""
        local target_os=""

        # Detect OS
        if [ "$(uname)" = "Linux" ]; then
          target_os="linux"
        else
          target_os="macos"
        fi

        while [ $# -gt 0 ]; do
          case "$1" in
            --remote) origin="remote"; shift ;;
            --local)  origin="local";  shift ;;
            -h|--help)
              echo "Usage: nix-switch [--local|--remote] [HOST] [extra args]"
              return 0
              ;;
            *)
              if [ -z "$host" ]; then
                host="$1"
                shift
              else
                break
              fi
              ;;
          esac
        done

        # Default hostnames if none provided
        if [ -z "$host" ]; then
          if [ "$target_os" = "linux" ]; then
            host="nixos-vm"
          else
            host="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
          fi
        fi

        # Select flake source
        local flake
        if [ "$origin" = "local" ]; then
          flake="$local_flake"
        else
          flake="$remote_flake"
        fi

        echo "🚀 Switching $target_os to $flake#$host..."

        # Execute correct rebuild command
        if [ "$target_os" = "linux" ]; then
          sudo nixos-rebuild switch --flake "$flake#$host" "$@"
        else
          sudo darwin-rebuild switch --flake "$flake#$host" "$@"
        fi
      }
    '';
  };

  home.file.".mbsyncrc".text = ''
    IMAPAccount gmail
    AuthMechs LOGIN
    Host imap.gmail.com
    User notjustsilicon@gmail.com
    # google app passwords: https://support.google.com/mail/answer/185833?hl=en
    # setting an app passwork: https://myaccount.google.com/apppasswords
    PassCmd "op read op://Private/gmail-mbsync/password"
    TLSType IMAPS
    #CertificateFile /etc/ssl/certs/ca-certificates.crt
    PipeLineDepth 1

    IMAPStore gmail-remote
    Account gmail

    MaildirStore gmail-local
    Subfolders Verbatim
    Path ~/mail/notjust/
    Inbox ~/mail/notjust/Inbox

    Channel gmail
    Far :gmail-remote:
    Near :gmail-local:
    Patterns * ![Gmail]* "[Gmail]/Sent Mail" "[Gmail]/Starred" "[Gmail]/All Mail" "[Gmail]/Trash"
    Create Both
    SyncState *

    IMAPAccount 8-bit
    AuthMechs LOGIN
    Host imap.gmail.com
    User sami@8-bit-sheep.com
    # google app passwords: https://support.google.com/mail/answer/185833?hl=en
    # setting an app passwork: https://myaccount.google.com/apppasswords
    PassCmd "op read op://Private/8bs-gmail-mbsync/password"
    TLSType IMAPS
    #CertificateFile /etc/ssl/certs/ca-certificates.crt
    PipeLineDepth 1

    IMAPStore 8-bit-remote
    Account 8-bit

    MaildirStore 8-bit-local
    Subfolders Verbatim
    Path ~/mail/8-bit/
    Inbox ~/mail/8-bit/Inbox

    Channel 8-bit
    Far :8-bit-remote:
    Near :8-bit-local:
    Patterns * ![Gmail]* "[Gmail]/Sent Mail" "[Gmail]/Starred" "[Gmail]/All Mail" "[Gmail]/Trash"
    Create Both
    SyncState *


    IMAPAccount oderland
    AuthMechs LOGIN
    Host raiden.oderland.com
    User sami@kpsystem.se  # Replace with your actual email address
    PassCmd "op read op://Private/oderland-mbsync/password"  # You'll need to add this password to 1Password
    TLSType IMAPS
    Port 993  # Using the SSL port you mentioned
    PipeLineDepth 1

    IMAPStore oderland-remote
    Account oderland

    MaildirStore oderland-local
    Subfolders Verbatim
    Path ~/mail/oderland/  # You can change this path if you prefer
    Inbox ~/mail/oderland/Inbox

    Channel oderland
    Far :oderland-remote:
    Near :oderland-local:
    Patterns *
    Create Both
    SyncState *
  '';

  
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "zile";
    DOCKER_CONTEXT = "desktop-linux";
    DOTNET_ROOT = "${pkgs.dotnet-sdk_8}/share/dotnet";
  };

  home.sessionPath = [
    "$HOME/.dotnet/tools"
    "$HOME/.local/bin"   # bbin installs clojure-mcp-light tools here
  ];

  home.stateVersion = "22.11";
}
