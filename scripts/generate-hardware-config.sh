#!/usr/bin/env bash
# Utility script to generate hardware configuration for NixOS
# This helps bridge the gap between a flake-based approach and 
# the traditional nixos-generate-config workflow

set -euo pipefail

# Define colors for better readability
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Check if running as root (required for hardware scan)
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  echo "Please run with: sudo $0"
  exit 1
fi

# Destination directory
DEST_DIR="/etc/nixos"

# Check if target directory exists
if [[ ! -d "$DEST_DIR" ]]; then
  echo -e "${YELLOW}Creating $DEST_DIR directory...${NC}"
  mkdir -p "$DEST_DIR"
fi

# Warn about overwriting existing files
if [[ -f "$DEST_DIR/hardware-configuration.nix" ]]; then
  echo -e "${YELLOW}Warning: $DEST_DIR/hardware-configuration.nix already exists${NC}"
  read -p "Overwrite? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborting hardware configuration generation${NC}"
    exit 0
  fi
fi

echo -e "${BLUE}Scanning hardware and generating configuration...${NC}"

# Generate the hardware configuration
nixos-generate-config --dir "$DEST_DIR" --show-hardware-config > "$DEST_DIR/hardware-configuration.nix"

# Verify success
if [[ -f "$DEST_DIR/hardware-configuration.nix" ]]; then
  echo -e "${GREEN}Hardware configuration successfully generated at:${NC}"
  echo -e "  $DEST_DIR/hardware-configuration.nix"
  echo
  echo -e "${GREEN}Your flake will now use this hardware configuration when building for this machine.${NC}"
  echo -e "${YELLOW}Note: If you're building on a different machine for this target, you'll need to${NC}"
  echo -e "${YELLOW}copy this hardware-configuration.nix to that machine's $DEST_DIR.${NC}"
else
  echo -e "${RED}Failed to generate hardware configuration!${NC}"
  exit 1
fi

# Check disk UUIDs and hardware details
echo
echo -e "${BLUE}Detected filesystems:${NC}"
lsblk -f | grep -v loop

# Give instructions for next steps
echo 
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Review the generated hardware-configuration.nix if needed"
echo -e "2. Build and switch to your flake configuration with:"
echo -e "   ${GREEN}sudo nixos-rebuild switch --flake /path/to/your/flake#nix-ws${NC}"