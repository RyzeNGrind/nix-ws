# 1Password SSH Agent Integration for NixOS in WSL

This document explains how to set up the 1Password SSH Agent integration between Windows and NixOS running in WSL.

## Overview

The integration enables SSH keys stored in 1Password on Windows to be used within NixOS running in WSL. This is accomplished by:

1. Creating a bridge between the Windows 1Password SSH agent pipe and a Unix socket in WSL
2. Using `npiperelay.exe` and `socat` to relay SSH agent protocol messages between the two systems
3. Configuring SSH in NixOS to use the Unix socket for authentication

## Prerequisites

- 1Password installed on Windows with SSH Agent enabled
- NixOS running in WSL
- SSH keys added to 1Password and marked for use with SSH Agent

## Setup Steps

### 1. Enable the SSH Agent in 1Password on Windows

1. Open 1Password on Windows
2. Go to Settings > Developer
3. Enable "Use the SSH agent"
4. Add your SSH keys to 1Password if they aren't already added
5. Mark your SSH keys for use with SSH agent

### 2. Configure NixOS for 1Password SSH Agent

Add the following to your Home Manager configuration:

```nix
# In home/modules/1password-ssh.nix
{ config, pkgs, lib, ... }:

{
  imports = [ ../../modules/1password-ssh-agent.nix ];

  services.onepassword-ssh-agent = {
    enable = true;
    socketPath = "${config.home.homeDirectory}/.1password/agent.sock";
    windowsPipeName = "//./pipe/com.1password.1password.ssh";  # 1Password SSH pipe name
    autoStartAgent = true;
    setEnvironmentVariable = true;
  };
}

# Then import this module in your home configuration
```

### 3. Rebuild and activate your Home Manager configuration

```bash
home-manager switch
```

## Testing the Integration

Run the diagnostic script to verify everything is working:

```bash
~/bin/test-1password-ssh.sh
```

This script will:

1. Check for 1Password installation on Windows
2. Verify the Unix socket exists
3. Test connectivity to the SSH agent
4. List available SSH identities
5. Provide troubleshooting recommendations if needed

## Troubleshooting

If you encounter issues:

1. **No Socket Created**: Verify the 1Password SSH agent service is running:
   ```bash
   systemctl --user status 1password-ssh-agent-bridge
   ```

2. **No Identities Available**: Check if SSH agent is enabled in 1Password and keys are marked for use with SSH agent

3. **Connection Errors**: Verify the pipe name is correct (should be `//./pipe/com.1password.1password.ssh`)

4. **Manual Testing**: Try running the bridge script manually:
   ```bash
   ~/bin/setup-1password-ssh-bridge.sh
   ```

5. **SSH Configuration**: Ensure your SSH config contains the IdentityAgent setting:
   ```
   IdentityAgent ~/.1password/agent.sock
   ```

## How It Works

1. A systemd user service starts the bridge script on login
2. The script downloads `npiperelay.exe` if needed
3. It creates a Unix socket at `~/.1password/agent.sock`
4. It uses `socat` to relay connections between the Unix socket and the Windows named pipe
5. SSH in NixOS is configured to use this socket for authentication

## References

- [1Password SSH Agent Documentation](https://developer.1password.com/docs/ssh/agent/)
- [npiperelay Project](https://github.com/jstarks/npiperelay)
- [WSL Interoperability](https://learn.microsoft.com/en-us/windows/wsl/interop)