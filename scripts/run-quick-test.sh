#!/usr/bin/env bash
set -euo pipefail

# Run a specific VM test directly without using flake checks
# Usage: ./scripts/run-quick-test.sh [test-module] [timeout-seconds]

TEST_NAME=${1:-"nix-ws-min"}  # Default test is nix-ws-min
TIMEOUT=${2:-60}  # Default timeout is 60 seconds

echo "Running test: $TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo "----------------------------------------"

# Make sure the test module exists
TEST_MODULE="$PWD/scripts/test-$TEST_NAME.nix"
if [ ! -f "$TEST_MODULE" ]; then
  echo "ERROR: Test module not found: $TEST_MODULE"
  echo "Available test modules:"
  find "$PWD/scripts" -name "test-*.nix" | sort | sed 's|.*/test-||' | sed 's|\.nix$||'
  exit 1
fi

# Run the test
cd "$(dirname "$0")/.."  # Move to repo root
echo "Building test..."
NIXPKGS_ALLOW_UNFREE=1 nix-build "$TEST_MODULE" --option timeout "$TIMEOUT" --show-trace

echo
echo "Test completed successfully!"