{
  description = "NixOS configurations for baremetal and WSL development/server/cluster environments";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    trustix = {
      url = "github:nix-community/trustix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opnix = {
      url = "github:brizzbuzz/opnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Add nixos-wsl to inputs
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ld = {
      url = "github:nix-community/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hardware configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    pre-commit-hooks,
    trustix,
    opnix,
    self,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        pre-commit-hooks.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem = {
        config,
        pkgs,
        system,
        lib,
        ...
      }: let
        isWSL = pkgs.stdenv.isLinux && (pkgs.stdenv.isWSL or false);
      in {
        pre-commit = {
          check.enable = true;
          settings = {
            hooks = {
              alejandra.enable = true;
              deadnix = {
                enable = true;
                excludes = ["^hosts/nix-ws/hardware-configuration\\.nix$"];
              };
              statix.enable = true;
              prettier.enable = true;
            };
          };
        };
        devShells.default = pkgs.mkShell {
          name = "nix-config-dev-shell";
          nativeBuildInputs = with pkgs;
            [
              alejandra
              deadnix
              statix
              nodePackages.prettier
              git
              gh
              fish
              pre-commit
              jq
              nil
              nix-output-monitor
              home-manager.packages.${pkgs.hostPlatform.system}.default
              starship
              bashInteractive
              bash-completion
              bash-preexec
              fzf
              zoxide
              direnv
              cachix
              attic-server
              attic-client
              _1password-cli
              _1password-gui-beta
            ]
            ++ (lib.optionals isWSL [
              wslu
              wsl-open
            ]);
          shellHook = ''
            ${config.pre-commit.installationScript}
            # Agentic aliases for fast Nix workflows
            if [ -n "$BASH_VERSION" ]; then
              alias nfc='nix run github:Mic92/nix-fast-build -- --flake ".#checks.$(nix eval --impure --raw --expr "builtins.currentSystem")"'
              alias nfco='nix flake check'
              alias fastcheck='nix run github:Mic92/nix-fast-build -- --flake ".#checks.$(nix eval --impure --raw --expr "builtins.currentSystem")"'
              alias fastdev='nix run github:Mic92/nix-fast-build -- --flake ".#devShells.$(nix eval --impure --raw --expr "builtins.currentSystem").default"'
            fi
            if [ -n "$FISH_VERSION" ]; then
              alias nfc "nix run github:Mic92/nix-fast-build -- --flake .#checks.(nix eval --impure --raw --expr 'builtins.currentSystem')"
              alias nfco "nix flake check"
              alias fastcheck "nix run github:Mic92/nix-fast-build -- --flake .#checks.(nix eval --impure --raw --expr 'builtins.currentSystem')"
              alias fastdev "nix run github:Mic92/nix-fast-build -- --flake .#devShells.(nix eval --impure --raw --expr 'builtins.currentSystem').default"
            end
            echo "[nix-ws] Aliases: nfc (fast check), nfco (flake check), fastcheck, fastdev loaded."
            # Source any additional devShellHook if needed
            if [ -f "./scripts/bin/devShellHook.sh" ]; then
              . ./scripts/bin/devShellHook.sh
            fi
          '';
        };
      };
      flake = {
        overlays = {
          unstable = _: prev: {
            unstable = import nixpkgs-unstable {
              inherit (prev) system;
              config.allowUnfree = true;
            };
          };
          trustixOverlay = _: prev: let
            inherit (trustix.packages.${prev.system}) trustix trustix-nix;
          in {
            inherit trustix trustix-nix;
          };
        };
        nixosConfigurations.nix-ws = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            trustix.nixosModules.trustix
            opnix.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            ./hosts/nix-ws/configuration.nix
            {
              nix.settings = {
                trusted-users = ["ryzengrind"];
                trusted-substituters = ["https://cache.nixos.org/"];
              };
            }
          ];
          specialArgs = {
            inherit inputs self;
            pkgs = import nixpkgs {
              system = "x86_64-linux";
              overlays = [
                self.overlays.unstable
                self.overlays.trustixOverlay
              ];
              config.allowUnfree = true;
            };
          };
        };
        homeConfigurations.ryzengrind = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {
            inherit inputs self;
          };
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [
              self.overlays.unstable
              self.overlays.trustixOverlay
            ];
            config.allowUnfree = true;
          };
          modules = [
            opnix.homeManagerModules.opnix
            ./home-manager/ryzengrind/default.nix
            {
              nix.settings = {
                trusted-users = ["ryzengrind"];
                trusted-substituters = ["https://cache.nixos.org/"];
              };
            }
          ];
        };
      };
    };
}
