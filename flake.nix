{
  description = "NixOS configurations for baremetal and WSL development/server/cluster environments";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    # You can access packages and modules from different nixpkgs revs
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-commit hooks
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS-WSL
    nixos-wsl.url = "github:nix-community/nixos-wsl";
    nix-ld = {
      url = "github:nix-community/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hardware configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    pre-commit-hooks,
    nixos-wsl,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Only build for Linux systems
    linuxSystems = ["x86_64-linux" "aarch64-linux"];
    # For packages that can build on any system
    allSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs allSystems;
    # Add this new overlay to make unstable packages available
    overlayUnstable = _: prev: {
      unstable = import nixpkgs-unstable {
        inherit (prev) system;
        config.allowUnfree = true;
      };
    };

    overlays = {
      #   default = import ./overlays/default-bash.nix;
      unstable = overlayUnstable;
    };
  in {
    inherit overlays;
    # Add checks for pre-commit hooks
    checks = forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra = {
            enable = true;
            excludes = ["^modules/nixos/cursor/.*$"];
            settings.verbosity = "quiet";
          };
          deadnix = {
            enable = true;
            excludes = ["^modules/nixos/cursor/.*$"];
            settings.noLambdaPatternNames = true;
          };
          statix = {
            enable = true;
            excludes = ["^modules/nixos/cursor/.*$"];
            entry = "statix check";
            pass_filenames = false;
          };
          prettier = {
            enable = true;
            excludes = [
              "^modules/nixos/cursor/.*$"
              "^.vscode/settings.json$"
            ];
            types_or = [
              "markdown"
              "yaml"
              "json"
            ];
          };
          test-flake = {
            enable = true;
            name = "NixOS Configuration Tests";
            entry = "scripts/test-flake.sh";
            language = "system";
            pass_filenames = false;
            stages = ["commit-msg"];
            always_run = true;
          };
        };
      };
    });

    # Your custom packages and modifications
    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = system == "x86_64-linux" || system == "aarch64-linux";
            amdgpuSupport = system == "x86_64-linux" || system == "aarch64-linux";
            experimental-features = ["nix-command" "flakes" "repl-flake" "recursive-nix" "fetch-closure" "dynamic-derivations" "daemon-trust-override" "cgroups" "ca-derivations" "auto-allocate-uids" "impure-derivations"];
          };
        };
      in {
        default = pkgs.mkShell {
          name = "nix-config-dev-shell";
          nativeBuildInputs = with pkgs; [
            # Formatters and linters
            alejandra
            deadnix
            statix
            nodePackages.prettier

            # Git and pre-commit
            git
            pre-commit
            jq

            # Nix tools
            nil
            nix-output-monitor
            home-manager.packages.${system}.default
            starship
            bashInteractive
            bash-completion
            bash-preexec
            fzf
            zoxide
            direnv
          ];
          shellHook = builtins.readFile ./scripts/bin/devShellHook.sh;
        };
      }
    );

    nixosConfigurations = {
      nix-ws = let
        basePkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [
            #  overlays.default  # Use local binding instead of self-reference
            overlays.unstable
          ];
          config.allowUnfree = true;
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
            pkgs = basePkgs;
          };
          modules = [
            ./hosts/nix-ws/configuration.nix
            {
              # given the users in this list the right to specify additional substituters via:
              #    1. `nixConfig.substituters` in `flake.nix`
              nix.settings.trusted-users = ["ryzengrind"];
            }
          ];
        };
    };

    homeConfigurations = {
      ryzengrind = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
        };
        modules = [
          ./home-manager/ryzengrind/default.nix
        ];
      };
    };
  };
}
