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
  # Import nixpkgs
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # This will fail and Nix will suggest the correct hash
  };
  
  # Get flake inputs using builtins.getFlake
  flake = builtins.getFlake "path:$PROJECT_ROOT";
  
  # Import the test file with all required parameters
  testModule = import "$PROJECT_ROOT/tests/${TEST_NAME}.nix" {
    pkgs = import nixpkgs {};
    lib = (import nixpkgs {}).lib;
    self' = flake.outputs.packages.\${builtins.currentSystem};
    inputs = flake.inputs;
    # Additional parameters that may be needed
    environment.noTailscale = true;
    nix-fast-build.enable = true;
    config = {};
  };
in
  testModule
EOF

# For debugging
echo "Created test runner at: $TMP_NIX"
echo "Contents:"
cat "$TMP_NIX"
echo

# Run the test with specified timeout
echo "Starting test with timeout of $TIMEOUT seconds..."
NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix-build --timeout $TIMEOUT "$TMP_NIX" --show-trace

echo
echo "Test $TEST_NAME completed successfully!"