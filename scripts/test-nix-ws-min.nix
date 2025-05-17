{ pkgs ? import <nixpkgs> {} }:

let
  # Get the repository root as a path
  repoRoot = builtins.toString ./.;  # Path to scripts dir
  repoRootParent = builtins.toString ./..;  # Parent directory (repo root)

  # Import the test module directly
  testModule = import ../tests/nix-ws-min.nix;
  
  # Our flake
  flake = builtins.getFlake repoRootParent;
  
  # Call the test module with the correct arguments
  test = testModule {
    self = flake.self;
    pkgs = pkgs;
    lib = pkgs.lib;
  };
in test