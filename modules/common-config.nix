# Common configuration module that defines central settings for all NixOS systems
{ lib, config, pkgs, ... }:

let
  # Central configuration settings
  nixConfig = {
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
  userConfig = {
    name = "ryzengrind";
    homeDirectory = "/home/ryzengrind";
    uid = 1000;
    description = "NixOS System Administrator";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPL6GOQ1zpvnxJK0Mz+vUHgEd0f/sDB0q3pa38yHHEsC ryzengrind@git"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaDf9eWQpCOZfmuCwkc0kOH6ZerU7tprDlFTc+RHxCq ryzengrind@termius"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAitSzTpub1baCfA94ja3DNZpxd74kDSZ8RMLDwOZEOw ryzengrind@nixos"
    ];
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    # Default password, should be changed or managed via secrets in production
    initialPassword = "nixos";
  };

  # Common packages to be installed on all systems
  commonPackages = with pkgs; [
    neovim
    curl
    htop
    wget
    git
    tmux
    # Build optimization packages
    nix-output-monitor
  ];
  
  # Build system configuration
  buildSystemConfig = {
    enableFastBuild = true;
    defaultBuildFlags = "--skip-cached";
    evalWorkers = 4; # Adjust based on CPU cores
  };

  # VPN/Network packages and settings
  networkConfig = {
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
in
{
  # Export the configuration for use in other modules
  options = {
    commonConfig = lib.mkOption {
      type = lib.types.attrs;
      description = "Common configuration settings for all systems";
      default = {
        inherit nixConfig userConfig commonPackages networkConfig;
      };
    };
  };
  
  # Apply some common settings directly when this module is imported
  config = {
    # Set state version
    system.stateVersion = nixConfig.stateVersion;
    
    # Apply common nix settings
    nix.settings = {
      experimental-features = nixConfig.experimentalFeatures;
      trusted-public-keys = nixConfig.trustedPublicKeys;
      substituters = nixConfig.substituters;
    };
    nixpkgs.config.allowUnfree = nixConfig.allowUnfree;
    
    # Install common packages
    environment.systemPackages = commonPackages;
    
    # Setup common user 
    users.users.${userConfig.name} = {
      isNormalUser = true;
      home = userConfig.homeDirectory;
      uid = userConfig.uid;
      description = userConfig.description;
      extraGroups = userConfig.extraGroups;
      initialPassword = userConfig.initialPassword;
      openssh.authorizedKeys.keys = userConfig.authorizedKeys;
    };
  };
}