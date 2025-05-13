{ self, pkgs }:

pkgs.nixosTest {
  name = "nix-ws-min";
  nodes.machine = { config, pkgs, ... }: {
    networking.hostName = "nix-ws";
    users.users.ryzengrind = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
    };
    services.openssh.enable = true;
    services.tailscale.enable = true;
    services.tailscale.authKeyFile = "/etc/tailscale-authkey";
    environment.etc."tailscale-authkey".text = "tskey-auth-kJhi8g4Zxb11CNTRL-jbiraaq8eEX3gmeCJwLSFXYUMG3a77vcf";
    services.zerotierone.enable = true;
    # Optionally: services.cloudflared.enable = true;
    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("id ryzengrind")
    machine.succeed("systemctl is-enabled sshd")
    machine.succeed("systemctl is-enabled tailscale")
    machine.succeed("systemctl is-enabled zerotierone")
    machine.succeed("test -f /etc/tailscale-authkey")
    # Optionally: check cloudflared, devshell, etc.
  '';
} 