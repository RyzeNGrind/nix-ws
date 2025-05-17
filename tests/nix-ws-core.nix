{ self, pkgs, lib ? pkgs.lib }:

pkgs.nixosTest {
  name = "nix-ws-core";
  nodes.machine = { config, pkgs, lib, ... }: {
    networking.hostName = "nix-ws";
    users.users.ryzengrind = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
    };
    services.openssh.enable = true;

    # Set a short timeout for fast testing
    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("id ryzengrind")
    machine.succeed("systemctl is-enabled sshd")
    machine.succeed("hostname | grep nix-ws")
  '';
}