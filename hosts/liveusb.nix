{ config, pkgs, ... }:
{
  imports = [
    ../modules/overlay-networks.nix
    ../modules/devshell.nix
    ../modules/users.nix
    ../modules/secrets.nix
  ];
  networking.hostName = "liveusb";
  # Additional host-specific config can go here
}
