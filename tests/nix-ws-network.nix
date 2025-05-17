{ self', pkgs, lib ? pkgs.lib, ... }:

pkgs.nixosTest {
  name = "nix-ws-network";
  nodes.machine = { config, pkgs, lib, ... }: {
    networking.hostName = "nix-ws";
    # Network services only
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      authKeyFile = "/etc/tailscale-authkey";
    };
    environment.etc."tailscale-authkey".text = "test-dummy-key";
    
    services.zerotierone.enable = true;

    # Mask services for fast testing
    systemd.services.tailscaled.wantedBy = lib.mkForce [];
    systemd.services.zerotierone.wantedBy = lib.mkForce [];
    
    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    # Verify services are installed but not started
    machine.succeed("systemctl is-enabled tailscaled")
    machine.succeed("systemctl is-enabled zerotierone")
    # Verify auth key file exists
    machine.succeed("test -f /etc/tailscale-authkey")
    # Verify basic networking utilities
    machine.succeed("ip addr")
    machine.succeed("ping -c 1 127.0.0.1")
  '';
}