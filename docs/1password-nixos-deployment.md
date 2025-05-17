# 1Password SSH Agent Integration with NixOS Deployments

This documentation provides a comprehensive understanding of how the 1Password SSH agent integrates with NixOS for deployments using `nixos-anywhere`, particularly in a WSL environment.

## System Architecture

```
┌───────────────────────┐         ┌───────────────────────┐
│                       │         │                       │
│  Windows Host         │         │  NixOS (WSL)          │
│                       │         │                       │
│  ┌─────────────────┐  │         │  ┌─────────────────┐  │
│  │                 │  │         │  │                 │  │
│  │  1Password      │  │         │  │  nixos-anywhere │  │
│  │                 │  │         │  │                 │  │
│  │  [SSH Keys]     │  │         │  │                 │  │
│  │                 │  │         │  └────────┬────────┘  │
│  └────────┬────────┘  │         │           │           │
│           │           │         │           │           │
│           ▼           │         │           │           │
│  ┌─────────────────┐  │         │  ┌────────▼────────┐  │
│  │                 │  │  Pipe   │  │                 │  │
│  │  SSH Agent      ├──┼─────────┼─►│  SSH Agent      │  │
│  │  Named Pipe     │  │  Relay  │  │  Unix Socket    │  │
│  │                 │  │         │  │                 │  │
│  └─────────────────┘  │         │  └─────────────────┘  │
│                       │         │                       │
└───────────────────────┘         └───────────────────────┘
                                          │
                                          │ SSH with Agent Forwarding
                                          ▼
                                  ┌───────────────────────┐
                                  │                       │
                                  │  Target NixOS Host    │
                                  │                       │
                                  │  ┌─────────────────┐  │
                                  │  │                 │  │
                                  │  │  NixOS System   │  │
                                  │  │  Configuration  │  │
                                  │  │                 │  │
                                  │  └─────────────────┘  │
                                  │                       │
                                  └───────────────────────┘
```

## Component Map

| Component | File Path | Purpose |
|-----------|-----------|---------|
| 1Password SSH Agent Module | `modules/1password-ssh-agent.nix` | Home Manager module for configuring 1Password SSH agent integration |
| Home Module Config | `home/modules/1password-ssh.nix` | Configuration for the 1Password SSH agent in Home Manager |
| SSH Bridge Script | `scripts/setup-1password-ssh-bridge.sh` | Creates the bridge between Windows named pipe and Unix socket |
| Test Script | `scripts/test-1password-ssh-agent.sh` | Tests the 1Password SSH agent connection |
| Deployment Script | `scripts/nixos-deploy-with-1password.sh` | Deploys NixOS using nixos-anywhere with 1Password SSH authentication |
| Documentation | `docs/1password-ssh-agent.md` | General documentation for 1Password SSH agent integration |
| Documentation | `docs/1password-nixos-deployment.md` | This file - documentation on deployment integration |

## Flow of Execution

1. **Setup Phase**
   - 1Password is configured on Windows to enable SSH Agent
   - The Home Manager module (`modules/1password-ssh-agent.nix`) is imported into the user's Home Manager configuration
   - On login, a systemd user service starts the SSH bridge via `scripts/setup-1password-ssh-bridge.sh`
   - The bridge connects the Windows named pipe to a Unix socket in WSL

2. **Verification Phase**
   - The `scripts/test-1password-ssh-agent.sh` script can be used to verify the bridge is working
   - It checks if the socket exists, tests connectivity to the SSH agent, and lists available identities

3. **Deployment Phase**
   - The `scripts/nixos-deploy-with-1password.sh` script is used to deploy NixOS
   - It verifies the 1Password SSH agent is working
   - It deploys to the target host using nixos-anywhere with SSH agent forwarding

## Integration with opnix

The `opnix` integration for 1Password secrets is handled through a separate pathway, not directly related to the SSH agent:

