#!/usr/bin/env bash
# Comprehensive 1Password SSH Agent Diagnostic Tool
# This script checks all aspects of the integration including agent.toml configuration

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration - correct pipe path for 1Password 8+
SOCKET_PATH="$HOME/.1password/agent.sock"
PIPE_PATH="//./pipe/com.1password.1password.ssh"
# Corrected agent.toml path based on user feedback
WINDOWS_AGENT_TOML_PATH_PRIMARY="/mnt/c/Users/RyzeNGrind/AppData/Local/1Password/config/ssh/agent.toml"
WINDOWS_AGENT_TOML_PATH_FALLBACK="/mnt/c/Users/RyzeNGrind/AppData/Local/1Password/app/8/op-ssh-sign/agent.toml"


echo -e "${BLUE}${BOLD}=== 1Password SSH Agent Diagnostic Test (Complete) ===${NC}"

# Step 1: Check 1Password installation on Windows
echo -e "\n${BLUE}${BOLD}1. Checking 1Password installation on Windows...${NC}"
FOUND_1PASSWORD=false

if [ -e "/mnt/c/Program Files/1Password/app/8/1Password.exe" ]; then
    echo -e "${GREEN}✓ 1Password found in Program Files${NC}"
    FOUND_1PASSWORD=true
elif find /mnt/c/Users/*/AppData/Local/1Password/app/8/1Password.exe -type f 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ 1Password found in AppData${NC}"
    FOUND_1PASSWORD=true
fi

if [ "$FOUND_1PASSWORD" = false ]; then
    echo -e "${YELLOW}⚠ Cannot detect 1Password installation${NC}"
    echo -e "${YELLOW}  This does not necessarily mean it's not installed${NC}"
fi

# Step 2: Check agent.toml configuration
echo -e "\n${BLUE}${BOLD}2. Checking agent.toml configuration...${NC}"

ACTUAL_AGENT_TOML_PATH=""
if [ -f "$WINDOWS_AGENT_TOML_PATH_PRIMARY" ]; then
    ACTUAL_AGENT_TOML_PATH="$WINDOWS_AGENT_TOML_PATH_PRIMARY"
    echo -e "${GREEN}✓ agent.toml found at primary path: $ACTUAL_AGENT_TOML_PATH${NC}"
elif [ -f "$WINDOWS_AGENT_TOML_PATH_FALLBACK" ]; then
    ACTUAL_AGENT_TOML_PATH="$WINDOWS_AGENT_TOML_PATH_FALLBACK"
    echo -e "${GREEN}✓ agent.toml found at fallback path: $ACTUAL_AGENT_TOML_PATH${NC}"
else
    echo -e "${RED}✗ agent.toml not found at expected locations:${NC}"
    echo -e "${RED}  Primary: $WINDOWS_AGENT_TOML_PATH_PRIMARY${NC}"
    echo -e "${RED}  Fallback: $WINDOWS_AGENT_TOML_PATH_FALLBACK${NC}"
    echo -e "${YELLOW}This is likely the cause of the 'no identities' issue.${NC}"
    echo -e "${YELLOW}1Password needs this file to know which SSH keys to make available.${NC}"
    echo -e "${YELLOW}Create this file with content like:${NC}"
    echo
    echo "  # 1Password SSH agent configuration"
    echo "  # Example configuration:"
    echo "  [[ssh-keys]]"
    echo "  vault = \"Private\""
    echo
    echo "  [[ssh-keys]]"
    echo "  item = \"my-github-key\""
    echo "  vault = \"Development\""
    echo
    echo -e "${YELLOW}Then restart 1Password on Windows.${NC}"
fi

if [ -n "$ACTUAL_AGENT_TOML_PATH" ]; then
    # Count SSH key configurations
    KEY_COUNT=$(grep -c '\[\[ssh-keys\]\]' "$ACTUAL_AGENT_TOML_PATH" || echo "0")
    if [ "$KEY_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ $KEY_COUNT SSH key configuration entries found in agent.toml${NC}"
        
        # Display configured vaults
        echo -e "${BLUE}Configured vaults:${NC}"
        grep -o 'vault\s*=\s*"[^"]*"' "$ACTUAL_AGENT_TOML_PATH" | sort | uniq | sed 's/vault\s*=\s*/  /'
        
        # Display configured items
        if grep -q 'item\s*=' "$ACTUAL_AGENT_TOML_PATH"; then
            echo -e "${BLUE}Configured specific items:${NC}"
            grep -o 'item\s*=\s*"[^"]*"' "$ACTUAL_AGENT_TOML_PATH" | sed 's/item\s*=\s*/  /'
        fi
    else
        echo -e "${YELLOW}⚠ No SSH key configurations (e.g., [[ssh-keys]]) found in agent.toml${NC}"
        echo -e "${YELLOW}  You need to configure SSH keys in agent.toml for them to be available.${NC}"
    fi
