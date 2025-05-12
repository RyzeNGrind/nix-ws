# Production server configuration
{ config, lib, ... }:

{
  # Hardened security settings
  # High availability configurations
  # Automated backup integrations
  # Monitoring and logging setups

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos-server";
    fsType = "ext4";
  };
  boot.loader.grub.devices = [ "/dev/sda" ];
}