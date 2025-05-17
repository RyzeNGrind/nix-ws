{ pkgs, ... }: # Simplest possible Home Manager module signature

{
  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";
  home.stateVersion = "24.05"; # Must match your Home Manager version

  programs.home-manager.enable = true;

  # Add a single, simple package to ensure something is happening
  home.packages = [ pkgs.hello ];

  # All other configurations and imports are removed for this test.
  imports = [];
}
