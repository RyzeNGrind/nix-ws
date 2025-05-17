{ pkgs, self', inputs, ... }@args: # Added 'inputs'
let
  baseConfig = import ../hosts/nix-ws.nix;
in (baseConfig args).config.system.build.vmTest.override {
  # Enable fast build optimizations
  nix-fast-build.enable = true;
  
  # GUI test configuration
  testEnv = {
    includeDesktop = true; # Ensure a desktop environment is available
    runDuration = "medium"; # GUI tests might take longer
  };

  name = "nix-ws-gui-test"; # Unique name for the test

  nodes.machine.config = { pkgs, ... }: {
    services.xserver.enable = true;
    services.xserver.displayManager.sddm.enable = true; # Or your preferred DM
    services.xserver.desktopManager.plasma5.enable = true; # Or your preferred DE
    # Add any other GUI related services or packages needed for the test
  };

  testScript = ''
    machine.wait_for_x()
    machine.wait_for_unit("display-manager.service")
    machine.sleep(10) # Give time for desktop to load
    machine.screenshot("desktop")
    # Add more specific GUI interaction tests here
    # e.g., machine.execute("krunner --help") # Check if krunner is available
  '';
}