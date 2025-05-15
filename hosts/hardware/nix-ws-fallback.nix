# Fallback hardware configuration for nix-ws
# Used when /etc/nixos/hardware-configuration.nix is not available
# DO NOT EDIT: This is a template and will be overridden by nixos-generate-config
# when deployed to actual hardware.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ 
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Minimal required boot settings - these will be ignored on an actual system
  # that has /etc/nixos/hardware-configuration.nix
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # These UUIDs are from your current system, but will be overridden
  # by the actual hardware-configuration.nix on the target system
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5dc27f19-81cf-49db-a770-3415885b6cb7";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/17B6-1473";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/a869621e-d381-4777-adc8-7de13e6ae4b0"; }
  ];

  # Enables DHCP on each ethernet and wireless interface
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Add warnings to make it clear this is a fallback
  warnings = [
    ''
    ⚠️ Using fallback hardware configuration for nix-ws
    This means you're building without access to the target machine's hardware-configuration.nix
    When deploying to the actual machine, run: nixos-generate-config
    ''
  ];
}