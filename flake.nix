{
  description = "NixOS system configuration with clustering support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    divnix-std.url = "github:divnix/std";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      
      imports = [
        ./modules/base-system.nix
        ./modules/impermanence.nix
        ./modules/home-config.nix
      ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # System-specific configurations can go here
      };

      flake = {
        nixosConfigurations = { };

        clusterConfig = inputs.flake-parts.lib.makeModule {
          imports = [ ./clusters ];
        };

        nodeRoles = {
          workstation = ./roles/workstation.nix;
          server = ./roles/server.nix;
          edge = ./roles/edge.nix;
        };

        cloudProviders = {
          oci = ./providers/oracle.nix;
          lxd = ./providers/lxd.nix;
        };
      };
    };
}