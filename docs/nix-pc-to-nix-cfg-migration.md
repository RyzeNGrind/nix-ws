# Migration Guide: nix-pc to nix-cfg

This guide explains how to migrate configurations from `nix-pc` to `nix-cfg`, with a special focus on the 1Password SSH agent integration.

## Repository Visualization

To understand both repositories and their component relationships, use the provided visualization tools:

```bash
# For nix-cfg repository
cd ~/nix-cfg
bash scripts/nix-topology-graph.sh

# For nix-pc repository
cd ~/nix-cfg
bash scripts/nix-pc-topology-graph.sh -p ~/nix-pc
```

The generated SVG files (`nix-topology.svg` and `nix-pc-topology.svg`) provide visual diagrams of both repositories, making it easier to understand how components relate to each other.

## Component Mapping

### 1Password SSH Agent Integration

| nix-pc Component | nix-cfg Component | Notes |
|------------------|-------------------|-------|
| `home/1password-ssh-agent.nix` | `modules/1password-ssh-agent.nix` | Moved to modules directory and expanded |
| `home-ryzengrind.nix` | `home/ryzengrind.nix` | Restructured with imports |
| `home/systemd/1password-ssh-bridge.service` | Built into module | Service is now defined in the module |
| `scripts/setup-1password-ssh-bridge.sh` | `scripts/setup-1password-ssh-bridge.sh` | Script updated with better error handling |
| `scripts/test-1password-ssh.sh` | `scripts/test-1password-ssh-agent.sh` | Enhanced diagnostic capabilities |
| `docs/1password-ssh-integration.md` | `docs/1password-ssh-agent.md` | Updated documentation |

### New Components in nix-cfg

| Component | Purpose |
|-----------|---------|
| `home/modules/1password-ssh.nix` | Home Manager module that imports the 1Password SSH agent module |
| `modules/wsl-integration.nix` | WSL-specific integration for 1Password |
| `scripts/nixos-deploy-with-1password.sh` | Deployment script using nixos-anywhere with 1Password SSH agent |
| `docs/1password-nixos-deployment.md` | Comprehensive documentation with visual diagrams |

## Migration Steps

1. **Copy 1Password SSH Agent Module**
   - The module now lives in `modules/1password-ssh-agent.nix`
   - It has been updated to use the correct pipe name (`//./pipe/com.1password.1password.ssh`)

2. **Update Home Manager Configuration**
   - Import `home/modules/1password-ssh.nix` in `home/ryzengrind.nix`
   - This will set up the necessary Home Manager configuration

3. **Copy and Update Scripts**
   - Update `scripts/setup-1password-ssh-bridge.sh` with enhanced error handling
   - Use `scripts/test-1password-ssh-agent.sh` for verification
   - Use `scripts/nixos-deploy-with-1password.sh` for deployment

4. **Integrate with opnix (Optional)**
   - If using opnix for 1Password secrets, the integration is configured in:
     - `modules/mcp-1password.nix` for MCP and AI services
     - `flake.nix` with conditional imports

## Testing Your Migration

After migrating, verify everything works:

1. **Test 1Password SSH Agent**
   ```bash
   bash scripts/test-1password-ssh-agent.sh
   ```

2. **Deploy to a Test Host**
   ```bash
   bash scripts/nixos-deploy-with-1password.sh -t  # Test mode
   ```

## Integration with nixos-anywhere

The `scripts/nixos-deploy-with-1password.sh` script provides a one-click solution for deploying NixOS with 1Password SSH authentication:

```bash
# Deploy to a remote host
bash scripts/nixos-deploy-with-1password.sh your-target-host

# Use a specific flake configuration
bash scripts/nixos-deploy-with-1password.sh -f ~/nix-cfg -n liveusb your-target-host
```

## Architecture Comparison

### nix-pc Architecture

```
┌───────────────────────┐
│  nix-pc               │
│  ┌─────────────────┐  │
│  │ flake.nix       │  │
│  └───────┬─────────┘  │
│          │            │
│          ▼            │
│  ┌─────────────────┐  │
│  │ home-ryzengrind ◄──┼────┐
│  └───────┬─────────┘  │    │
│          │            │    │
│          ▼            │    │
│  ┌─────────────────┐  │    │
│  │ 1password-ssh-  │  │    │
│  │ agent.nix       │  │    │
│  └───────┬─────────┘  │    │
│          │            │    │
│          ▼            │    │
│  ┌─────────────────┐  │    │
│  │ setup-1password-│  │    │
│  │ ssh-bridge.sh   │  │    │
│  └─────────────────┘  │    │
└───────────────────────┘    │
                             │
                             │
┌───────────────────────┐    │
│  Windows Host         │    │
│  ┌─────────────────┐  │    │
│  │                 │  │    │
│  │  1Password      ├──┼────┘
│  │                 │  │
│  └─────────────────┘  │
└───────────────────────┘
```

### nix-cfg Enhanced Architecture

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

## Understanding Module Relationships

The improved module hierarchy in `nix-cfg` provides better separation of concerns:

1. `modules/1password-ssh-agent.nix` - Core Home Manager module
2. `home/modules/1password-ssh.nix` - Configuration for the module
3. `modules/wsl-integration.nix` - WSL-specific integration
4. `scripts/nixos-deploy-with-1password.sh` - Deployment integration

This structure makes it easier to maintain and understand the codebase.

## Additional Resources

- `docs/1password-ssh-agent.md`: General documentation
- `docs/1password-nixos-deployment.md`: Deployment documentation
- Generated topology diagrams: For visualizing component relationships