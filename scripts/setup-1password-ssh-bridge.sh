#!/usr/bin/env bash
# 1Password SSH Agent Bridge for NixOS on WSL
# This script creates a bridge between Windows 1Password SSH agent and NixOS

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration - KEY CHANGE: Use the correct pipe path for 1Password 8+
PIPE_PATH="//./pipe/com.1password.1password.ssh"
SOCKET_DIR="$HOME/.1password"
SOCKET_PATH="$SOCKET_DIR/agent.sock"
NPIPERELAY_DIR="$HOME/bin"
NPIPERELAY_PATH="$NPIPERELAY_DIR/npiperelay.exe"

echo -e "${BLUE}${BOLD}=== 1Password SSH Agent Bridge ===${NC}"

# Create directories
mkdir -p "$NPIPERELAY_DIR" "$SOCKET_DIR"

# Install npiperelay if needed
if [ ! -f "$NPIPERELAY_PATH" ]; then
    echo -e "${BLUE}Installing npiperelay...${NC}"
    
    TEMP_DIR=$(mktemp -d)
    curl -L -o "$TEMP_DIR/npiperelay.zip" "https://github.com/jstarks/npiperelay/releases/latest/download/npiperelay_windows_amd64.zip"
    
    if ! command -v unzip &> /dev/null; then
        echo -e "${YELLOW}Installing unzip...${NC}"
        nix-env -iA nixos.unzip
    fi
    
    mkdir -p /tmp/npiperelay
    unzip -o "$TEMP_DIR/npiperelay.zip" npiperelay.exe -d /tmp/npiperelay
    mv /tmp/npiperelay/npiperelay.exe "$NPIPERELAY_PATH"
    chmod +x "$NPIPERELAY_PATH"
    
    rm -rf /tmp/npiperelay "$TEMP_DIR"
    echo -e "${GREEN}✓ Installed npiperelay.exe to $NPIPERELAY_PATH${NC}"
fi

# Remove existing socket
if [ -S "$SOCKET_PATH" ]; then
    echo -e "${BLUE}Removing existing socket...${NC}"
    rm -f "$SOCKET_PATH"
fi

# Ensure proper socket directory permissions (important for SSH)
chmod 700 "$SOCKET_DIR"

# Find socat
SOCAT_PATH=$(command -v socat || echo "/run/current-system/sw/bin/socat")
if [ ! -x "$SOCAT_PATH" ]; then
    SOCAT_PATH="$HOME/.nix-profile/bin/socat"
fi

if [ ! -x "$SOCAT_PATH" ]; then
    echo -e "${YELLOW}Installing socat...${NC}"
    nix-env -iA nixos.socat
    SOCAT_PATH=$(command -v socat)
fi

echo -e "${BLUE}Starting bridge between:${NC}"
echo -e "${BLUE}Windows pipe:${NC} $PIPE_PATH"
echo -e "${BLUE}Unix socket:${NC} $SOCKET_PATH"
echo

# Clear environment variable if already set to another value
if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$SOCKET_PATH" ]; then
    echo -e "${YELLOW}Note: SSH_AUTH_SOCK was previously set to $SSH_AUTH_SOCK${NC}"
    echo -e "${YELLOW}Updating to point to the 1Password socket${NC}"
fi

export SSH_AUTH_SOCK="$SOCKET_PATH"
echo -e "${GREEN}✓ SSH_AUTH_SOCK set to $SSH_AUTH_SOCK${NC}"

# Print a reminder for the common issue of "no identities"
echo -e "${YELLOW}If you see 'The agent has no identities' error:${NC}"
echo -e "${YELLOW}1. Open 1Password on Windows${NC}"
echo -e "${YELLOW}2. Go to Settings > Developer${NC}"
echo -e "${YELLOW}3. Make sure 'Use the SSH agent' is enabled${NC}"
echo -e "${YELLOW}4. Ensure your keys are configured for SSH agent${NC}"
echo

# Start the relay (foreground) - this will keep running
echo -e "${GREEN}Starting relay...${NC}"
echo -e "${BLUE}Press Ctrl+C to stop${NC}"
echo
exec "$SOCAT_PATH" "UNIX-LISTEN:$SOCKET_PATH,fork" "EXEC:$NPIPERELAY_PATH -ei -ep $PIPE_PATH,nofork"