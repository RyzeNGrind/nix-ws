#!/usr/bin/env bash
# setup-mcp.sh
# Comprehensive setup script for MCP configuration with Venice Router Integration
# and multi-layered secrets management (sops-nix, agenix, 1Password/opnix)
set -e

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Banner
echo -e "${BLUE}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          MCP Configuration and Secrets Setup Tool            ║"
echo "║                                                              ║"
echo "║   Configures MCP with Venice Router & Multiple Secret Stores ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
  echo -e "${YELLOW}WARNING: You are running this script as root. Some operations are better run as the user.${RESET}"
  read -p "Continue as root? (y/N): " continue_as_root
  if [[ ! $continue_as_root =~ ^[Yy]$ ]]; then
    echo "Please run this script as a regular user."
    exit 1
  fi
fi

# Detect environment
detect_environment() {
  if grep -q Microsoft /proc/version 2>/dev/null; then
    echo "nixos-wsl"
  elif [ -f /etc/nixos/configuration.nix ]; then
    echo "nixos"
  else
    echo "windows"
  fi
}

ENVIRONMENT=$(detect_environment)
echo -e "${CYAN}Detected environment: ${BOLD}$ENVIRONMENT${RESET}"

# Check if nix is installed
if ! command -v nix >/dev/null 2>&1; then
  echo -e "${RED}Nix is not installed. Please install Nix first.${RESET}"
  exit 1
fi

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}Git is not installed. Please install git first.${RESET}"
  exit 1
fi

# Ask for user configuration
echo -e "${CYAN}${BOLD}User Configuration${RESET}"
read -p "Username [ryzengrind]: " USERNAME
USERNAME=${USERNAME:-ryzengrind}

# Create directories
echo -e "\n${CYAN}${BOLD}Creating necessary directories...${RESET}"
mkdir -p ~/.roo
mkdir -p ~/nix-cfg/secrets/{sops,agenix,opnix}

# Check for secrets management tools
echo -e "\n${CYAN}${BOLD}Checking for required tools...${RESET}"

# Check for sops
if ! command -v sops >/dev/null 2>&1; then
  echo -e "${YELLOW}sops not found. Installing with nix...${RESET}"
  nix-shell -p sops --command "echo 'sops installed temporarily via nix-shell'"
  SOPS_AVAILABLE="nix-shell -p sops --run"
else
  echo -e "${GREEN}sops found${RESET}"
  SOPS_AVAILABLE=""
fi

# Check for age/rage
if ! command -v rage >/dev/null 2>&1; then
  echo -e "${YELLOW}rage not found. Installing with nix...${RESET}"
  nix-shell -p rage --command "echo 'rage installed temporarily via nix-shell'"
  RAGE_AVAILABLE="nix-shell -p rage --run"
else
  echo -e "${GREEN}rage found${RESET}"
  RAGE_AVAILABLE=""
fi

# Check for agenix
if ! command -v agenix >/dev/null 2>&1; then
  echo -e "${YELLOW}agenix not found. Installing with nix...${RESET}"
  nix-shell -p agenix --command "echo 'agenix installed temporarily via nix-shell'"
  AGENIX_AVAILABLE="nix-shell -p agenix --run"
else
  echo -e "${GREEN}agenix found${RESET}"
  AGENIX_AVAILABLE=""
fi

# Check for 1Password CLI
if ! command -v op >/dev/null 2>&1; then
  echo -e "${YELLOW}1Password CLI not found. Some features will be limited.${RESET}"
  OP_AVAILABLE=false
else
  echo -e "${GREEN}1Password CLI found${RESET}"
  OP_AVAILABLE=true
fi

# MCP Configuration
echo -e "\n${CYAN}${BOLD}MCP Configuration Setup${RESET}"
echo "Now we'll set up the MCP configuration."

