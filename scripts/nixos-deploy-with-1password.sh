#!/usr/bin/env bash
# Enhanced NixOS Deployment with 1Password SSH Authentication
# This script integrates with the 1Password SSH agent for secure remote deployments

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SOCKET_PATH="$HOME/.1password/agent.sock"
PIPE_PATH="//./pipe/com.1password.1password.ssh"  # Correct pipe for 1Password 8+
DEFAULT_TARGET_HOST="nix-ws"
DEFAULT_FLAKE_PATH="."
DEFAULT_HOSTNAME="nix-ws"

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TARGET_HOST]

Deploy NixOS to a remote host using nixos-anywhere with 1Password SSH authentication.

Options:
  -f, --flake PATH     Path to the flake directory (default: $DEFAULT_FLAKE_PATH)
  -n, --hostname NAME  Name of the NixOS configuration to deploy (default: $DEFAULT_HOSTNAME)
  -t, --test           Test mode: verify 1Password SSH agent setup without deploying
  -v, --verbose        Enable verbose output for SSH connections
  -h, --help           Display this help message and exit

Arguments:
  TARGET_HOST          Target host to deploy to (default: $DEFAULT_TARGET_HOST)

Examples:
  $0                           # Deploy to default host using default flake and hostname
  $0 remote-server             # Deploy to remote-server using default config
  $0 -f ~/configs -n liveusb   # Deploy liveusb config from ~/configs to default host
  $0 -t                        # Test 1Password SSH agent integration without deploying
EOF
}

# Parse arguments
TEST_MODE=false
VERBOSE_MODE=false
FLAKE_PATH="$DEFAULT_FLAKE_PATH"
HOSTNAME="$DEFAULT_HOSTNAME"
TARGET_HOST="$DEFAULT_TARGET_HOST"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -t|--test)
            TEST_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -f|--flake)
            FLAKE_PATH="$2"
            shift 2
            ;;
        -n|--hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            show_usage
            exit 1
            ;;
        *)
            TARGET_HOST="$1"
            shift
            ;;
    esac
done

# Header
echo -e "${BLUE}${BOLD}=== NixOS Deployment with 1Password SSH Authentication ===${NC}"
echo -e "${BLUE}Target Host:${NC} $TARGET_HOST"
echo -e "${BLUE}Flake Path:${NC} $FLAKE_PATH"
echo -e "${BLUE}Hostname:${NC} $HOSTNAME"

