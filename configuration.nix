# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    nixos-wsl.nixosModules.wsl
  ];

  nix.settings = { 
    trusted-users = [ "root" "@wheel" ];
    experimental-features = [ "auto-allocate-uids" "ca-derivations" "cgroups" "dynamic-derivations" "fetch-closure" "fetch-tree" "flakes" "git-hashing" "local-overlay-store" "mounted-ssh-store" "no-url-literals" "pipe-operators" "nix-command" "recursive-nix"]; 
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
      package = pkgs.bashInteractive;
      enable = true;
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
      bashInteractive  # Replace regular bash
      bash-completion  # Better completion support
      ncurses          # Terminfo database
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
    ];
  };  
  security.sudo = {
    enable = true;
    execWheelOnly = true;  # Optional security measure
    wheelNeedsPassword = false;
  };

  users.users.ryzengrind = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "audio" "docker" "kvm" "libvirt" "libvirtd" "networkmanager" "podman" "qemu-libvirtd" "users" "video" "wheel" ];
  };

  wsl = {
    enable = true;
    defaultUser = "ryzengrind";
    wslConf.network.hostname = "nix-ws";
    startMenuLaunchers = true;
    docker-desktop.enable = false;
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
