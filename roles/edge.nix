# IoT/Edge device configuration
{ config, lib, ... }:

{
  # Lightweight services optimization
  # IoT connectivity configurations
  # Resource constrained environment settings

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos-edge";
    fsType = "ext4";
  };
  boot.loader.grub.devices = [ "/dev/sda" ];
}