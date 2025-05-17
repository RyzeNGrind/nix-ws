#!/usr/bin/env bash
# Setup 1Password SSH Agent Bridge Script for NixOS WSL
# This script creates a bridge between the Windows 1Password SSH agent socket
# and a Unix socket in WSL using npiperelay and socat.

set -eo pipefail

# Configuration
NPIPERELAY_DIR="$HOME/bin"
NPIPERELAY_PATH="$NPIPERELAY_DIR/npiperelay.exe"
PIPE_PATH="//./pipe/openssh-ssh-agent"
SOCKET_DIR="$HOME/.1password"
SOCKET_PATH="$SOCKET_DIR/agent.sock"

# Create directories if they don't exist
mkdir -p "$NPIPERELAY_DIR" "$SOCKET_DIR"

# If npiperelay doesn't exist, download it
if [ ! -f "$NPIPERELAY_PATH" ]; then
    echo "Downloading npiperelay..."
    curl -L -o "$NPIPERELAY_DIR/npiperelay.zip" https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip
    mkdir -p /tmp/npiperelay
    cd /tmp/npiperelay
    unzip "$NPIPERELAY_DIR/npiperelay.zip"
    mv npiperelay.exe "$NPIPERELAY_PATH"
    cd - >/dev/null
    rm -rf /tmp/npiperelay "$NPIPERELAY_DIR/npiperelay.zip"
    chmod +x "$NPIPERELAY_PATH"
fi

# Kill any existing socat processes for this socket
if [ -S "$SOCKET_PATH" ]; then
    echo "Removing existing socket..."
    rm -f "$SOCKET_PATH"
fi

# Start the bridge
echo "Starting 1Password SSH agent bridge..."
SOCAT_PATH="/etc/profiles/per-user/ryzengrind/bin/socat"
exec "$SOCAT_PATH" "UNIX-LISTEN:$SOCKET_PATH,fork" "EXEC:$NPIPERELAY_PATH -ei -ep $PIPE_PATH,nofork"