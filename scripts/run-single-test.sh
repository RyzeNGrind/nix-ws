#!/usr/bin/env bash
set -euo pipefail

# Run a single NixOS VM test with configurable timeout
# Usage: ./scripts/run-single-test.sh [test_name] [timeout_seconds]
# Example: ./scripts/run-single-test.sh nix-ws-core 60

TEST_NAME=${1:?"Please provide a test name (core, network, gui, integration)"}
TIMEOUT=${2:-30}  # Default timeout: 30 seconds for most tests

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"

# Full test name
FULL_TEST_NAME="nix-ws-$TEST_NAME"
TEST_FILE="$PROJECT_ROOT/tests/$FULL_TEST_NAME.nix"

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo "ERROR: Test file not found: $TEST_FILE"
    echo "Available tests:"
    find "$PROJECT_ROOT/tests" -name "nix-ws-*.nix" -type f | sort | sed "s|$PROJECT_ROOT/tests/nix-ws-||" | sed "s|\.nix$||"
    exit 1
fi

echo "Running test: $FULL_TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo "Test file: $TEST_FILE"

# Build using flake syntax directly - using checks namespace
SYSTEM=$(nix eval --impure --expr builtins.currentSystem --raw)
echo "System architecture: $SYSTEM"

# Use nix build with flake reference - target the check directly
cd "$PROJECT_ROOT"
NIXPKGS_ALLOW_UNFREE=1 nix build \
  ".#checks.$SYSTEM.vm-test-run-$FULL_TEST_NAME" \
  --option timeout $TIMEOUT \
  --print-build-logs \
  --no-link \
  --show-trace

echo
echo "Test completed successfully!"