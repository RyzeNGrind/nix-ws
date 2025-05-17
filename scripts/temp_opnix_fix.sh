#!/usr/bin/env bash
set -e;
echo 'Connected to nix-ws. Navigating to nix-cfg directory...';
cd ~/Workspaces/nix-cfg || exit 1; # Exit if cd fails
echo 'Ensuring we are on the safe-test-config branch...';
git checkout safe-test-config;
echo 'Correcting opnix import in flake.nix...';
# Use a different delimiter for sed if paths contain slashes, though not strictly needed here.
# Using | as delimiter for s command.
sed -i 's|inputs.opnix.nixosModules.opnix|inputs.opnix.nixosModules.default|' flake.nix;
echo 'Verifying the change in flake.nix...';
grep 'inputs.opnix.nixosModules.default' flake.nix || (echo "Grep verification failed!" && exit 1);
echo 'Committing the fix...';
git add flake.nix;
git commit -m 'fix(flake): correct opnix module import path

Changed the import from inputs.opnix.nixosModules.opnix
to inputs.opnix.nixosModules.default based on opnix documentation.';
echo 'Attempting to build the configuration with the fix...';
sudo nixos-rebuild build --flake .#nix-ws --show-trace;
echo 'Build command finished. Check output for success or errors.'