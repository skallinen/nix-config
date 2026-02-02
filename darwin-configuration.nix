{ pkgs, ... }:

{
  networking.hostName = "Samis-MacBook-Air";

  # --- System Defaults & Keyboard ---
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder._FXShowPosixPathInTitle = true;
  system.defaults.dock.autohide = true;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 14;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.defaults.spaces.spans-displays = false;

  # Spotlight & Input Source Shortcuts (Cmd+Space / Cmd+D)
  system.activationScripts.postUserActivation.text = ''
    # Spotlight -> Cmd+Space (Standard Default)
    /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{enabled = 1; value = {parameters = (32, 49, 1048576); type = standard;};}'
    
    # Spotlight Window (Finder Search) -> Disabled
    /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '{enabled = 0;}'
    
    # Input Source -> Cmd+Space (Karabiner intercepts this, but we keep it standard)
    /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '{enabled = 1; value = {parameters = (32, 49, 1048576); type = standard;};}'

    # Disable "Switch to Desktop" 1-10 to avoid conflict with Aerospace (Cmd+Num)
    ${pkgs.lib.concatMapStringsSep "\n" (i: 
      "/usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${toString i} '{enabled = 0;}'"
    ) (pkgs.lib.range 118 127)}

    # Force reload of settings
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    killall cfprefsd 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

    # Enable Remote Login (SSH) for VM access
    if /usr/sbin/systemsetup -getremotelogin | grep -q "Off"; then
      sudo /usr/sbin/systemsetup -f -setremotelogin on
    fi
  '';

  # --- Homebrew Configuration ---
  homebrew = {
    enable = true;
    onActivation = { 
      autoUpdate = true; 
      upgrade = true; 
      cleanup = "zap"; 
    };

    taps = [
      "railwaycat/emacsmacport"
      "pharo-project/pharo"
      "koekeishiya/formulae"
      "brewsci/homebrew-science"
      "nikitabobko/tap"
      "d12frosted/emacs-plus"
      "wedow/tools"

      # "local/emacs-deps" # <--- Disabled broken custom tap
    ];

    # CLI Packages via Brew (Mac-specific or preferred over Nix)
    brews = [
      # Build & Toolchain
      "autoconf" "automake" "libtool" "pkg-config"
      "isl" "libmpc" "mpfr"
      
      # Your custom Tree-sitter build
      # "local/emacs-deps/tree-sitter@0.24.3" # Disabled to allow Emacs to manage its own deps

      # Runtimes & Libs
      "node" "python-setuptools"
      "giflib" "glib" "jpeg" "libpng" "zlib"
      "cairo" "librsvg" "pango" "poppler"
      
      # Tools
      "mpv" "sox" "yt-dlp"
      "ollama" "syncthing"
      "w3m" "pandoc"
      "mu" "isync"
      "wedow/tools/ticket"
    ];

    # GUI Applications
    casks = [
      # mouse
      "logi-options+"
      # Browsers
      "firefox" "google-chrome"
      
      # Communication
      "discord" "signal" "slack" "telegram" "zoom"
      
      # Creative & Media
      "audacity" "calibre" "inkscape" "krita" "meshlab" "obs" "vlc"
      
      # Cloud & Sync
      "dropbox" "google-drive" "utm"
      
      
      # Developer & Utilities
      "1password-cli" "mongodb-compass" "pharo-launcher"
      "aerospace" "blackhole-2ch" "caffeine" "docker-desktop"
      "karabiner-elements" "keycastr" "antigravity"
      { name = "nordlayer"; greedy = true; }
      "pdf-pals" "spaceid"
      
      # Security & Misc
      "1password" "claude" "opencpn" "supercollider"
    ];

    masApps = {
      "GarageBand" = 682658836;
    };

    # Emacs-Plus Configuration
    extraConfig = ''
      # Using emacs-plus@30 (Master) which supports Tree-sitter 0.26+
      # Native compilation is default or implied in 30
      brew "d12frosted/emacs-plus/emacs-plus@30", args: ["with-xwidgets", "with-no-frame-refocus"]
    '';
  };

  # --- Nix Configuration ---
  services.nix-daemon.enable = true;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  
  # Set State Version to 5 to avoid the error you saw earlier
  system.stateVersion = 4;

  # --- Security ---
  security.pam.enableSudoTouchIdAuth = true;

  # --- User Setup ---
  users.users.samikallinen.home = "/Users/samikallinen";
  users.users.samikallinen.shell = pkgs.zsh;
  programs.zsh = {
    enable = true;
    interactiveShellInit = ''
      if [ -d /opt/homebrew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    '';
  }; 

  # --- Home Manager (Mac Specifics) ---
  home-manager.backupFileExtension = "backup";
  home-manager.users.samikallinen = { pkgs, ... }: {
    imports = [ ./shared-home.nix ];

    # Mac-only packages (Not in shared-home.nix)
    home.packages = with pkgs; [
      pngpaste
      terminal-notifier
      m-cli
    ];

    # Config Files
    home.file.".config/aerospace/aerospace.toml".source = ./aerospace/aerospace.toml;
    home.file.".config/karabiner/karabiner.json".text = builtins.toJSON {
      profiles = [
        {
          name = "Default";
          selected = true;
          complex_modifications = {
            rules = [
              {
                description = "Cmd+Space -> Toggle Input Source (US <-> Swedish)";
                manipulators = [
                  {
                    type = "basic";
                    conditions = [
                      {
                        type = "input_source_if";
                        input_sources = [{ language = "^en.*$"; }];
                      }
                    ];
                    from = {
                      key_code = "spacebar";
                      modifiers = { mandatory = ["left_command"]; };
                    };
                    to = [{ select_input_source = { language = "sv"; }; }];
                  }
                  {
                    type = "basic";
                    conditions = [
                      {
                        type = "input_source_if";
                        input_sources = [{ language = "^sv$"; }];
                      }
                    ];
                    from = {
                      key_code = "spacebar";
                      modifiers = { mandatory = ["left_command"]; };
                    };
                    to = [{ select_input_source = { language = "en"; }; }];
                  }
                  # Fallback if neither matches (assume we want English)
                  {
                    type = "basic";
                    from = {
                      key_code = "spacebar";
                      modifiers = { mandatory = ["left_command"]; };
                    };
                    to = [{ select_input_source = { language = "en"; }; }];
                  }
                ];
              }
              {
                description = "Cmd+D -> Cmd+Space (Spotlight)";
                manipulators = [
                  {
                    type = "basic";
                    from = {
                      key_code = "d";
                      modifiers = { mandatory = ["left_command"]; };
                    };
                    to = [
                      {
                        key_code = "spacebar";
                        modifiers = ["left_command"];
                      }
                    ];
                  }
                ];
              }
              {
                description = "Right Cmd → Super when UTM focused";
                manipulators = [
                  {
                    type = "basic";
                    conditions = [
                      {
                        type = "frontmost_application_if";
                        bundle_identifiers = ["^com\\.utmapp\\.UTM$"];
                      }
                    ];
                    from = { key_code = "right_command"; };
                    to = [{ key_code = "left_gui"; }];
                  }
                ];
              }
              {
                description = "Caps Lock -> Left Command";
                manipulators = [
                  {
                    type = "basic";
                    from = {
                      key_code = "caps_lock";
                      modifiers = { optional = ["any"]; };
                    };
                    to = [{ key_code = "left_command"; }];
                  }
                ];
              }
            ];
          };
          simple_modifications = [
            {
              from = { key_code = "caps_lock"; };
              to = [{ key_code = "left_command"; }];
            }
            {
              from = { key_code = "right_command"; };
              to = [{ key_code = "left_gui"; }];
            }
          ];
          virtual_hid_keyboard = { keyboard_type_v2 = "ansi"; };
        }
      ];
    };

  
  };
  
  # --- Fonts ---
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "RobotoMono" ]; })
  ];
}
