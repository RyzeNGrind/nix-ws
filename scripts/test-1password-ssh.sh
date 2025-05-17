#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 1Password SSH Agent Diagnostic Test ===${NC}"

# Define socket path
SOCKETPATH="$HOME/.1password/agent.sock"

# Check if the socket file exists
echo -e "\n${BLUE}1. Checking if socket file exists...${NC}"
if [ -S "$SOCKETPATH" ]; then
  echo -e "${GREEN}✓ Socket file exists at $SOCKETPATH${NC}"
else
  echo -e "${RED}✗ Socket file does not exist at $SOCKETPATH${NC}"
  echo -e "${YELLOW}Hint: Check if the 1password-ssh-agent-bridge service is running:${NC}"
  echo "  systemctl --user status 1password-ssh-agent-bridge"
  exit 1
fi

# Export SSH_AUTH_SOCK for this session
echo -e "\n${BLUE}2. Setting SSH_AUTH_SOCK environment variable...${NC}"
export SSH_AUTH_SOCK="$SOCKETPATH"
echo -e "${GREEN}✓ SSH_AUTH_SOCK is now set to $SSH_AUTH_SOCK${NC}"

# Test SSH agent connectivity
echo -e "\n${BLUE}3. Testing SSH agent connectivity...${NC}"
if ssh-add -l &>/dev/null; then
  echo -e "${GREEN}✓ Successfully connected to SSH agent${NC}"
  
  # List identities
  echo -e "\n${BLUE}4. Available SSH identities:${NC}"
  ssh-add -l
  
  echo -e "\n${GREEN}=== SUCCESS: 1Password SSH Agent is working correctly! ===${NC}"
  echo -e "${YELLOW}Note: To use the SSH agent in your current shell, run:${NC}"
  echo "  export SSH_AUTH_SOCK=\"$SOCKETPATH\""
else
  echo -e "${RED}✗ Could not connect to SSH agent${NC}"
  
  if [ "$(ssh-add -l 2>&1)" == "The agent has no identities." ]; then
    echo -e "${YELLOW}The agent is working but has no identities.${NC}"
    echo -e "${YELLOW}Check if you have enabled the SSH Agent feature in 1Password and added SSH keys.${NC}"
    echo -e "${YELLOW}Follow these steps in 1Password for Windows:${NC}"
    echo "  1. Open 1Password"
    echo "  2. Go to Settings > Developer"
    echo "  3. Enable 'Use the SSH agent'"
    echo "  4. Add your SSH keys to 1Password and mark them for use with SSH agent"
  else
    echo -e "${RED}=== ERROR: 1Password SSH Agent bridge is not working correctly! ===${NC}"
    echo -e "${YELLOW}Troubleshooting steps:${NC}"
    echo "  1. Check if the Windows 1Password application is running"
    echo "  2. Verify SSH agent is enabled in 1Password Settings > Developer"
    echo "  3. Restart the bridge service: systemctl --user restart 1password-ssh-agent-bridge"
    echo "  4. Check service logs: journalctl --user -u 1password-ssh-agent-bridge -n 50"
  fi
  exit 1
fi