# MCP Configuration and AI Router Integration

## Architecture Overview

This system implements a comprehensive Mission Control Panel (MCP) configuration for the RooCode extension, with intelligent AI inference cost optimization between Venice VCU and OpenRouter. The architecture leverages multiple layers of secure secrets management and provides cross-environment compatibility.

### Core Components

```
                      ┌─────────────────┐
                      │   Void Editor   │
                      │  with RooCode   │
                      └────────┬────────┘
                               │
                               ▼
                      ┌─────────────────┐
                      │  MCP Router &   │
                      │ Server Registry │
                      └────────┬────────┘
                               │
                      ┌────────┴────────┐
                      ▼                 ▼
           ┌─────────────────┐ ┌─────────────────┐
           │  TaskMaster AI  │ │ Venice OpenAI   │
           │     Server      │ │ Compatibility   │
           └─────────────────┘ └────────┬────────┘
                                        │
                                        ▼
                               ┌─────────────────┐
                               │  Venice Router  │
                               └────────┬────────┘
                                        │
                            ┌───────────┴───────────┐
                            ▼                       ▼
                  ┌─────────────────┐     ┌─────────────────┐
                  │   Venice VCU    │     │   OpenRouter    │
                  │  (97.3% Usage)  │     │  (2.7% Usage)   │
                  └─────────────────┘     └─────────────────┘
```

### Key Features

- **Declarative Configuration**: All MCP servers defined using idiomatic NixOS modules
- **Multi-layered Secret Management**: Choose from sops-nix, agenix, or 1Password (via opnix)
- **Cost Optimization**: Intelligent routing between Venice VCU (~97.3%) and OpenRouter (~2.7%)
- **Cross-Environment Support**: Works seamlessly across nixos-wsl, native NixOS, and Windows hosts
- **TaskMaster Integration**: Optimized API integration for project management
- **OpenAI Compatibility**: Proxy layer for apps expecting the OpenAI API format

## Module Structure

| Module                | Purpose                                                 |
|-----------------------|---------------------------------------------------------|
| `mcp-configuration.nix` | Core MCP server configuration and environment detection |
| `mcp-secrets.nix`     | sops-nix based API key management                      |
| `mcp-1password.nix`   | 1Password integration via opnix                        |
| `mcp-agenix.nix`      | agenix (age-encrypted) secrets management              |
| `ai-inference.nix`    | Venice Router intelligent API cost optimization         |

## Setup Instructions

### Prerequisites

- NixOS or WSL with NixOS
- flake.nix with proper inputs for sops-nix, agenix, and opnix
- Venice and OpenRouter API keys
- TaskMaster API keys (Anthropic, Perplexity)

### Step 1: Add flake inputs

Ensure your `flake.nix` contains these inputs:

```nix
inputs = {
  # ... existing inputs
  sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  opnix = {
    url = "github:brizzbuzz/opnix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Step 2: Run the setup script

```bash
# Make the script executable
chmod +x scripts/setup-mcp.sh

# Run the setup script
./scripts/setup-mcp.sh
```

This will:
1. Create necessary directories
2. Initialize MCP configuration templates
3. Set up secret management templates
4. Guide you through API key configuration

### Step 3: Configure your NixOS host

Update your host configuration (e.g., `hosts/nix-ws.nix`):

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    # ... existing imports
    ../modules/ai-inference.nix
    ../modules/mcp-configuration.nix
    ../modules/mcp-secrets.nix
    # Optional: Choose one or more of these based on your needs
    ../modules/mcp-1password.nix
    ../modules/mcp-agenix.nix
  ];

  # AI Inference Configuration
  services.ai-inference = {
    enable = true;
    targetRatio = 97.3;  # 97.3% Venice, 2.7% OpenRouter
    complexityThreshold = 25;
    prometheus.enable = true;
    openFirewall = true;
  };

  # MCP Configuration
  services.mcp-configuration = {
    enable = true;
    user = "ryzengrind";  # Your username
    manageGlobalSettings = true;
    environmentType = "nixos";  # or "nixos-wsl" or "windows"
    
    # Venice Router integration
    veniceRouterIntegration = {
      enable = true;
      veniceApiEndpoint = "http://localhost:8765/v1";
      openRouterApiEndpoint = "https://openrouter.ai/api/v1";
    };
    
    # TaskMaster integration
    taskMaster = {
      enable = true;
      model = "claude-3-7-sonnet-20250219";
      perplexityModel = "sonar-pro";
      maxTokens = 64000;
      temperature = 0.2;
      defaultSubtasks = 5;
      defaultPriority = "medium";
    };
  };

  # Choose ONE of the following secret management options:
  
  # Option 1: sops-nix
  services.mcp-secrets = {
    enable = true;
    user = "ryzengrind";  # Your username
    keysFile = "/etc/mcp-secrets.yaml";
  };
  
  # Option 2: 1Password integration
  services.mcp-1password = {
    enable = true;
    user = "ryzengrind";  # Your username
    vaultUuid = "12345678-1234-1234-1234-123456789012";  # Your 1Password vault UUID
    
    # Fill in your 1Password item information
    veniceApiKey.uuid = "uuid1";
    veniceApiKey.itemUuid = "item1";
    
    openRouterApiKey.uuid = "uuid2";
    openRouterApiKey.itemUuid = "item2";
    
    anthropicApiKey.uuid = "uuid3";
    anthropicApiKey.itemUuid = "item3";
    
    perplexityApiKey.uuid = "uuid4";
    perplexityApiKey.itemUuid = "item4";
    
    mcprToken.uuid = "uuid5";
    mcprToken.itemUuid = "item5";
  };
  
  # Option 3: agenix
  services.mcp-agenix = {
    enable = true;
    user = "ryzengrind";  # Your username
    
    # Optional: Enable YubiKey support
    yubikey = {
      enable = false;  # Set to true if using YubiKey
      slot = 1;
    };
  };
}
```

