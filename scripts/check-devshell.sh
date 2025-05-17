#!/usr/bin/env bash
set -eu

# Print header
echo "=== Quick Devshell Check ==="
echo "Checking devShells.x86_64-linux.void-editor..."

# Check syntax of modified overlays
echo -e "\n1. Checking overlay syntax..."
nix-instantiate --eval -E 'with import <nixpkgs> {}; callPackage ./overlays/void-editor/package.nix {}' --show-trace 2>&1 | grep -i error || echo "✓ No syntax errors in void-editor package"

# Check if the devshell evaluates correctly (without building)
echo -e "\n2. Checking devshell evaluation..."
nix eval --impure --expr "(builtins.getFlake (toString .))" --apply "f: f.devShells.x86_64-linux" --json 2>&1 | grep -i error || echo "✓ Devshells evaluate correctly"

# Try to build just the devshell
echo -e "\n3. Attempting to build devshell..."
nix build --impure .#devShells.x86_64-linux.void-editor --no-link --show-trace

# Check if the shell integration scripts are available
echo -e "\n4. Checking for shell integration files..."
if [ -d "./overlays/void-editor/shell-integration" ]; then
  find ./overlays/void-editor/shell-integration -type f -name "shellIntegration*" | while read -r file; do
    echo "Found: $file"
  done
else
  echo "Shell integration directory not found. Creating it..."
  mkdir -p ./overlays/void-editor/shell-integration
  echo "Directory created. Shell scripts need to be added."
fi

echo -e "\nCheck complete!"