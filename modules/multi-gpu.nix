# modules/multi-gpu.nix
# Configuration for multi-GPU setups with mixed Intel/NVIDIA GPUs
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.nvidia-multi-gpu;
  
  # Helper function to generate X11 display configurations
  makeScreenSection = { 
    device, 
    monitor, 
    screenName ? "Screen0", 
    defaultDepth ? 24,
    resolution ? "3840x2160", 
    refreshRate ? 60
  }: ''
    Section "Screen"
      Identifier "${screenName}"
      Device "${device}"
      Monitor "${monitor}"
      DefaultDepth ${toString defaultDepth}
      SubSection "Display"
        Depth ${toString defaultDepth}
        Modes "${resolution}_${toString refreshRate}"
      EndSubSection
    EndSection
  '';

  makeMonitorSection = {
    name, 
    identifier, 
    vendorName ? "Generic",
    modelName ? "Monitor",
    horizontalSync ? "30.0 - 140.0",
    verticalRefresh ? "60.0 - 165.0",
    modeLine ? "3840x2160_60 533.25 3840 3888 3920 4000 2160 2163 2168 2222 +hsync -vsync"
  }: ''
    Section "Monitor"
      Identifier "${identifier}"
      VendorName "${vendorName}"
      ModelName "${modelName}"
      HorizSync ${horizontalSync}
      VerticalRefresh ${verticalRefresh}
      Modeline "${modeLine}"
    EndSection
  '';

  makeDeviceSection = {
    identifier, 
    driver, 
    busID ? null,
    options ? { }
  }: let
    # Convert options to X11 conf format
    optionsStr = concatStringsSep "\n  " 
      (mapAttrsToList (name: value: "Option \"${name}\" \"${toString value}\"") options);
    busIDStr = optionalString (busID != null) ''
      BusID "${busID}"
    '';
  in ''
    Section "Device"
      Identifier "${identifier}"
      Driver "${driver}"
      ${busIDStr}
      ${optionsStr}
    EndSection
  '';
