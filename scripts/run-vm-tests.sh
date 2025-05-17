#!/usr/bin/env bash
set -euo pipefail

# Script to run individual VM tests using nix flake check
# This avoids running all tests at once, which can take too long

# Default timeout in seconds
DEFAULT_TIMEOUT=240

TIMEOUT=${1:-$DEFAULT_TIMEOUT}
TEST_NAME=${2:-}

# Get the absolute path to the project directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# If a specific test was provided, run only that test
if [ -n "$TEST_NAME" ]; then
  echo "Running VM test: $TEST_NAME"
  echo "Timeout: $TIMEOUT seconds"
  
  # Run the specific test using nix flake check
  SPECIFIC_CHECK="vm-test-run-$TEST_NAME"
  nix flake check --keep-going --option timeout $TIMEOUT --print-build-logs \
    --override-input self "$PROJECT_ROOT" \
    --no-update-lock-file \
    -A "checks.$(nix eval --impure --expr builtins.currentSystem --raw).$SPECIFIC_CHECK" \
    "$PROJECT_ROOT"
else
  # List available VM tests
  echo "Available VM tests:"
  echo
  find "$PROJECT_ROOT/tests" -name "*.nix" -type f | while read -r test_file; do
    test_name=$(basename "$test_file" .nix)
    echo " - $test_name"
  done
  
  echo
  echo "Usage: $0 [timeout_seconds] [test_name]"
  echo "Example: $0 600 nix-ws-core"
  echo "Default timeout: $DEFAULT_TIMEOUT seconds"
fi

# Success message if we get here
if [ -n "$TEST_NAME" ]; then
  echo
  echo "Test $TEST_NAME completed successfully!"
fi