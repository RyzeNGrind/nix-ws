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

echo "--- nix-cfg: Staging flake.lock ---"
git add flake.lock

COMMIT_MSG_FILE_LOCK_UPDATE="/tmp/nix_cfg_flake_lock_update_commit_msg.txt"
echo "--- nix-cfg: Creating commit message file at $COMMIT_MSG_FILE_LOCK_UPDATE ---"
cat > "$COMMIT_MSG_FILE_LOCK_UPDATE" <<'COMMITLOCKUPDATEEND'
chore(deps): Update home-manager flake input

Updated the home-manager input in flake.lock to the latest version.
This should resolve issues related to internal Home Manager modules,
such as the 'attribute lib missing' error in mako.nix.
COMMITLOCKUPDATEEND

echo "--- nix-cfg: Committing flake.lock update ---"
git commit -F "$COMMIT_MSG_FILE_LOCK_UPDATE"
rm "$COMMIT_MSG_FILE_LOCK_UPDATE"

echo "--- nix-cfg: flake.lock update committed successfully! ---"
git status -s
# Add this script to git as well
git add scripts/commit-flake-lock-update.sh
git commit --amend --no-edit
echo "--- nix-cfg: commit-flake-lock-update.sh script added to commit. ---"