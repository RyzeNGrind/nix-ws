#!/usr/bin/env bash
# Quick installer for 1Password SSH Agent integration
# This script sets up the 1Password SSH agent bridge for NixOS on WSL
# without requiring Home Manager

set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 1Password SSH Agent Integration Quick Installer ===${NC}"
echo -e "This script will set up the 1Password SSH agent integration for NixOS on WSL"

# Configuration
SOCKET_PATH="$HOME/.1password/agent.sock"
PIPE_PATH="//./pipe/openssh-ssh-agent"
BIN_DIR="$HOME/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
PROFILE_DIR="$HOME/.profile.d"

# Check for required dependencies
echo -e "\n${BLUE}Checking dependencies...${NC}"
if ! command -v socat &> /dev/null; then
  echo -e "${YELLOW}socat is required but not found. Installing via nix-env...${NC}"
  nix-env -iA nixos.socat
fi

if ! command -v curl &> /dev/null; then
  echo -e "${YELLOW}curl is required but not found. Installing via nix-env...${NC}"
  nix-env -iA nixos.curl
fi

if ! command -v unzip &> /dev/null; then
  echo -e "${YELLOW}unzip is required but not found. Installing via nix-env...${NC}"
  nix-env -iA nixos.unzip
fi

# Create directories
echo -e "\n${BLUE}Creating directories...${NC}"
mkdir -p "$BIN_DIR" "$SYSTEMD_DIR" "$PROFILE_DIR" "$(dirname "$SOCKET_PATH")"

# Create bridge script
echo -e "\n${BLUE}Creating bridge script...${NC}"
cat > "$BIN_DIR/setup-1password-ssh-bridge.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Configuration
SOCKET_PATH="$HOME/.1password/agent.sock"
PIPE_PATH="//./pipe/openssh-ssh-agent"
SOCKET_DIR="$(dirname "$SOCKET_PATH")"
NPIPERELAY_PATH="$HOME/bin/npiperelay.exe"
SOCAT_PATH="$(command -v socat)"

# Ensure socket directory exists
mkdir -p "$SOCKET_DIR"

# Remove existing socket if present
if [ -e "$SOCKET_PATH" ]; then
  rm -f "$SOCKET_PATH"
fi

# Check if npiperelay.exe exists, if not download it
if [ ! -f "$NPIPERELAY_PATH" ] || [ ! -x "$NPIPERELAY_PATH" ]; then
  echo "Downloading npiperelay.exe..."
  mkdir -p "$(dirname "$NPIPERELAY_PATH")"
  
  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  
  # Download npiperelay zip file
  curl -L -o "$TEMP_DIR/npiperelay.zip" "https://github.com/jstarks/npiperelay/releases/latest/download/npiperelay_windows_amd64.zip"
  
  # Extract the executable
  unzip -o "$TEMP_DIR/npiperelay.zip" npiperelay.exe -d "$TEMP_DIR"
  
  # Move to final location
  mv "$TEMP_DIR/npiperelay.exe" "$NPIPERELAY_PATH"
  
  # Cleanup
  rm -rf "$TEMP_DIR"
  
  echo "npiperelay.exe installed to $NPIPERELAY_PATH"
fi

# Check if the pipe exists on the Windows side
if ! ls -la /mnt/c/Windows/System32/OpenSSH/ssh-agent.exe >/dev/null 2>&1; then
  echo "Warning: OpenSSH agent may not be installed on Windows."
  echo "Please ensure OpenSSH Client is installed via Windows Settings > Apps > Optional features."
fi

echo "Starting 1Password SSH agent bridge..."
echo "Connecting to Windows pipe: $PIPE_PATH"
echo "Creating Unix socket: $SOCKET_PATH"

# Start the relay
exec "$SOCAT_PATH" "UNIX-LISTEN:$SOCKET_PATH,fork" "EXEC:$NPIPERELAY_PATH -ei -ep $PIPE_PATH,nofork"
EOF
chmod +x "$BIN_DIR/setup-1password-ssh-bridge.sh"
echo -e "${GREEN}✓ Created bridge script at $BIN_DIR/setup-1password-ssh-bridge.sh${NC}"

# Create test script
echo -e "\n${BLUE}Creating test script...${NC}"
cat > "$BIN_DIR/test-1password-ssh.sh" << 'EOF'
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
EOF
chmod +x "$BIN_DIR/test-1password-ssh.sh"
echo -e "${GREEN}✓ Created test script at $BIN_DIR/test-1password-ssh.sh${NC}"

