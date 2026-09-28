{
  description = "Hybrid Mac and NixOS Flake";

  inputs = {
    # NixOS Official (Covers both Mac and Linux packages)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05"; 
    
    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Darwin Support
    darwin.url = "github:lnl7/nix-darwin/nix-darwin-26.05";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Unstable, for single fast moving CLIs only (codex on the utm VM). GUI apps
    # and GPU drivers stay on one nixpkgs (utm-arch wiki/home-manager-standalone.md, pitfall 6).
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, darwin, home-manager, ... }: 
  let
    # Helper to clean up configuration definitions
    mkMac = host: module: darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = import nixpkgs { system = "aarch64-darwin"; config.allowUnfree = true; };
      modules = [
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
        # The output name IS the hostname. Setting it here rather than in the
        # shared module means no machine is the implicit default: adding a host is
        # one line below, and no host needs `lib.mkForce` to undo another one's
        # name. It also keeps attribute and hostname from drifting apart, which
        # matters because a bare `darwin-rebuild switch` resolves the configuration
        # by the machine's hostname.
        { networking.hostName = host; }
        module
      ];
    };
  in {
    # --- macOS Configurations ---
    darwinConfigurations = {
      # The Air also runs the utm-arch VM, so it carries the macbridge (utm-arch
      # wiki/macbridge.md): Touch ID and 1Password for the VM.
      "Samis-MacBook-Air" = mkMac "Samis-MacBook-Air" {
        imports = [ ./darwin-configuration.nix ./utm-arch/macbridge/darwin.nix ];
      };

      # Mac16,7 / M4 Pro. This output was called -Air until 2026-09-01: a Migration
      # Assistant leftover, where macOS set ComputerName from the new machine
      # ("Sami's MacBook Pro") but carried the old HostName/LocalHostName across, so
      # the Sharing pane showed the right name while `hostname` and `.local` both
      # still said Air. ComputerName is NOT managed here, which is why the two
      # drifted. The attribute has to track the hostname: a bare `darwin-rebuild
      # switch` resolves the configuration by it.
      "Samis-MacBook-Pro" = mkMac "Samis-MacBook-Pro" ./darwin-configuration.nix;

      "Gmtk-MacBook-Pro"  = mkMac "Gmtk-MacBook-Pro"  ./darwin-configuration.nix;
    };

    # --- utm-arch VM: Arch Linux ARM in UTM, standalone Home Manager ---
    # ~/common/projects/utm-arch (D13). Switch inside the VM with
    #   home-manager switch --flake ~/nix-config#sakalli@utm
    homeConfigurations."sakalli@utm" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; config.allowUnfree = true; };
      extraSpecialArgs.unstable = import nixpkgs-unstable { system = "aarch64-linux"; config.allowUnfree = true; };
      modules = [ ./shared-home.nix ./utm-home.nix ./utm-arch/macbridge/home.nix ];
    };

    # --- NixOS VM Configuration ---
    nixosConfigurations."nixos-vm" = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./vm-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.sakalli = { 
            imports = [ ./shared-home.nix ]; 
          };
        }
      ];
    };
  };
}