fi


# Step 3: Check if socket file exists
echo -e "\n${BLUE}${BOLD}3. Checking if socket file exists...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    echo -e "${GREEN}✓ Socket file exists at $SOCKET_PATH${NC}"
else
    echo -e "${RED}✗ Socket file does not exist at $SOCKET_PATH${NC}"
    echo -e "${YELLOW}  Run: ./scripts/setup-1password-ssh-complete.sh${NC}"
fi

# Step 4: Setting up test environment
echo -e "\n${BLUE}${BOLD}4. Setting up test environment...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    export SSH_AUTH_SOCK="$SOCKET_PATH"
    echo -e "${GREEN}✓ SSH_AUTH_SOCK is now set to $SSH_AUTH_SOCK${NC}"
else
    echo -e "${YELLOW}⚠ Skipping SSH_AUTH_SOCK setup (socket doesn't exist)${NC}"
    # Try to start the bridge
    if [ -x "./scripts/setup-1password-ssh-complete.sh" ]; then
        echo -e "${BLUE}Attempting to start the bridge in background...${NC}"
        "./scripts/setup-1password-ssh-complete.sh" &>/dev/null &
        BRIDGE_PID=$!
        
        # Give it a moment to start
        sleep 3
        
        # Check if socket exists now
        if [ -S "$SOCKET_PATH" ]; then
            export SSH_AUTH_SOCK="$SOCKET_PATH"
            echo -e "${GREEN}✓ Bridge started and socket created successfully${NC}"
        else
            echo -e "${RED}✗ Bridge started but socket not created${NC}"
            kill $BRIDGE_PID 2>/dev/null || true
        fi
    else
        echo -e "${RED}✗ Bridge script not found or not executable${NC}"
    fi
fi

