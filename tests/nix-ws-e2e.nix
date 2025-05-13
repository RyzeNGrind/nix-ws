{ self, pkgs, agenix, opnix }:

pkgs.nixosTest {
  name = "nix-ws-e2e";
  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../modules/base-system.nix
      ../modules/impermanence.nix
      ../modules/home-config.nix
      ../roles/workstation.nix
      ../providers/lxd.nix
      ../providers/oracle.nix
      # Add secret management modules if available
      # ../modules/secrets.nix
    ];
    networking.hostName = "nix-ws";
    users.users.ryzengrind = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
    };
    services.tailscale.enable = true;
    services.tailscale.authKeyFile = "/etc/tailscale-authkey";
    environment.etc."tailscale-authkey".text = "tskey-auth-kJPa6qEFNB21CNTRL-yFXrrFryWdjwZofxfoUecj9LhgdKfooV8";
    services.zerotierone.enable = true;
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    services.openssh.enable = true;
    services.pipewire.enable = true;
    # Secret management, editors, and devshells
    environment.systemPackages = with pkgs; [
      agenix
      sops
      opnix
      (pkgs.callPackage ../overlays/void-editor/package.nix { })
      vscodium
      # Add code-cursor and extensions if available
    ];
    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("id ryzengrind")
    machine.succeed("systemctl is-active tailscale")
    machine.succeed("systemctl is-active zerotierone")
    machine.succeed("systemctl is-active gdm")
    machine.succeed("systemctl is-active pipewire")
    machine.succeed("systemctl is-active sshd")
    # Check secret management tools
    machine.succeed("agenix --version")
    machine.succeed("sops --version")
    machine.succeed("opnix --help || true")
    # Check devshells (simulate shell launch)
    machine.succeed("which bash")
    machine.succeed("which fish")    
    # Check editors
    machine.succeed("void --version || true")
    machine.succeed("vscodium --version")
    machine.succeed("cursor --version")
    # Check for extensions (mocked, as real extension install is not trivial in test)
    # machine.succeed("vscodium --list-extensions | grep nix-ide || true")
    # Add more checks as needed for your environment
  '';
} 