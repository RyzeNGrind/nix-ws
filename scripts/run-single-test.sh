#!/usr/bin/env bash
set -euo pipefail

# Script to run a single NixOS VM test without using flake checks
# This approach avoids the long build times of running all tests at once

# Get the test name from the first argument, or use a default
TEST_NAME=${1:-nix-ws-core}

# Set timeout (default to 5 minutes)
TIMEOUT=${TIMEOUT:-300}

echo "Running test: $TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo

# Create a test expression that imports the test file
cat > /tmp/test-runner.nix <<EOF
let
  # Import nixpkgs
  pkgs = import <nixpkgs> {};
  
  # Run the test
  test = import ./tests/${TEST_NAME}.nix;
in
  test
EOF

# Run the test with specified timeout
echo "Starting test with timeout of $TIMEOUT seconds..."
nix-build --timeout $TIMEOUT /tmp/test-runner.nix

echo
echo "Test $TEST_NAME completed successfully!"