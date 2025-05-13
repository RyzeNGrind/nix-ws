{ self, pkgs, lib ? pkgs.lib }:

pkgs.nixosTest {
  name = "liveusb-ssh-vpn";
  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [
      # Use the same modules as the liveusb image
      (import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/nixos-24.11.tar.gz";
      }) + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
      ({ pkgs, ... }: {
        networking = {
          hostName = "nix-live-usb";
          useDHCP = false;
          interfaces.enp1s0.ipv4.addresses = [{ address = "192.168.1.15"; prefixLength = 24; }];
          defaultGateway = "192.168.1.1";
          nameservers = [ "192.168.1.1" "1.1.1.1" ];
        };
        services.openssh = {
          enable = true;
          permitRootLogin = "yes";
          passwordAuthentication = true;
        };
        users.users.root.password = "nixos";
        environment.systemPackages = with pkgs; [ zerotierone cloudflared tailscale ];
        services.zerotierone = {
          enable = true;
          joinNetworks = [ "fada62b0158621fe" ];
        };
        system.stateVersion = "24.11";
      })
    ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("hostname | grep nix-live-usb")
    machine.succeed("ip addr show enp1s0 | grep 192.168.1.15")
    machine.succeed("systemctl is-active sshd")
    machine.succeed("grep PermitRootLogin /etc/ssh/sshd_config | grep yes")
    machine.succeed("zerotier-cli info")
    machine.succeed("zerotier-cli listnetworks | grep fada62b0158621fe")
    # Optionally: test SSH login (would require expect or similar)
  '';
} 