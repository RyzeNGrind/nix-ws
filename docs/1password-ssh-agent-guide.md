# 1Password SSH Agent Integration for NixOS-WSL

## Overview

This guide describes the integration between 1Password's SSH agent on Windows and NixOS running in WSL. This setup allows you to use SSH keys stored in 1Password for authentication without exposing them to the filesystem.

## How It Works

This integration consists of:

1. **Windows Side**: 1Password app with SSH agent enabled, configured via `agent.toml`
2. **Bridge**: A Unix socket in WSL connects to the Windows named pipe via `npiperelay` and `socat`
3. **NixOS Side**: SSH client configuration and systemd services to automate the connection

### Key Components

- **1Password SSH Agent**: Runs on Windows, provides access to SSH keys stored in 1Password
- **npiperelay**: Windows utility to relay between Windows named pipes and standard I/O
- **socat**: Unix utility to establish bidirectional data transfers
- **systemd user service**: Automatically starts and manages the bridge
- **SSH client configuration**: Points to the 1Password SSH agent socket

## Installation and Setup

This integration is handled declaratively through NixOS and Home Manager. The setup automatically:

1. Creates the necessary directories and permissions
2. Installs required dependencies
3. Sets up the bridge script and systemd service
4. Configures SSH client to use the 1Password agent

### Enabling in Your Configuration

To enable the integration, include the 1Password SSH agent Home Manager module in your configuration:

```nix
# In your home-manager configuration (e.g., home/ryzengrind.nix)
{
  imports = [
    ./modules/1password-ssh.nix
    # Other imports...
  ];
}
```

And configure it:

```nix
# In home/modules/1password-ssh.nix
{ config, pkgs, lib, ... }:

{
  # Import the 1Password SSH agent module
  imports = [ ../../modules/1password-ssh-agent.nix ];

  # Configure 1Password SSH agent integration
  services.onepassword-ssh-agent = {
    enable = true;
    socketPath = "${config.home.homeDirectory}/.1password/agent.sock";
    windowsPipeName = "//./pipe/com.1password.1password.ssh";
    autoStartAgent = true;
    setEnvironmentVariable = true;
  };
}
```

## Windows 1Password Configuration

For the integration to work properly, you **must** configure 1Password on Windows:

1. **Enable SSH Agent in 1Password**:
   - Open 1Password on Windows
   - Go to Settings → Developer
   - Enable "Use the SSH agent"

2. **Configure agent.toml**:
   This is **critical** for solving the "no identities" issue. The file tells 1Password which SSH keys should be available to the agent.

   - Location: `C:\Users\<YourUser>\AppData\Local\1Password\config\ssh\agent.toml`
   - Create this file if it doesn't exist
   - Add configuration to specify which keys are available:

   ```toml
   # Make all keys from the Private vault available
   [[ssh-keys]]
   vault = "Private"
   
   # Make specific key available
   [[ssh-keys]]
   item = "My GitHub SSH Key"
   vault = "Development"
   ```

3. **Add SSH Keys to 1Password**:
   - Create a new item in 1Password using the SSH Key template
   - Add your private key to the "Private Key" field
   - Enable "Allow using this key for SSH agent" in the item settings

4. **Restart 1Password** after making any changes to the agent configuration

## Troubleshooting

### 1. "The agent has no identities" Error

This is the most common issue and almost always means:
- The agent.toml file is missing or misconfigured
- SSH keys in 1Password aren't marked for use with the SSH agent

**Solution**:
1. Verify agent.toml exists and contains valid [[ssh-keys]] entries
2. Check the SSH keys in 1Password are enabled for SSH agent use
3. Restart 1Password on Windows

### 2. Socket Connection Issues

If you can't connect to the socket:

1. Check if the service is running:
   ```bash
   systemctl --user status 1password-ssh-agent-bridge
   ```

2. Start or restart the service:
   ```bash
   systemctl --user restart 1password-ssh-agent-bridge
   ```

3. Check the logs:
   ```bash
   journalctl --user -u 1password-ssh-agent-bridge
   ```

### 3. Testing the Integration

Use the included diagnostic script:
```bash
~/bin/test-1password-ssh.sh
```

This script will:
- Check if the socket exists
- Test connectivity to the agent
- List available identities
- Provide detailed error messages if issues are found

## Advanced Configuration

### Service Options

The module provides several configuration options:

- `enable`: Whether to enable the integration
- `socketPath`: Path to the Unix socket in WSL
- `windowsPipeName`: Windows named pipe for 1Password SSH agent
- `autoStartAgent`: Whether to start the bridge service automatically
- `setEnvironmentVariable`: Whether to set SSH_AUTH_SOCK in shell profile

### WSL-Specific Considerations

- The service is configured to restart properly when WSL resumes from sleep
- The integration works with both WSL1 and WSL2
- SSH keys are protected by 1Password's security - they never leave the Windows side

## Security Benefits

This integration enhances security in several ways:

1. **No key files on disk**: Private keys remain securely stored in 1Password
2. **Auto-locking**: When 1Password locks, SSH keys become unavailable
3. **Selective key availability**: Only keys explicitly configured in agent.toml are exposed
4. **Hardware key protection**: Keys can remain protected by 1Password's security mechanisms

## References

- [1Password SSH Documentation](https://developer.1password.com/docs/ssh/)
- [NixOS Wiki - 1Password](https://nixos.wiki/wiki/1Password)
- [npiperelay GitHub Repository](https://github.com/jstarks/npiperelay)