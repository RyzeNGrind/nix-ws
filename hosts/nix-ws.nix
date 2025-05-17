{ lib, config, pkgs, inputs, ... }:

{
  imports = [
    # CRITICAL: Smart hardware configuration handling
    # If the system's hardware-configuration.nix exists, use it
    # Otherwise, fall back to our minimal version (for build/testing purposes)
    (if builtins.pathExists /etc/nixos/hardware-configuration.nix
     then /etc/nixos/hardware-configuration.nix
     else ./hardware/nix-ws-fallback.nix)
    
    # Modules from your flake
    ../modules/overlay-networks.nix
    ../modules/virtualization.nix
    ../modules/multi-gpu.nix
    ../modules/ai-inference.nix
    ../modules/mcp-configuration.nix
    ../modules/mcp-secrets.nix
    # Consider if the following modules are essential for this specific host configuration
    # or if their concerns are better handled globally or via Home Manager.
    # ../modules/devshell.nix
    # ../modules/secrets.nix
  ];

  # ----------------------------------------------------------------------------
  # Bootloader Configuration (safe to specify in flake)
  # ----------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Filesystem-specific settings are now handled by the imported
  # /etc/nixos/hardware-configuration.nix file

  # ----------------------------------------------------------------------------
  # Hostname and Core System Settings for nix-ws
  # Derived from your working /etc/nixos/configuration.nix
  # ----------------------------------------------------------------------------
  networking.hostName = "nix-ws";

  boot.supportedFilesystems = [ "ntfs" "exfat" ]; # For accessing other drives/partitions

  networking.networkmanager.enable = true; # Standard for desktop network management
  hardware.graphics.enable = true; # General graphics enablement (specific drivers elsewhere if needed)
  
  # ----------------------------------------------------------------------------
  # VFIO GPU Passthrough and Virtualization Configuration
  # ----------------------------------------------------------------------------
  virtualisation.ryzengrind = {
    enable = true;
    
    # VFIO GPU passthrough configuration
    # Use 'lspci -nnk' to find these IDs and replace with your actual RTX 4090 IDs
    vfioIds = [ "10de:2204" "10de:1aef" ];  # Example NVIDIA RTX 4090 IDs
    
    lookingGlass = {
      enable = true;
      memSize = "128M";  # Increased for 4K resolution
    };
    
    # Configure Windows 11 VM
    windows11Vm = {
      enable = true;
      cpuCores = 12;       # Allocate 12 cores
      memory = 32768;      # 32GB RAM
      diskSize = 500;      # 500GB disk
      autostart = false;   # Don't autostart, launch manually
    };
  };

  # ----------------------------------------------------------------------------
  # Multi-GPU Configuration
  # ----------------------------------------------------------------------------
  hardware.nvidia-multi-gpu = {
    enable = true;
    intelPrimary = true;  # Use Intel iGPU as primary display
    
    # PCI IDs for your GPUs - use 'lspci -nnk' to find these
    # Replace with actual values from your system
    intelPciBusId = "PCI:0:2:0";       # Intel iGPU
    nvidia1050PciBusId = "PCI:1:0:0";  # GTX 1050 Ti
    nvidia4090PciBusId = "PCI:2:0:0";  # RTX 4090 (for passthrough)
    
    # Let the module generate custom X11 configuration
    customXorgConf = true;
  };

  # ----------------------------------------------------------------------------
  # AI Inference Cost Optimization
  # ----------------------------------------------------------------------------
  services.ai-inference = {
    enable = true;
    
    # API keys should be replaced with securely managed secrets
    # in a production environment using sops-nix or agenix
    veniceApiKey = "";    # Will be prompted to set this during setup
    openRouterApiKey = ""; # Will be prompted to set this during setup
    
    # Target ratio: 97.3% Venice, 2.7% OpenRouter for optimal savings
    targetRatio = 97.3;
    
    # Complexity threshold (0-100) - higher means more tasks routed to Venice
    complexityThreshold = 25;
    
    # Enable Prometheus metrics
    prometheus.enable = true;
    
    # Open firewall for the service
    openFirewall = true;
  };

  # ----------------------------------------------------------------------------
  # MCP Configuration and Secure API Integration
  # ----------------------------------------------------------------------------
  services.mcp-secrets = {
    enable = true;
    user = "ryzengrind";
    # keysFile is /etc/mcp-secrets.yaml by default
  };

  services.mcp-configuration = {
    enable = true;
    user = "ryzengrind";
    debug = false; # Set to true for initial testing
    manageGlobalSettings = true;
    environmentType = "nixos"; # Change to "nixos-wsl" if needed
    
    # Use existing AI inference service configuration
    veniceRouterIntegration = {
      enable = true;
      # API keys will be sourced from sops-nix secrets
      veniceApiEndpoint = "http://localhost:8765/v1";
      openRouterApiEndpoint = "https://openrouter.ai/api/v1";
    };
    
    # Enable TaskMaster
    taskMaster = {
      enable = true;
      # API keys will be sourced from sops-nix secrets
      model = "claude-3-7-sonnet-20250219"; # Default model
      perplexityModel = "sonar-pro";
      maxTokens = 64000;
      temperature = 0.2;
      defaultSubtasks = 5;
      defaultPriority = "medium";
    };
  };

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  # ----------------------------------------------------------------------------
  # Desktop Environment (GNOME)
  # ----------------------------------------------------------------------------
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; options = "ctrl:swapcaps"; }; # Keyboard layout
  console.useXkbConfig = true; # Apply XKB settings to TTY console

  # Automatic login for GNOME
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "ryzengrind";
  # Workaround for GNOME autologin issues with getty/autovt
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  services.printing.enable = true; # CUPS for printing support

  # Sound configuration (Pipewire)
  hardware.pulseaudio.enable = false; # Disable PulseAudio in favor of Pipewire
  security.rtkit.enable = true;    # RealtimeKit for low-latency audio applications
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # Provide PulseAudio compatibility via Pipewire
    # jack.enable = true; # Uncomment if JACK audio server support is needed
  };

  # Custom Tailscale autoconnect service
  systemd.services.tailscale-autoconnect = {
    description = "Tailscale autoconnect service";
    serviceConfig.Type = "oneshot";
    # IMPORTANT: The auth key is hardcoded here from your /etc/nixos/configuration.nix.
    # For better security, this should be managed via a secrets management tool
    # like sops-nix or agenix, especially if your flake is public.
    script = with pkgs; ''
      ${tailscale}/bin/tailscale up --auth-key tskey-auth-kcGiyaY5bv11CNTRL-89rSySGMYwQihjkscHMVxQJKyyupZospY
    '';
    after = ["network-pre.target" "tailscale.service"]; # Ensure network and tailscale service are up
    wants = ["network-pre.target" "tailscale.service"];
    wantedBy = [ "multi-user.target" ]; # Start on normal system boot
  };

  # SSH server configuration
  services.openssh = {
    enable = true; # Ensure SSHD is running
    settings.PermitRootLogin = "yes"; # Set according to your security policy (e.g., "prohibit-password")
  };

  # ----------------------------------------------------------------------------
  # User Configuration and Packages
  # ----------------------------------------------------------------------------
  # Augment packages for the 'ryzengrind' user on this specific host.
  # These will be merged with packages defined in common-config.nix and Home Manager.
  users.users.ryzengrind.packages = with pkgs; [
    rustdesk-flutter      # Remote desktop client
    virt-viewer           # Virtual machine viewer
    looking-glass-client  # For low-latency VM display
    spice-gtk             # SPICE client
    remmina               # Remote desktop client with RDP support
    win-virtio           # Windows VirtIO drivers
    qemu-utils            # QEMU utilities
  ];

  # Host-specific system packages, merged with those from common-config.nix
  environment.systemPackages = with pkgs; [
    ntfs3g      # For NTFS filesystem support
    exfatprogs  # For exFAT filesystem support
    udftools    # For UDF filesystem support
    gh          # GitHub CLI

    # Gaming and multimedia
    steam-run   # Run games in sandbox
    mangohud    # Gaming performance overlay
    gamemode    # Gaming performance optimization
    
    # Secrets management GUI tools
    _1password-gui-beta
    _1password-cli
    
    # Advanced virtualization and hardware utilities
    virt-manager
    virtiofsd
    OVMF
    pciutils    # For lspci command
    usbutils    # For lsusb command
    glxinfo     # OpenGL information utility
    vulkan-tools # Vulkan tools
    nvtopPackages.intel # GPU monitoring tool for Intel GPUs
    nvtopPackages.nvidia # GPU monitoring tool for NVIDIA GPUs
    nvitop      # Higher quality NVIDIA monitoring
    intel-gpu-tools # Intel GPU tools
    
    # Additional browser
    ungoogled-chromium
    
    # Development tools
    direnv      # Environment management
    nix-direnv  # Nix integration for direnv
    
    # Custom GPU tools
    (pkgs.writeScriptBin "identify-gpus" (builtins.readFile ../scripts/identify-gpus.sh))
  ];

  programs.firefox.enable = true; # Ensure Firefox is installed and configured

  # ----------------------------------------------------------------------------
  # Networking and Firewall
  # ----------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [ 22 2222 ]; # Allow SSH on standard and alternative port

  # ----------------------------------------------------------------------------
  # ----------------------------------------------------------------------------
  # Additional Host Configuration
  # ----------------------------------------------------------------------------
  
  # Audio latency optimization for gaming and VM audio passthrough
  services.pipewire = {
    config.pipewire = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 8192;
      };
    };
  };
  
  # Improve system responsiveness
  services.systemd-oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };
  
  # Automatic TRIM for SSDs
  services.fstrim.enable = true;

  # Enable thermald for better thermal management
  services.thermald.enable = true;

  # Performance tuning
  powerManagement.cpuFreqGovernor = "performance";
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "kernel.sched_autogroup_enabled" = 1;
  };

  # Nix Configuration Overrides (if necessary)
  # ----------------------------------------------------------------------------
  # Allow broken packages if absolutely necessary for specific software on this host.
  # This was present in your working /etc/nixos/configuration.nix.
  # It's often better to address this globally in common-config.nix if it's a general policy.
  nixpkgs.config.allowBroken = true;

  # system.stateVersion is managed by modules/common-config.nix
}
