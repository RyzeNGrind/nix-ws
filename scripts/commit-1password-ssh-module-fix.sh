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

echo "--- nix-cfg: Staging home/modules/1password-ssh.nix ---"
git add home/modules/1password-ssh.nix

COMMIT_MSG_FILE_SUBMODULE_FIX="/tmp/nix_cfg_1pass_submodule_fix_commit_msg.txt"
echo "--- nix-cfg: Creating commit message file at $COMMIT_MSG_FILE_SUBMODULE_FIX ---"
cat > "$COMMIT_MSG_FILE_SUBMODULE_FIX" <<'COMMITSUBMODULEFIXEND'
fix(hm): Correct home.file definitions in 1password-ssh.nix

Consolidated all home.file definitions within
home/modules/1password-ssh.nix into a single attribute set.

This resolves a potential "attribute 'home.file' already defined"
error originating from this module.
COMMITSUBMODULEFIXEND

echo "--- nix-cfg: Committing home/modules/1password-ssh.nix update ---"
git commit -F "$COMMIT_MSG_FILE_SUBMODULE_FIX"
rm "$COMMIT_MSG_FILE_SUBMODULE_FIX"

echo "--- nix-cfg: home/modules/1password-ssh.nix update committed successfully! ---"
git status -s
# Add this script to git as well
git add scripts/commit-1password-ssh-module-fix.sh
git commit --amend --no-edit
echo "--- nix-cfg: commit-1password-ssh-module-fix.sh script added to commit. ---"