# modules/virtualization.nix
# Comprehensive virtualization module with VFIO GPU passthrough support
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.ryzengrind;
in {
  options.virtualisation.ryzengrind = {
    enable = mkEnableOption "Enable RyzeNGrind's virtualization stack";

    vfioIds = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "10de:2204" "10de:1aef" ];  # Example IDs for NVIDIA RTX 4090
      description = "PCI IDs of devices to bind to vfio-pci";
    };

    lookingGlass = {
      enable = mkEnableOption "Enable Looking Glass for low-latency VM display";
      memSize = mkOption {
        type = types.str;
        default = "64M";
        description = "Size of shared memory for Looking Glass";
      };
    };
    
    windows11Vm = {
      enable = mkEnableOption "Enable pre-configured Windows 11 VM";
      cpuCores = mkOption {
        type = types.int;
        default = 8;
        description = "Number of CPU cores to allocate to Windows 11 VM";
      };
      memory = mkOption {
        type = types.int;
        default = 16384;
        description = "Amount of RAM in MB to allocate to Windows 11 VM";
      };
      diskSize = mkOption {
        type = types.int;
        default = 200;
        description = "Size in GB for Windows 11 VM disk";
      };
      diskPath = mkOption {
        type = types.str;
        default = "/var/lib/libvirt/images/win11.qcow2";
        description = "Path to Windows 11 VM disk image";
      };
      autostart = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically start Windows 11 VM at boot";
      };
    };
  };

  config = mkIf cfg.enable {
    # Base virtualization packages
    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      spice-gtk
      win-virtio  # Windows VirtIO drivers
      OVMF        # UEFI firmware
      pciutils    # For lspci
      usbutils    # For lsusb
      qemu_kvm
      swtpm       # TPM emulation for Windows 11
      
      # Looking Glass if enabled
      (mkIf cfg.lookingGlass.enable looking-glass-client)
    ];

    # Enable libvirtd
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMF.fd ];
          };
          swtpm.enable = true;  # Required for Windows 11 TPM
        };
        onBoot = "ignore";
        onShutdown = "shutdown";
      };
      
      # Enable spiceUSBRedirection if using SPICE for VM display
      spiceUSBRedirection.enable = true;
    };

    # VFIO setup for GPU passthrough
    boot = {
      initrd.kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
        "vfio_virqfd"
      ];

      # Configure VFIO PCI passthrough
      kernelParams = mkIf (cfg.vfioIds != []) (
        [ "intel_iommu=on" "iommu=pt" ] ++
        (map (id: "vfio-pci.ids=${id}") cfg.vfioIds)
      );

      # Blacklist GPU drivers if using VFIO passthrough
      blacklistedKernelModules = mkIf (cfg.vfioIds != []) [ 
        "nvidia" 
        "nouveau" 
      ];
    };

    # Set up Looking Glass shared memory if enabled
    systemd.tmpfiles.rules = mkIf cfg.lookingGlass.enable [
      "f /dev/shm/looking-glass 0660 ryzengrind kvm -"
    ];

    # Configure huge pages for better VM performance
    boot.kernelParams = mkIf cfg.enable [
      "default_hugepagesz=1G"
      "hugepagesz=1G"
      "hugepages=16"
    ];

    # Create Windows 11 VM if enabled
    system.activationScripts = mkIf cfg.windows11Vm.enable {
      createWin11Vm = ''
        # Create disk if it doesn't exist
        if [ ! -f ${cfg.windows11Vm.diskPath} ]; then
          mkdir -p $(dirname ${cfg.windows11Vm.diskPath})
          ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 ${cfg.windows11Vm.diskPath} ${toString cfg.windows11Vm.diskSize}G
        fi
      '';
    };
    
    # Windows 11 automated setup script
    # This will be used by the PowerShell script to set up the Windows VM
    environment.etc."win11-vm-setup/setup-win11.ps1" = mkIf cfg.windows11Vm.enable {
      text = ''
        # Windows 11 VM setup PowerShell script
        # Run this from within Windows to configure optimally for gaming

        # Enable High Performance power plan
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

        # Disable unnecessary services
        $services = @(
            "DiagTrack",                       # Connected User Experiences and Telemetry
            "dmwappushservice",                # WAP Push Message Routing Service
            "MapsBroker",                      # Downloaded Maps Manager
            "lfsvc",                           # Geolocation Service
            "SharedAccess",                    # Internet Connection Sharing
            "lltdsvc",                         # Link-Layer Topology Discovery Mapper
            "NgcSvc",                          # Microsoft Passport Service
            "NgcCtnrSvc",                      # Microsoft Passport Container Service
            "SEMgrSvc",                        # Payments and NFC/SE Manager
            "PimIndexMaintenanceSvc",          # Contact Data
            "WpnService",                      # Windows Push Notifications System Service
            "WerSvc"                           # Windows Error Reporting Service
        )

        foreach ($service in $services) {
            Set-Service -Name $service -StartupType Disabled
        }

        # Configure registry for gaming performance
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        New-Item -Path $regPath -Name "HwSchMode" -Force
        Set-ItemProperty -Path $regPath -Name "HwSchMode" -Value 2

        # Disable game bar
        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
        New-Item -Path $regPath -Force
        Set-ItemProperty -Path $regPath -Name "AppCaptureEnabled" -Value 0
        Set-ItemProperty -Path $regPath -Name "GameDVR_Enabled" -Value 0

        # Set power settings for best performance
        powercfg -setacvalueindex scheme_current sub_processor PERFINCPOL 2
        powercfg -setacvalueindex scheme_current sub_processor PERFDECPOL 1
        powercfg -setactive scheme_current

        # Disable Windows Defender (for gaming performance)
        # Note: This reduces security, only do this for dedicated gaming VMs
        Set-MpPreference -DisableRealtimeMonitoring $true

        # Set virtual memory size
        $computerSystem = Get-WmiObject Win32_ComputerSystem
        $totalMemory = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB)
        $maxPageFile = ($totalMemory * 1.5) * 1024
        $minPageFile = ($totalMemory * 0.75) * 1024

        $pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
        $pagefile.AutomaticManagedPagefile = $false
        $pagefile.Put()

        $pagefileSetting = Get-WmiObject Win32_PageFileSetting
        $pagefileSetting.InitialSize = $minPageFile
        $pagefileSetting.MaximumSize = $maxPageFile
        $pagefileSetting.Put()

        Write-Host "Windows 11 VM has been optimized for gaming performance."
      '';
      mode = "0644";
    };

    # Add user to libvirt group
    users.users.ryzengrind.extraGroups = [ "libvirtd" "kvm" "qemu-libvirtd" ];
    
    # Enable services
    systemd.services.libvirtd.enable = true;
    
    networking.firewall = {
      allowedTCPPorts = [ 
        5900  # VNC
        3389  # RDP
        5901 5902 5903  # Additional VNC ports
      ];
    };
  };
}