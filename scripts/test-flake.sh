#!/usr/bin/env bash
set -eo pipefail

# Define colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Echo with timestamp
log() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

warn() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if running in a Nix environment
in_nix_shell() {
  [[ -n "$IN_NIX_SHELL" ]] || [[ -n "$NIX_SHELL_ACTIVE" ]]
}

# Working directory is the git root
cd "$(git rev-parse --show-toplevel)" || exit 1

# Check for clean repo
if [[ -n "$(git status --porcelain)" ]]; then
  warn "Git repository is not clean. Some tests may fail."
  warn "Consider committing or stashing changes first."
else
  log "Git repository is clean ✓"
fi

# Determine whether to run system tests
RUN_SYSTEM_TEST=${RUN_SYSTEM_TEST:-0}
RUN_HOME_TEST=${RUN_HOME_TEST:-0}

#################################################
# 1. Basic flake validation
#################################################
log "Step 1: Basic flake validation"

log "Checking flake syntax..."
if ! nix flake show --no-write-lock-file 2>/dev/null; then
  error "Flake show failed. Check flake.nix for syntax errors."
  exit 1
else
  success "Flake syntax check passed ✓"
fi

log "Running flake check..."
if ! nix flake check --no-write-lock-file 2>/dev/null; then
  warn "Flake check has warnings or errors, but continuing tests..."
else
  success "Flake check passed ✓"
fi

#################################################
# 2. Testing devShell
#################################################
log "Step 2: Testing devShell"

log "Building devShell..."
if ! nix build --no-link .#devShells.x86_64-linux.default 2>/dev/null; then
  error "Failed to build devShell"
  exit 1
else
  success "DevShell builds successfully ✓"
fi

# Create a temporary script to test the devShell
TMP_SCRIPT=$(mktemp)
cat > "$TMP_SCRIPT" << 'EOF'
#!/usr/bin/env bash
# Test if important tools are available in the devShell
echo "Testing tools in devShell..."

# Array of tools to check
TOOLS=(
  "void-editor"
  "vscodium"
  "alejandra"
  "deadnix"
  "statix"
  "prettier"
  "git"
  "pre-commit"
  "home-manager"
  "nix"
)

# Check each tool
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "✅ $tool is available"
    # If it's void-editor, check the version
    if [[ "$tool" == "void-editor" ]]; then
      echo "   Version: $($tool --version 2>/dev/null || echo 'unknown')"
    fi
  else
    echo "❌ $tool is NOT available"
    exit 1
  fi
done

echo "All tools available ✓"
exit 0
EOF

chmod +x "$TMP_SCRIPT"

log "Testing tools in devShell..."
if ! nix develop --command bash "$TMP_SCRIPT"; then
  error "DevShell tools test failed"
  exit 1
else
  success "DevShell tools available ✓"
fi

rm "$TMP_SCRIPT"

#################################################
# 3. Testing Void Editor Package
#################################################
log "Step 3: Testing Void Editor Package"

log "Building void-editor package..."
if ! nix build --no-link .#packages.x86_64-linux.void-editor 2>/dev/null; then
  warn "Package void-editor not found in flake outputs. Trying system build..."
  # Try to build it from the nixpkgs module
  if ! nix build --no-link 'nixpkgs#void-editor' 2>/dev/null; then
    error "Failed to build void-editor package"
    exit 1
  else
    success "void-editor package builds from nixpkgs ✓"
  fi
else
  success "void-editor package builds from flake ✓"
fi

#################################################
# 4. Testing NixOS configuration
#################################################
if [[ "$RUN_SYSTEM_TEST" -eq 1 ]]; then
  log "Step 4: Testing NixOS configuration"
  
  log "Dry-building NixOS configuration..."
  if ! nixos-rebuild dry-build --flake .#nix-ws; then
    error "NixOS configuration build failed"
    exit 1
  else
    success "NixOS configuration builds successfully ✓"
  fi
  
  log "Running nixos-rebuild dry-activate..."
  if ! sudo nixos-rebuild dry-activate --flake .#nix-ws; then
    error "NixOS configuration dry-activation failed"
    exit 1
  else
    success "NixOS configuration dry-activation passed ✓"
  fi
else
  warn "Skipping NixOS configuration test. Set RUN_SYSTEM_TEST=1 to test."
fi

#################################################
# 5. Testing Home Manager configuration
#################################################
if [[ "$RUN_HOME_TEST" -eq 1 ]]; then
  log "Step 5: Testing Home Manager configuration"
  
  log "Validating Home Manager configuration..."
  if ! home-manager build --flake .#ryzengrind; then
    error "Home Manager configuration build failed"
    exit 1
  else
    success "Home Manager configuration builds successfully ✓"
  fi
else
  warn "Skipping Home Manager test. Set RUN_HOME_TEST=1 to test."
fi

#################################################
# Final summary
#################################################
log "All tests completed"
success "Your flake configuration appears valid and ready for deployment"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "- Run full tests: RUN_SYSTEM_TEST=1 RUN_HOME_TEST=1 ./scripts/test-flake.sh"
echo "- Apply system changes: sudo nixos-rebuild switch --flake .#nix-ws"
echo "- Apply home-manager changes: home-manager switch --flake .#ryzengrind"
echo ""
