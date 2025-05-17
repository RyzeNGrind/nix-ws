#!/usr/bin/env bash
set -euo pipefail

# Helper script to run individual VM tests
# Usage: ./scripts/run-vm-test.sh [test-name]
# Example: ./scripts/run-vm-test.sh nix-ws-core

# Get the absolute path to the project directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Default timeout in seconds (4 minutes)
TIMEOUT=${TIMEOUT:-240}

# Default test to run if none specified
TEST_NAME=${1:-nix-ws-core}

echo "Running test: $TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo "Project root: $PROJECT_ROOT"
echo

# Create a temporary Nix expression that will import the test with the right parameters
TMP_NIX=$(mktemp)
trap "rm -f $TMP_NIX" EXIT

cat > "$TMP_NIX" <<EOF
let
  flake = builtins.getFlake (toString $PROJECT_ROOT);
  system = builtins.currentSystem;
  pkgs = flake.inputs.nixpkgs.legacyPackages.\${system};
  inputs = flake.inputs;
  self = flake;
  self' = flake.outputs.packages.\${system};
in
  import $PROJECT_ROOT/tests/$TEST_NAME.nix {
    inherit pkgs self' inputs;
    lib = pkgs.lib;
    config = {}; # Provide an empty config object
    environment.noTailscale = true;
    nix-fast-build.enable = true;
  }
EOF

# For debugging
echo "Created temporary Nix file at: $TMP_NIX"
echo "Contents:"
cat "$TMP_NIX"
echo

# Build and run the VM test
nix-build "$TMP_NIX" --timeout $TIMEOUT --no-out-link

echo
echo "Test $TEST_NAME completed successfully!"