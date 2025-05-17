#!/usr/bin/env bash
set -euo pipefail

# Helper script to run individual VM tests
# Usage: ./scripts/run-vm-test.sh [test-name]
# Example: ./scripts/run-vm-test.sh nix-ws-core

# Default timeout in seconds (4 minutes)
TIMEOUT=${TIMEOUT:-240}

# Default test to run if none specified
TEST_NAME=${1:-nix-ws-core}

echo "Running test: $TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo 

# Build and run the VM test
nix-build ./tests/$TEST_NAME.nix --timeout $TIMEOUT

echo 
echo "Test $TEST_NAME completed successfully!"