# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  nix.settings = {
    trusted-users = ["root" "@wheel" "ryzengrind"];
    experimental-features = ["auto-allocate-uids" "ca-derivations" "cgroups" "dynamic-derivations" "fetch-closure" "fetch-tree" "flakes" "git-hashing" "local-overlay-store" "mounted-ssh-store" "no-url-literals" "pipe-operators" "nix-command" "recursive-nix"];

    # Explicitly allow all substituters and their keys without prompting
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://ryzengrind.cachix.org"
      "https://ryzengrind-nix-config.cachix.org"
      "https://daimyo.cachix.org"
      "http://localhost:9001" # Trustix local cache
      #"https://your-attic-cache.example.com" # Replace with your actual Attic URL
    ];

    # Trust all substituters automatically without prompting
    trusted-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://ryzengrind.cachix.org"
      "https://ryzengrind-nix-config.cachix.org"
      "https://daimyo.cachix.org"
      "http://localhost:9001" # Trustix local cache
      #"https://your-attic-cache.example.com" # Replace with your actual Attic URL
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "ryzengrind.cachix.org-1:bejzYd+Baf3Mwua/xSeysm97G9JL8133glujCUCnK7g="
      "ryzengrind-nix-config.cachix.org-1:V3lFs0Pd5noCZegBaSgnWGjGqJgY7XTcTKG/Baj8jXk="
      "daimyo.cachix.org-1:IgolikHY/HwiVJWM2UoPhSK+dzGrJ3IgY0joV9VTpC8="
      "localhost:VXOPwgEJPB/fAiY+EopQY7gvVfQZyF1+ifn2NhYYJgA=" # Example Trustix key - replace with your actual key
      #"binarycache.example.com://TRUSTIX_PUBLIC_KEY_HERE" # Replace with your Trustix public key
      #"your-attic-cache:ATTIC_PUBLIC_KEY_HERE" # Replace with your Attic public key
    ];

    # Prevent substituter prompts
    require-sigs = true;
    accept-flake-config = true;
    allow-dirty = true; # Prevent dirty Git tree warnings
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
        # Manual starship init for fish
        ${pkgs.starship}/bin/starship init fish | source
      '';
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        #  stdenv.cc.cc
        #  zlib
        #  openssl
        #  libunwind
        #  icu
        #  libuuid
      ];
    };
    bash = {
      completion.enable = true;

      interactiveShellInit = ''
        # Initialize starship first
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
        # Add explicit format wrapping
        #format = """$all\ $character""";
      };
    };
  };
  environment = {
    shellAliases = {
      # Clear any conflicting aliases
    };
    pathsToLink = ["/share/bash-completion"];
    systemPackages = with pkgs; [
      readline
      bashInteractive # Replace regular bash
      bash-completion # Better completion support
      ncurses # Terminfo database
      wsl-vpnkit
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
    execWheelOnly = true; # Optional security measure
    wheelNeedsPassword = false;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = true;
      };
      ports = [2222];
    };

    onepassword-secrets = {
      enable = false; # Temporarily disable until token file is present
      users = ["ryzengrind"];
      tokenFile = "/etc/opnix-token";
      configFile = "/home/ryzengrind/.config/opnix/secrets.json";
      outputDir = "/home/ryzengrind/.config/opnix/secrets";
    };

    # Configure Trustix local binary cache
    trustix-nix-cache = {
      enable = false; # Temporarily disable until issues are resolved
      private-key = "/var/trustix/keys/cache-priv-key.pem";
      port = 9001;
    };
  };

  # Configure Trustix daemon for validating binary caches
  services.trustix = {
    enable = false; # Temporarily disable until specific issues can be addressed

    # Define how we verify the trustworthiness of packages
    deciders.nix = {
      engine = "percentage";
      percentage = {
        minimum = 66; # Require 2/3 majority
      };
    };

    # For subscribing to external Trustix logs
    subscribers = [
      {
        protocol = "nix";
        publicKey = {
          type = "ed25519";
          key = "2uy8gNIOYEewTiV7iB7cUxBGpXxQtdlFepFoRvJTCJo="; # Example key - replace with actual
        };
      }
    ];

    # Remote Trustix servers
    remotes = [
      "https://demo.trustix.dev" # Example - replace with actual servers
    ];
  };

  users.users.ryzengrind = {
    isNormalUser = true;
    shell = pkgs.fish;
    group = "ryzengrind";
    extraGroups = ["audio" "docker" "kvm" "libvirt" "libvirtd" "networkmanager" "podman" "qemu-libvirtd" "users" "video" "wheel"];
  };

  # Create the ryzengrind group
  users.groups.ryzengrind = {};

  wsl = {
    enable = true;
    defaultUser = "ryzengrind";
    wslConf = {
      network.hostname = "nix-ws";
      wsl2.vmIdleTimeout = -1;
    };
    startMenuLaunchers = true;
    docker-desktop.enable = true;
  };
  #  systemd.services.wsl-vpnkit = {
  #    enable = true;
  #    description = "wsl-vpnkit";
  #    after = [ "network.target" ];

  #    serviceConfig = {
  #      ExecStart = "${pkgs.wsl-vpnkit}/bin/wsl-vpnkit";
  #      Restart = "always";
  #      KillMode = "mixed";
  #    };
  #  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
