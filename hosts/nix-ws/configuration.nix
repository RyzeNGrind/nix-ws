{ config, lib, pkgs, inputs, self, ... }:

let
  # Define the missing variable here
  displayVariable = {
    # Add your display-related variables here
    # For example:
    # DISPLAY = ":0";
  };
  
  # Define etcFiles variable that was also used but not defined
  etcFiles = {
    # Add your etc files configuration here
    # For example:
    # "hosts".text = "127.0.0.1 localhost\n";
  };
in

lib.mkMerge [
  # --- Block 1: Main Configuration (including specialisations) ---
  {
    # --- Add safe defaults for essential boot options ---
    fileSystems."/" = lib.mkDefault {
      # Keep the default root separate for simplicity here, statix doesn't complain about this top-level one
      device = "/dev/disk/by-label/NIXOS_ROOT";
      fsType = "ext4";
    };

    # --- Grouped boot defaults ---
    boot = {
      loader = {
        systemd-boot.enable = lib.mkDefault false; # Default to disabled
        grub = {
          enable = lib.mkDefault false; # Explicitly disable GRUB by default
          device = lib.mkDefault null; # Satisfies the check when grub is disabled
        };
      };
      # Add other common boot settings here if needed
    };

    nix.settings = {
      trusted-users = ["root" "@wheel" "ryzengrind"];
      experimental-features = ["auto-allocate-uids" "ca-derivations" "cgroups" "dynamic-derivations" "fetch-closure" "fetch-tree" "flakes" "git-hashing" "local-overlay-store" "mounted-ssh-store" "no-url-literals" "pipe-operators" "nix-command" "recursive-nix"];
      substituters = ["https://cache.nixos.org" "https://nix-community.cachix.org" "https://cuda-maintainers.cachix.org" "https://ryzengrind.cachix.org" "https://ryzengrind-nix-config.cachix.org" "https://daimyo.cachix.org"];
      trusted-substituters = ["https://cache.nixos.org" "https://nix-community.cachix.org" "https://cuda-maintainers.cachix.org" "https://ryzengrind.cachix.org" "https://ryzengrind-nix-config.cachix.org" "https://daimyo.cachix.org"];
      trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" "ryzengrind.cachix.org-1:bejzYd+Baf3Mwua/xSeysm97G9JL8133glujCUCnK7g=" "ryzengrind-nix-config.cachix.org-1:V3lFs0Pd5noCZegBaSgnWGjGqJgY7XTcTKG/Baj8jXk=" "daimyo.cachix.org-1:IgolikHY/HwiVJWM2UoPhSK+dzGrJ3IgY0joV9VTpC8="];
      require-sigs = true;
      accept-flake-config = true;
      allow-dirty = true;
      warn-dirty = false;
    };

    nixpkgs.config = {
      allowUnfree = true;
      allowBroken = true;
    };

    # ... programs, environment, security, services, users ... (keep as before)
    programs = {
      fish = {
        enable = true;
        interactiveShellInit = ''${pkgs.starship}/bin/starship init fish | source'';
      };
      nix-ld = {enable = true;};
      bash = {
        completion.enable = true;
        interactiveShellInit = ''eval "$(${pkgs.starship}/bin/starship init bash)"'';
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
      etc = etcFiles;
      variables = displayVariable;
      shellAliases = {};
      pathsToLink = ["/share/bash-completion"];
      systemPackages = with pkgs; [readline bashInteractive bash-completion ncurses wget jq git starship nix-ld binutils glibc gcc python3 nodejs zlib cachix attic-server attic-client _1password-cli _1password-gui-beta];
    };
    # System state version
    system = {
      stateVersion = "24.11";
      configurationRevision =
        if self ? rev && self.rev != null
        then self.rev
        else (lib.trace "Repository must be clean and committed" null);
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
          PasswordAuthentication = false;
        };
        ports = [ 22 2222 ];
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
      tailscale = {
        enable = true;
      };  
    };
    virtualisation = {
      docker.enable = true;
      libvirtd.enable = true;
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

          # --- Grouped WSL Boot settings ---
          boot = {
            loader = {
              # Force disable both bootloaders, overriding any defaults
              systemd-boot.enable = lib.mkForce false;
              grub.enable = lib.mkForce false;
            };
            # Let WSL manage init
            initrd.systemd.enable = lib.mkForce false;
          };

          services.logind.enable = lib.mkForce false;
          systemd.targets.graphical.enable = lib.mkForce false;
          services.udev.enable = lib.mkForce false;
          hardware.opengl.enable = lib.mkForce false;

          # --- Grouped WSL Service Configurations ---
          #systemd.services.wsl-vpnkit = {
            # serviceConfig = {
            #   ExecStart = "${pkgs.wsl-vpnkit}/bin/wsl-vpnkit";
            #   Restart = "always";
            #   KillMode = "mixed";
            # };
          #};
        };
      };
    };
  }
  
  # --- Block 2: Specialization for bare metal ---
  {
    specialisation.baremetal = {
      configuration = {
        # --- Grouped Bare-metal Filesystems ---
        fileSystems = {
          "/" = {
            device = "/dev/disk/by-uuid/5dc27f19-81cf-49db-a770-3415885b6cb7"";
            fsType = "ext4";
          };
          "/boot" = {
            device = "/dev/disk/by-uuid/17B6-1473";
            fsType = "vfat";
            options = [ "fmask=0077" "dmask=0077" ];
          };
        };
        swapDevices = [
          { device = "/dev/disk/by-uuid/a869621e-d381-4777-adc8-7de13e6ae4b0"; }
        ];

        # --- Grouped Bare-metal Bootloader ---
        boot = {
          loader = {
            # Enable desired bootloader, overriding common defaults
            systemd-boot.enable = true;
            # grub = { # Keep commented unless using GRUB
            #   enable = true;
            #   device = "/dev/sda";
            # };
          };
          # Add other baremetal-specific boot settings here if needed
        };

        # --- Other baremetal settings ---
        networking.networkmanager.enable = lib.mkDefault true;
        services.openssh.ports = [22]; # Override default SSH port

        # Add graphics, sound, etc. here
        # hardware.opengl.enable = true;
        # sound.enable = true;
      };
    };
  }

  # --- Block 3: Conditional Configuration for Default ---
  (lib.mkIf (config.specialisation == {}) {
    # Settings ONLY for the default build when no specialisation is chosen
    # Inherits safe defaults from common section.
  })
]