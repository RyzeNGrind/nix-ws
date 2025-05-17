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

# Create a temporary Nix expression that will import the test with the right parameters
TMP_NIX=$(mktemp)
trap "rm -f $TMP_NIX" EXIT

cat > "$TMP_NIX" <<EOF
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;
  pkgs = flake.inputs.nixpkgs.legacyPackages.\${system};
  inputs = flake.inputs;
  self = flake;
  self' = flake.outputs.packages.\${system};
in
  import ./tests/$TEST_NAME.nix {
    inherit pkgs self' inputs;
    lib = pkgs.lib;
    config = {}; # Provide an empty config object
    environment.noTailscale = true;
    nix-fast-build.enable = true;
  }
EOF

# Build and run the VM test
nix-build "$TMP_NIX" --timeout $TIMEOUT --no-out-link

echo
echo "Test $TEST_NAME completed successfully!"