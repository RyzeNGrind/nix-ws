#!/usr/bin/env bash
# Comprehensive 1Password SSH Agent Setup for NixOS on WSL
# This script sets up the complete integration between 1Password SSH agent on Windows
# and NixOS running in WSL, including agent.toml configuration guidance

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration - CORRECT pipe path for 1Password 8+
PIPE_PATH="//./pipe/com.1password.1password.ssh"
SOCKET_DIR="$HOME/.1password"
SOCKET_PATH="$SOCKET_DIR/agent.sock"
NPIPERELAY_DIR="$HOME/bin"
NPIPERELAY_PATH="$NPIPERELAY_DIR/npiperelay.exe"
AGENT_TOML_EXAMPLE="$HOME/.1password/agent.toml.example"
# Corrected agent.toml path based on user feedback
WINDOWS_AGENT_TOML_PATH_PRIMARY="/mnt/c/Users/RyzeNGrind/AppData/Local/1Password/config/ssh/agent.toml"
WINDOWS_AGENT_TOML_PATH_FALLBACK="/mnt/c/Users/RyzeNGrind/AppData/Local/1Password/app/8/op-ssh-sign/agent.toml"


echo -e "${BLUE}${BOLD}=== Comprehensive 1Password SSH Agent Setup ===${NC}"

# Step 1: Create directories
echo -e "\n${BLUE}${BOLD}Step 1: Creating directories...${NC}"
mkdir -p "$NPIPERELAY_DIR" "$SOCKET_DIR"
chmod 700 "$SOCKET_DIR"  # Important for security

# Step 2: Install dependencies
echo -e "\n${BLUE}${BOLD}Step 2: Checking dependencies...${NC}"

# Check for socat
if ! command -v socat &> /dev/null; then
    echo -e "${YELLOW}⚠ socat is required but not found. Installing...${NC}"
    nix-env -iA nixos.socat
else
    echo -e "${GREEN}✓ socat is installed${NC}"
fi

# Check for curl
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}⚠ curl is required but not found. Installing...${NC}"
    nix-env -iA nixos.curl
else
    echo -e "${GREEN}✓ curl is installed${NC}"
fi

# Check for unzip
if ! command -v unzip &> /dev/null; then
    echo -e "${YELLOW}⚠ unzip is required but not found. Installing...${NC}"
    nix-env -iA nixos.unzip
else
    echo -e "${GREEN}✓ unzip is installed${NC}"
fi

# Step 3: Install npiperelay
echo -e "\n${BLUE}${BOLD}Step 3: Installing npiperelay...${NC}"
if [ -f "$NPIPERELAY_PATH" ]; then
    echo -e "${GREEN}✓ npiperelay.exe already installed${NC}"
else
    echo -e "${BLUE}Downloading npiperelay.exe...${NC}"
    
    TEMP_DIR=$(mktemp -d)
    curl -L -o "$TEMP_DIR/npiperelay.zip" "https://github.com/jstarks/npiperelay/releases/latest/download/npiperelay_windows_amd64.zip"
    
    echo -e "${BLUE}Extracting npiperelay.exe...${NC}"
    unzip -o "$TEMP_DIR/npiperelay.zip" npiperelay.exe -d "$TEMP_DIR"
    mv "$TEMP_DIR/npiperelay.exe" "$NPIPERELAY_PATH"
    chmod +x "$NPIPERELAY_PATH"
    
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}✓ npiperelay.exe installed to $NPIPERELAY_PATH${NC}"
fi

# Step 4: Check 1Password installation
echo -e "\n${BLUE}${BOLD}Step 4: Checking 1Password installation on Windows...${NC}"
OP_FOUND=false

if [ -e "/mnt/c/Program Files/1Password/app/8/1Password.exe" ]; then
    echo -e "${GREEN}✓ 1Password found in Program Files${NC}"
    OP_FOUND=true
