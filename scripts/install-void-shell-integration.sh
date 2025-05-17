#!/usr/bin/env bash
set -euo pipefail

# Void Editor Shell Integration Installation Script
# This script sets up shell integration for Void Editor in various shells

SHELL_INTEGRATION_PATH="$HOME/.config/void-editor/shell-integration"
VOID_EDITOR_PATH="$1"

if [ -z "$VOID_EDITOR_PATH" ]; then
  echo "Error: Please provide the path to your Void Editor installation."
  echo "Usage: $0 /path/to/void-editor"
  exit 1
fi

# Ensure the source path exists
SOURCE_PATH="${VOID_EDITOR_PATH}/lib/void-editor/resources/app/shell-integration"
if [ ! -d "$SOURCE_PATH" ]; then
  echo "Error: Shell integration scripts not found at $SOURCE_PATH"
  echo "Make sure you've provided the correct path to your Void Editor installation."
  exit 1
fi

# Create the destination directory
mkdir -p "$SHELL_INTEGRATION_PATH"

# Copy all shell integration scripts
echo "Copying shell integration scripts..."
cp -v "$SOURCE_PATH"/* "$SHELL_INTEGRATION_PATH"/

# Make all scripts executable
chmod +x "$SHELL_INTEGRATION_PATH"/*

# Setup for Bash
setup_bash() {
  local BASH_RC="$HOME/.bashrc"
  
  if [ ! -f "$BASH_RC" ]; then
    touch "$BASH_RC"
  fi
  
  # Check if the integration is already set up
  if grep -q "Void Editor Shell Integration" "$BASH_RC"; then
    echo "Bash shell integration is already set up."
  else
    echo -e "\n# Void Editor Shell Integration" >> "$BASH_RC"
    echo "if [ -f \"$SHELL_INTEGRATION_PATH/shellIntegration-bash.sh\" ]; then" >> "$BASH_RC"
    echo "  source \"$SHELL_INTEGRATION_PATH/shellIntegration-bash.sh\"" >> "$BASH_RC"
    echo "fi" >> "$BASH_RC"
    echo "Bash shell integration set up successfully."
  fi
}

# Setup for Zsh
setup_zsh() {
  local ZSH_RC="$HOME/.zshrc"
  
  if [ ! -f "$ZSH_RC" ]; then
    touch "$ZSH_RC"
  fi
  
  # Check if the integration is already set up
  if grep -q "Void Editor Shell Integration" "$ZSH_RC"; then
    echo "Zsh shell integration is already set up."
  else
    echo -e "\n# Void Editor Shell Integration" >> "$ZSH_RC"
    echo "if [[ -f \"$SHELL_INTEGRATION_PATH/shellIntegration-rc.zsh\" ]]; then" >> "$ZSH_RC"
    echo "  source \"$SHELL_INTEGRATION_PATH/shellIntegration-rc.zsh\"" >> "$ZSH_RC"
    echo "fi" >> "$ZSH_RC"
    echo "Zsh shell integration set up successfully."
  fi
}

# Setup for Fish
setup_fish() {
  local FISH_CONFIG_DIR="$HOME/.config/fish"
  local FISH_CONFIG="$FISH_CONFIG_DIR/config.fish"
  
  if [ ! -d "$FISH_CONFIG_DIR" ]; then
    mkdir -p "$FISH_CONFIG_DIR"
  fi
  
  if [ ! -f "$FISH_CONFIG" ]; then
    touch "$FISH_CONFIG"
  fi
  
  # Check if the integration is already set up
  if grep -q "Void Editor Shell Integration" "$FISH_CONFIG"; then
    echo "Fish shell integration is already set up."
  else
    echo -e "\n# Void Editor Shell Integration" >> "$FISH_CONFIG"
    echo "if test -f \"$SHELL_INTEGRATION_PATH/shellIntegration.fish\"" >> "$FISH_CONFIG"
    echo "  source \"$SHELL_INTEGRATION_PATH/shellIntegration.fish\"" >> "$FISH_CONFIG"
    echo "end" >> "$FISH_CONFIG"
    echo "Fish shell integration set up successfully."
  fi
}

# Detect and set up shell integrations
echo "Setting up shell integrations..."

# Check for bash
if command -v bash &> /dev/null; then
  setup_bash
fi

# Check for zsh
if command -v zsh &> /dev/null; then
  setup_zsh
fi

# Check for fish
if command -v fish &> /dev/null; then
  setup_fish
fi

echo -e "\nVoid Editor shell integration setup complete!"
echo "Please restart your terminal or source your shell configuration file to activate the integration."