# Check if 1Password SSH agent is properly configured
check_1password_ssh_agent() {
    echo -e "\n${BLUE}1. Checking 1Password SSH agent...${NC}"
    
    # Check if socket file exists
    if [ ! -S "$SOCKET_PATH" ]; then
        echo -e "${RED}✗ Socket file does not exist at $SOCKET_PATH${NC}"
        echo -e "${YELLOW}  Starting 1Password SSH bridge...${NC}"
        
        # Try to start the bridge in background
        if [ -x "./scripts/setup-1password-ssh-bridge.sh" ]; then
            "./scripts/setup-1password-ssh-bridge.sh" &
            BRIDGE_PID=$!
            
            # Wait for socket to appear (max 5 seconds)
            TIMEOUT=5
            for i in $(seq 1 $TIMEOUT); do
                sleep 1
                if [ -S "$SOCKET_PATH" ]; then
                    echo -e "${GREEN}✓ Socket created successfully!${NC}"
                    break
                fi
                echo -e "${BLUE}  Waiting for socket... ($i/$TIMEOUT)${NC}"
            done
            
            if [ ! -S "$SOCKET_PATH" ]; then
                echo -e "${RED}✗ Failed to create socket after $TIMEOUT seconds${NC}"
                kill $BRIDGE_PID 2>/dev/null || true
                return 1
            fi
        else
            echo -e "${RED}✗ Bridge script not found at ./scripts/setup-1password-ssh-bridge.sh${NC}"
            echo -e "${YELLOW}  Make sure the bridge script is in the correct location and executable${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Socket file exists at $SOCKET_PATH${NC}"
    fi
    
    # Set SSH_AUTH_SOCK environment variable
    export SSH_AUTH_SOCK="$SOCKET_PATH"
    echo -e "${GREEN}✓ SSH_AUTH_SOCK set to $SSH_AUTH_SOCK${NC}"
    
    # Test SSH agent connectivity
    SSH_ADD_OUTPUT=$(ssh-add -l 2>&1)
    SSH_ADD_STATUS=$?
    
    case $SSH_ADD_STATUS in
        0)  # Success, keys found
            echo -e "${GREEN}✓ Successfully connected to SSH agent${NC}"
            echo -e "${BLUE}Available SSH identities:${NC}"
            echo "$SSH_ADD_OUTPUT"
            return 0
            ;;
        1)  # Success, no keys
            echo -e "${RED}✗ Could not connect to SSH agent${NC}"
            echo -e "${YELLOW}Error message: The agent has no identities.${NC}"
            echo -e "${YELLOW}The agent is working but has no identities.${NC}"
            echo -e "${YELLOW}Check if you have enabled the SSH Agent feature in 1Password and added SSH keys.${NC}"
            echo -e "${BLUE}Follow these steps in 1Password for Windows:${NC}"
            echo "  1. Open 1Password"
            echo "  2. Go to Settings > Developer"
            echo "  3. Make sure 'Use the SSH agent' is enabled"
            echo "  4. Add your SSH keys to 1Password and mark them for use with SSH agent"
            echo "  5. Restart 1Password"
            return 1
            ;;
        *)  # Connection error
            echo -e "${RED}✗ Could not connect to SSH agent${NC}"
            echo -e "${RED}Error message: ${SSH_ADD_OUTPUT}${NC}"
            echo -e "${RED}=== ERROR: 1Password SSH Agent bridge is not working correctly! ===${NC}"
            echo -e "${YELLOW}Troubleshooting steps:${NC}"
            echo "  1. Check if the Windows 1Password application is running"
            echo "  2. Verify SSH agent is enabled in 1Password Settings > Developer"
            echo "  3. Check if pipe name is correct (should be: $PIPE_PATH)"
            echo "  4. Try running the bridge manually: ./scripts/setup-1password-ssh-bridge.sh"
            return 1
            ;;
    esac
}

# Function to verify connection to target host
verify_ssh_connection() {
    echo -e "\n${BLUE}2. Verifying SSH connection to $TARGET_HOST...${NC}"
    
    local SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5"
    if [ "$VERBOSE_MODE" = true ]; then
        SSH_OPTS="$SSH_OPTS -v"
    fi
    
    if ssh $SSH_OPTS $TARGET_HOST true 2>/dev/null; then
        echo -e "${GREEN}✓ SSH connection to $TARGET_HOST successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Could not connect to $TARGET_HOST${NC}"
        echo -e "${YELLOW}Attempting test connection with verbose logging...${NC}"
        
        # Try again with verbose logging for diagnostics
        if ssh -v -o ConnectTimeout=5 $TARGET_HOST true; then
            echo -e "${GREEN}✓ Connection works but may require interactive authentication${NC}"
            return 0
        else
            echo -e "${RED}✗ SSH connection failed even with interactive mode${NC}"
            echo -e "${YELLOW}Please check:${NC}"
            echo "  1. Host is reachable (ping $TARGET_HOST)"
            echo "  2. SSH server is running on target"
            echo "  3. Your public key is in the target's authorized_keys"
            echo "  4. SSH key in 1Password is correctly enabled for SSH agent"
            return 1
        fi
    fi
}

