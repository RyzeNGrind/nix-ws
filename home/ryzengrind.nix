{ inputs, host ? null, std ? null, hive ? null, devmods ? null, flakelight ? null, ... }:
let
  devmods_ = inputs ? devmods && inputs.devmods;
  flakelight_ = inputs ? flakelight && inputs.flakelight;
in
{
  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";
  home.stateVersion = "24.11";
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
