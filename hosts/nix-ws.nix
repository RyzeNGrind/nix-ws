{ lib, config, pkgs, inputs, ...
}:

# Define local common configuration in case the global one isn't available
let
  # Common configuration settings
  commonNixConfig = {
    stateVersion = "24.11";
    experimentalFeatures = [ "nix-command" "flakes" ];
    allowUnfree = true;
    substituters = [
      "https://nixpkgs-ci.cachix.org"
      "https://cache.nixos.org"
    ];
    trustedPublicKeys = [
      "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # User settings
  commonUserConfig = {
    name = "ryzengrind";
    homeDirectory = "/home/ryzengrind";
    uid = 1000;
    description = "NixOS System Administrator";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPL6GOQ1zpvnxJK0Mz+vUHgEd0f/sDB0q3pa38yHHEsC ryzengrind@git"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaDf9eWQpCOZfmuCwkc0kOH6ZerU7tprDlFTc+RHxCq ryzengrind@termius"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAitSzTpub1baCfA94ja3DNZpxd74kDSZ8RMLDwOZEOw ryzengrind@nixos"
    ];
    initialPassword = "nixos";
  };

  # Common packages
  commonSystemPackages = with pkgs; [
    neovim
    curl
    htop
    wget
    git
    tmux
  ];

  # Network configuration
  commonNetworkConfig = {
    vpnPackages = with pkgs; [
      zerotierone
      cloudflared
      tailscale
    ];
    zerotierNetworks = [ "fada62b0158621fe" ];
    tailscaleSettings = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };

  # Try to use global common config if available, otherwise use local
  nixConfig = if config ? commonConfig then config.commonConfig.nixConfig else commonNixConfig;
  userConfig = if config ? commonConfig then config.commonConfig.userConfig else commonUserConfig;
  commonPackages = if config ? commonConfig then config.commonConfig.commonPackages else commonSystemPackages;
  networkConfig = if config ? commonConfig then config.commonConfig.networkConfig else commonNetworkConfig;

in
{
  imports = [
    # Specific modules
    ../modules/overlay-networks.nix
    ../modules/devshell.nix
    ../modules/secrets.nix
  ];
  
  networking.hostName = "nix-ws";
  
  # Enable VPN services using the common network config
  services.tailscale = networkConfig.tailscaleSettings;
  services.zerotierone = {
    enable = true;
    joinNetworks = networkConfig.zerotierNetworks;
  };
  
  # Use state version from common config
  system.stateVersion = nixConfig.stateVersion;
  
  # The buildSystem options are now handled by the nix.fastBuild module
  # imported via nixosCommon in flake.nix.
  
  # Additional host-specific config can go here
}
