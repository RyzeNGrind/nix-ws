# Set colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Print welcome message
echo -e "\n${BLUE}Welcome to the NixOS Configuration Development Shell${NC}"
echo -e "${YELLOW}Project: ClusterLab/nix-pc${NC}\n"

# Display available tools
echo -e "${GREEN}Available Tools:${NC}"
echo -e "${BLUE}Formatters & Linters:${NC}"
echo -e "  • alejandra    - Format Nix files"
echo -e "  • deadnix      - Find dead code in Nix files"
echo -e "  • statix       - Lint Nix files"
echo -e "  • prettier     - Format other files"

echo -e "\n${BLUE}Git & Version Control:${NC}"
echo -e "  • git          - Version control"
echo -e "  • pre-commit   - Run pre-commit hooks"

echo -e "\n${BLUE}Nix Tools:${NC}"
echo -e "  • nil          - Nix language server"
echo -e "  • nom          - Nix output monitor"
echo -e "  • home-manager - User environment manager"

echo -e "\n${BLUE}Common Commands:${NC}"
echo -e "  • ./scripts/test-flake.sh                                  - Run basic tests"
echo -e "  • RUN_SYSTEM_TEST=1 RUN_HOME_TEST=1 ./scripts/test-flake.sh - Run comprehensive tests"
echo -e "  • nix flake check                                         - Check flake integrity"
echo -e "  • home-manager switch                                     - Update user environment"
echo -e "  • nixos-rebuild test --flake .                           - Test system configuration"
echo -e "  • pre-commit run --all-files                             - Run all pre-commit hooks"

echo -e "\n${BLUE}Development Workflow:${NC}"
echo -e "1. Make changes to configuration files"
echo -e "2. Run formatters (alejandra, prettier)"
echo -e "3. Run pre-commit hooks"
echo -e "4. Test changes with test-flake.sh"
echo -e "5. Rebuild system to apply changes"

# Ensure TMPDIR exists and has correct permissions
if [ -w /tmp ]; then
  export TMPDIR="/tmp"
else
  export TMPDIR="$HOME/.cache/tmp"
  mkdir -p "$TMPDIR"
fi

# Configure git for better WSL performance
git config --local core.fsmonitor false
git config --local core.untrackedcache false

# Create custom pre-commit hook
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
set -e

# Helper function to check if we're in a Nix shell
in_nix_shell() {
  [[ -n "$IN_NIX_SHELL" ]] || [[ -n "$NIX_SHELL_ACTIVE" ]]
}

# Check if we're in the development shell
if ! in_nix_shell; then
  echo -e "\033[1;33mWarning: Not in development shell. Running git commit outside of development shell may skip hooks.\033[0m"
  echo -e "\033[1;33mPlease run 'nix develop' first.\033[0m"
  exit 1
fi

# Use pre-commit from the development shell
if ! command -v pre-commit >/dev/null 2>&1; then
  echo -e "\033[1;31mError: pre-commit command not found. Are you in the development shell?\033[0m"
  exit 1
fi

exec pre-commit run --config .pre-commit-config.yaml "$@"
EOF

chmod +x .git/hooks/pre-commit

# Export shell indicator
export NIX_SHELL_ACTIVE=1

# Set up bash shell environment
mkdir -p ~/.bashrc.d
cat > ~/.bashrc.d/nix-develop.bash << EOF
# Initialize starship
if command -v starship >/dev/null; then
  eval "\$(starship init bash)"
fi

# Initialize direnv
if command -v direnv >/dev/null; then
  eval "\$(direnv hook bash)"
fi

# Initialize zoxide
if command -v zoxide >/dev/null; then
  eval "\$(zoxide init bash)"
fi

# Enable bash completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi
EOF

# Run initial pre-commit check
pre-commit run --all-files || true

echo -e "\n${GREEN}Development shell activated with pre-commit hooks${NC}"
echo -e "${YELLOW}Type 'exit' to leave the shell${NC}\n"
