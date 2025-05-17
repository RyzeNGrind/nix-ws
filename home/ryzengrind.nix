{ inputs, host ? null, lib, pkgs, config, ... }: # Rely on 'inputs' from extraSpecialArgs for flake inputs
let
  # Access flake inputs via the 'inputs' argument passed from extraSpecialArgs
  std = inputs.std or null;
  hive = inputs.hive or null;
  current_devmods = inputs.devmods or null;
  current_flakelight = inputs.flakelight or null;

  # commonModule is no longer imported manually here; it's added to imports.
  # Values from common-config will be accessed via the 'config' argument.
in
{
  # Values from common-config.nix are accessed via the 'config' argument
  # once common-config.nix is correctly imported.
  # common-config.nix defines options.commonConfig.userConfig.name etc.
  # and sets config.commonConfig.userConfig.name etc. in its own 'config' block.
  # However, common-config.nix directly sets users.users.ryzengrind.name etc.
  # So, we might not need to reference config.commonConfig here if common-config already sets these.
  # Let's assume common-config sets these directly for now, or they are options.
  # For safety, we'll assume common-config makes its values available under config.commonConfig.
  home.username = config.commonConfig.userConfig.name;
  home.homeDirectory = config.commonConfig.userConfig.homeDirectory;
  home.stateVersion = config.commonConfig.nixConfig.stateVersion; # This was defined in common-config's let block,
                                                              # but used to set system.stateVersion.
                                                              # For HM's stateVersion, it should be set directly or from an option.
                                                              # common-config sets system.stateVersion, not home.stateVersion.
                                                              # We'll use the one from common-config's nixConfig let binding for now.
  programs.home-manager.enable = true;

  imports = lib.filter (x: x != null) [ # Use lib.filter to remove nulls if inputs are missing
    ../modules/common-config.nix # Import common-config as a module
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
