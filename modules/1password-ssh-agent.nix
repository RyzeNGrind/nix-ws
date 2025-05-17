# 1Password SSH Agent integration module for Home Manager
# This module sets up the 1Password SSH agent integration for NixOS on WSL

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.onepassword-ssh-agent;
in {
  options.services.onepassword-ssh-agent = {
    enable = mkEnableOption "1Password SSH agent integration";

    socketPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.1password/agent.sock";
      description = "Path to the 1Password SSH agent socket";
    };

    windowsPipeName = mkOption {
      type = types.str;
      default = "//./pipe/openssh-ssh-agent";
      description = "Windows named pipe for the SSH agent";
    };

    autoStartAgent = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically start the SSH agent bridge on login";
    };

    setEnvironmentVariable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to set the SSH_AUTH_SOCK environment variable in shell profile";
    };
  };

  config = mkIf cfg.enable {
    # Create directory for the socket
    home.file.".1password/.keep".text = "";

    # Install required dependencies
    home.packages = with pkgs; [
      socat
    ];

    # Create the bridge script
    home.file."bin/setup-1password-ssh-bridge.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        # Configuration
        SOCKET_PATH="${cfg.socketPath}"
        PIPE_PATH="${cfg.windowsPipeName}"
        SOCKET_DIR="$(dirname "$SOCKET_PATH")"
        NPIPERELAY_PATH="$HOME/bin/npiperelay.exe"
        SOCAT_PATH="${pkgs.socat}/bin/socat"

        # Ensure socket directory exists
        mkdir -p "$SOCKET_DIR"

        # Remove existing socket if present
        if [ -e "$SOCKET_PATH" ]; then
          rm -f "$SOCKET_PATH"
        fi

        # Check if npiperelay.exe exists, if not download it
        if [ ! -f "$NPIPERELAY_PATH" ] || [ ! -x "$NPIPERELAY_PATH" ]; then
          echo "Downloading npiperelay.exe..."
          mkdir -p "$(dirname "$NPIPERELAY_PATH")"
          
          # Create temporary directory
          TEMP_DIR=$(mktemp -d)
          
          # Download npiperelay zip file
          curl -L -o "$TEMP_DIR/npiperelay.zip" "https://github.com/jstarks/npiperelay/releases/latest/download/npiperelay_windows_amd64.zip"
          
          # Extract the executable
          unzip -o "$TEMP_DIR/npiperelay.zip" npiperelay.exe -d "$TEMP_DIR"
          
          # Move to final location
          mv "$TEMP_DIR/npiperelay.exe" "$NPIPERELAY_PATH"
          
          # Cleanup
          rm -rf "$TEMP_DIR"
          
          echo "npiperelay.exe installed to $NPIPERELAY_PATH"
        fi

        # Check if the pipe exists on the Windows side
        if ! ls -la /mnt/c/Windows/System32/OpenSSH/ssh-agent.exe >/dev/null 2>&1; then
          echo "Warning: OpenSSH agent may not be installed on Windows."
          echo "Please ensure OpenSSH Client is installed via Windows Settings > Apps > Optional features."
        fi

        echo "Starting 1Password SSH agent bridge..."
        echo "Connecting to Windows pipe: $PIPE_PATH"
        echo "Creating Unix socket: $SOCKET_PATH"

        # Start the relay
        exec "$SOCAT_PATH" "UNIX-LISTEN:$SOCKET_PATH,fork" "EXEC:$NPIPERELAY_PATH -ei -ep $PIPE_PATH,nofork"
      '';
    };
    
    # Create the test script
    home.file."bin/test-1password-ssh.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        # ANSI color codes
        GREEN='\033[0;32m'
        RED='\033[0;31m'
        BLUE='\033[0;34m'
        YELLOW='\033[0;33m'
        NC='\033[0m' # No Color

        echo -e "''${BLUE}=== 1Password SSH Agent Diagnostic Test ===$NC"

        # Define socket path
        SOCKETPATH="${cfg.socketPath}"

        # Check if the socket file exists
        echo -e "\n''${BLUE}1. Checking if socket file exists...$NC"
        if [ -S "$SOCKETPATH" ]; then
          echo -e "''${GREEN}✓ Socket file exists at $SOCKETPATH$NC"
        else
          echo -e "''${RED}✗ Socket file does not exist at $SOCKETPATH$NC"
          echo -e "''${YELLOW}Hint: Check if the 1password-ssh-agent-bridge service is running:$NC"
          echo "  systemctl --user status 1password-ssh-agent-bridge"
          exit 1
        fi

        # Export SSH_AUTH_SOCK for this session
        echo -e "\n''${BLUE}2. Setting SSH_AUTH_SOCK environment variable...$NC"
        export SSH_AUTH_SOCK="$SOCKETPATH"
        echo -e "''${GREEN}✓ SSH_AUTH_SOCK is now set to $SSH_AUTH_SOCK$NC"

        # Test SSH agent connectivity
        echo -e "\n''${BLUE}3. Testing SSH agent connectivity...$NC"
        if ssh-add -l &>/dev/null; then
          echo -e "''${GREEN}✓ Successfully connected to SSH agent$NC"
          
          # List identities
          echo -e "\n''${BLUE}4. Available SSH identities:$NC"
          ssh-add -l
          
          echo -e "\n''${GREEN}=== SUCCESS: 1Password SSH Agent is working correctly! ===$NC"
          echo -e "''${YELLOW}Note: To use the SSH agent in your current shell, run:$NC"
          echo "  export SSH_AUTH_SOCK=\"$SOCKETPATH\""
        else
          echo -e "''${RED}✗ Could not connect to SSH agent$NC"
          
          if [ "$(ssh-add -l 2>&1)" == "The agent has no identities." ]; then
            echo -e "''${YELLOW}The agent is working but has no identities.$NC"
            echo -e "''${YELLOW}Check if you have enabled the SSH Agent feature in 1Password and added SSH keys.$NC"
            echo -e "''${YELLOW}Follow these steps in 1Password for Windows:$NC"
            echo "  1. Open 1Password"
            echo "  2. Go to Settings > Developer"
            echo "  3. Enable 'Use the SSH agent'"
            echo "  4. Add your SSH keys to 1Password and mark them for use with SSH agent"
          else
            echo -e "''${RED}=== ERROR: 1Password SSH Agent bridge is not working correctly! ===$NC"
            echo -e "''${YELLOW}Troubleshooting steps:$NC"
            echo "  1. Check if the Windows 1Password application is running"
            echo "  2. Verify SSH agent is enabled in 1Password Settings > Developer"
            echo "  3. Restart the bridge service: systemctl --user restart 1password-ssh-agent-bridge"
            echo "  4. Check service logs: journalctl --user -u 1password-ssh-agent-bridge -n 50"
          fi
          exit 1
        fi
      '';
    };

    # Set up shell profile if requested
    home.file = mkIf cfg.setEnvironmentVariable {
      ".profile.d/1password-ssh.sh" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # 1Password SSH Agent environment setup

          # Define the socket path
          ONEPASSWORD_SOCKET="${cfg.socketPath}"

          # Check if the socket exists and set SSH_AUTH_SOCK
          if [[ -S "$ONEPASSWORD_SOCKET" ]]; then
            export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET"
          fi
        '';
      };
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
        Environment = "PATH=${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Configure SSH to use the socket
    programs.ssh = {
      enable = true;
      matchBlocks = {
        "*" = {
          extraOptions = {
            "IdentityAgent" = "${cfg.socketPath}";
          };
        };
      };
    };
  };
}