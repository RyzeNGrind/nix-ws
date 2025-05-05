# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL
# hosts/nix-ws/configuration.nix
# hosts/nix-ws/configuration.nix
{
  config, # Final config object (available for use in mkIf conditions etc.)
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Use lib.mkMerge to combine the main config block and the conditional one
  config = lib.mkMerge [
    # --- Block 1: Main Configuration (including specialisations) ---
    {
      nix.settings = {
        trusted-users = ["root" "@wheel" "ryzengrind"];
        experimental-features = ["auto-allocate-uids" "ca-derivations" "cgroups" "dynamic-derivations" "fetch-closure" "fetch-tree" "flakes" "git-hashing" "local-overlay-store" "mounted-ssh-store" "no-url-literals" "pipe-operators" "nix-command" "recursive-nix"];
        # ... other nix settings ...
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://cuda-maintainers.cachix.org"
          "https://ryzengrind.cachix.org"
          "https://ryzengrind-nix-config.cachix.org"
          "https://daimyo.cachix.org"
          "http://localhost:9001" # Trustix local cache
        ];
        trusted-substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://cuda-maintainers.cachix.org"
          "https://ryzengrind.cachix.org"
          "https://ryzengrind-nix-config.cachix.org"
          "https://daimyo.cachix.org"
          "http://localhost:9001" # Trustix local cache
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
          "ryzengrind.cachix.org-1:bejzYd+Baf3Mwua/xSeysm97G9JL8133glujCUCnK7g="
          "ryzengrind-nix-config.cachix.org-1:V3lFs0Pd5noCZegBaSgnWGjGqJgY7XTcTKG/Baj8jXk="
          "daimyo.cachix.org-1:IgolikHY/HwiVJWM2UoPhSK+dzGrJ3IgY0joV9VTpC8="
          "localhost:VXOPwgEJPB/fAiY+EopQY7gvVfQZyF1+ifn2NhYYJgA=" # Example Trustix key
        ];
        require-sigs = true;
        accept-flake-config = true;
        allow-dirty = true;
        warn-dirty = false;
      };

      nixpkgs.config = {
        allowUnfree = true;
        allowBroken = true;
      };

      programs = {
        fish = {
          enable = true;
          interactiveShellInit = ''
            ${pkgs.starship}/bin/starship init fish | source
          '';
        };
        nix-ld = {
          enable = true;
          # libraries = ...;
        };
        bash = {
          completion.enable = true;
          interactiveShellInit = ''
            eval "$(${pkgs.starship}/bin/starship init bash)"
          '';
        };
        starship = {
          enable = true;
          settings = {
            add_newline = true;
            command_timeout = 5000;
            character = {
              error_symbol = "[❯](bold red)";
              success_symbol = "[❯](bold green)";
              vicmd_symbol = "[❮](bold blue)";
            };
          };
        };
      };

      environment = {
        shellAliases = {};
        pathsToLink = ["/share/bash-completion"];
        systemPackages = with pkgs; [
          readline
          bashInteractive
          bash-completion
          ncurses
          wget
          jq
          git
          starship
          nix-ld
          binutils
          glibc
          gcc
          python3
          nodejs
          zlib
          cachix
          attic-server
          attic-client
          _1password-cli
          _1password-gui-beta
        ];
      };

      security.sudo = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };

      services = {
        openssh = {
          enable = true;
          settings = {
            PermitRootLogin = "yes";
            PasswordAuthentication = true;
          };
          ports = lib.mkDefault [2222];
        };
        onepassword-secrets = {
          enable = false;
          users = ["ryzengrind"];
          tokenFile = "/etc/opnix-token";
          configFile = "/home/ryzengrind/.config/opnix/secrets.json";
          outputDir = "/home/ryzengrind/.config/opnix/secrets";
        };
        trustix-nix-cache = {
          enable = false;
          private-key = "/var/trustix/keys/cache-priv-key.pem";
          port = 9001;
        };
        trustix = {
          enable = false;
          deciders.nix = {
            engine = "percentage";
            percentage = {minimum = 66;};
          };
          subscribers = [
            {
              protocol = "nix";
              publicKey = {
                type = "ed25519";
                key = "2uy8gNIOYEewTiV7iB7cUxBGpXxQtdlFepFoRvJTCJo=";
              };
            }
          ];
          remotes = ["https://demo.trustix.dev"];
        };
      };

      users.users.ryzengrind = {
        isNormalUser = true;
        shell = pkgs.fish;
        group = "ryzengrind";
        extraGroups = lib.mkDefault ["users" "wheel" "docker" "networkmanager" "audio" "video" "kvm" "libvirt" "libvirtd" "podman" "qemu-libvirtd"];
      };
      users.groups.ryzengrind = {};

      # --- Specialisations Definition ---
      specialisation = {
        wsl = {
          configuration = {
            imports = [inputs.nixos-wsl.nixosModules.wsl];
            wsl = {
              enable = true;
              defaultUser = "ryzengrind";
              wslConf = {
                network.hostname = "nix-ws-wsl";
                wsl2.vmIdleTimeout = -1;
              };
              startMenuLaunchers = true;
              docker-desktop.enable = true;
            };
            environment.systemPackages = with pkgs; [wsl-vpnkit];
            services.logind.enable = lib.mkForce false;
            systemd.targets.graphical.enable = lib.mkForce false;
            services.udev.enable = lib.mkForce false;
            hardware.opengl.enable = lib.mkForce false;
          };
        };
        # Renamed back to 'baremetal' for clarity, was 'bm'
        baremetal = {
          configuration = {
            boot.loader.systemd-boot.enable = lib.mkDefault true;
            networking.networkmanager.enable = lib.mkDefault true;
            services.openssh.ports = [22];
            # Add other baremetal specifics here
          };
        };
      };

      # System state version
      system.stateVersion = "24.11";
    } # End of the first block for mkMerge

    # --- Block 2: Conditional Configuration for Default ---
    (lib.mkIf (config.specialisation == {}) {
      # Settings ONLY for the default build when no specialisation is chosen
      # Example: Maybe set a default hostname or enable a specific service
      # networking.hostName = lib.mkDefault "nix-ws-default";
      # services.nginx.enable = true;
    }) # End of the second block (mkIf) for mkMerge
  ]; # End of list for mkMerge
}
