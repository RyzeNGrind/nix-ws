#!/usr/bin/env bash
# test-mcp-connection.sh
# Tests MCP configuration and Venice Router integration
set -e

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Banner
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║       MCP Connection and Integration Test Tool         ║"
echo "║                                                        ║"
echo "║  Verifies MCP, Venice Router, and TaskMaster setup     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Helper functions
check_file() {
  if [ -f "$1" ]; then
    echo -e "${GREEN}✓ Found $1${RESET}"
    return 0
  else
    echo -e "${RED}✗ Missing $1${RESET}"
    return 1
  fi
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ $1 command is available${RESET}"
    return 0
  else
    echo -e "${RED}✗ $1 command not found${RESET}"
    return 1
  fi
}

check_service() {
  if systemctl is-active --quiet "$1"; then
    echo -e "${GREEN}✓ Service $1 is running${RESET}"
    return 0
  else
    echo -e "${RED}✗ Service $1 is not running${RESET}"
    return 1
  fi
}

check_port() {
  if nc -z localhost "$1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Port $1 is open${RESET}"
    return 0
  else
    echo -e "${RED}✗ Port $1 is not open${RESET}"
    return 1
  fi
}

# Check basic environment
echo -e "\n${BOLD}Checking environment...${RESET}"

# Check for .roo/mcp.json
check_file "$HOME/.roo/mcp.json"
if [ $? -eq 0 ]; then
  # Verify mcp.json doesn't contain placeholder text
  if grep -q "REPLACE_WITH_YOUR" "$HOME/.roo/mcp.json"; then
    echo -e "${YELLOW}⚠️  Warning: mcp.json contains placeholder values that need to be replaced${RESET}"
  fi
fi

# Check NixOS modules
echo -e "\n${BOLD}Checking for NixOS modules...${RESET}"
MODULES_PATH="$(git rev-parse --show-toplevel 2>/dev/null || echo "./modules")/modules"

for module in mcp-configuration.nix mcp-secrets.nix mcp-1password.nix mcp-agenix.nix; do
  check_file "$MODULES_PATH/$module"
done

# Check secrets
echo -e "\n${BOLD}Checking for secrets configuration...${RESET}"

# sops-nix
SOPS_PATH="/etc/mcp-secrets.yaml"
if [ -f "$SOPS_PATH" ]; then
  echo -e "${GREEN}✓ Found sops-nix secrets file${RESET}"
else
  echo -e "${YELLOW}⚠️  sops-nix secrets file not found. This is fine if you're using alternative secret stores.${RESET}"
fi

