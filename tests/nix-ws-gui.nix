{ pkgs, lib, self', inputs, ... }@args:
let
  # Properly evaluate the NixOS configuration using nixos lib
  nixosSystem = pkgs.nixos {
    configuration = { pkgs, config, lib, ... }: {
      imports = [
        ../hosts/nix-ws.nix
      ];
      
      # Set parameters needed for basic evaluation
      _module.args = {
        inherit self' inputs;
      };
      
      # Enable fast build optimizations
      nix-fast-build.enable = true;
    };
  };
in
  # Extract the VM test from the evaluated config
  nixosSystem.config.system.build.vmTest.override {
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