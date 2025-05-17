{ self, self', pkgs, lib ? pkgs.lib, ... }:

pkgs.nixosTest {
  name = "nix-ws-gui";
  nodes.machine = { config, pkgs, lib, ... }: {
    networking.hostName = "nix-ws";
    users.users.ryzengrind = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" ];
    };
    
    # Basic GUI services
    services.xserver.enable = true;
    services.xserver.displayManager.sddm.enable = true;
    services.xserver.desktopManager.plasma5.enable = true;
    
    # For faster testing
    services.xserver.displayManager.autoLogin = {
      enable = false;  # Disable actual auto-login for faster testing
    };
    
    # Hardware acceleration mocked
    hardware.opengl.enable = true;
    hardware.opengl.driSupport = true;
    
    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    
    # Verify X server is installed
    machine.succeed("which Xorg")
    
    # Verify display manager is installed
    machine.succeed("systemctl is-enabled display-manager.service")
    
    # Verify KDE Plasma is installed
    machine.succeed("test -d /run/current-system/sw/share/plasma")
    
    # Verify OpenGL packages are present
    machine.succeed("test -d /run/opengl-driver")
  '';
}