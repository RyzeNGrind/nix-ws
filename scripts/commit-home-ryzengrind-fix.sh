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

echo "--- nix-cfg: Staging home/ryzengrind.nix ---"
git add home/ryzengrind.nix

COMMIT_MSG_FILE_HM_FIX="/tmp/nix_cfg_hm_fix_commit_msg.txt"
echo "--- nix-cfg: Creating commit message file at $COMMIT_MSG_FILE_HM_FIX ---"
cat > "$COMMIT_MSG_FILE_HM_FIX" <<'COMMITHMFIXEND'
fix(hm): Refactor home/ryzengrind.nix to resolve recursion

- Changed module signature to standard Home Manager form.
- Consistently access flake inputs (std, hive, etc.) via the 'inputs'
  specialArg passed from flake.nix.
- Made imports of external homeModules more robust.
- Commented out problematic 'devmods.shells' assignment.

This should resolve the infinite recursion error during
`home-manager switch` related to the 'std' argument.
COMMITHMFIXEND

echo "--- nix-cfg: Committing home/ryzengrind.nix update ---"
git commit -F "$COMMIT_MSG_FILE_HM_FIX"
rm "$COMMIT_MSG_FILE_HM_FIX"

echo "--- nix-cfg: home/ryzengrind.nix update committed successfully! ---"
git status -s
# Add this script to git as well
git add scripts/commit-home-ryzengrind-fix.sh
git commit --amend --no-edit
echo "--- nix-cfg: commit-home-ryzengrind-fix.sh script added to commit. ---"