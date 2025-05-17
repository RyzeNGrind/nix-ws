# 1Password SSH Agent Integration for NixOS on WSL

This repository provides a seamless integration between 1Password's SSH agent on Windows and NixOS running in WSL. It allows you to securely use SSH keys stored in 1Password without exposing the private keys on disk in your NixOS environment.

## Features

- **Secure Key Storage**: SSH keys remain securely stored in 1Password, never exposed on disk
- **Automatic Bridge**: Systemd user service automatically establishes the connection at login
- **Declarative Setup**: Fully integrated with Home Manager for declarative configuration
- **Testing & Diagnostics**: Includes diagnostic tools to verify correct functionality
- **Documentation**: Comprehensive guides for setup and troubleshooting

## Quick Start

### Option 1: Using the Home Manager module

1. Import the module in your Home Manager configuration:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./modules/1password-ssh-agent.nix
  ];

  services.onepassword-ssh-agent = {
    enable = true;
    # Optional: customize settings
    # socketPath = "~/.1password/custom-socket-name.sock";
    # windowsPipeName = "//./pipe/custom-pipe-name";
    # autoStartAgent = true;
    # setEnvironmentVariable = true;
  };
}
```

2. Apply your Home Manager configuration:

```bash
home-manager switch
```

3. Configure 1Password on Windows:
   - Open 1Password
   - Go to Settings > Developer
   - Enable "Use the SSH agent"
   - Add your SSH keys to 1Password

4. Verify the setup:

```bash
~/bin/test-1password-ssh.sh
```

### Option 2: Manual Setup

If you prefer to set up the integration manually:

1. Copy the required scripts to your system:

```bash
mkdir -p ~/bin ~/.1password
cp scripts/setup-1password-ssh-bridge.sh ~/bin/
cp scripts/test-1password-ssh.sh ~/bin/
chmod +x ~/bin/setup-1password-ssh-bridge.sh ~/bin/test-1password-ssh.sh
```

2. Create a systemd user service:

```bash
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/1password-ssh-agent-bridge.service << 'EOF'
[Unit]
Description=1Password SSH Agent Bridge for WSL
Documentation=https://nixos.wiki/wiki/1Password

[Service]
ExecStart=%h/bin/setup-1password-ssh-bridge.sh
Restart=always
Environment=PATH=%h/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now 1password-ssh-agent-bridge
```

3. Configure your shell to use the SSH agent:

```bash
cat > ~/.profile.d/1password-ssh.sh << 'EOF'
#!/usr/bin/env bash
if [[ -S "$HOME/.1password/agent.sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi
EOF
chmod +x ~/.profile.d/1password-ssh.sh
```

## Testing the Integration

Run the test script to verify everything is working correctly:

```bash
~/bin/test-1password-ssh.sh
```

This script checks:
- If the socket file exists
- If the SSH agent is accessible
- If there are any keys available in the agent

## Configuration Options

The Home Manager module supports the following options:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable the 1Password SSH agent integration |
| `socketPath` | `~/.1password/agent.sock` | Path to create the Unix socket |
| `windowsPipeName` | `//./pipe/openssh-ssh-agent` | Windows named pipe for the SSH agent |
| `autoStartAgent` | `true` | Automatically start the SSH agent bridge on login |
| `setEnvironmentVariable` | `true` | Set the SSH_AUTH_SOCK environment variable |

## Requirements

- Windows with WSL2 and NixOS installed
- 1Password desktop application installed on Windows (version 8+)
- NixOS configured with Home Manager
- 1Password SSH agent feature enabled in 1Password settings

## How It Works

The integration works by creating a bridge between the Windows named pipe that 1Password uses for SSH agent communication and a Unix socket in the NixOS environment:

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

The bridge uses:
- `npiperelay.exe` to access the Windows named pipe
- `socat` to forward communications between the Windows pipe and a Unix socket
- Systemd user service to manage the bridge process

## Troubleshooting

See the [detailed documentation](1password-ssh-integration.md) for troubleshooting information.

## Security Considerations

- Private SSH keys are never exposed to the filesystem
- All access to keys requires 1Password to be unlocked
- First-time key usage requires explicit approval in 1Password
- The bridge only provides access to keys marked for SSH agent use in 1Password