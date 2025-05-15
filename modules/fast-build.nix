{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix.fastBuild;
in
{
  options = {
    nix.fastBuild = {
      enable = mkEnableOption "Fast build optimizations for Nix";

      cpuCores = mkOption {
        type = types.nullOr types.int;
        default = null; # Auto-detect by nix-fast-build or Nix itself
        description = "Number of CPU cores to use for building (null = auto-detect).";
      };

      maxMemoryPercent = mkOption {
        type = types.nullOr types.int;
        default = 80;
        description = "Maximum percentage of system memory to allow for builds (null = no limit).";
      };

      substituters = {
        cachix = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "my-company-cache" "nix-community" ];
          description = "List of Cachix cache names (e.g., 'nix-community') to use. Keys will be fetched from netrc if needed.";
        };

        attic = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption { type = types.str; description = "Name of the Attic cache."; };
              url = mkOption { type = types.str; description = "URL of the Attic cache."; };
              publicKey = mkOption { type = types.str; description = "Public key for the Attic cache."; };
            };
          });
          default = [];
          example = [{ name = "my-attic"; url = "https://attic.example.com"; publicKey = "attic:my-attic:abcdef..."; }];
          description = "List of self-hosted Attic caches to use.";
        };
        
        additional = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "https://cache.example.org" ];
          description = "List of additional generic substituter URLs.";
        };
        
        additionalTrustedPublicKeys = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "cache.example.org-1:abcdef..." ];
          description = "List of trusted public keys for additional substituters.";
        };
      };

      remoteBuilders = mkOption {
        type = types.listOf (types.submodule {
          options = {
            hostName = mkOption { type = types.str; description = "Hostname or IP of the remote builder."; };
            sshUser = mkOption { type = types.nullOr types.str; default = null; description = "SSH user for the remote builder."; };
            sshKey = mkOption { type = types.nullOr types.str; default = null; description = "Path to SSH key for the remote builder."; };
            systems = mkOption { type = types.listOf types.str; default = []; example = ["x86_64-linux" "aarch64-linux"]; description = "Systems the builder can build for."; };
            speedFactor = mkOption { type = types.int; default = 1; description = "Speed factor of the builder."; };
            maxJobs = mkOption { type = types.nullOr types.int; default = null; description = "Max concurrent jobs on this builder."; };
          };
        });
        default = [];
        description = "List of remote builders to use.";
      };
      
      useNixFastBuildWrapper = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to wrap nix-build, nix build, etc. with nix-fast-build.";
      };

      nixFastBuildPackage = mkOption {
        type = types.package;
        default = pkgs.nix-fast-build;
        defaultText = literalExpression "pkgs.nix-fast-build";
        description = "The nix-fast-build package to use.";
      };
    };
  };

  config = mkIf cfg.enable {
    nix.settings = {
      builders-use-substitutes = true;
      
      substituters = mkMerge ([
        "https://cache.nixos.org/"
        "https://nixpkgs-ci.cachix.org"
      ] ++ (map (name: "https://${name}.cachix.org") cfg.substituters.cachix)
        ++ (map (attic: attic.url) cfg.substituters.attic)
        ++ cfg.substituters.additional);
        
      trusted-public-keys = mkMerge ([
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="
      ] ++ (map (attic: attic.publicKey) cfg.substituters.attic)
        ++ cfg.substituters.additionalTrustedPublicKeys);

      builders = if cfg.remoteBuilders == [] then null else concatMapStringsSep " ; " (builder:
        let
          systemPart = if builder.systems == [] then "" else builtins.concatStringsSep "," builder.systems;
          userPart = if builder.sshUser == null then "" else "${builder.sshUser}@";
          keyPart = if builder.sshKey == null then "" else builder.sshKey;
          maxJobsPart = if builder.maxJobs == null then "" else toString builder.maxJobs;
        in "${userPart}${builder.hostName} ${systemPart} ${keyPart} ${toString builder.speedFactor} ${maxJobsPart}"
      ) cfg.remoteBuilders;

      cores = mkIf (cfg.cpuCores != null && cfg.cpuCores > 0) cfg.cpuCores;
      max-jobs = mkIf (cfg.cpuCores != null && cfg.cpuCores > 0) cfg.cpuCores; # Often set to cores
    };

    environment.systemPackages = mkIf cfg.useNixFastBuildWrapper [ cfg.nixFastBuildPackage ];
    
    # nix-fast-build specific settings might go into /etc/nix-fast-build.conf or similar if the tool supports it.
    # For now, we rely on its default behavior and the standard nix.conf settings.
    
    # Example of how you might configure nix-fast-build if it had its own config file mechanism
    # environment.etc."nix-fast-build.conf".text = mkIf (cfg.maxMemoryPercent != null) ''
    #   max_memory_percent = ${toString cfg.maxMemoryPercent}
    # '';
  };
}