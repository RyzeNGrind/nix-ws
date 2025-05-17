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

echo "--- nix-cfg: Staging modules/1password-ssh-agent.nix ---"
git add modules/1password-ssh-agent.nix

COMMIT_MSG_FILE_MODULE_FIX="/tmp/nix_cfg_1pass_module_fix_commit_msg.txt"
echo "--- nix-cfg: Creating commit message file at $COMMIT_MSG_FILE_MODULE_FIX ---"
cat > "$COMMIT_MSG_FILE_MODULE_FIX" <<'COMMITMODULEFIXEND'
fix(hm): Correct home.file definitions in 1password-ssh-agent module

Consolidated all home.file definitions within
modules/1password-ssh-agent.nix into a single attribute set,
using attribute set merging (`//`) for conditional parts.

This resolves the "attribute 'home.file' already defined" error
encountered during `home-manager switch`.
COMMITMODULEFIXEND

echo "--- nix-cfg: Committing 1password-ssh-agent.nix update ---"
git commit -F "$COMMIT_MSG_FILE_MODULE_FIX"
rm "$COMMIT_MSG_FILE_MODULE_FIX"

echo "--- nix-cfg: 1password-ssh-agent.nix update committed successfully! ---"
git status -s
# Add this script to git as well
git add scripts/commit-1password-module-fix.sh
git commit --amend --no-edit
echo "--- nix-cfg: commit-1password-module-fix.sh script added to commit. ---"