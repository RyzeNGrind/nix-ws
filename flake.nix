{
  description = "NixOS configurations for baremetal and WSL development/server/cluster environments";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Direct reference to the PR branch with a specific commit
    void-editor-pkgs = {
      url = "github:jskrzypek/nixpkgs/void-editor";
      flake = true;
    };

    # Cluster management frameworks
    std = {
      url = "github:divnix/std";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hiveFlake = {
      url = "github:divnix/hive";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.std.follows = "std";
    };
    nixago.url = "github:nix-community/nixago";
    kaizen.url = "github:thericecold/kaizen";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
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
  nixConfig = {
    extra-substituters = [
      "https://nixpkgs-ci.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    nixpkgs-unstable,
    trustix,
    std,
    hiveFlake,
    nixago,
    void-editor-pkgs,
    git-hooks,
    home-manager,
    opnix,
    kaizen,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [git-hooks.flakeModule];

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
            (self: super: {
              unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
              trustixPkgs = import trustix {
                inherit system;
              };
            })
            # Add a proper void-editor overlay using the fork directly
            (final: prev: {
              void-editor =
                (import inputs.void-editor-pkgs {
                  inherit system;
                  config.allowUnfree = true;
                })
                .void-editor;
            })
          ];
        };
        # No longer need the placeholder since we're using the actual package
      in {
        pre-commit = {
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
        packages = {
          pre-commit-run = pkgs.stdenv.mkDerivation {
            name = "pre-commit-check";
            buildCommand = "true";
          };
          statix-config = pkgs.writeTextFile {
            name = "statix.toml";
            text = ''
              [ignore]
              paths = ["hosts/nix-ws/hardware-configuration.nix"]
            '';
          };
          # Use the actual package
          void-editor = pkgs.void-editor;
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
            void-editor
          ];
          shellHook = ''
            ${config.pre-commit.installationScript or ""}
            if [ ! -e .statix.toml ]; then
              ln -sf ${config.packages.statix-config} .statix.toml
            fi
            ${pkgs.lib.readFile ./scripts/bin/devShellHook.sh}

            # Inline void-editor check script instead of reading from file

            # Check if void (void-editor) is available in the shell
            echo -e "\n\033[0;34m== Checking void-editor availability ==\033[0m"

            if command -v void >/dev/null 2>&1; then
              VOID_PATH=$(which void)
              echo -e "\033[0;32m✓ void-editor found at: $VOID_PATH\033[0m"

              # Get version info
              VERSION=$(void --version 2>&1 | head -n 1 || echo "unknown")
              echo -e "\033[0;32m✓ void-editor version: $VERSION\033[0m"

              # Check if we can run it (non-blocking test)
              if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
                echo -e "\033[0;34m• Display connection available. You can run void.\033[0m"
              else
                echo -e "\033[1;33m! No display detected. void-editor is installed but may not launch GUI.\033[0m"
              fi

              echo -e "\033[0;32m✓ void-editor is ready to use\033[0m"
            else
              echo -e "\033[0;31m✗ void-editor is not available in this shell\033[0m"
              echo -e "\033[1;33m• You can build it with: nix build --impure '.#void-editor'\033[0m"
              echo -e "\033[1;33m• Or run: nix shell github:jskrzypek/nixpkgs/void-editor#void-editor\033[0m"
            fi

            # Shell integration for Void Editor
            if [ "''${TERM_PROGRAM:-}" = "vscode" ]; then
              shellName=$(basename "$SHELL")
              if command -v void >/dev/null 2>&1; then
                VOID_PATH=$(dirname $(which void))
                VOID_SHARE="$VOID_PATH/../share/void-editor"

                # Check if integration files exist before sourcing
                if [[ -d "$VOID_SHARE" ]]; then
                  BASH_INTEGRATION="$VOID_SHARE/resources/app/out/vs/workbench/contrib/terminal/browser/media/shellIntegration-bash.sh"
                  FISH_INTEGRATION="$VOID_SHARE/resources/app/out/vs/workbench/contrib/terminal/browser/media/fish_xdg_data/fish/vendor_conf.d/shellIntegration.fish"

                  case "$shellName" in
                    bash|sh)
                      [[ -f "$BASH_INTEGRATION" ]] && source "$BASH_INTEGRATION"
                      ;;
                    fish)
                      [[ -f "$FISH_INTEGRATION" ]] && source "$FISH_INTEGRATION"
                      ;;
                  esac
                else
                  echo -e "\033[1;33m! Shell integration files not found for void-editor\033[0m"
                fi
              fi
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
          trustix = _: prev: {
            inherit (trustix.packages.${prev.system}) trustix trustix-nix;
          };
          vscodium = final: prev: (import ./vscodium-overlay.nix) final prev;
          # Add void-editor overlay for easier reuse
          void-editor = final: prev: {
            void-editor =
              (import inputs.void-editor-pkgs {
                inherit (prev) system;
                config.allowUnfree = true;
              })
              .void-editor;
          };
        };

        # Create a hive for cell-based organization, but still define nixosConfigurations directly
        nixosConfigurations.nix-ws = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            trustix.nixosModules.trustix
            opnix.nixosModules.default
            ./hosts/nix-ws/configuration.nix
            {nix.settings.trusted-users = ["ryzengrind"];}
            # Include the void-editor module
            self.nixosModules.void-editor
          ];
          specialArgs = {
            inherit inputs self;
            pkgs = import nixpkgs {
              system = "x86_64-linux";
              config.allowUnfree = true;
              overlays = [
                self.overlays.unstable
                self.overlays.trustix
                self.overlays.vscodium
                self.overlays.void-editor
              ];
            };
          };
        };

        # Void-editor module for cluster-wide use
        nixosModules.void-editor = {
          config,
          pkgs,
          lib,
          ...
        }: {
          options.programs.void-editor = {
            enable = lib.mkEnableOption "void-editor";
            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.void-editor;
              description = "The void-editor package to use";
            };
            extensions = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [];
              description = "List of void-editor extensions to install";
            };
          };

          config = lib.mkIf config.programs.void-editor.enable {
            environment.systemPackages =
              [
                config.programs.void-editor.package
              ]
              ++ config.programs.void-editor.extensions
              # Add desktop entry conditionally
              ++ lib.optionals pkgs.stdenv.isLinux [
                (pkgs.makeDesktopItem {
                  name = "void-editor";
                  desktopName = "Void Editor";
                  exec = "${config.programs.void-editor.package}/bin/void-editor %F";
                  icon = "code";
                  comment = "Code Editing. Redefined.";
                  categories = ["Development" "IDE"];
                  mimeTypes = [
                    "text/plain"
                    "inode/directory"
                    "application/x-code-workspace"
                  ];
                })
              ];
          };
        };

        # Home manager configuration
        homeConfigurations.ryzengrind = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs self;};
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
            overlays = [
              self.overlays.unstable
              self.overlays.trustix
              self.overlays.vscodium
              self.overlays.void-editor
            ];
          };
          modules = [
            opnix.homeManagerModules.default
            ./home-manager/ryzengrind/default.nix
            kaizen.homeManagerModules.default
            # Add the void-editor home manager module
            self.homeManagerModules.void-editor
          ];
        };

        # Add home-manager modules
        homeManagerModules = {
          # Home Manager module for void-editor
          void-editor = {
            config,
            lib,
            pkgs,
            ...
          }: {
            options.programs.void-editor = {
              enable = lib.mkEnableOption "void-editor";
              package = lib.mkOption {
                type = lib.types.package;
                default = pkgs.void-editor;
                description = "The void-editor package to use";
              };
              extensions = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [];
                description = "List of void-editor extensions to install";
              };
              enableExtensionUpdateCheck = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to enable automatic extension updates";
              };
              enableUpdateCheck = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to enable update checks";
              };
              userSettings = lib.mkOption {
                type = lib.types.attrs;
                default = {};
                description = "User settings for void-editor";
              };
            };

            config = lib.mkIf config.programs.void-editor.enable {
              home.packages =
                [config.programs.void-editor.package]
                ++ config.programs.void-editor.extensions;

              # Configure settings
              xdg.configFile = lib.mkIf (config.programs.void-editor.userSettings != {}) {
                "void-editor/User/settings.json".text = builtins.toJSON config.programs.void-editor.userSettings;
              };
            };
          };
        };
      };
    };
}
