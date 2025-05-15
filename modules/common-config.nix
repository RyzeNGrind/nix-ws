# Common configuration module that defines central settings for all NixOS systems
{ lib, config, pkgs, ... }:

let
  # Central configuration settings
  nixConfig = {
    stateVersion = "24.11"; # From your /etc/nixos/configuration.nix
    experimentalFeatures = [
      "auto-allocate-uids" "ca-derivations" "cgroups" "dynamic-derivations"
      "fetch-closure" "fetch-tree" "flakes" "git-hashing" "local-overlay-store"
      "mounted-ssh-store" "no-url-literals" "pipe-operators" "nix-command"
      "recursive-nix"
    ]; # From your /etc/nixos/configuration.nix
    allowUnfree = true; # From your /etc/nixos/configuration.nix
    allowBroken = true; # From your /etc/nixos/configuration.nix

    # Substituters and trusted keys from your /etc/nixos/configuration.nix
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://ryzengrind.cachix.org"
      "https://ryzengrind-nix-config.cachix.org"
      "https://daimyo.cachix.org"
      # Consider if "http://localhost:9001" is needed for all hosts or specific ones
    ];
    trustedPublicKeys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw=" # Added from flake.nix as it's common
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "ryzengrind.cachix.org-1:bejzYd+Baf3Mwua/xSeysm97G9JL8133glujCUCnK7g="
      "ryzengrind-nix-config.cachix.org-1:V3lFs0Pd5noCZegBaSgnWGjGqJgY7XTcTKG/Baj8jXk="
      "daimyo.cachix.org-1:IgolikHY/HwiVJWM2UoPhSK+dzGrJ3IgY0joV9VTpC8="
      # "localhost:VXOPwgEJPB/fAiY+EopQY7gvVfQZyF1+ifn2NhYYJgA=" # Consider if needed for all hosts
    ];
    # Additional settings from your /etc/nixos/configuration.nix
    trustedUsers = ["root" "@wheel" "ryzengrind"];
    requireSigs = true;
    acceptFlakeConfig = true;
    allowDirty = true; # Note: allowDirty is generally for development convenience.
    warnDirty = false;
  };

  # User settings (remains largely the same, but ensure consistency)
  userConfig = {
    name = "ryzengrind";
    homeDirectory = "/home/ryzengrind";
    uid = 1000;
    description = "NixOS System Administrator"; # Updated description
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPL6GOQ1zpvnxJK0Mz+vUHgEd0f/sDB0q3pa38yHHEsC ryzengrind@git"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaDf9eWQpCOZfmuCwkc0kOH6ZerU7tprDlFTc+RHxCq ryzengrind@termius"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAitSzTpub1baCfA94ja3DNZpxd74kDSZ8RMLDwOZEOw ryzengrind@nixos"
    ];
    extraGroups = [ "wheel" "networkmanager" "docker" "ryzengrind" ]; # Added "ryzengrind" group from /etc/nixos/configuration.nix
    initialPassword = "nixos"; # Default password, manage via secrets in production.
  };

  # Common packages to be installed on all systems
  commonPackages = with pkgs; [
    # Core development and system tools
    neovim # Or your preferred editor like vim/nano
    curl
    wget
    htop
    git
    tmux
    jq # Useful JSON processor

    # Build optimization packages
    nix-output-monitor
    # Consider adding other common dev tools if universally needed
  ];

  # Build system configuration (remains the same)
  buildSystemConfig = {
    enableFastBuild = true;
    defaultBuildFlags = "--skip-cached";
    evalWorkers = 4; # Adjust based on CPU cores
  };

  # VPN/Network packages and settings (remains largely the same)
  networkConfig = {
    vpnPackages = with pkgs; [
      zerotierone
      cloudflared
      tailscale
    ];
    zerotierNetworks = [ "fada62b0158621fe" ]; # From your /etc/nixos/configuration.nix
    tailscaleSettings = {
      enable = true; # Tailscale itself is enabled here
      # useRoutingFeatures = "client"; # This is more of a client-side setting, often managed by `tailscale up` flags
    };
    # Note: The tailscale-autoconnect service with auth key is host-specific
    # and was moved to hosts/nix-ws.nix.
    # Cloudflared tunnel configuration is also typically host-specific or managed via its own module.
  };
in
{
  # Export the configuration for use in other modules
  options = {
    commonConfig = lib.mkOption {
      type = lib.types.attrs;
      description = "Common configuration settings for all systems";
      default = {
        inherit nixConfig userConfig commonPackages networkConfig buildSystemConfig; # Added buildSystemConfig
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
      trusted-users = nixConfig.trustedUsers;
      require-sigs = nixConfig.requireSigs;
      accept-flake-config = nixConfig.acceptFlakeConfig;
      allow-dirty = nixConfig.allowDirty;
      warn-dirty = nixConfig.warnDirty;
      # auto-optimise-store = true; # Consider adding this for store optimization
    };
    nixpkgs.config = {
      allowUnfree = nixConfig.allowUnfree;
      allowBroken = nixConfig.allowBroken; # Added from /etc/nixos/configuration.nix
    };

    # Install common packages
    environment.systemPackages = commonPackages;

    # Setup common user
    users.users.${userConfig.name} = {
      isNormalUser = true;
      home = userConfig.homeDirectory;
      uid = userConfig.uid;
      description = userConfig.description;
      extraGroups = userConfig.extraGroups;
      initialPassword = userConfig.initialPassword; # Consider using hashedPasswordFile for better security
      openssh.authorizedKeys.keys = userConfig.authorizedKeys;
    };

    # Enable core services that are generally useful
    services.zerotierone = {
      enable = true;
      joinNetworks = networkConfig.zerotierNetworks;
    };
    services.tailscale.enable = networkConfig.tailscaleSettings.enable;

    # Ensure common system utilities are available
    programs.git.enable = true;
  };
}