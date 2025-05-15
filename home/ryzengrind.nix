{ inputs, host ? null, std ? null, hive ? null, devmods ? null, flakelight ? null, ... }:
let
  devmods_ = inputs ? devmods && inputs.devmods;
  flakelight_ = inputs ? flakelight && inputs.flakelight;
  
  # Import the common-config module for access to the settings
  commonModule = import ../modules/common-config.nix {
    inherit (inputs) lib;
    config = {};
    pkgs = inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  };
  
  # Extract the user configuration
  userConfig = commonModule.config.commonConfig.userConfig;
in
{
  # Use the common user settings
  home.username = userConfig.name;
  home.homeDirectory = userConfig.homeDirectory;
  home.stateVersion = commonModule.config.commonConfig.nixConfig.stateVersion;
  programs.home-manager.enable = true;

  imports = [
    (std.homeModules.default or null)
    (hive.homeModules.default or null)
    (devmods.homeModules.default or null)
    (flakelight.homeModules.default or null)
    # ./shells.nix
    # ./editors.nix
    # ./dotfiles.nix
  ];

  # Devshells via devmods/flakelight if available
  devmods.shells =
    if devmods_ != null && flakelight_ != null then [ flakelight_.shells.minimal ] else [];
  # void-editor devshell is defined in void-editor.nix, do not duplicate
}
