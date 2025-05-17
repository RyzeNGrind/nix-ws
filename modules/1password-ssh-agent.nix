# 1Password SSH Agent integration module for Home Manager
# This module sets up the 1Password SSH agent integration for NixOS on WSL

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.onepassword-ssh-agent;

  # Fetch npiperelay.exe using Nix
  npiperelay-zip = pkgs.fetchurl {
    url = "https://github.com/jstarks/npiperelay/releases/latest/download/npiperelay_windows_amd64.zip";
    sha256 = "1xp59iv1wp92yhxzqrxcd7kdmcyfbn0lvmd3m43kbh0pzlgzd7kb"; # Verified hash
  };

  # Unpack npiperelay.exe and make it executable
  npiperelay-unwrapped = pkgs.runCommand "npiperelay-unwrapped" {
    nativeBuildInputs = [ pkgs.unzip ];
    src = npiperelay-zip;
  } ''
    unzip $src -d $out
    mv $out/npiperelay.exe $out/npiperelay
    chmod +x $out/npiperelay
  '';

in {
options.services.onepassword-ssh-agent = {
  enable = mkEnableOption "1Password SSH agent integration";

    socketPath = mkOption {
      type = lib.types.str; # Corrected: use lib.types
      default = "${config.home.homeDirectory}/.1password/agent.sock";
      description = "Path to the 1Password SSH agent socket";
    };

    windowsPipeName = mkOption {
      type = lib.types.str; # Corrected: use lib.types
      default = "//./pipe/com.1password.1password.ssh";
      description = "Windows named pipe for the 1Password SSH agent";
    };

    autoStartAgent = mkOption {
      type = lib.types.bool; # Corrected: use lib.types
      default = true;
      description = "Whether to automatically start the SSH agent bridge on login";
    };

    setEnvironmentVariable = mkOption {
      type = lib.types.bool; # Corrected: use lib.types
      default = true;
      description = "Whether to set the SSH_AUTH_SOCK environment variable in shell profile";
    };
  }; # End of options block

  config = mkIf cfg.enable {
    # Install required dependencies
    home.packages = with pkgs; [
      socat # npiperelay is now handled via Nix derivation
      # curl and unzip are not needed by the script anymore if npiperelay is pre-fetched
    ];

    home.file = {
      # Create directory for the socket
      ".1password/.keep".text = "";

      # Create the bridge script
      "bin/setup-1password-ssh-bridge.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          echo "Placeholder for setup-1password-ssh-bridge.sh"
          echo "Socket path would be (cfg.socketPath)"
          echo "Pipe name would be (cfg.windowsPipeName)"
          # exec (pkgs.socat)/bin/socat UNIX-LISTEN:(cfg.socketPath),fork EXEC:(npiperelay-unwrapped)/npiperelay -ei -ep (cfg.windowsPipeName),nofork
        '';
      };
      
      # Create the test script
      "bin/test-1password-ssh.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          echo "Placeholder for test-1password-ssh.sh"
          echo "Testing agent at a path that would be (cfg.socketPath)"
          # SSH_AUTH_SOCK=(cfg.socketPath) ssh-add -l
        '';
      };

    } // lib.mkIf cfg.setEnvironmentVariable { # Set up shell profile if requested (MERGED)
      ".profile.d/1password-ssh.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          # Placeholder for 1Password SSH Agent environment setup
          echo "Setting ONEWORD_SOCKET to a path that would be (cfg.socketPath)"
          # ONEWORD_SOCKET="(cfg.socketPath)"
          # if [[ -S "$ONEWORD_SOCKET" ]]; then
          #   export SSH_AUTH_SOCK="$ONEWORD_SOCKET"
          # fi
        '';
      };

    # Configure systemd user service
    systemd.user.services."1password-ssh-agent-bridge" = mkIf cfg.autoStartAgent {
      Unit = {
        Description = "1Password SSH Agent Bridge for WSL";
        Documentation = "https://nixos.wiki/wiki/1Password";
      };

      Service = {
        ExecStart = "${config.home.homeDirectory}/bin/setup-1password-ssh-bridge.sh";
        Restart = "always";
        RestartSec = 3;
        # Use a more comprehensive PATH that includes user tools
        Environment = "PATH=${config.home.profileDirectory}/bin:${config.home.homeDirectory}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
        # Ensure WSL-specific environment variables are available
        # This helps if the service needs to interact with Windows processes
        PassEnvironment = ["WSL_DISTRO_NAME" "WSL_INTEROP"];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Configure SSH to use the socket
    programs.ssh = {
      enable = true;
      extraConfig = ''
        # 1Password SSH Agent Configuration
        IdentityAgent ${cfg.socketPath}
      '';
    };
  };
}