# Create shell profile script
echo -e "\n${BLUE}Creating shell profile script...${NC}"
cat > "$PROFILE_DIR/1password-ssh.sh" << 'EOF'
#!/usr/bin/env bash
# 1Password SSH Agent environment setup

# Define the socket path
ONEPASSWORD_SOCKET="$HOME/.1password/agent.sock"

# Check if the socket exists and set SSH_AUTH_SOCK
if [[ -S "$ONEPASSWORD_SOCKET" ]]; then
  export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET"
fi
EOF
chmod +x "$PROFILE_DIR/1password-ssh.sh"
echo -e "${GREEN}✓ Created shell profile script at $PROFILE_DIR/1password-ssh.sh${NC}"

# Update shell profile to source the 1password script
if [ -f "$HOME/.bashrc" ]; then
  if ! grep -q "$PROFILE_DIR/1password-ssh.sh" "$HOME/.bashrc"; then
    echo -e "\n${BLUE}Adding profile script to .bashrc...${NC}"
    echo "" >> "$HOME/.bashrc"
    echo "# 1Password SSH Agent" >> "$HOME/.bashrc"
    echo "if [ -f \"$PROFILE_DIR/1password-ssh.sh\" ]; then" >> "$HOME/.bashrc"
    echo "  source \"$PROFILE_DIR/1password-ssh.sh\"" >> "$HOME/.bashrc"
    echo "fi" >> "$HOME/.bashrc"
    echo -e "${GREEN}✓ Updated .bashrc${NC}"
  else
    echo -e "${GREEN}✓ .bashrc already configured${NC}"
  fi
fi

if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q "$PROFILE_DIR/1password-ssh.sh" "$HOME/.zshrc"; then
    echo -e "\n${BLUE}Adding profile script to .zshrc...${NC}"
    echo "" >> "$HOME/.zshrc"
    echo "# 1Password SSH Agent" >> "$HOME/.zshrc"
    echo "if [ -f \"$PROFILE_DIR/1password-ssh.sh\" ]; then" >> "$HOME/.zshrc"
    echo "  source \"$PROFILE_DIR/1password-ssh.sh\"" >> "$HOME/.zshrc"
    echo "fi" >> "$HOME/.zshrc"
    echo -e "${GREEN}✓ Updated .zshrc${NC}"
  else
    echo -e "${GREEN}✓ .zshrc already configured${NC}"
  fi
fi

# Create systemd user service
echo -e "\n${BLUE}Creating systemd user service...${NC}"
cat > "$SYSTEMD_DIR/1password-ssh-agent-bridge.service" << EOF
[Unit]
Description=1Password SSH Agent Bridge for WSL
Documentation=https://nixos.wiki/wiki/1Password

[Service]
ExecStart=$BIN_DIR/setup-1password-ssh-bridge.sh
Restart=always
RestartSec=3
Environment=PATH=\$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin

[Install]
WantedBy=default.target
EOF
echo -e "${GREEN}✓ Created systemd user service at $SYSTEMD_DIR/1password-ssh-agent-bridge.service${NC}"

# Enable and start the service
echo -e "\n${BLUE}Enabling and starting the service...${NC}"
systemctl --user daemon-reload
systemctl --user enable 1password-ssh-agent-bridge.service
systemctl --user restart 1password-ssh-agent-bridge.service
sleep 2
echo -e "${GREEN}✓ Service enabled and started${NC}"

# Display status
echo -e "\n${BLUE}Service status:${NC}"
systemctl --user status 1password-ssh-agent-bridge.service --no-pager

# Final instructions
echo -e "\n${BLUE}=== Setup Complete ===${NC}"
echo -e "${YELLOW}Final steps:${NC}"
echo "1. Configure 1Password on Windows:"
echo "   - Open 1Password"
echo "   - Go to Settings > Developer"
echo "   - Enable 'Use the SSH agent'"
echo "   - Add your SSH keys to 1Password and mark them for SSH agent use"
echo ""
echo "2. Restart your terminals or source your shell profile:"
echo "   source ~/.bashrc  # or ~/.zshrc if using zsh"
echo ""
echo "3. Test the integration:"
echo "   ~/bin/test-1password-ssh.sh"
echo ""
echo -e "${GREEN}Enjoy using 1Password SSH agent integration with NixOS on WSL!${NC}"