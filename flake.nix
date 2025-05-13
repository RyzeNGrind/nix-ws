{
  description = "NixOS and Home Manager configurations for the entire cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    void-fork.url = "github:jskrzypek/nixpkgs/void-editor";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    std.url = "github:divnix/std";
    hive.url = "github:divnix/hive";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opnix = {
      url = "github:1Password/opnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    void-editor-pr = {
      url = "github:NixOS/nixpkgs/pull/398996/head";
      flake = false;
    };
    emanote-flake = {
      url = "github:srid/emanote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cloudflared = {
      url = "github:piperswe/nix-cloudflared";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixpkgs-ci.cachix.org"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-experimental-features = [ "nix-command" "flakes" ];
  };

  outputs = inputs@{ self, flake-parts, std, hive, nixpkgs, nixpkgs-unstable, void-editor-pr, void-fork, home-manager, sops-nix, agenix, opnix, nix-vscode-extensions, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      imports = [ ];
      perSystem = { config, self', inputs', pkgs, system, ... }: let
        void-editor-overlay = final: prev: {
          void-editor = let
            vscode-generic-fn-attr = final.vscode-generic-fn;
          in prev.callPackage ./overlays/void-editor/package.nix {
            vscode-generic-fn = vscode-generic-fn-attr;
          };
          unstable = import nixpkgs-unstable {
            system = prev.system;
            config.allowUnfree = true;
          };
        };
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import ./overlays/vscode-generic.nix) void-editor-overlay ];
        };
        devShells.default = pkgs.mkShell {
          name = "nix-cfg-mgmt-shell";
          packages = with pkgs; [
            git gh pre-commit alejandra statix deadnix sops
          ];
        };
        devShells.void-editor = import ./devshells/void-editor.nix { inherit pkgs; };
        # Expose vscode-generic and void-editor as packages for direct flake builds
        packages = {
          vscode-generic = pkgs.vscode-generic;
          void-editor = pkgs.void-editor;
        };
      };
    } // {
      # Expose extension sets at the top-level outputs for use in modules
      editorExtensionSets = {
        x86_64-linux = let extensions = nix-vscode-extensions.extensions.x86_64-linux; in {
          base = [
            extensions.vscode-marketplace.ieviev.nix-vscode-completions
            extensions.vscode-marketplace.kaliahayes.kolada
            extensions.vscode-marketplace.bbenoist.nix
          ];
          vscodeDesktop = [
            extensions.vscode-marketplace.ieviev.nix-vscode-completions
            extensions.vscode-marketplace.kaliahayes.kolada
            extensions.vscode-marketplace.bbenoist.nix
            extensions.vscode-marketplace.ms-vscode-remote.remote-wsl
          ];
          nixos = [
            extensions.vscode-marketplace.ieviev.nix-vscode-completions
            extensions.vscode-marketplace.kaliahayes.kolada
            extensions.vscode-marketplace.bbenoist.nix
            extensions.vscode-marketplace.arrterian.nix-env-selector
            extensions.vscode-marketplace.jnoortheen.nix-ide
            extensions.vscode-marketplace.kamadorueda.alejandra
            extensions.vscode-marketplace.mkhl.direnv
          ];
        };
        aarch64-linux = let extensions = nix-vscode-extensions.extensions.aarch64-linux; in {
          base = [
            extensions.vscode-marketplace.ieviev.nix-vscode-completions
            extensions.vscode-marketplace.kaliahayes.kolada
            extensions.vscode-marketplace.bbenoist.nix
          ];
          vscodeDesktop = [
            extensions.vscode-marketplace.ieviev.nix-vscode-completions
            extensions.vscode-marketplace.kaliahayes.kolada
            extensions.vscode-marketplace.bbenoist.nix
            extensions.vscode-marketplace.ms-vscode-remote.remote-wsl
          ];
          nixos = [
            extensions.vscode-marketplace.ieviev.nix-vscode-completions
            extensions.vscode-marketplace.kaliahayes.kolada
            extensions.vscode-marketplace.bbenoist.nix
            extensions.vscode-marketplace.arrterian.nix-env-selector
            extensions.vscode-marketplace.jnoortheen.nix-ide
            extensions.vscode-marketplace.kamadorueda.alejandra
            extensions.vscode-marketplace.mkhl.direnv
          ];
        };
      };
      nixosConfigurations = hive.lib.mkNixosConfigurations {
        cluster = import ./clusters/default.nix;
        modules = [
          ./modules/base-system.nix
          ./modules/impermanence.nix
          ./modules/home-config.nix
          ./modules/secrets.nix
        ];
        specialArgs = { inherit inputs; };
      };
    };
}
