#!/usr/bin/env bash
# 1Password SSH Agent Diagnostic Tool
# Comprehensive test script to identify and troubleshoot 1Password SSH agent issues

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration - KEY POINT: Use the correct pipe path for 1Password 8+
SOCKET_PATH="$HOME/.1password/agent.sock"
PIPE_PATH="//./pipe/com.1password.1password.ssh"  # Official 1Password 8+ pipe name

echo -e "${BLUE}${BOLD}=== 1Password SSH Agent Diagnostic Test ===${NC}"

# Step 1: Check 1Password installation on Windows
echo -e "\n${BLUE}1. Checking 1Password installation on Windows...${NC}"
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

# Step 2: Check if socket file exists
echo -e "\n${BLUE}2. Checking if socket file exists...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    echo -e "${GREEN}✓ Socket file exists at $SOCKET_PATH${NC}"
else
    echo -e "${RED}✗ Socket file does not exist at $SOCKET_PATH${NC}"
    echo -e "${YELLOW}  Run: ./scripts/setup-1password-ssh-bridge.sh${NC}"
fi

# Step 3: Setting up test environment
echo -e "\n${BLUE}3. Setting up test environment...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    export SSH_AUTH_SOCK="$SOCKET_PATH"
    echo -e "${GREEN}✓ SSH_AUTH_SOCK is now set to $SSH_AUTH_SOCK${NC}"
else
    echo -e "${YELLOW}⚠ Skipping SSH_AUTH_SOCK setup (socket doesn't exist)${NC}"
    # Check if bridge script exists and try to run it
    if [ -x "./scripts/setup-1password-ssh-bridge.sh" ]; then
        echo -e "${BLUE}Attempting to start the bridge in background...${NC}"
        "./scripts/setup-1password-ssh-bridge.sh" &>/dev/null &
        BRIDGE_PID=$!
        sleep 3  # Give it a moment to start
        
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

# Step 4: Check SSH agent connectivity
echo -e "\n${BLUE}4. Testing SSH agent connectivity...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    SSH_ADD_OUTPUT=$(ssh-add -l 2>&1)
    SSH_ADD_STATUS=$?
    
    case $SSH_ADD_STATUS in
        0)  # Success, keys found
            echo -e "${GREEN}✓ Successfully connected to SSH agent${NC}"
            echo -e "${BLUE}Available SSH identities:${NC}"
            echo "$SSH_ADD_OUTPUT"
            ;;
        1)  # Success, no keys
            echo -e "${YELLOW}⚠ Connected to SSH agent, but no identities available${NC}"
            echo -e "${YELLOW}The agent is working but has no identities.${NC}"
            echo -e "${BLUE}Follow these steps in 1Password for Windows:${NC}"
            echo "  1. Open 1Password"
            echo "  2. Go to Settings > Developer"
            echo "  3. Make sure 'Use the SSH agent' is enabled"
            echo "  4. Add your SSH keys to 1Password and mark them for use with SSH agent:"
            echo "     - Open 1Password"
            echo "     - Select your SSH key item"
            echo "     - Click Edit"
            echo "     - Check 'Enable SSH Agent' checkbox"
            echo "     - Save changes"
            echo "  5. Restart 1Password"
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

# Step 5: Check SSH configuration
echo -e "\n${BLUE}5. Checking SSH configuration...${NC}"
if [ -f "$HOME/.ssh/config" ]; then
    if grep -q "IdentityAgent.*$SOCKET_PATH" "$HOME/.ssh/config"; then
        echo -e "${GREEN}✓ SSH config already has IdentityAgent configured${NC}"
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

# Step 6: Check WSL configuration
echo -e "\n${BLUE}6. Checking WSL integration...${NC}"

# Check if systemd service exists for auto-start
if [ -f "$HOME/.config/systemd/user/1password-ssh-agent-bridge.service" ]; then
    echo -e "${GREEN}✓ Systemd user service is configured${NC}"
    
    if systemctl --user is-active "1password-ssh-agent-bridge.service" &>/dev/null; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${YELLOW}⚠ Service is not running${NC}"
        echo -e "${YELLOW}  Run: systemctl --user start 1password-ssh-agent-bridge.service${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No systemd service found for automatic startup${NC}"
    echo -e "${YELLOW}  Consider creating a systemd user service${NC}"
fi

# Step 7: Try a connection test
echo -e "\n${BLUE}7. Connection test...${NC}"
if [ -S "$SOCKET_PATH" ]; then
    echo -e "${YELLOW}To test with a real server, you can run:${NC}"
    echo "  SSH_AUTH_SOCK=$SOCKET_PATH ssh -T git@github.com"
    echo
    echo -e "${YELLOW}Testing internal communication...${NC}"
    
    if ssh-add -l &>/dev/null; then
        echo -e "${GREEN}✓ SSH agent communication is working${NC}"
    elif [ "$(ssh-add -l 2>&1)" == "The agent has no identities." ]; then
        echo -e "${YELLOW}⚠ SSH agent is working but has no identities${NC}"
    else
        echo -e "${RED}✗ SSH agent communication failed${NC}"
    fi
fi

# Final assessment and next steps
echo -e "\n${BLUE}${BOLD}=== Summary ===${NC}"

if [ ! -S "$SOCKET_PATH" ]; then
    echo -e "${RED}✗ Main issue: Socket file does not exist${NC}"
    echo -e "${YELLOW}Start the 1Password SSH bridge:${NC}"
    echo "  ./scripts/setup-1password-ssh-bridge.sh"
elif ! ssh-add -l &>/dev/null && [ "$(ssh-add -l 2>&1)" != "The agent has no identities." ]; then
    echo -e "${RED}✗ Main issue: Cannot connect to SSH agent${NC}"
    echo -e "${YELLOW}Check if 1Password is running and SSH agent is enabled${NC}"
elif [ "$(ssh-add -l 2>&1)" == "The agent has no identities." ]; then
    echo -e "${YELLOW}⚠ Main issue: SSH agent has no identities${NC}"
    echo -e "${YELLOW}Ensure keys are enabled for SSH agent in 1Password settings${NC}"
else
    echo -e "${GREEN}✓ 1Password SSH Agent integration appears to be working correctly!${NC}"
    echo -e "${GREEN}  You can now use SSH commands normally${NC}"
fi

echo -e "\n${BLUE}For complete documentation:${NC}"
echo "  cat docs/1password-ssh-integration.md"
echo "  cat modules/1password-ssh-agent.nix"