{ config, pkgs, lib, inputs, ... }: # Standard Home Manager module arguments

{
  # Hardcode basic settings, removing dependency on common-config.nix for this test
  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";
  home.stateVersion = "24.05"; # Explicitly "24.05" to match home-manager release-24.05

  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false; # Disable HM/Nixpkgs version mismatch warning

  imports = [
    # ../modules/common-config.nix # Temporarily REMOVED for debugging
    ./modules/1password-ssh.nix  # For 1Password SSH agent functionality

    # External flake modules remain commented out
    # (if (inputs.std or null) != null && inputs.std ? homeModules && inputs.std.homeModules ? default then inputs.std.homeModules.default else null)
    # ... and others ...
  ];
}
