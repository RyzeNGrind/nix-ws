#!/usr/bin/env bash
# 1Password SSH Agent environment setup
# Source this file from your .bashrc, .zshrc or other shell profile

# Define the socket path
ONEPASSWORD_SOCKET="$HOME/.1password/agent.sock"

# Check if the socket exists and set SSH_AUTH_SOCK
if [[ -S "$ONEPASSWORD_SOCKET" ]]; then
  export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET"
  echo "1Password SSH agent socket found at $SSH_AUTH_SOCK"
else
  echo "1Password SSH agent socket not found at $ONEPASSWORD_SOCKET"
  echo "Make sure the 1password-ssh-agent-bridge service is running:"
  echo "  systemctl --user status 1password-ssh-agent-bridge"
fi

# Test SSH agent connection (optional - comment out if not wanted)
ssh-add -l &>/dev/null
status=$?
if [ $status -eq 0 ]; then
  echo "✓ Connected to 1Password SSH agent (keys available)"
elif [ $status -eq 1 ]; then
  echo "! Connected to 1Password SSH agent (no keys available)"
  echo "  Add SSH keys to 1Password and mark them for use with SSH agent"
else
  echo "✗ Cannot connect to 1Password SSH agent"
  echo "  Check if 1Password is running on Windows"
fi