elif find /mnt/c/Users/*/AppData/Local/1Password/app/8/1Password.exe -type f 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ 1Password found in AppData${NC}"
    OP_FOUND=true
fi

if [ "$OP_FOUND" = false ]; then
    echo -e "${YELLOW}⚠ Could not detect 1Password installation${NC}"
    echo -e "${YELLOW}  Please ensure 1Password is installed on Windows${NC}"
else
    echo -e "${GREEN}✓ 1Password appears to be installed correctly${NC}"
fi

# Step 5: Create agent.toml example
echo -e "\n${BLUE}${BOLD}Step 5: Creating agent.toml example...${NC}"

cat > "$AGENT_TOML_EXAMPLE" << 'EOF'
# This is the 1Password SSH agent config file, which allows you to customize the
# behavior of the SSH agent running on this machine.
#
# You can use it to:
# * Enable keys from other vaults than the Private vault
# * Control the order in which keys are offered to SSH servers

# IMPORTANT: This file should be placed in one of these locations:
# Windows (Primary - User Confirmed): C:\Users\YourUser\AppData\Local\1Password\config\ssh\agent.toml
# Windows (Fallback/Older): %LOCALAPPDATA%\1Password\app\8\op-ssh-sign\agent.toml
# macOS: ~/Library/Group Containers/2BUA8C4S2C.com.1password/op-ssh-sign/agent.toml
# Linux: ~/.config/1Password/op-ssh-sign/agent.toml

# Example configuration:

# Enable a specific key from a specific vault and account
[[ssh-keys]]
item = "my-github-key"
vault = "Development"
account = "My Account Name"

# Enable all keys from the k8s-lab vault
[[ssh-keys]]
vault = "k8s-lab"

# Then enable all keys from the Private vault
[[ssh-keys]]
vault = "Private"

# For testing, run:
# SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
EOF

echo -e "${GREEN}✓ Created agent.toml example at $AGENT_TOML_EXAMPLE${NC}"

# Step 6: Check existing agent.toml on Windows
echo -e "\n${BLUE}${BOLD}Step 6: Checking for existing agent.toml on Windows...${NC}"

ACTUAL_AGENT_TOML_PATH=""
if [ -f "$WINDOWS_AGENT_TOML_PATH_PRIMARY" ]; then
    ACTUAL_AGENT_TOML_PATH="$WINDOWS_AGENT_TOML_PATH_PRIMARY"
    echo -e "${GREEN}✓ agent.toml found at primary path: $ACTUAL_AGENT_TOML_PATH${NC}"
elif [ -f "$WINDOWS_AGENT_TOML_PATH_FALLBACK" ]; then
    ACTUAL_AGENT_TOML_PATH="$WINDOWS_AGENT_TOML_PATH_FALLBACK"
    echo -e "${GREEN}✓ agent.toml found at fallback path: $ACTUAL_AGENT_TOML_PATH${NC}"
else
    echo -e "${YELLOW}⚠ agent.toml not found at expected locations:${NC}"
    echo -e "${YELLOW}  Primary: $WINDOWS_AGENT_TOML_PATH_PRIMARY${NC}"
    echo -e "${YELLOW}  Fallback: $WINDOWS_AGENT_TOML_PATH_FALLBACK${NC}"
    echo -e "${YELLOW}You need to create this file to configure which SSH keys to use with the agent.${NC}"
    echo -e "${YELLOW}Use the example at $AGENT_TOML_EXAMPLE as a starting point.${NC}"
    
    # Check for SSH agent directory
    AGENT_DIR_PRIMARY=$(dirname "$WINDOWS_AGENT_TOML_PATH_PRIMARY")
    if [ ! -d "$AGENT_DIR_PRIMARY" ]; then
        echo -e "${YELLOW}The directory $AGENT_DIR_PRIMARY might not exist. You may need to create it first.${NC}"
    fi
fi

if [ -n "$ACTUAL_AGENT_TOML_PATH" ]; then
    KEY_COUNT=$(grep -c '\[\[ssh-keys\]\]' "$ACTUAL_AGENT_TOML_PATH" || echo "0")
    echo -e "${BLUE}  $KEY_COUNT SSH key configuration entries found in $ACTUAL_AGENT_TOML_PATH${NC}"
fi


echo -e "\n${BLUE}${BOLD}IMPORTANT: Configuring agent.toml${BOLD}${NC}"
echo -e "${YELLOW}The agent.toml file is crucial for the 'no identities' issue.${NC}"
echo -e "${YELLOW}It specifies which SSH keys should be available via the SSH agent.${NC}"
echo -e "${YELLOW}Without this file properly configured, the SSH agent will report 'no identities'.${NC}"
echo -e "${YELLOW}Ensure it's at: $WINDOWS_AGENT_TOML_PATH_PRIMARY (or fallback path).${NC}"
echo -e "${YELLOW}After updating agent.toml, restart 1Password on Windows.${NC}"

# Step 7: Set up environment
echo -e "\n${BLUE}${BOLD}Step 7: Setting up environment...${NC}"

# Create SSH config directory
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Check if SSH config exists and has IdentityAgent config
if [ -f "$HOME/.ssh/config" ]; then
    if grep -q "IdentityAgent.*$SOCKET_PATH" "$HOME/.ssh/config"; then
        echo -e "${GREEN}✓ SSH config already has IdentityAgent configured${NC}"
    else
        echo -e "${YELLOW}⚠ Adding IdentityAgent to SSH config${NC}"
        cat >> "$HOME/.ssh/config" << EOF

# 1Password SSH Agent Configuration
Host *
    IdentityAgent $SOCKET_PATH
EOF
        echo -e "${GREEN}✓ Updated SSH config${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Creating SSH config with IdentityAgent${NC}"
    cat > "$HOME/.ssh/config" << EOF
# 1Password SSH Agent Configuration
Host *
    IdentityAgent $SOCKET_PATH
EOF
    chmod 600 "$HOME/.ssh/config"
    echo -e "${GREEN}✓ Created SSH config${NC}"
fi

# Step 8: Start the bridge
echo -e "\n${BLUE}${BOLD}Step 8: Starting 1Password SSH agent bridge...${NC}"

# Remove existing socket if present
if [ -S "$SOCKET_PATH" ]; then
    echo -e "${BLUE}Removing existing socket...${NC}"
    rm -f "$SOCKET_PATH"
fi

# Export SSH_AUTH_SOCK
export SSH_AUTH_SOCK="$SOCKET_PATH"
echo -e "${GREEN}✓ SSH_AUTH_SOCK set to $SSH_AUTH_SOCK${NC}"

# Set up bridge in background
echo -e "\n${BLUE}Starting bridge between:${NC}"
echo -e "${BLUE}Windows pipe: $PIPE_PATH${NC}"
echo -e "${BLUE}Unix socket:  $SOCKET_PATH${NC}"
echo

# Check for existing socat process
EXISTING_SOCAT=$(pgrep -f "socat.*$SOCKET_PATH" || echo "")
if [ -n "$EXISTING_SOCAT" ]; then
    echo -e "${YELLOW}⚠ Existing socat process found (PID: $EXISTING_SOCAT)${NC}"
    echo -e "${YELLOW}  Killing existing process...${NC}"
    kill $EXISTING_SOCAT
    sleep 1
fi

echo -e "${GREEN}▶ Starting 1Password SSH bridge...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"

# Start the relay (foreground)
exec socat "UNIX-LISTEN:$SOCKET_PATH,fork" "EXEC:$NPIPERELAY_PATH -ei -ep $PIPE_PATH,nofork"