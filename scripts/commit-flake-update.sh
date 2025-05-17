#!/bin/bash
set -ef -o pipefail

echo "--- nix-cfg: Sourcing Nix profile for Git ---"
if [ -f /etc/profile ]; then . /etc/profile; fi
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; elif [ -f /etc/profile.d/nix.sh ]; then . /etc/profile.d/nix.sh; fi

if ! command -v git &> /dev/null; then echo "Error: git command not found."; exit 1; fi
echo "Git version: $(git --version)"

echo "--- nix-cfg: Navigating to repository root ---"
cd "$(dirname "$0")/.." || { echo "Failed to cd to repository root"; exit 1; }
echo "--- nix-cfg: Current directory: $(pwd) ---"

echo "--- nix-cfg: Staging flake.nix ---"
git add flake.nix

COMMIT_MSG_FILE_FLAKE="/tmp/nix_cfg_flake_update_commit_msg.txt"
echo "--- nix-cfg: Creating commit message file at $COMMIT_MSG_FILE_FLAKE ---"
cat > "$COMMIT_MSG_FILE_FLAKE" <<'COMMITMSGFLAKEEND'
fix(flake): Correct Home Manager configuration structure

Updated flake.nix to use `home-manager.lib.homeManagerConfiguration`
for defining `homeConfigurations.ryzengrind`. This resolves the
error encountered during `home-manager switch`.
COMMITMSGFLAKEEND

echo "--- nix-cfg: Committing flake.nix update ---"
git commit -F "$COMMIT_MSG_FILE_FLAKE"
rm "$COMMIT_MSG_FILE_FLAKE"

echo "--- nix-cfg: flake.nix update committed successfully! ---"
git status -s
# Add this script to git as well
git add scripts/commit-flake-update.sh
git commit --amend --no-edit
echo "--- nix-cfg: commit-flake-update.sh script added to commit. ---"