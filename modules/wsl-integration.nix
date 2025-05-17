# WSL integration module for NixOS
# This module provides integration between Windows and NixOS running in WSL

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.wsl-integration;
in {
  options.wsl-integration = {
    enable = mkEnableOption "WSL integration features";

    enableWindowsInterop = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Windows interoperability features";
    };

    enableWindowsHome = mkOption {
      type = types.bool;
      default = false;
      description = "Mount Windows home directory";
    };

    windowsHome = mkOption {
      type = types.str;
      default = "/mnt/c/Users/$USER";
      description = "Path to Windows home directory";
    };
    
    enable1PasswordSSH = mkOption {
      type = types.bool;
      default = false;
      description = "Enable 1Password SSH agent integration";
    };
    
    pipeName = mkOption {
      type = types.str;
      default = "//./pipe/com.1password.1password.ssh";
      description = "Windows named pipe for 1Password SSH agent";
    };
  };

  config = mkIf cfg.enable {
    # Basic WSL integration
    environment.systemPackages = with pkgs; [
      wslu          # WSL utilities
      socat         # Socket relay
      curl          # For downloads
      unzip         # For unpacking
    ];

    # WSL-specific settings
    boot.isContainer = mkDefault true;
    networking.useHostResolvConf = mkDefault true;

    # Windows interoperability
    environment.etc."wsl.conf".text = mkIf cfg.enableWindowsInterop ''
      [automount]
      options = "metadata,umask=22,fmask=11"
      
      [network]
      generateHosts = true
      generateResolvConf = true
      
      [interop]
      enabled = true
      appendWindowsPath = true
    '';

    # Add user's Windows home directory
    environment.extraInit = mkIf cfg.enableWindowsHome ''
      # Create symlink to Windows home directory
      if [ ! -e "$HOME/WindowsHome" ] && [ -d "${cfg.windowsHome}" ]; then
        ln -sf "${cfg.windowsHome}" "$HOME/WindowsHome"
      fi
    '';

    # 1Password SSH Agent integration
    system.activationScripts.wsl-interop = mkIf cfg.enable1PasswordSSH {
      text = ''
        # Create directories for 1Password SSH agent
        mkdir -p /home/${config.users.users.ryzengrind.name}/bin
        mkdir -p /home/${config.users.users.ryzengrind.name}/.1password
        
        # Ensure correct permissions
        chown ${config.users.users.ryzengrind.name}:users /home/${config.users.users.ryzengrind.name}/bin
        chown ${config.users.users.ryzengrind.name}:users /home/${config.users.users.ryzengrind.name}/.1password
      '';
      deps = [];
    };

    # Configure system-wide SSH to use 1Password SSH agent if enabled
    programs.ssh.extraConfig = mkIf cfg.enable1PasswordSSH ''
      # 1Password SSH Agent Configuration
      Host github.com gitlab.com bitbucket.org
        IdentityAgent /home/${config.users.users.ryzengrind.name}/.1password/agent.sock
    '';
  };
}