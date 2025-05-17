# 1Password SSH Agent Integration for NixOS on WSL

This document provides detailed instructions for setting up the 1Password SSH agent integration with NixOS running under WSL. This integration allows you to securely use SSH keys stored in 1Password without exposing the private keys on disk in your NixOS environment.

## Architecture Overview

```
┌───────────────────┐           ┌──────────────────┐
│  Windows Host     │           │  NixOS (WSL)     │
│                   │           │                  │
│  ┌─────────────┐  │           │  ┌────────────┐  │
│  │ 1Password   │  │           │  │            │  │
│  │ SSH Agent   │◄─┼───────────┼──┤ SSH Client │  │
│  └─────┬───────┘  │           │  │            │  │
│        │          │           │  └────────────┘  │
│        │          │           │         ▲        │
│  ┌─────▼───────┐  │ Windows   │         │        │
│  │ Named Pipe  │◄─┼─Pipe─────┼─────────┘        │
│  └─────────────┘  │           │  Unix Socket     │
└───────────────────┘           └──────────────────┘
```

The integration works through these components:
1. 1Password for Windows provides an SSH agent
2. A Windows named pipe (`//./pipe/openssh-ssh-agent`) exposes the agent
3. A Unix socket (`~/.1password/agent.sock`) is created in NixOS
4. `npiperelay.exe` and `socat` create a bridge between the Windows pipe and NixOS socket
5. SSH in NixOS uses the socket to access keys stored in 1Password

## Prerequisites

- Windows with WSL2 and NixOS installed
- 1Password desktop application installed on Windows (version 8+)
- NixOS configured with Home Manager

## Setup Instructions

### 1. Configure 1Password on Windows

1. Open 1Password on Windows
2. Go to Settings > Developer
3. Enable the "Use the SSH agent" option
4. Restart 1Password to apply changes

### 2. Add SSH Keys to 1Password

1. Open 1Password
2. Create a new Login or Document item
3. Add your SSH private key in one of two ways:
   - **For existing keys**: Copy the contents of your private key file (e.g., `id_rsa`) and paste it into a new Document item
   - **For new keys**: Generate a new key directly in 1Password using the SSH Key generator tool
4. Ensure you select "Use for SSH" when saving the key
5. Give your key a recognizable name

### 3. Verify NixOS Configuration

Our NixOS configuration has already been set up with:

1. A systemd user service to create and maintain the SSH agent bridge
2. SSH client configuration to use the forwarded socket
3. Automatic installation of required dependencies (`socat` and `npiperelay.exe`)

The following components are configured:

- **Systemd User Service**: Starts the bridge automatically on login
- **SSH Configuration**: Points to the 1Password socket location
- **Bridge Script**: Uses `socat` to forward the Windows named pipe to a Unix socket

### 4. Testing the Integration

Run the test script to verify the integration is working:

```bash
~/nix-cfg/scripts/test-1password-ssh.sh
```

This script checks:
- If the socket file exists
- If the SSH agent is accessible
- If there are any keys available in the agent

### 5. Using SSH with 1Password

After configuration, your SSH client will automatically use keys from 1Password:

1. Ensure you're logged into 1Password on Windows
2. Set the SSH_AUTH_SOCK environment variable in your shell:
   ```bash
   export SSH_AUTH_SOCK=$HOME/.1password/agent.sock
   ```
   (Add this to your `.bashrc` or equivalent for persistence)
3. Use SSH as normal: `ssh user@host`
4. 1Password will prompt for approval when the key is used (first time)

## Troubleshooting

### Socket Not Found

If the SSH socket is not found:

1. Check if the service is running:
   ```bash
   systemctl --user status 1password-ssh-agent-bridge
   ```
2. If not running, start it:
   ```bash
   systemctl --user restart 1password-ssh-agent-bridge
   ```
3. Check the logs for errors:
   ```bash
   journalctl --user -u 1password-ssh-agent-bridge -n 50
   ```

### No Identities Available

If "The agent has no identities" is shown:

1. Verify you've enabled the SSH agent feature in 1Password on Windows
2. Check that you've added SSH keys to 1Password and marked them for SSH agent use
3. Ensure 1Password is unlocked on Windows
4. Restart the 1Password application on Windows

### Connection Refused

If you get "connection refused" errors:

1. Make sure 1Password is running on Windows
2. Check if the named pipe exists:
   ```
   ls -la /mnt/c/Windows/System32/npiperelay.exe
   ```
3. Verify the bridge service is correctly configured and running

## Advanced Configuration

### Automatically Setting SSH_AUTH_SOCK

Add to your `.bashrc`, `.zshrc`, or equivalent:

```bash
if [[ -S "$HOME/.1password/agent.sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi
```

### Using with Git

Configure Git to use SSH through 1Password:

```bash
git config --global core.sshCommand "ssh -o IdentityAgent=~/.1password/agent.sock"
```

## Security Considerations

- Private SSH keys are securely stored in 1Password and never exposed to the filesystem
- All access to keys requires 1Password to be unlocked
- First-time key usage requires explicit approval in 1Password
- The bridge only provides access to keys marked for SSH agent use in 1Password

## Additional Resources

- [1Password SSH Agent Documentation](https://developer.1password.com/docs/ssh/)
- [NixOS Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/about)