# agenix
AGENIX_PATH="/run/agenix/mcp"
if [ -d "$AGENIX_PATH" ]; then
  echo -e "${GREEN}✓ Found agenix secrets directory${RESET}"
  # Check if any files exist in the directory
  if [ "$(ls -A "$AGENIX_PATH" 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Agenix secrets are present${RESET}"
  else
    echo -e "${YELLOW}⚠️  Agenix secrets directory is empty${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  Agenix secrets directory not found. This is fine if you're using alternative secret stores.${RESET}"
fi

# 1Password
if command -v op >/dev/null 2>&1; then
  echo -e "${GREEN}✓ 1Password CLI is installed${RESET}"
  
  # Check if signed in
  if op account list &>/dev/null; then
    echo -e "${GREEN}✓ 1Password is signed in${RESET}"
  else
    echo -e "${YELLOW}⚠️  Not signed in to 1Password. Run 'op signin' if using 1Password for secrets.${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  1Password CLI not found. This is fine if you're using alternative secret stores.${RESET}"
fi

# Check Venice Router
echo -e "\n${BOLD}Checking Venice Router...${RESET}"

# Check if service is enabled
if systemctl list-unit-files | grep -q "ai-inference.service"; then
  if systemctl is-enabled --quiet ai-inference.service; then
    echo -e "${GREEN}✓ ai-inference service is enabled${RESET}"
    
    # Check if service is running
    if systemctl is-active --quiet ai-inference.service; then
      echo -e "${GREEN}✓ ai-inference service is running${RESET}"
    else
      echo -e "${YELLOW}⚠️  ai-inference service is not running${RESET}"
      echo -e "   Run: ${BOLD}sudo systemctl start ai-inference.service${RESET}"
    fi
  else
    echo -e "${YELLOW}⚠️  ai-inference service is not enabled${RESET}"
    echo -e "   Run: ${BOLD}sudo systemctl enable ai-inference.service${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  ai-inference service not found in system${RESET}"
  echo -e "   Ensure services.ai-inference.enable = true; in your NixOS config"
fi

# Check if Venice Router port is open
if nc -z localhost 8765 >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Venice Router port (8765) is open${RESET}"
  
  # Try to get status from the API
  if command -v curl >/dev/null 2>&1; then
    echo -en "${BLUE}Checking Venice Router API...${RESET} "
    if curl -s http://localhost:8765/status >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Venice Router API is responding${RESET}"
      
      # Get current routing ratio
      RATIO=$(curl -s http://localhost:8765/status | grep -o '"current_ratio":[^,]*' | cut -d: -f2)
      if [ -n "$RATIO" ]; then
        echo -e "${GREEN}✓ Current Venice/OpenRouter ratio: $RATIO%${RESET}"
      fi
    else
      echo -e "${RED}✗ Venice Router API is not responding${RESET}"
    fi
  fi
else
  echo -e "${YELLOW}⚠️  Venice Router port (8765) is not open${RESET}"
  echo -e "   Make sure ai-inference service is running"
fi

# Check OpenAI proxy (if configured)
if nc -z localhost 3001 >/dev/null 2>&1; then
  echo -e "${GREEN}✓ OpenAI compatibility proxy (3001) is running${RESET}"
else
  echo -e "${YELLOW}⚠️  OpenAI compatibility proxy (port 3001) is not running${RESET}"
  echo -e "   This is needed for compatibility with OpenAI applications"
fi

# Check TaskMaster
echo -e "\n${BOLD}Testing TaskMaster-AI integration...${RESET}"
MCP_JSON="$HOME/.roo/mcp.json"
if jq -e '.mcpServers."taskmaster-ai"' "$MCP_JSON" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ TaskMaster-AI is configured in MCP${RESET}"
  
  # Check for placeholder API keys
  if grep -q "REPLACE_WITH_YOUR_ANTHROPIC_API_KEY" "$MCP_JSON"; then
    echo -e "${RED}✗ Anthropic API key is still a placeholder${RESET}"
  else
    echo -e "${GREEN}✓ Anthropic API key appears to be set${RESET}"
  fi
  
  if grep -q "REPLACE_WITH_YOUR_PERPLEXITY_API_KEY" "$MCP_JSON"; then
    echo -e "${RED}✗ Perplexity API key is still a placeholder${RESET}"
  else
    echo -e "${GREEN}✓ Perplexity API key appears to be set${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  TaskMaster-AI not found in MCP configuration${RESET}"
fi

# Final status
echo -e "\n${BOLD}Final Status:${RESET}"
echo -e "1. Basic MCP configuration is present"
echo -e "2. Secrets management enabled via sops-nix, agenix, or 1Password"
echo -e "3. Venice Router API status verified"
echo -e "4. TaskMaster-AI integration checked"

echo -e "\n${YELLOW}${BOLD}Next Steps:${RESET}"
echo -e "• If you found any issues, update your configuration accordingly"
echo -e "• Ensure all API keys are properly set in your chosen secret store"
echo -e "• Test MCP integration in the Void editor by running a MCP tool"
echo -e "• Verify that Venice Router is properly load balancing between APIs"
echo -e "• Try creating a task with TaskMaster:\n  ${BOLD}npx task-master create${RESET}"

echo -e "\n${GREEN}${BOLD}Test completed!${RESET}"