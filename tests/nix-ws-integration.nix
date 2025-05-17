{ self', pkgs, lib ? pkgs.lib, ... }:

pkgs.nixosTest {
  name = "nix-ws-integration";
  nodes.machine = { config, pkgs, lib, ... }: {
    networking.hostName = "nix-ws";
    users.users.ryzengrind = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" ];
    };
    
    # Core services
    services.openssh.enable = true;
    services.tailscale.enable = true;
    services.tailscale.authKeyFile = "/etc/tailscale-authkey";
    environment.etc."tailscale-authkey".text = "test-dummy-key";
    
    # Development tools
    environment.systemPackages = with pkgs; [
      git
      vim
      curl 
      wget
    ];
    
    # Lightweight GUI with networking 
    services.xserver.enable = true;
    networking.networkmanager.enable = true;
    
    # Mask services for quick testing
    systemd.services.tailscaled.wantedBy = lib.mkForce [];
    
    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    
    # Test user can use sudo
    machine.succeed("sudo -u ryzengrind sudo true")
    
    # Test SSH server is working
    machine.succeed("systemctl is-active sshd")
    
    # Test dev tools are installed
    machine.succeed("which git")
    machine.succeed("which vim")
    machine.succeed("which curl")
    
    # Test basic network config
    machine.succeed("networkctl")
    
    # Test X server starts
    machine.succeed("systemctl start display-manager")
    machine.wait_for_unit("display-manager.service")
    machine.sleep(2)
    machine.succeed("ps aux | grep X")
  '';
}