# Function to deploy with nixos-anywhere
deploy_with_nixos_anywhere() {
    echo -e "\n${BLUE}3. Deploying to $TARGET_HOST using nixos-anywhere...${NC}"
    
    # Check if flake path exists
    if [ ! -d "$FLAKE_PATH" ]; then
        echo -e "${RED}✗ Flake path does not exist: $FLAKE_PATH${NC}"
        return 1
    fi
    
    # Check if hostname exists in the flake
    local FLAKE_URI="$FLAKE_PATH"
    if [[ "$FLAKE_PATH" != *"#"* ]]; then
        FLAKE_URI="$FLAKE_PATH#"
    fi
    
    if ! nix flake show "$FLAKE_URI" | grep -q "$HOSTNAME"; then
        echo -e "${RED}✗ NixOS configuration '$HOSTNAME' not found in flake${NC}"
        echo -e "${YELLOW}Available configurations:${NC}"
        nix flake show "$FLAKE_URI" | grep -A 100 nixosConfigurations | grep -v "nixosConfigurations" | sed 's/^[[:space:]]*/  /'
        return 1
    fi
    
    # Ensure SSH_AUTH_SOCK is exported
    if [ -z "$SSH_AUTH_SOCK" ] || [ "$SSH_AUTH_SOCK" != "$SOCKET_PATH" ]; then
        export SSH_AUTH_SOCK="$SOCKET_PATH"
    fi
    
    # Summary of deployment
    echo -e "${BLUE}Deploying with the following parameters:${NC}"
    echo -e "  ${BLUE}Target:${NC} $TARGET_HOST"
    echo -e "  ${BLUE}Flake:${NC} $FLAKE_PATH"
    echo -e "  ${BLUE}Configuration:${NC} $HOSTNAME"
    echo -e "  ${BLUE}SSH Agent:${NC} $SSH_AUTH_SOCK"
    
    # Ask for confirmation
    read -p "Proceed with deployment? [y/N] " -n 1 -r CONFIRM
    echo
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deployment cancelled${NC}"
        return 0
    fi
    
    # Prepare command
    local NIXOS_ANYWHERE_OPTS="--flake $FLAKE_PATH#$HOSTNAME"
    NIXOS_ANYWHERE_OPTS="$NIXOS_ANYWHERE_OPTS --build-on-remote --ssh-options='-o ForwardAgent=yes'"
    
    if [ "$VERBOSE_MODE" = true ]; then
        NIXOS_ANYWHERE_OPTS="$NIXOS_ANYWHERE_OPTS --debug"
    fi
    
    echo -e "${BLUE}Running nixos-anywhere with: $NIXOS_ANYWHERE_OPTS${NC}"
    
    # Execute nixos-anywhere
    if nix run github:nix-community/nixos-anywhere -- \
        --flake "$FLAKE_PATH#$HOSTNAME" \
        --build-on-remote \
        root@"$TARGET_HOST" \
        --ssh-options="-o ForwardAgent=yes"; then
        
        echo -e "${GREEN}${BOLD}✓ Deployment to $TARGET_HOST completed successfully!${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}✗ Deployment to $TARGET_HOST failed!${NC}"
        return 1
    fi
}

# Main execution flow
if ! check_1password_ssh_agent; then
    echo -e "${RED}${BOLD}=== ERROR: 1Password SSH agent setup failed ===${NC}"
    echo -e "${YELLOW}Run the diagnostic tool for detailed troubleshooting:${NC}"
    echo "  ./scripts/test-1password-ssh-agent.sh"
    exit 1
fi

if [ "$TEST_MODE" = true ]; then
    echo -e "${GREEN}${BOLD}=== 1Password SSH agent integration is working correctly ===${NC}"
    echo -e "${BLUE}You can now deploy with:${NC}"
    echo "  $0 your-target-host"
    exit 0
fi

if ! verify_ssh_connection; then
    echo -e "${RED}${BOLD}=== ERROR: SSH connection to target host failed ===${NC}"
    exit 1
fi

if ! deploy_with_nixos_anywhere; then
    echo -e "${RED}${BOLD}=== ERROR: Deployment failed ===${NC}"
    exit 1
fi

echo -e "${GREEN}${BOLD}=== Deployment completed successfully! ===${NC}"