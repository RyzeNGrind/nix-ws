# Build system configuration with nix-fast-build integration
{ config, lib, pkgs, inputs, ... }:

with lib;

let
in

let
  cfg = config.buildSystem;
  
  # Default command templates for nix-fast-build
  defaultNixFastBuildCommand = "nix-fast-build --skip-cached";
  currentSystemCommand = "${defaultNixFastBuildCommand} --systems \"$(nix eval --raw --impure --expr builtins.currentSystem)\"";
  ciCommand = "${currentSystemCommand} --no-nom --result-format junit --result-file result.xml";
  
  # Create a wrapper script for nix commands to use nix-fast-build by default
  nixWrapperScript = pkgs.writeShellScriptBin "nix-wrapper" ''
    #!/usr/bin/env bash
    
    # Help function to show nix-fast-build usage
    function show_help {
      echo "Enhanced nix command using nix-fast-build"
      echo ""
      echo "Usage: nix [COMMAND] [OPTIONS] [ARGS]"
      echo ""
      echo "Common commands:"
      echo "  build      - Build packages using nix-fast-build"
      echo "  run        - Run packages using nix-fast-build"
      echo "  develop    - Enter a development shell"
      echo "  flake      - Flake related commands"
      echo ""
      echo "Additional commands:"
      echo "  fast       - Run nix-fast-build with optimal defaults"
      echo "  fast-ci    - Run nix-fast-build with CI settings"
      echo "  fast-local - Run nix-fast-build for current system only"
      echo ""
      echo "Use 'nix [command] --help' for more information"
    }
    
    # Parse command
    cmd="$1"
    if [[ -z "$cmd" ]]; then
      show_help
      exit 0
    fi
    
    # Shift away the command
    shift
    
    case "$cmd" in
      build)
        # Use nix-fast-build instead of normal build
        ${defaultNixFastBuildCommand} "$@"
        ;;
      fast)
        # Directly use nix-fast-build with optimal defaults
        ${defaultNixFastBuildCommand} "$@"
        ;;
      fast-ci)
        # Use ci-optimized settings
        ${ciCommand} "$@"
        ;;
      fast-local)
        # Only build for current system
        ${currentSystemCommand} "$@"
        ;;
      run|develop|flake)
        # For these commands, use the original nix
        /run/current-system/sw/bin/nix "$cmd" "$@"
        ;;
      --help|-h)
        show_help
        ;;
      *)
        # Pass through to regular nix for other commands
        /run/current-system/sw/bin/nix "$cmd" "$@"
        ;;
    esac
  '';

in {
  options.buildSystem = {
    enableNixFastBuild = mkEnableOption "Enable nix-fast-build as the default builder";
    
    defaultFlags = mkOption {
      type = types.str;
      default = "--skip-cached";
      description = "Default flags to pass to nix-fast-build";
    };
    
    evalWorkers = mkOption {
      type = types.int;
      default = 4;
      description = "Number of evaluation workers for nix-eval-jobs";
    };
    
    enableWrapper = mkEnableOption "Enable nix command wrapper for nix-fast-build";
    
    enableShellAliases = mkEnableOption "Add shell aliases for nix-fast-build";
  };
  
  config = mkIf cfg.enableNixFastBuild {
    # Ensure required packages are installed
    environment.systemPackages = with pkgs; [
      inputs.nix-fast-build.packages.${pkgs.system}.default
      inputs.nix-eval-jobs.packages.${pkgs.system}.default
      nix-output-monitor
    ] ++ (if cfg.enableWrapper then [ nixWrapperScript ] else []);
    
    # Add global shell aliases
    programs.bash.shellAliases = mkIf cfg.enableShellAliases {
      nb = defaultNixFastBuildCommand;
      "nix-build" = defaultNixFastBuildCommand;
      "nix-fast" = defaultNixFastBuildCommand;
      "nbl" = currentSystemCommand;
      "nbc" = ciCommand;
    };
    
    # Also add for zsh if available
    programs.zsh.shellAliases = mkIf (config.programs.zsh.enable && cfg.enableShellAliases) {
      nb = defaultNixFastBuildCommand;
      "nix-build" = defaultNixFastBuildCommand;
      "nix-fast" = defaultNixFastBuildCommand;
      "nbl" = currentSystemCommand;
      "nbc" = ciCommand;
    };
    
    # Also add for fish if available
    programs.fish.shellAliases = mkIf (config.programs.fish.enable && cfg.enableShellAliases) {
      nb = defaultNixFastBuildCommand;
      "nix-build" = defaultNixFastBuildCommand;
      "nix-fast" = defaultNixFastBuildCommand;
      "nbl" = currentSystemCommand;
      "nbc" = ciCommand;
    };
    
    # Set up environment for all shells
    environment.shellInit = mkIf cfg.enableNixFastBuild ''
      # nix-fast-build configuration
      export NIX_FAST_BUILD_FLAGS="${cfg.defaultFlags}"
      export NIX_EVAL_WORKERS="${toString cfg.evalWorkers}"
      
      # Add nix-fast-build info to shell startup
      echo "🚀 nix-fast-build is configured as the default builder"
      echo "Use 'nb' shorthand for nix-fast-build with cached derivations skipped"
      echo "Use 'nbl' to build only the current system"
      echo "Use 'nbc' for CI-optimized builds with junit output"
    '';
  };
}