```
┌───────────────────────┐         ┌───────────────────────┐
│                       │         │                       │
│  Windows Host         │         │  NixOS (WSL)          │
│                       │         │                       │
│  ┌─────────────────┐  │         │  ┌─────────────────┐  │
│  │                 │  │         │  │                 │  │
│  │  1Password      │  │  CLI    │  │  opnix Module   │  │
│  │                 ◄──┼─────────┼──┤                 │  │
│  │  [Secrets]      │  │  API    │  │                 │  │
│  │                 │  │         │  └────────┬────────┘  │
│  └─────────────────┘  │         │           │           │
│                       │         │           │           │
└───────────────────────┘         │           │           │
                                  │           ▼           │
                                  │  ┌─────────────────┐  │
                                  │  │                 │  │
                                  │  │  NixOS Config   │  │
                                  │  │  With Secrets   │  │
                                  │  │                 │  │
                                  │  └─────────────────┘  │
                                  │                       │
                                  └───────────────────────┘
```

The opnix integration is configured through:

1. Flake inputs: `opnix = { url = "github:brizzbuzz/opnix"; ... }`
2. NixOS module imports: `inputs.opnix.nixosModules.opnix` (in `flake.nix`)
3. Configuration in various modules:
   - `modules/mcp-1password.nix`: Integration with MCP and AI services
   - `modules/mcp-secrets.nix`: Management of secret references

## Environment Variables

Key environment variables include:

- `SSH_AUTH_SOCK`: Set to the path of the Unix socket (`~/.1password/agent.sock`)
- Various API keys referenced by path (e.g., `/run/op/mcp/venice_api_key`)

## Security Considerations

1. **1Password SSH Agent**:
   - Private SSH keys never leave the 1Password app on Windows
   - Only signing operations occur through the agent
   - The Unix socket has restrictive permissions (0600)

2. **opnix Secrets**:
   - Secrets are retrieved from 1Password at runtime
   - Permissions are set to restrict access (0400)
   - Designed for integration with NixOS's declarative configuration

## Migration Guide: nix-pc → nix-cfg

If you're migrating from `nix-pc` to `nix-cfg`, the key steps are:

1. Ensure the 1Password SSH agent module is properly imported in Home Manager:
   - `modules/1password-ssh-agent.nix` exists in both repos and has been updated with the correct pipe name
   - `home/modules/1password-ssh.nix` imports and configures the module
   - The module is imported in `home/ryzengrind.nix`

2. Test the 1Password SSH agent:
   ```bash
   bash scripts/test-1password-ssh-agent.sh
   ```

3. Deploy using the new script:
   ```bash
   bash scripts/nixos-deploy-with-1password.sh [target-host]
   ```

## Troubleshooting

### 1Password SSH Agent Issues

If the agent doesn't work:

1. Check if 1Password is running on Windows
2. Verify SSH Agent is enabled in 1Password Settings > Developer
3. Make sure the named pipe exists (`//./pipe/com.1password.1password.ssh`)
4. Restart the bridge: `systemctl --user restart 1password-ssh-agent-bridge`
5. Check logs: `journalctl --user -u 1password-ssh-agent-bridge -n 50`

### opnix Issues

If opnix doesn't work:

1. Check the opnix token: `cat /etc/opnix-token`
2. Verify 1Password CLI is working: `op whoami`
3. Check permissions on secret files
4. Look for error messages in NixOS rebuild logs

### nixos-anywhere Issues

1. Verify SSH connectivity: `ssh root@target-host`
2. Check if SSH agent forwarding works: `ssh -A root@target-host 'ssh-add -l'`
3. Make sure the target host has SSH enabled
4. Check the flake configuration name

## Automated Deployment Workflow

For regular deployments:

1. Update your NixOS configuration in `nix-cfg`
2. Run the test script: `scripts/test-1password-ssh-agent.sh`
3. Deploy to the target: `scripts/nixos-deploy-with-1password.sh target-host`

This workflow provides a seamless, secure way to deploy NixOS configurations to remote hosts.