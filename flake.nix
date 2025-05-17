{
  description = "NixOS and Home Manager configurations for the entire cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    void-fork.url = "github:jskrzypek/nixpkgs/void-editor";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    std.url = "github:divnix/std";
    hive.url = "github:divnix/hive";
    nix-fast-build = {
      url = "github:Mic92/nix-fast-build";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opnix = {
      url = "github:brizzbuzz/opnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    void-editor-pr = {
      url = "github:NixOS/nixpkgs/pull/398996/head";
      flake = false;
    };
    emanote-flake = {
      url = "github:srid/emanote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cloudflared = {
      url = "github:piperswe/nix-cloudflared";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-eval-jobs = {
      url = "github:nix-community/nix-eval-jobs"; # Reverted to original simple form
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs"; # Ensure it uses the same nixpkgs
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nixpkgs-ci.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-experimental-features = [ "nix-command" "flakes" ];
  };

  outputs = inputs@{ self, flake-parts, std, hive, nixpkgs, nixpkgs-unstable, void-editor-pr, void-fork, home-manager, sops-nix, agenix, opnix, nix-vscode-extensions, nix-fast-build, nix-eval-jobs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      imports = [ ];
      perSystem = { config, self', inputs', pkgs, system, ... }: let
        void-editor-overlay = final: prev: {
          void-editor = prev.callPackage ./overlays/void-editor/package.nix {
            vscode-generic-fn = import ./overlays/vscode-generic/generic.nix;
          };
          unstable = import nixpkgs-unstable {
            system = prev.system;
            config.allowUnfree = true;
          };
        };
        generate-hardware-config-pkg = pkgs.writeShellApplication {
          name = "generate-hardware-config";
          runtimeInputs = with pkgs; [ coreutils gnugrep gawk util-linux ]; # Dependencies for the script
          text = builtins.readFile ./scripts/generate-hardware-config.sh;
        };
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (import ./overlays/vscode-generic.nix)
            (final: prev: {
              void-editor = prev.callPackage ./overlays/void-editor/package.nix {
                vscode-generic-fn = prev.vscode-generic-fn;
              };
            })
          ];
        };
        devShells.default = pkgs.mkShell {
          name = "nix-cfg-mgmt-shell";
          packages = with pkgs; [
            git gh pre-commit alejandra statix deadnix sops wslu # Added wslu for wslpath
            generate-hardware-config-pkg # Use let-bound variable
            inputs.nix-fast-build.packages.${system}.default
            # inputs.nix-eval-jobs.packages.${system}.default # Temporarily commented out due to incompatibility
            nix-output-monitor
          ];
          shellHook = ''
            # Configure nix-fast-build as the default builder
            alias nix-build='nix-fast-build --skip-cached'
            alias nb='nix-fast-build --skip-cached'
            alias nbe='nix-fast-build --skip-cached --systems "$(nix eval --raw --impure --expr builtins.currentSystem)" --result-format junit --result-file result.xml'
            
            echo "🚀 nix-fast-build is configured as the default builder"
            echo "Use 'nb' shorthand for nix-fast-build with cached derivations skipped"
            echo "Use 'nbe' to build only the current system with junit output"

            # Alias for nix-topology (using nix run directly)
            alias generate-topology='nix run github:oddlama/nix-topology -- --flake .# --out-link ./topology.svg && echo "Topology diagram generated: topology.svg"'
            echo "🔷 Use 'generate-topology' to create a cluster topology diagram (topology.svg)"
          '';
        };
        devShells.void-editor = import ./devshells/void-editor.nix { inherit pkgs; };
        # Expose vscode-generic and void-editor as packages for direct flake builds
        packages = {
          vscode-generic = pkgs.vscode-generic;
          void-editor = pkgs.void-editor;
          generate-hardware-config = generate-hardware-config-pkg; # Assign let-bound variable
          # The liveusb package is defined below in the outputs section
        };
        checks = {
          # Minimal test to verify basic structure
          dummy-core-check = pkgs.callPackage ./tests/nix-ws-core.nix {
            self = self';
            pkgs = pkgs;
            # Pass a minimal config directly for this test
            nix-fast-build.enable = true;
            environment.noTailscale = true;
          };
          # Minimal liveusb test
          dummy-liveusb-check = pkgs.callPackage ./tests/liveusb-ssh-vpn.nix {
            self = self; # self from flake outputs
            inputs = inputs;
            pkgs = pkgs; # pkgs from perSystem
             # Add any specific minimal config for liveusb if needed
          };
        };
      };
    } // {
      # Standard flake outputs
      packages.x86_64-linux = {
        liveusb = self.nixosConfigurations.liveusb.config.system.build.isoImage;
      };

      # Editor extension sets moved into outputs
      overlays.editorExtensionSets = final: prev: {
        editorExtensionSets = {
          x86_64-linux = let extensions = nix-vscode-extensions.extensions.x86_64-linux; in {
            base = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
            ];
            cursor = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.anysphere.remote-ssh
              extensions.vscode-marketplace.anysphere.remote-wsl
            ];
            vscodeDesktop = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.ms-vscode.remote-server
              extensions.vscode-marketplace.ms-vscode-remote.remote-ssh-edit
              extensions.vscode-marketplace.ms-vscode-remote.remote-ssh
              extensions.vscode-marketplace.ms-vscode-remote.remote-repositories
              extensions.vscode-marketplace.ms-vscode-remote.remote-wsl
              extensions.vscode-marketplace.ms-vscode-remote.vscode-remote-extensionpack
            ];
            nixos = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.arrterian.nix-env-selector
              extensions.vscode-marketplace.jnoortheen.nix-ide
              extensions.vscode-marketplace.kamadorueda.alejandra
              extensions.vscode-marketplace.mkhl.direnv
            ];
            nonNix = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.ms-azuretools.vscode-docker
              extensions.vscode-marketplace.github.vscode-github-actions
            ];
          };
          aarch64-linux = let extensions = nix-vscode-extensions.extensions.aarch64-linux; in {
            base = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
            ];
            cursor = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.anysphere.remote-ssh
              extensions.vscode-marketplace.anysphere.remote-wsl
            ];
            vscodeDesktop = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.ms-vscode.remote-server
              extensions.vscode-marketplace.ms-vscode-remote.remote-ssh-edit
              extensions.vscode-marketplace.ms-vscode-remote.remote-ssh
              extensions.vscode-marketplace.ms-vscode-remote.remote-repositories
              extensions.vscode-marketplace.ms-vscode-remote.remote-wsl
              extensions.vscode-marketplace.ms-vscode-remote.vscode-remote-extensionpack
            ];
            nixos = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.arrterian.nix-env-selector
              extensions.vscode-marketplace.jnoortheen.nix-ide
              extensions.vscode-marketplace.kamadorueda.alejandra
              extensions.vscode-marketplace.mkhl.direnv
            ];
            nonNix = [
              extensions.vscode-marketplace.ieviev.nix-vscode-completions
              extensions.vscode-marketplace.kaliahayes.kolada
              extensions.vscode-marketplace.bbenoist.nix
              extensions.vscode-marketplace.ms-azuretools.vscode-docker
              extensions.vscode-marketplace.github.vscode-github-actions
            ];
          };
        };
      };

      # Common modules for NixOS configurations
      nixosModules.common = { ... }: {
        imports = [
          ./modules/common-config.nix
          ./modules/build-system.nix
          ./modules/fast-build.nix
          inputs.nix-cloudflared.nixosModules.default # Or .cloudflared if 'default' is not the one
        ];
        nixpkgs.config.allowUnfree = true;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
      };

      # NixOS configurations
      nixosConfigurations = {
        liveusb = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.common
            ./hosts/liveusb.nix
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
            })
            # Configure fast-build for this host
            { nix.fastBuild.enable = true; }
            # Root user is now configured in common-config.nix with a DRY approach
            # No need for per-host configuration as it's centralized
          ];
          specialArgs = with inputs; {
            inherit self inputs nixpkgs;
          };
        };
        
        nix-ws = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.common
            ./hosts/nix-ws.nix
            # Configure fast-build for this host
            { nix.fastBuild.enable = true; }
            # Root user is now configured in common-config.nix with a DRY approach
            # No need for per-host configuration as it's centralized
            # Filesystem and bootloader are now managed in hosts/nix-ws.nix
          ];
          specialArgs = with inputs; {
            inherit self inputs nixpkgs;
          };
        };
      };
      
      # Home Manager configurations with consistent user settings
      homeConfigurations = {} // {
        "ryzengrind@liveusb" = import ./home/ryzengrind.nix { inherit inputs self; host = "liveusb"; };
        "ryzengrind@nix-ws" = import ./home/ryzengrind.nix { inherit inputs self; host = "nix-ws"; };
      };
    };
}
