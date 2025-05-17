#!/bin/bash
set -ef -o pipefail # Removed 'u' to prevent unbound variable errors during profile sourcing

echo "--- nix-cfg: Sourcing Nix profile for Git ---"
if [ -f /etc/profile ]; then
  . /etc/profile
fi
# Attempt to source common Nix profile locations
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
  . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
elif [ -f /etc/profile.d/nix.sh ]; then
  . /etc/profile.d/nix.sh
fi

# Verify git is available
if ! command -v git &> /dev/null; then
    echo "Error: git command not found after sourcing profiles. Please ensure Nix environment is correctly set up."
    exit 1
fi
echo "Git version: $(git --version)"

echo "--- nix-cfg: Navigating to repository root ---"
# The script is already in nix-cfg/scripts, so cd ..
cd "$(dirname "$0")/.." || { echo "Failed to cd to repository root"; exit 1; }

echo "--- nix-cfg: Current directory: $(pwd) ---"
echo "--- nix-cfg: Git status before removal ---"
git status -s

FILES_TO_REMOVE=(
  "modules/1password-ssh-agent-bridge.nix"
  "scripts/setup-1password-ssh-bridge.sh.tmp"
  "scripts/1password-ssh-agent-bridge.sh"
  "scripts/1password-ssh-bridge-wrapper.sh"
  "scripts/1password-ssh-profile.sh"
  "scripts/test-1password-ssh.sh"
  "docs/1password-ssh-integration.md"
  "docs/README-1password-ssh.md"
  "docs/1password-ssh-cleanup-plan.md"
  "docs/1password-ssh-integration-complete.md"
)

echo "--- nix-cfg: Removing specified files ---"
for file_to_remove in "${FILES_TO_REMOVE[@]}"; do
  if [ -f "$file_to_remove" ]; then
    echo "Deleting $file_to_remove from filesystem..."
    rm -f "$file_to_remove"
  else
    echo "Warning: File $file_to_remove not found on filesystem, skipping deletion."
  fi
done

COMMIT_MSG_FILE="/tmp/nix_cfg_1pass_cleanup_commit_msg.txt"
echo "--- nix-cfg: Creating commit message file at $COMMIT_MSG_FILE ---"
cat > "$COMMIT_MSG_FILE" <<'COMMITMSGEND'
refactor(1password): Remove redundant SSH agent scripts and docs

This commit streamlines the 1Password SSH agent integration by removing
superseded scripts and consolidating documentation.

Removed files:
- modules/1password-ssh-agent-bridge.nix
- scripts/setup-1password-ssh-bridge.sh.tmp
- scripts/1password-ssh-agent-bridge.sh
- scripts/1password-ssh-bridge-wrapper.sh
- scripts/1password-ssh-profile.sh
- scripts/test-1password-ssh.sh
- docs/1password-ssh-integration.md
- docs/README-1password-ssh.md
- docs/1password-ssh-cleanup-plan.md
- docs/1password-ssh-integration-complete.md

The core functionality is preserved through the declarative Home Manager
module (modules/1password-ssh-agent.nix) and the primary scripts:
- scripts/setup-1password-ssh-bridge.sh
- scripts/test-1password-ssh-agent.sh
- scripts/nixos-deploy-with-1password.sh

The primary documentation is now:
- docs/1password-ssh-agent.md
- docs/1password-nixos-deployment.md
COMMITMSGEND

echo "--- nix-cfg: Committing changes ---"
echo "--- nix-cfg: Staging all changes (including deletions and this script) ---"
git add . # Stage all changes, including deletions and this script itself

echo "--- nix-cfg: Committing changes ---"
git commit -F "$COMMIT_MSG_FILE"

echo "--- nix-cfg: Removing temporary commit message file ---"
rm "$COMMIT_MSG_FILE"

echo "--- nix-cfg: Git status after commit ---"
git status -s
echo "--- nix-cfg: Cleanup and commit successful! ---"
# The script is now part of the commit due to 'git add .'
# No need to amend if it was added before the commit.
# If the script was modified and we want that in the *same* commit,
# it should be `git add scripts/apply-1password-cleanup-commit.sh` before the commit.
# The `git add .` above handles adding the script if it's new or modified.
echo "--- nix-cfg: This script (scripts/apply-1password-cleanup-commit.sh) should be part of the commit. ---"