# Initialize .roo/mcp.json if it doesn't exist
if [ ! -f ~/.roo/mcp.json ]; then
  echo -e "${YELLOW}Creating default MCP configuration at ~/.roo/mcp.json${RESET}"
  cat > ~/.roo/mcp.json << EOF
{
  "mcpServers": {
    "mcp-router": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "-u",
        "${USERNAME}",
        "/bin/bash",
        "-c",
        "export MCPR_TOKEN='REPLACE_WITH_YOUR_MCPR_TOKEN'; export NIX_CONNECT_TIMEOUT=15; export NIXPKGS_ALLOW_UNFREE=1; export NIXPKGS_ALLOW_INSECURE=1; source /etc/profile; nix-shell --option substitute true --option builders '' --option builders-use-substitutes false -p nodejs --run 'NODE_TLS_REJECT_UNAUTHORIZED=0 npx -y mcpr-cli@latest connect'"
      ]
    },
    "taskmaster-ai": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "-u",
        "${USERNAME}",
        "/bin/bash",
        "-c",
        "export ANTHROPIC_API_KEY='REPLACE_WITH_YOUR_ANTHROPIC_API_KEY'; export PERPLEXITY_API_KEY='REPLACE_WITH_YOUR_PERPLEXITY_API_KEY'; export MODEL='claude-3-7-sonnet-20250219'; export PERPLEXITY_MODEL='sonar-pro'; export MAX_TOKENS=64000; export TEMPERATURE=0.2; export DEFAULT_SUBTASKS=5; export DEFAULT_PRIORITY='medium'; source /etc/profile; nix-shell --option substitute true --option builders '' --option builders-use-substitutes false -p nodejs --run 'NODE_TLS_REJECT_UNAUTHORIZED=0 npx -y --package=task-master-ai task-master-ai'"
      ],
      "alwaysAllow": []
    },
    "venice-openai-client": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "-u",
        "${USERNAME}",
        "/bin/bash",
        "-c",
        "export VENICE_API_KEY='REPLACE_WITH_YOUR_VENICE_API_KEY'; export OPENROUTER_API_KEY='REPLACE_WITH_YOUR_OPENROUTER_API_KEY'; export VENICE_API_ENDPOINT='http://localhost:8765/v1'; export OPENROUTER_API_ENDPOINT='https://openrouter.ai/api/v1'; source /etc/profile; nix-shell --option substitute true --option builders '' --option builders-use-substitutes false -p nodejs python3 --run 'NODE_TLS_REJECT_UNAUTHORIZED=0 npx -y @smithery/cli@latest run @utensils/openai-compat-proxy --port 3001 --host 127.0.0.1 --target http://localhost:8765/v1'"
      ],
      "alwaysAllow": [
        "openai_chat_completions",
        "openai_text_completions",
        "openai_embeddings"
      ]
    }
  }
}
EOF
  echo -e "${GREEN}Created default MCP configuration. Edit ~/.roo/mcp.json to add your API keys.${RESET}"
else
  echo -e "${GREEN}MCP configuration already exists at ~/.roo/mcp.json${RESET}"
fi

# Initialize sops-nix secrets template
echo -e "\n${CYAN}${BOLD}sops-nix Setup${RESET}"
if [ ! -f ~/nix-cfg/secrets/sops/mcp-secrets.yaml ]; then
  echo -e "${YELLOW}Creating sops-nix secrets template at ~/nix-cfg/secrets/sops/mcp-secrets.yaml${RESET}"
  cat > ~/nix-cfg/secrets/sops/mcp-secrets.yaml << EOF
# MCP and AI Inference secrets template
# Encrypt this file with:
# sops -e -i ~/nix-cfg/secrets/sops/mcp-secrets.yaml

# Venice Router API key
venice_api_key: your-venice-api-key-here

# OpenRouter API key
openrouter_api_key: your-openrouter-api-key-here

# Anthropic API key for TaskMaster
anthropic_api_key: your-anthropic-api-key-here

# Perplexity API key for TaskMaster
perplexity_api_key: your-perplexity-api-key-here

# MCP Router token
mcpr_token: your-mcpr-token-here
EOF
  echo -e "${GREEN}Created sops-nix secrets template.${RESET}"
else
  echo -e "${GREEN}sops-nix secrets template already exists.${RESET}"
fi

