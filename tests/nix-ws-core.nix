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
      
      # Disable network dependencies
      networking.useDHCP = false;
      services.tailscale.enable = false;
  
      # Enable fast build optimizations
      nix-fast-build.enable = true;
    };
  };
in
  # Extract the VM test from the evaluated config
  nixosSystem.config.system.build.vmTest.override {
    # Minimal test configuration
    testEnv = {
      includeDesktop = false;
      runDuration = "short";
    };
  }