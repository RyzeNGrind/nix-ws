{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    divnix-std.url = "github:divnix/std";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, inputs } @ attrs: {
    nixosConfigurations = { };

    modules = [
      ./modules/base-system.nix
      ./modules/impermanence.nix
      ./modules/home-config.nix
    ];

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
}