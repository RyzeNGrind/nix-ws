#!/usr/bin/env bash
# Wrapper script for systemd service to run the 1Password SSH agent bridge
# This script ensures the proper environment is available

# Source the user's profile to get the right PATH
source /etc/profile
if [ -f "$HOME/.profile" ]; then
  source "$HOME/.profile"
fi

# Run the bridge script with explicit socat path
SOCAT_PATH="/etc/profiles/per-user/ryzengrind/bin/socat"
BRIDGE_SCRIPT="$HOME/nix-cfg/scripts/setup-1password-ssh-bridge.sh"

exec "$BRIDGE_SCRIPT"