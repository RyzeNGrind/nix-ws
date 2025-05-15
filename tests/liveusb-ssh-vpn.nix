{ self, pkgs, lib ? pkgs.lib, inputs ? {} }:

# Create a new package instance with allowUnfree
let
  pkgsWithUnfree = import pkgs.path {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in

pkgsWithUnfree.nixosTest {
  name = "liveusb-ssh-vpn";
  
  nodes.machine = { pkgs, modulesPath, ... }: {
    imports = [
      # Import the actual liveusb configuration - it now has its own fallback values
      ../hosts/liveusb.nix
      # Import the installation media module
      "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ];

    # Use QEMU's default network settings rather than the static IP from liveusb.nix
    networking = {
      usePredictableInterfaceNames = lib.mkForce false;
      # Let VM use DHCP to get 10.0.2.x address from QEMU
      useDHCP = lib.mkForce true;
      # Clear the static IP configuration for testing
      interfaces.eth0.ipv4.addresses = lib.mkForce [];
      defaultGateway = lib.mkForce null;
      nameservers = lib.mkForce [];
    };
    
    # VM resources - increase for faster boot
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
    virtualisation.diskSize = 4096;
    
    # Disable VPN services for faster testing
    services.tailscale.enable = lib.mkForce false;
    services.zerotierone.enable = lib.mkForce false;
    
    # No need to set nixpkgs.config.allowUnfree here since we're using pkgsWithUnfree
  };

  testScript = ''
    start_all()
    
    # Wait for system to be fully booted
    machine.wait_for_unit("multi-user.target")
    
    # Hostname test
    machine.succeed("hostname | grep liveusb")
    
    # Network configuration test - using QEMU's default network
    machine.succeed("ip addr show eth0 | grep -E '10\\.0\\.2\\.[0-9]+'")
    machine.succeed("ip route | grep default")
    
    # SSH service tests
    machine.wait_for_unit("sshd")
    machine.succeed("systemctl is-active sshd")
    machine.succeed("grep 'PermitRootLogin yes' /etc/ssh/sshd_config")
    machine.succeed("grep 'PasswordAuthentication yes' /etc/ssh/sshd_config")
    
    # Test VPN tools are installed (but not running)
    machine.succeed("command -v zerotier-cli")
    machine.succeed("command -v cloudflared")
    machine.succeed("command -v tailscale")
    
    # Test root user creation
    machine.succeed("id root")
    
    # Test SSH connectivity to localhost
    machine.succeed("nc -z localhost 22")
    
    # Check for common system packages
    machine.succeed("command -v vim || command -v nvim")
    machine.succeed("command -v git")
    machine.succeed("command -v curl")
    
    # Log test success
    machine.succeed("echo 'LiveUSB test completed successfully'")
  '';
}