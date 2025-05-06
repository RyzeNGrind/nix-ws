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
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    nixpkgs-unstable,
    trustix,
    pre-commit-hooks,
    home-manager,
    opnix,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [pre-commit-hooks.flakeModule];

      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        config,
        system,
        ...
      }: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (_: prev: {
              unstable = import nixpkgs-unstable {
                inherit (prev) system;
                config.allowUnfree = true;
              };
            })
            (_: prev: {
              inherit (trustix.packages.${prev.system}) trustix trustix-nix;
            })
          ];
        };
      in {
        _module.args.pkgs = pkgs;

        pre-commit = {
          check.enable = true;
          settings.hooks = {
            alejandra.enable = true;
            deadnix = {
              enable = true;
              excludes = ["^hosts/nix-ws/hardware-configuration\\.nix$"];
            };
            statix = {
              enable = true;
              args = ["--config" ".statix.toml"];
            };
            prettier.enable = true;
          };
        };
        checks = {
          inherit (config.checks) pre-commit;
        };
        packages = {
          pre-commit-run = config.checks.pre-commit;
          statix-config = pkgs.writeTextFile {
            name = "statix.toml";
            text = ''
              [ignore]
              paths = ["hosts/nix-ws/hardware-configuration.nix"]
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          name = "nix-config-dev-shell";
          nativeBuildInputs = with pkgs; [
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
          ];
          shellHook = ''
            ${config.pre-commit.installationScript or ""}
            if [ ! -e .statix.toml ]; then
              ln -sf ${config.packages.statix-config} .statix.toml
            fi
            ${pkgs.lib.readFile ./scripts/bin/devShellHook.sh}
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
          trustix = _: prev: {
            inherit (trustix.packages.${prev.system}) trustix trustix-nix;
          };
        };

        nixosConfigurations.nix-ws = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            trustix.nixosModules.trustix
            opnix.nixosModules.default
            ./hosts/nix-ws/configuration.nix
            {nix.settings.trusted-users = ["ryzengrind"];}
          ];
          specialArgs = {
            inherit inputs self;
            pkgs = import nixpkgs {
              system = "x86_64-linux";
              config.allowUnfree = true;
              overlays = [
                self.overlays.unstable
                self.overlays.trustix
              ];
            };
          };
        };

        homeConfigurations.ryzengrind = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs self;};
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
            overlays = [
              self.overlays.unstable
              self.overlays.trustix
            ];
          };
          modules = [
            opnix.homeManagerModules.default
            ./home-manager/ryzengrind/default.nix
          ];
        };
      };
    };
}
