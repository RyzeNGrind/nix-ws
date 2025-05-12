# SurfaceBook3 workstation configuration
{ config, lib, ... }:

{
  # Mobile optimization settings
  # Remote dev tools (SSH, RDP)
  # GPU passthrough for gaming/virtualization
  # Realtime audio scheduling for music production

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.grub.devices = [ "/dev/sda" ];
}