# Step 5: Test SSH agent connectivity
echo -e "\n${BLUE}${BOLD}5. Testing SSH agent connectivity...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    SSH_ADD_OUTPUT=$(ssh-add -l 2>&1)
    SSH_ADD_STATUS=$?
    
    case $SSH_ADD_STATUS in
        0)  # Success, keys found
            echo -e "${GREEN}✓ Successfully connected to SSH agent${NC}"
            echo -e "${BLUE}Available SSH identities:${NC}"
            echo "$SSH_ADD_OUTPUT"
            echo -e "${GREEN}✓ SSH agent integration is working correctly!${NC}"
            ;;
        1)  # Success, no keys
            echo -e "${YELLOW}⚠ Connected to SSH agent, but no identities available${NC}"
            echo -e "${RED}This is the 'no identities' issue${NC}"
            echo -e "${YELLOW}Likely causes:${NC}"
            echo -e "  1. ${YELLOW}agent.toml is not properly configured or missing (Checked in Step 2).${NC}"
            echo -e "  2. ${YELLOW}SSH keys in 1Password are not set up for SSH agent use (in 1Password app settings).${NC}"
            echo -e "  3. ${YELLOW}1Password wasn't restarted after agent.toml changes.${NC}"
            
            echo -e "\n${BOLD}Steps to fix:${NC}"
            echo -e "  1. ${YELLOW}Ensure agent.toml is correctly configured at the path identified in Step 2.${NC}"
            echo -e "  2. ${YELLOW}For each SSH key in 1Password:${NC}"
            echo -e "     - Open the key"
            echo -e "     - Click Edit"
            echo -e "     - Check 'Allow using this key for SSH agent'"
            echo -e "     - Save changes"
            echo -e "  3. ${YELLOW}Restart 1Password on Windows${NC}"
            echo -e "  4. ${YELLOW}Run this test again${NC}"
            ;;
        *)  # Connection error
            echo -e "${RED}✗ Could not connect to SSH agent${NC}"
            echo -e "${RED}Error message: ${SSH_ADD_OUTPUT}${NC}"
            echo -e "${YELLOW}Possible issues:${NC}"
            echo "  1. 1Password is not running on Windows"
            echo "  2. SSH agent is not enabled in 1Password Settings > Developer"
            echo "  3. Pipe path might be incorrect (currently using: $PIPE_PATH)"
            echo "  4. WSL bridge isn't forwarding correctly"
            ;;
    esac
else
    echo -e "${RED}✗ Cannot test SSH agent - socket does not exist${NC}"
fi

# Step 6: Check SSH configuration
echo -e "\n${BLUE}${BOLD}6. Checking SSH configuration...${NC}"
if [ -f "$HOME/.ssh/config" ]; then
    if grep -q "IdentityAgent.*$SOCKET_PATH" "$HOME/.ssh/config"; then
        echo -e "${GREEN}✓ SSH config has IdentityAgent configured correctly${NC}"
    else
        echo -e "${YELLOW}⚠ SSH config doesn't specify IdentityAgent${NC}"
        echo -e "${YELLOW}Consider adding to ~/.ssh/config:${NC}"
        echo "Host *"
        echo "    IdentityAgent $SOCKET_PATH"
    fi
else
    echo -e "${YELLOW}⚠ No SSH config file found${NC}"
    echo -e "${YELLOW}Consider creating ~/.ssh/config with:${NC}"
    echo "Host *"
    echo "    IdentityAgent $SOCKET_PATH"
fi

# Final assessment and next steps
echo -e "\n${BLUE}${BOLD}=== Summary ===${NC}"

if [ ! -S "$SOCKET_PATH" ]; then
    echo -e "${RED}✗ Main issue: Socket file does not exist${NC}"
    echo -e "${YELLOW}Start the 1Password SSH bridge:${NC}"
    echo "  ./scripts/setup-1password-ssh-complete.sh"
elif ! ssh-add -l &>/dev/null && [ "$(ssh-add -l 2>&1)" != "The agent has no identities." ]; then
    echo -e "${RED}✗ Main issue: Cannot connect to SSH agent${NC}"
    echo -e "${YELLOW}Check if 1Password is running and SSH agent is enabled${NC}"
elif [ "$(ssh-add -l 2>&1)" == "The agent has no identities." ]; then
    echo -e "${RED}✗ Main issue: SSH agent has no identities${NC}"
    echo -e "${YELLOW}Configure agent.toml (see Step 2) and enable SSH keys for agent use in 1Password (see Step 5).${NC}"
else
    echo -e "${GREEN}✓ 1Password SSH Agent integration is working correctly!${NC}"
    echo -e "${GREEN}  You can now use SSH commands normally${NC}"
    echo -e "${GREEN}  Deploy to remote hosts with: ./scripts/nixos-deploy-with-1password.sh${NC}"
fi

echo -e "\n${BLUE}For complete documentation:${NC}"
echo "  cat docs/1password-ssh-integration-complete.md"