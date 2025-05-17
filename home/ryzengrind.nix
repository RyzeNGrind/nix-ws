{ config, pkgs, lib, inputs, ... }: # Standard Home Manager module arguments

{
  # Basic required settings from common-config
  home.username = config.commonConfig.userConfig.name;
  home.homeDirectory = config.commonConfig.userConfig.homeDirectory;
  # home.stateVersion is set explicitly below to "24.05"

  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false; # Disable HM/Nixpkgs version mismatch warning

  imports = [
    ../modules/common-config.nix # For common user settings
    ./modules/1password-ssh.nix  # For 1Password SSH agent functionality

    # External flake modules remain commented out for further stability/debugging if needed
    # (if inputs.std != null && inputs.std ? homeModules && inputs.std.homeModules ? default then inputs.std.homeModules.default else null)
    # (if inputs.hive != null && inputs.hive ? homeModules && inputs.hive.homeModules ? default then inputs.hive.homeModules.default else null)
    # (if (inputs.devmods or null) != null && inputs.devmods ? homeModules && inputs.devmods.homeModules ? default then inputs.devmods.homeModules.default else null)
    # (if (inputs.flakelight or null) != null && inputs.flakelight ? homeModules && inputs.flakelight.homeModules ? default then inputs.flakelight.homeModules.default else null)
  ];

  # Ensure stateVersion is explicitly 24.05 if common-config doesn't set it as such for home.stateVersion
  # common-config.nix sets system.stateVersion = "24.11" and options.commonConfig.default.nixConfig.stateVersion = "24.11"
  # So, we must override home.stateVersion here to "24.05" for HM 24.05.
  home.stateVersion = "24.05";
}