### Step 4: Encrypt your secrets

#### Using sops-nix:

```bash
# Edit your sops configuration
$EDITOR .sops.yaml

# Example .sops.yaml
keys:
  - &admin_user age15h3m...your-age-public-key...qp
  - &server_key age1kvs...your-server-key...vd
creation_rules:
  - path_regex: secrets/sops/.*\.yaml$
    key_groups:
    - age:
      - *admin_user
      - *server_key

# Create and encrypt your secrets
cp ~/nix-cfg/secrets/sops/mcp-secrets.yaml /etc/mcp-secrets.yaml
sops -e -i /etc/mcp-secrets.yaml
```

#### Using agenix:

```bash
# Create recipient keys
mkdir -p ~/.config/agenix

# Add your SSH public key(s) as recipients
echo "ssh-ed25519 AAAA..." > ~/.config/agenix/keys.txt

# Create and encrypt each secret
agenix -e secrets/agenix/mcp-venice-api-key.age
# Enter your API key when prompted
# Repeat for other API keys
```

#### Using 1Password:

Follow the 1Password CLI setup instructions:

```bash
# Login to 1Password
op signin

# Create items for each API key
op item create --category="API Credential" \
  --title="Venice API Key" \
  --vault="Your Vault" \
  --fields="password=your-venice-api-key"

# Get the item UUID
op item list --format=json | jq '.[] | select(.title=="Venice API Key") | .id'

# Update your NixOS configuration with these UUIDs
```

### Step 5: Apply the configuration

```bash
# Rebuild NixOS with the new configuration
sudo nixos-rebuild switch

# Check services are running
systemctl status ai-inference.service
```

### Step 6: Test your setup

```bash
# Make the test script executable
chmod +x scripts/test-mcp-connection.sh

# Run the test script
./scripts/test-mcp-connection.sh
```

## Usage and Integration

### Using TaskMaster

TaskMaster AI is now configured to use your preferred AI providers via the Venice Router for cost optimization:

```bash
# Create a new task
npx task-master create

# View existing tasks
npx task-master get-tasks
```

### Using Venice Router Directly

The Venice Router API is available at `http://localhost:8765/v1`:

```bash
# Test the API
curl -X POST http://localhost:8765/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen-3-4b", "prompt": "Explain Nix flakes", "max_tokens": 512}'

# Check routing status
curl http://localhost:8765/status
```

### Using the OpenAI Compatibility Proxy

For applications expecting the OpenAI API:

```bash
# OpenAI-compatible endpoint available at:
http://localhost:3001/v1/chat/completions
```

## Advanced Configuration

### Cross-Environment Configuration

The MCP modules automatically detect and adapt to different environments:

- **NixOS**: Direct service configuration
- **WSL with NixOS**: Proper WS command wrapping
- **Windows Host**: Path adjustments for Windows compatibility

### API Key Rotation

For optimal security, rotate your API keys regularly:

1. Generate new API keys from the provider websites
2. Update your secrets using your chosen method:
   - sops-nix: `sops -e -i /etc/mcp-secrets.yaml`
   - agenix: `agenix -e secrets/agenix/mcp-KEY_NAME.age` 
   - 1Password: Update through the 1Password UI or CLI
3. Restart the services: `systemctl restart ai-inference.service`

### Custom Routing Adjustments

To adjust the Venice/OpenRouter routing ratio:

```nix
services.ai-inference = {
  targetRatio = 95.0;  # Adjust as needed (95% Venice, 5% OpenRouter)
  complexityThreshold = 30;  # Higher = more tasks routed to Venice
};
```

## Monitoring and Troubleshooting

### Monitoring

The Venice Router exposes Prometheus metrics at `http://localhost:8765/metrics` when enabled:

```nix
services.ai-inference.prometheus = {
  enable = true;
  port = 9090;  # Prometheus port
};
```

Key metrics to monitor:
- `venice_total_tokens`: Total tokens processed by Venice
- `openrouter_total_tokens`: Total tokens processed by OpenRouter
- `model_usage_total`: Usage by model and provider
- `inference_failures_total`: Failures by model, provider, and error type

### Troubleshooting

#### Venice Router Issues

```bash
# Check service status
systemctl status ai-inference.service

# View service logs
journalctl -u ai-inference.service -f

# Test API connectivity
curl http://localhost:8765/status
```

#### MCP Configuration Issues

```bash
# Verify MCP configuration
cat ~/.roo/mcp.json | jq .

# Check if secrets are properly configured
ls -la /run/agenix/mcp/  # For agenix
ls -la /run/op/mcp/      # For 1Password/opnix
```

#### TaskMaster Issues

```bash
# Check for errors in TaskMaster
ANTHROPIC_API_KEY=$(cat /run/agenix/mcp/anthropic_api_key) \
npx task-master get-tasks --debug
```

## Security Best Practices

- **Never commit API keys** to your Git repository
- Use **different API keys** for development and production
- Keep the OpenAI compatibility proxy **bound to localhost only**
- Enable **firewall rules** to restrict API access
- Set appropriate **file permissions** (0400) for secret files
- Consider using **YubiKey** with agenix for enhanced security

---

This setup provides a robust, secure, and cost-effective solution for AI inference in your NixOS environment, with deep integration to the RooCode MCP/TaskMaster ecosystem.