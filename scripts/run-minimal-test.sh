#!/usr/bin/env bash

# Minimal Test Runner
# Run only the minimal test with optimized settings
# Usage: ./scripts/run-minimal-test.sh [timeout_seconds]

set -euo pipefail

# Default timeout of 120 seconds if not specified
TIMEOUT=${1:-120}

# Project root directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

echo "Running minimal NixOS VM test with ${TIMEOUT}s timeout"
echo "This test uses a lightweight configuration for faster boot and basic verification"

# Run the minimal test directly - targeting the specific check 
NIXPKGS_ALLOW_UNFREE=1 nix build \
  ".#checks.$(nix eval --impure --expr builtins.currentSystem --raw).vm-test-run-nix-ws-minimal" \
  --option timeout "$TIMEOUT" \
  --print-build-logs \
  --keep-going \
  --no-link \
  --show-trace

echo "✅ Minimal test completed successfully!"