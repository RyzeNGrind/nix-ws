#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Enable required experimental features
export NIX_CONFIG="experimental-features = nix-command flakes repl-flake"

# Function to check sudo access
check_sudo() {
    if ! sudo -v &>/dev/null; then
        echo -e "${RED}Error: sudo access is not properly configured${NC}"
        echo "Please ensure:"
        echo "1. Your user is in the wheel group"
        echo "2. sudo is properly installed with setuid bit"
        echo "3. The security.sudo configuration is correct"
        return 1
    fi
}

# Function to check command status
check_status() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        return 0
    else
        if [ "$2" = "warn" ]; then
            echo -e "${YELLOW}! $1 (non-critical failure)${NC}"
            return 0
        else
            echo -e "${RED}✗ $1 (exit code: $exit_code)${NC}"
            return 1
        fi
    fi
}

# Function to show spinner with elapsed time
spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    local start=$SECONDS
    
    while ps -p $pid > /dev/null; do
        local elapsed=$((SECONDS - start))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        local temp=${spinstr#?}
        printf "\r${BLUE}%s${NC} [%c] (%02d:%02d)" "$message" "$spinstr" $mins $secs
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%-100s\r" " "
}

# Function to run command with progress and real-time output
run_with_progress() {
    local message=$1
    shift
    local log_file="/tmp/cmd.$$.log"
    local output_file="/tmp/cmd.$$.output"
    
    # Create named pipe for real-time output
    mkfifo "$output_file"
    
    # Start command and redirect output
    echo -e "\n${BLUE}=== ${message} ===${NC}"
    ("$@" 2>&1 | tee "$log_file" > "$output_file") &
    local pid=$!
    
    # Start spinner in background
    spinner $pid "$message" &
    local spinner_pid=$!
    
    # Read and display output in real-time with timeout
    local timeout=1800  # 30 minutes timeout
    local start=$SECONDS
    while IFS= read -r -t $timeout line || [ -n "$line" ]; do
        echo "  $line"
        if [ $((SECONDS - start)) -gt $timeout ]; then
            echo -e "${RED}Command timed out after ${timeout} seconds${NC}"
            kill $pid 2>/dev/null || true
            kill $spinner_pid 2>/dev/null || true
            rm -f "$output_file" "$log_file"
            return 124
        fi
    done < "$output_file"
    
    # Wait for command to finish
    wait $pid
    local exit_code=$?
    
    # Kill spinner and clean up
    kill $spinner_pid 2>/dev/null || true
    wait $spinner_pid 2>/dev/null || true
    rm -f "$output_file"
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${BLUE}${message}${NC} ${GREEN}✓${NC}"
    else
        echo -e "${BLUE}${message}${NC} ${RED}✗${NC}"
        if [ -f "$log_file" ]; then
            echo -e "\n${RED}Error output:${NC}"
            cat "$log_file"
        fi
    fi
    
    rm -f "$log_file"
    return $exit_code
}

# Function to run pre-commit hook directly
run_precommit_hook() {
    local hook=$1
    shift
    if command -v pre-commit >/dev/null 2>&1; then
        pre-commit run --hook-stage manual "$hook" "$@"
    else
        nix shell nixpkgs#pre-commit -c pre-commit run --hook-stage manual "$hook" "$@"
    fi
}

# Start timer
start_time=$(date +%s)

echo -e "\n${BLUE}=== Starting comprehensive flake testing ===${NC}\n"

# Skip pre-commit hooks if we're already running them
if [ -z "${RUNNING_TEST_FLAKE:-}" ]; then
    echo -e "${BLUE}=== Running pre-commit hooks ===${NC}\n"
    
    run_with_progress "Running alejandra formatting" \
        run_precommit_hook alejandra --all-files

    run_with_progress "Running deadnix check" \
        run_precommit_hook deadnix --all-files

    run_with_progress "Running prettier formatting" \
        run_precommit_hook prettier --all-files

    run_with_progress "Running statix check" \
        run_precommit_hook statix --all-files
fi

echo -e "\n${BLUE}=== Running flake checks ===${NC}\n"
run_with_progress "Checking flake outputs" \
    nix flake check \
        --no-build \
        --keep-going \
        --show-trace \
        --allow-import-from-derivation

echo -e "\n${BLUE}=== Testing configurations ===${NC}\n"
run_with_progress "Testing nix-pc configuration" \
    nix eval --json .#nixosConfigurations.nix-pc.config.system.build.toplevel.drvPath

run_with_progress "Testing nix-ws configuration" \
    nix eval --json .#nixosConfigurations.nix-ws.config.system.build.toplevel.drvPath

run_with_progress "Testing home-manager configuration" \
    nix eval --json .#homeConfigurations."ryzengrind@nix-pc".activationPackage.drvPath

# System build test (only if explicitly requested)
if [ "${RUN_SYSTEM_TEST:-0}" = "1" ]; then
    echo -e "\n${BLUE}=== Running system build test ===${NC}\n"
    if ! check_sudo; then
        echo -e "${RED}Skipping system build test due to sudo configuration issues${NC}"
    else
        run_with_progress "Building system configuration" \
            sudo nixos-rebuild test \
                --flake .#nix-pc \
                --show-trace \
                --keep-going
    fi
fi

# Home Manager test (only if explicitly requested)
if [ "${RUN_HOME_TEST:-0}" = "1" ]; then
    echo -e "\n${BLUE}=== Running Home Manager test ===${NC}\n"
    run_with_progress "Building home configuration" \
        home-manager switch --flake .#ryzengrind@nix-pc
fi

# Quick system verification
echo -e "\n${BLUE}=== Running quick system verification ===${NC}\n"
run_with_progress "Checking critical services" \
    systemctl is-active dbus docker

# Calculate execution time
end_time=$(date +%s)
duration=$((end_time - start_time))

echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}✓${NC} Pre-commit hooks"
echo -e "${GREEN}✓${NC} Flake integrity"
echo -e "${GREEN}✓${NC} Configuration checks"
echo -e "${GREEN}✓${NC} Quick system verification"
echo -e "\nExecution time: ${duration} seconds"

echo -e "\n${GREEN}Tests completed successfully!${NC}"
if [ "${RUN_SYSTEM_TEST:-0}" != "1" ] || [ "${RUN_HOME_TEST:-0}" != "1" ]; then
    echo -e "${YELLOW}Note: For full system testing, run with:${NC}"
    echo "RUN_SYSTEM_TEST=1 RUN_HOME_TEST=1 ./scripts/test-flake.sh"
fi

# Cleanup any leftover temporary files
rm -f /tmp/cmd.$$.* 2>/dev/null || true 