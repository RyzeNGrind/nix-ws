{ inputs, host ? null, ... }:
let
  devmods = inputs ? devmods && inputs.devmods;
  flakelight = inputs ? flakelight && inputs.flakelight;
in
{
  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # Modular Home Manager config via divnix/std cells (add as needed)
  imports = [
    # ./shells.nix
    # ./editors.nix
    # ./dotfiles.nix
  ];

  # Devshells via devmods/flakelight if available
  devmods.shells =
    if devmods != null && flakelight != null then [ flakelight.shells.minimal ] else [];
  # void-editor devshell is defined in void-editor.nix, do not duplicate
}
