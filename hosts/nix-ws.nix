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

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  # ----------------------------------------------------------------------------
  # Desktop Environment (GNOME)
  # ----------------------------------------------------------------------------
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
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
    rustdesk-flutter # Specific remote desktop client
  ];

  # Host-specific system packages, merged with those from common-config.nix
  environment.systemPackages = with pkgs; [
    ntfs3g      # For NTFS filesystem support
    exfatprogs  # For exFAT filesystem support
    udftools    # For UDF filesystem support
    gh          # GitHub CLI

    # Secrets management GUI tools - consider if these are better suited for Home Manager
    _1password-gui-beta # Ensure this package name is correct and available in your nixpkgs
    _1password-cli      # Ensure this package name is correct and available

    # Hardware utilities
    pciutils    # For lspci command
    glxinfo     # OpenGL information utility
    nvtopPackages.intel # GPU monitoring tool for Intel GPUs
    nvtopPackages.nvidia # GPU monitoring tool for NVIDIA GPUs

    # Additional browser
    ungoogled-chromium
  ];

  programs.firefox.enable = true; # Ensure Firefox is installed and configured

  # ----------------------------------------------------------------------------
  # Networking and Firewall
  # ----------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [ 22 2222 ]; # Allow SSH on standard and alternative port

  # ----------------------------------------------------------------------------
  # Nix Configuration Overrides (if necessary)
  # ----------------------------------------------------------------------------
  # Allow broken packages if absolutely necessary for specific software on this host.
  # This was present in your working /etc/nixos/configuration.nix.
  # It's often better to address this globally in common-config.nix if it's a general policy.
  nixpkgs.config.allowBroken = true;

  # system.stateVersion is managed by modules/common-config.nix
}