in {
  options.hardware.nvidia-multi-gpu = {
    enable = mkEnableOption "Enable multi-GPU support with NVIDIA and Intel";

    intelPrimary = mkOption {
      type = types.bool;
      default = true;
      description = "Use Intel iGPU as primary display device";
    };

    reserveGpu = mkOption {
      type = types.str;
      default = "RTX4090";
      example = "RTX4090";
      description = "GPU model to reserve for VFIO passthrough (e.g., RTX4090)";
    };

    # Allow specifying PCI IDs directly
    intelPciBusId = mkOption {
      type = types.str;
      default = "PCI:0:2:0";
      example = "PCI:0:2:0";
      description = "PCI bus ID for Intel iGPU";
    };

    nvidia1050PciBusId = mkOption {
      type = types.str;
      default = "PCI:1:0:0";
      example = "PCI:1:0:0";
      description = "PCI bus ID for NVIDIA GTX 1050 Ti";
    };

    nvidia4090PciBusId = mkOption {
      type = types.str;
      default = "PCI:2:0:0";
      example = "PCI:2:0:0";
      description = "PCI bus ID for NVIDIA RTX 4090 (for passthrough)";
    };
    
    # X11 server configuration
    customXorgConf = mkOption {
      type = types.bool;
      default = true;
      description = "Generate a custom Xorg.conf file for multi-GPU setup";
    };
  };

  config = mkIf cfg.enable {
    # Base NVIDIA driver setup
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # Set up display drivers
    services.xserver.videoDrivers = [ "nvidia" "intel" ];
    
    # Enable OpenGL and DRI support for all GPUs
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for some applications)
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    # Add kernel parameters for proper DRM and GPU handling
    boot.kernelParams = [
      "nvidia-drm.modeset=1"
      "video=efifb:off"
    ] ++ optionals cfg.intelPrimary [
      # Ensure Intel is initialized first for primary display
      "vga=0" 
      "nomodeset"
    ];

    # Environment variables for GPU handling
    environment.variables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia"; # Use NVIDIA for GLX
      LIBVA_DRIVER_NAME = "iHD";           # Intel media driver for VAAPI
    };

    # Custom Xorg configuration for multi-GPU support
    services.xserver.extraConfig = mkIf cfg.customXorgConf ''
      Section "ServerLayout"
        Identifier "layout"
        Screen 0 "intelScreen"
        ${optionalString (!cfg.intelPrimary) ''
          Screen 0 "nvidiaScreen"
          Screen 1 "intelScreen" RightOf "nvidiaScreen"
        ''}
        ${optionalString cfg.intelPrimary ''
          Screen 1 "nvidiaScreen" RightOf "intelScreen"
        ''}
        Option "AllowNVIDIAGPUScreens"
      EndSection

      # Intel GPU configuration
      ${makeDeviceSection {
        identifier = "intelGPU";
        driver = "intel";
        busID = cfg.intelPciBusId;
        options = {
          AccelMethod = "sna";
          TearFree = "true";
          DRI = "3";
        };
      }}
      
      ${makeMonitorSection {
        name = "Intel Monitor";
        identifier = "intelMonitor";
        vendorName = "Intel";
        modelName = "Integrated Display";
      }}
      
      ${makeScreenSection {
        device = "intelGPU";
        monitor = "intelMonitor";
        screenName = "intelScreen";
      }}

      # NVIDIA GTX 1050 Ti configuration
      ${makeDeviceSection {
        identifier = "nvidia1050";
        driver = "nvidia";
        busID = cfg.nvidia1050PciBusId;
        options = {
          AllowEmptyInitialConfiguration = "true";
          UseDisplayDevice = "none";
          TripleBuffer = "true";
        };
      }}
      
      ${makeMonitorSection {
        name = "NVIDIA Monitor";
        identifier = "nvidiaMonitor";
        vendorName = "NVIDIA";
        modelName = "GTX 1050 Ti";
      }}
      
      ${makeScreenSection {
        device = "nvidia1050";
        monitor = "nvidiaMonitor";
        screenName = "nvidiaScreen";
      }}
    '';
    
    # NVIDIA Prime configuration for multi-GPU setup
    hardware.nvidia.prime = {
      # Sync mode provides better integration but offload is more efficient
      sync.enable = false;
      offload.enable = !cfg.intelPrimary;
      
      intelBusId = cfg.intelPciBusId;
      nvidiaBusId = cfg.nvidia1050PciBusId;
    };
    
    # Let's add special handling for display manager configurations
    services.xserver.displayManager = {
      # For SDDM, ensure proper GPU is used
      sddm.enableHidpi = true;
      # For GDM, which is used in current config
      gdm = {
        wayland = false; # Disable Wayland for better compatibility with multiple GPUs
        nvidiaWayland = false; 
      };
    };
    
    # Add appropriate tools for GPU management
    environment.systemPackages = with pkgs; [
      pciutils
      glxinfo
      vulkan-tools
      nvtop
      nvitop     # Higher quality NVIDIA monitoring
      intel-gpu-tools
      clinfo     # OpenCL info
    ];
    
    # Special service to automatically handle multi-GPU integration
    systemd.services.configure-multi-gpu = {
      description = "Configure multi-GPU environment";
      wantedBy = [ "multi-user.target" ];
      after = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "configure-multi-gpu" ''
          #!/bin/sh
          set -e
          
          # Setup environment for application-specific GPU selection
          echo "Setting up environment for multi-GPU usage..."
          
          # Create helper script at /usr/local/bin/nvidia-run
          mkdir -p /usr/local/bin
          cat > /usr/local/bin/nvidia-run << 'EOF'
          #!/bin/sh
          export __NV_PRIME_RENDER_OFFLOAD=1
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export __VK_LAYER_NV_optimus=NVIDIA_only
          exec "$@"
          EOF
          
          chmod +x /usr/local/bin/nvidia-run
          echo "Created nvidia-run helper script at /usr/local/bin/nvidia-run"
        '';
      };
    };

    # Documentation for users
    environment.etc."multi-gpu-usage.md" = {
      text = ''
        # Multi-GPU Configuration Guide
        
        Your system is configured with multiple GPUs:
        - Intel iGPU: Used as ${if cfg.intelPrimary then "primary" else "secondary"} display
        - NVIDIA GTX 1050 Ti: Used as ${if !cfg.intelPrimary then "primary" else "secondary"} display
        - NVIDIA RTX 4090: Reserved for VM passthrough
        
        ## Running applications on NVIDIA GPU:
        
        Use the `nvidia-run` helper:
        
        ```bash
        nvidia-run glxgears  # Run glxgears on the NVIDIA GPU
        nvidia-run steam     # Run Steam on the NVIDIA GPU
        ```
        
        ## Checking GPU status:
        
        ```bash
        nvtop               # Monitor NVIDIA GPUs
        intel_gpu_top       # Monitor Intel GPU
        glxinfo | grep OpenGL  # Check which GPU is used for OpenGL
        ```
        
        ## Troubleshooting:
        
        If displays are not working correctly, try:
        
        ```bash
        sudo systemctl restart display-manager.service
        ```
        
        You can check the GPU PCI addresses with:
        
        ```bash
        lspci | grep -E "VGA|3D|Display"
        ```
      '';
      mode = "0444";
    };
  };
}