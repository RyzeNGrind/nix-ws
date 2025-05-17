#!/usr/bin/env bash
set -euo pipefail

# Direct test runner that bypasses flake checks 
# This allows running individual tests quickly and reliably
# Usage: ./scripts/direct-test-runner.sh [test_name] [timeout_seconds]

TEST_NAME=${1:?"Please provide a test name (without .nix extension)"}
TIMEOUT=${2:-240}  # Default timeout: 240 seconds

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_FILE="$PROJECT_ROOT/tests/$TEST_NAME.nix"

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
  echo "ERROR: Test file not found: $TEST_FILE"
  echo "Available tests:"
  find "$PROJECT_ROOT/tests" -name "*.nix" -type f | sort | sed 's|.*/||' | sed 's/\.nix$//'
  exit 1
fi

echo "Running test: $TEST_NAME"
echo "Timeout: $TIMEOUT seconds"
echo "Test file: $TEST_FILE"
echo "----------------------------------------"

# Create a temporary test wrapper to fix the parameter mismatch
TMP_DIR=$(mktemp -d)
WRAPPER_FILE="$TMP_DIR/wrapper.nix"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$WRAPPER_FILE" <<EOF
let
  flake = builtins.getFlake "$PROJECT_ROOT";
  pkgs = flake.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
  testModule = import "$TEST_FILE";
  testWithFixedArgs = testModule // {
    __functor = _: args: testModule {
      self = flake.self;
      inherit pkgs;
      lib = pkgs.lib;
      inputs = flake.inputs;
      config = args.config or {};
    };
  };
in testWithFixedArgs {}
EOF

# Run the test directly using the wrapper
cd "$PROJECT_ROOT"
NIXPKGS_ALLOW_UNFREE=1 nix-build "$WRAPPER_FILE" --option timeout "$TIMEOUT" --show-trace