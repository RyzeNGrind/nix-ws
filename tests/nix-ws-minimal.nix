{ self', pkgs, lib ? pkgs.lib, ... }:

# A minimal test that only verifies core boot functionality
# This test has reduced services and configuration to speed up testing

pkgs.nixosTest {
  name = "nix-ws-minimal";
  
  nodes.machine = { config, pkgs, ... }: {
    imports = [
      # Import only the most basic configuration
      ../modules/base-system.nix
    ];
    
    # Disable any unnecessary services for quick testing
    services.xserver.enable = false;
    services.openssh.enable = true;
    networking.firewall.enable = false;
    
    # Minimal user setup
    users.users.root.password = "nixos";
    
    # Lightweight boot configuration
    boot.loader.timeout = 1;
    boot.kernelParams = [ "boot.shell_on_fail" "console=ttyS0" ];
    
    # Skip any unneeded initializations
    systemd.services = {
      "getty@tty1".enable = false;
      "autovt@".enable = false;
    };
    
    environment.systemPackages = with pkgs; [
      # Only essential packages
      coreutils
      bash
    ];
  };
  
  testScript = ''
    # Start machine and wait for basic boot
    machine.start()
    machine.wait_for_unit("network.target")
    
    # Simple check for successful boot
    machine.succeed("echo 'System booted successfully' > /dev/console")
    machine.succeed("uname -a")
    
    # Check basic services are running
    machine.succeed("systemctl is-active sshd.service")
    
    # Test completed successfully
    machine.succeed("touch /tmp/test-completed")
  '';
}