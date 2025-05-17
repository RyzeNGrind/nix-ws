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
          #!/usr/bin/env bash
          set -euo pipefail

          # Configuration
          SOCKET_PATH="${cfg.socketPath}"
          PIPE_PATH="${cfg.windowsPipeName}" # This comes from the module options
          SOCKET_DIR="$(dirname "$SOCKET_PATH")"
          NPIPERELAY_PATH="${npiperelay-unwrapped}/npiperelay" # Use the Nix-provided npiperelay
          SOCAT_PATH="${pkgs.socat}/bin/socat"

          # Ensure socket directory exists
          mkdir -p "$SOCKET_DIR"

          # Remove existing socket if present
          if [ -e "$SOCKET_PATH" ]; then
            rm -f "$SOCKET_PATH"
          fi

          # npiperelay.exe is now provided by Nix, no need to download

          # Check for 1Password on Windows side
          # Using a resilient method that doesn't require wslpath
          if [ -e "/mnt/c/Program Files/1Password/app/8/1Password.exe" ]; then
            echo "✓ 1Password found in Program Files"
          elif find /mnt/c/Users/*/AppData/Local/1Password/app/8/1Password.exe -type f 2>/dev/null | grep -q .; then
            echo "✓ 1Password found in AppData"
          else
            echo "Warning: Could not detect 1Password installation on Windows."
            echo "Please ensure 1Password is installed and the SSH Agent feature is enabled in Settings > Developer."
          fi

          # Ensure socket directory has correct permissions (important for SSH security)
          chmod 700 "$SOCKET_DIR"

          echo "Starting 1Password SSH agent bridge..."
          echo "Connecting to Windows pipe: $PIPE_PATH"
          echo "Creating Unix socket: $SOCKET_PATH"

          # Start the relay
          # Check agent.toml file on Windows (crucial for "no identities" issue)
          WIN_USERNAME=$(basename $(wslpath -w ~) | cut -d'\' -f2)
          AGENT_TOML_PRIMARY="/mnt/c/Users/$WIN_USERNAME/AppData/Local/1Password/config/ssh/agent.toml"
          AGENT_TOML_FALLBACK="/mnt/c/Users/$WIN_USERNAME/AppData/Local/1Password/app/8/op-ssh-sign/agent.toml"

          if [ -f "$AGENT_TOML_PRIMARY" ]; then
            echo "✓ agent.toml found at primary path: $AGENT_TOML_PRIMARY"
            KEY_COUNT=$(grep -c '\[\[ssh-keys\]\]' "$AGENT_TOML_PRIMARY" || echo "0")
            if [ "$KEY_COUNT" -gt 0 ]; then
              echo "✓ $KEY_COUNT SSH key configurations found in agent.toml"
            else
              echo "! Warning: No [[ssh-keys]] configurations found in agent.toml"
              echo "  This is likely causing the 'no identities' issue"
              echo "  Add at least one entry like:"
              echo "    [[ssh-keys]]"
              echo "    vault = \"Private\""
            fi
          elif [ -f "$AGENT_TOML_FALLBACK" ]; then
            echo "✓ agent.toml found at fallback path: $AGENT_TOML_FALLBACK"
            KEY_COUNT=$(grep -c '\[\[ssh-keys\]\]' "$AGENT_TOML_FALLBACK" || echo "0")
            if [ "$KEY_COUNT" -gt 0 ]; then
              echo "✓ $KEY_COUNT SSH key configurations found in agent.toml"
            else
              echo "! Warning: No [[ssh-keys]] configurations found in agent.toml"
            fi
          else
            echo "! Warning: agent.toml not found at expected locations"
            echo "  This will cause the 'no identities' issue"
            echo "  Create the file at: $AGENT_TOML_PRIMARY"
            echo "  With content like:"
            echo "    [[ssh-keys]]"
            echo "    vault = \"Private\""
            echo "  Then restart 1Password on Windows"
          fi

          # Ensure socket directory has correct permissions
          chmod 700 "$SOCKET_DIR"
          
          echo "Starting 1Password SSH agent bridge..."
          echo "Connecting to Windows pipe: $PIPE_PATH"
          echo "Creating Unix socket: $SOCKET_PATH"

          # Start the relay
          exec "$SOCAT_PATH" "UNIX-LISTEN:$SOCKET_PATH,fork" "EXEC:$NPIPERELAY_PATH -ei -ep $PIPE_PATH,nofork"
        '';
      };
      
      # Create the test script
      "bin/test-1password-ssh.sh" = {
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

    } // lib.mkIf cfg.setEnvironmentVariable { # Set up shell profile if requested (MERGED)
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