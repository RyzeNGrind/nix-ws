{ config, pkgs, lib, inputs, ... }: # Standard Home Manager module arguments

{
  # Basic required settings
  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";
  home.stateVersion = "24.11"; # Set to your target state version

  programs.home-manager.enable = true;

  # All other complex configurations and imports are temporarily removed for debugging.
  # This includes common-config, 1password-ssh, std, hive, etc.
  imports = [
    # Ensure this list is empty or contains only known-good, ultra-simple modules
    # if absolutely necessary for basic evaluation. For now, keeping it empty.
  ];

  # You can add a simple, known-good package to test activation:
  # home.packages = [ pkgs.hello ];
}
