#!/usr/bin/env bash
set -euo pipefail

# Script to run a single NixOS VM test without using flake checks
# This approach avoids the long build times of running all tests at once

# Get the absolute path to the project directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Get the test name from the first argument, or use a default
TEST_NAME=${1:-nix-ws-core}

# Set timeout (default to 5 minutes)
TIMEOUT=${TIMEOUT:-300}

echo "Running test: $TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo "Project root: $PROJECT_ROOT"
echo

# Create a test file directly in the project directory (to avoid path issues)
TMP_NIX="$PROJECT_ROOT/tmp-test-runner.nix"
trap "rm -f $TMP_NIX" EXIT

cat > "$TMP_NIX" <<EOF
let
  # Get absolute paths
  projectRoot = "$PROJECT_ROOT";
  testFile = "$PROJECT_ROOT/tests/${TEST_NAME}.nix";

  # Import nixpkgs
  pkgs = import <nixpkgs> {};
  
  # Run a specific test directly
  test = import testFile;
in
  test
EOF

# For debugging
echo "Created test runner at: $TMP_NIX"
echo "Contents:"
cat "$TMP_NIX"
echo

# Run the test with specified timeout
echo "Starting test with timeout of $TIMEOUT seconds..."
nix-build --timeout $TIMEOUT "$TMP_NIX"

echo
echo "Test $TEST_NAME completed successfully!"