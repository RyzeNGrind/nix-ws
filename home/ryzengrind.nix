{ inputs, host ? null, lib, pkgs, config, ... }: # Rely on 'inputs' from extraSpecialArgs for flake inputs
let
  # Access flake inputs via the 'inputs' argument passed from extraSpecialArgs
  std = inputs.std or null;
  hive = inputs.hive or null;
  current_devmods = inputs.devmods or null; # Renamed to avoid conflict if 'devmods' is an option set
  current_flakelight = inputs.flakelight or null;

  # Import the common-config module for access to the settings
  # Ensure common-config.nix can handle being imported this way, or adjust its signature/usage
  commonModule = import ../modules/common-config.nix {
    lib = inputs.nixpkgs.lib; # Use nixpkgs.lib explicitly
    config = {}; # Passing an empty config here might still be an issue if common-config expects more
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

  imports = lib.filter (x: x != null) [ # Use lib.filter to remove nulls if inputs are missing
    (if std != null && std ? homeModules && std.homeModules ? default then std.homeModules.default else null)
    (if hive != null && hive ? homeModules && hive.homeModules ? default then hive.homeModules.default else null)
    (if current_devmods != null && current_devmods ? homeModules && current_devmods.homeModules ? default then current_devmods.homeModules.default else null)
    (if current_flakelight != null && current_flakelight ? homeModules && current_flakelight.homeModules ? default then current_flakelight.homeModules.default else null)
    ./modules/1password-ssh.nix
    # ./shells.nix
    # ./editors.nix
    # ./dotfiles.nix
  ];

  # Devshells via devmods/flakelight if available
  # This section is problematic. 'devmods.shells =' is not standard Home Manager option assignment.
  # It should be 'config.programs.someProgram.shells = ...' or similar if 'devmods' provides such options.
  # Commenting out for now to ensure home-manager switch can proceed.
  # You'll need to refactor this based on how 'devmods' and 'flakelight' are intended to configure shells.
  # Example:
  # programs.devmods = lib.mkIf (current_devmods != null && current_flakelight != null && current_flakelight ? shells && current_flakelight.shells ? minimal) {
  #   shells = [ current_flakelight.shells.minimal ];
  # };
  # void-editor devshell is defined in void-editor.nix, do not duplicate
}
