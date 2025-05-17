#!/usr/bin/env bash

# Direct Test Runner - No VM Boot
# Performs a direct build test of NixOS configurations without booting VMs
# Usage: ./scripts/direct-test-runner.sh [system_name]

set -euo pipefail

# Default test target
SYSTEM_NAME=${1:-"nix-ws"}

# Project root directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

echo "Running direct build test for system: $SYSTEM_NAME"
echo "This test verifies configuration validity without VM boot"

# Test the configuration directly using nixos-rebuild
NIXPKGS_ALLOW_UNFREE=1 nix build \
  ".#nixosConfigurations.${SYSTEM_NAME}.config.system.build.toplevel" \
  --print-build-logs \
  --keep-going \
  --no-link \
  --show-trace

echo "✅ Direct build test for $SYSTEM_NAME completed successfully!"