# Initialize agenix secrets templates
echo -e "\n${CYAN}${BOLD}agenix Setup${RESET}"
mkdir -p ~/nix-cfg/secrets/agenix
echo -e "${YELLOW}Creating agenix README at ~/nix-cfg/secrets/agenix/README.md${RESET}"
cat > ~/nix-cfg/secrets/agenix/README.md << EOF
# Agenix Encrypted Secrets

This directory should contain the following age-encrypted secret files:
- mcp-venice-api-key.age
- mcp-openrouter-api-key.age
- mcp-anthropic-api-key.age
- mcp-perplexity-api-key.age
- mcp-mcpr-token.age

## Creating Secrets

To create each secret file (replace KEY_NAME with the actual name):

\`\`\`bash
agenix -e secrets/agenix/mcp-KEY_NAME.age
\`\`\`

When prompted, paste the corresponding API key or token value.

## Public Keys (Recipients)

To add a new recipient (someone who can decrypt these secrets):

1. Add their public key to the project's key list
2. Re-encrypt the secrets with:

\`\`\`bash
agenix -r
\`\`\`
EOF
echo -e "${GREEN}Created agenix README.${RESET}"

# 1Password integration if available
if $OP_AVAILABLE; then
  echo -e "\n${CYAN}${BOLD}1Password Integration Setup${RESET}"
  
  # Check if already signed in
  if op account list &>/dev/null; then
    echo -e "${GREEN}Already signed in to 1Password.${RESET}"
  else
    echo -e "${YELLOW}Please sign in to 1Password:${RESET}"
    op signin
  fi
  
  # Get vaults
  echo -e "\n${CYAN}Available 1Password vaults:${RESET}"
  op vault list
  
  echo -e "\n${YELLOW}Please note the vault UUID you wish to use for MCP secrets.${RESET}"
  echo "You will need to update your NixOS configuration with this UUID."
else
  echo -e "\n${YELLOW}1Password CLI not found. Skipping 1Password integration setup.${RESET}"
  echo "Install 1Password CLI to enable 1Password integration."
fi

# Configure Venice Router
echo -e "\n${CYAN}${BOLD}Venice Router Setup${RESET}"
echo "The Venice Router will be configured via the NixOS modules."
echo -e "${YELLOW}Make sure the ai-inference service is enabled in your NixOS configuration.${RESET}"

# Final instructions
echo -e "\n${CYAN}${BOLD}Setup Complete!${RESET}"
echo -e "Now you need to:"
echo -e " 1. ${MAGENTA}Update your API keys${RESET} in the secret stores of your choice:"
echo -e "    - Edit ~/.roo/mcp.json for direct configuration"
echo -e "    - Encrypt ~/nix-cfg/secrets/sops/mcp-secrets.yaml for sops-nix integration"
echo -e "    - Create agenix secret files in ~/nix-cfg/secrets/agenix/"
echo -e "    - Store secrets in 1Password for opnix integration"
echo -e " 2. ${MAGENTA}Import the MCP modules${RESET} in your NixOS configuration:"
echo -e "    - Add modules/mcp-configuration.nix"
echo -e "    - Add modules/mcp-secrets.nix for sops-nix integration"
echo -e "    - Add modules/mcp-1password.nix for 1Password integration"
echo -e "    - Add modules/mcp-agenix.nix for agenix integration"
echo -e " 3. ${MAGENTA}Enable the services${RESET} in your NixOS configuration:"
echo -e "    - services.mcp-configuration.enable = true;"
echo -e "    - services.mcp-secrets.enable = true;  # For sops-nix"
echo -e "    - services.mcp-1password.enable = true;  # For 1Password"
echo -e "    - services.mcp-agenix.enable = true;  # For agenix"
echo -e " 4. ${MAGENTA}Rebuild your NixOS configuration${RESET}:"
echo -e "    - sudo nixos-rebuild switch"
echo -e " 5. ${MAGENTA}Test your MCP configuration${RESET}:"
echo -e "    - ./scripts/test-mcp-connection.sh"
echo -e "\n${GREEN}${BOLD}Happy Hacking with your optimized MCP setup!${RESET}"