{ pkgs, self', inputs, agenix, opnix, ... }@args: # Added 'inputs'
let
  baseConfig = import ../hosts/nix-ws.nix;
in (baseConfig args).config.system.build.vmTest.override {
  # Enable fast build optimizations
  nix-fast-build.enable = true;
  
  # Integration test configuration
  testEnv = {
    includeDesktop = false; # Or true if your integrations need a GUI
    runDuration = "medium";
  };

  name = "nix-ws-integration-test"; # Unique name for the test

  nodes.machine.config = { pkgs, ... }: {
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