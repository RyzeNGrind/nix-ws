{ pkgs, lib, self', inputs, agenix, opnix, ... }@args:
let
  # Properly evaluate the NixOS configuration using nixos lib
  nixosSystem = pkgs.nixos {
    configuration = { pkgs, config, lib, ... }: {
      imports = [
        ../hosts/nix-ws.nix
      ];
      
      # Set parameters needed for basic evaluation
      _module.args = {
        inherit self' inputs agenix opnix;
      };
      
      # Enable fast build optimizations
      nix-fast-build.enable = true;
    };
  };
in
  # Extract the VM test from the evaluated config
  nixosSystem.config.system.build.vmTest.override {
    # Integration test configuration
    testEnv = {
      includeDesktop = false; # Or true if your integrations need a GUI
      runDuration = "medium";
    };

    name = "nix-ws-integration-test"; # Unique name for the test

    nodes.machine.config = { pkgs, config, ... }: {
      # Include services needed for integration tests
      # For example, if testing sops-nix or agenix:
      environment.systemPackages = [ agenix opnix pkgs.sops ];
      # services.tailscale.enable = true; # If testing Tailscale integration

      # Example: sops-nix test setup
      sops.secrets.my-test-secret = {
        sopsFile = ../secrets/sops/secrets.yaml; # Adjust path as needed
        owner = config.users.users.root.name;
      };
      # Example: agenix test setup
      age.secrets.my-agenix-secret = {
        file = ../secrets/agenix/mysecret.age; # Adjust path as needed
        owner = config.users.users.root.name;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test -f /run/secrets/my-test-secret && echo 'sops secret accessible'")
      machine.succeed("test -f /run/agenix/my-agenix-secret && echo 'agenix secret accessible'")
      # Add more specific integration assertions here
    '';
  }