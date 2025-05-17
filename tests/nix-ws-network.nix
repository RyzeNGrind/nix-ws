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
    # Network test configuration
    testEnv = {
      includeDesktop = false;
      runDuration = "short";
    };
    
    name = "nix-ws-network-test"; # Unique name for the test

    nodes.machine.config = { pkgs, ... }: {
      # Specific network test configurations go here
      # For example, to test static IP:
      # networking.interfaces.eth0.ipv4.addresses = [ { address = "192.168.1.10"; prefixLength = 24; } ];
      # networking.defaultGateway = "192.168.1.1";
      # networking.nameservers = [ "1.1.1.1" ];
    };

    testScript = ''
      machine.wait_for_unit("network.target")
      machine.succeed("ip addr show eth0")
      # Add more specific network assertions here
    '';
  }