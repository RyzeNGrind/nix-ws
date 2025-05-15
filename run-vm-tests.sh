#!/usr/bin/env bash
# Run VM tests with better performance and debugging options

set -e

# Default values
TEST_NAME=""
VERBOSE=false
DEBUG=false
PRINT_BUILD_LOGS=false
TRACE=false
COPY_FROM_HOST=""
COPY_TO_VM=""
INSPECT=false

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
  echo -e "${BLUE}Usage:${NC} $0 [options] <test-name>"
  echo ""
  echo "Options:"
  echo "  -v, --verbose         Enable verbose output"
  echo "  -d, --debug           Enable debug mode (starts VM but doesn't run tests)"
  echo "  -L, --print-logs      Print build logs (useful for diagnosing build issues)"
  echo "  -t, --trace           Enable Nix trace for debugging"
  echo "  -c, --copy-to-vm PATH Copy a file/dir from host to VM"
  echo "  -f, --fetch PATH      Copy a file/dir from VM to host"
  echo "  -i, --inspect         Start QEMU with graphics for visual inspection"
  echo "  -h, --help            Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 liveusb-ssh-vpn"
  echo "  $0 --debug liveusb-ssh-vpn"
  echo "  $0 --verbose --print-logs nix-ws-min"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -d|--debug)
      DEBUG=true
      shift
      ;;
    -L|--print-logs)
      PRINT_BUILD_LOGS=true
      shift
      ;;
    -t|--trace)
      TRACE=true
      shift
      ;;
    -c|--copy-to-vm)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo -e "${RED}Error: --copy-to-vm requires a path argument${NC}"
        usage
      fi
      COPY_TO_VM="$2"
      shift 2
      ;;
    -f|--fetch)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo -e "${RED}Error: --fetch requires a path argument${NC}"
        usage
      fi
      COPY_FROM_HOST="$2"
      shift 2
      ;;
    -i|--inspect)
      INSPECT=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
    *)
      if [[ -z "$TEST_NAME" ]]; then
        TEST_NAME="$1"
      else
        echo -e "${RED}Error: Only one test name can be specified${NC}"
        usage
      fi
      shift
      ;;
  esac
done

# Check if test name is provided
if [[ -z "$TEST_NAME" ]]; then
  echo -e "${RED}Error: Test name is required${NC}"
  usage
fi

BASE_FLAGS=()

# Add flags based on options
if [[ "$VERBOSE" == true ]]; then
  BASE_FLAGS+=("--show-trace")
fi

if [[ "$PRINT_BUILD_LOGS" == true ]]; then
  BASE_FLAGS+=("--print-build-logs")
fi

if [[ "$TRACE" == true ]]; then
  export NIX_TRACE=1
fi

if [[ "$INSPECT" == true ]]; then
  export QEMU_OPTS="-nographic"
fi

# Common functions
build_test() {
  local test_name=$1
  echo -e "${BLUE}Building test:${NC} $test_name"
  
  # Always use nix-fast-build if available
  if command -v nix-fast-build &> /dev/null; then
    echo -e "${GREEN}Using nix-fast-build for better performance${NC}"
    nix-fast-build --skip-cached "checks.$test_name" "${BASE_FLAGS[@]}"
  else
    echo -e "${YELLOW}nix-fast-build not available, using standard nix build${NC}"
    nix build ".#checks.$test_name" "${BASE_FLAGS[@]}"
  fi
}

run_test() {
  local test_name=$1
  echo -e "${BLUE}Running test:${NC} $test_name"
  
  nix-build "./tests/$test_name.nix" -A driver "${BASE_FLAGS[@]}"
  
  if [[ "$DEBUG" == true ]]; then
    echo -e "${YELLOW}Debug mode: Starting VM without running tests${NC}"
    ./result/bin/nixos-test-driver --interactive
  else
    ./result/bin/nixos-test-driver
  fi
}

# Main execution
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Running NixOS VM test: ${YELLOW}$TEST_NAME${NC}"
echo -e "${GREEN}========================================${NC}"

# Add debug information
if [[ "$VERBOSE" == true ]]; then
  echo -e "${BLUE}Current directory:${NC} $(pwd)"
  echo -e "${BLUE}Test path:${NC} ./tests/$TEST_NAME.nix"
  ls -la "./tests/$TEST_NAME.nix" || echo -e "${RED}Test file not found!${NC}"
fi

# Check if test file exists
if [[ ! -f "./tests/$TEST_NAME.nix" ]]; then
  echo -e "${RED}Error: Test file ./tests/$TEST_NAME.nix does not exist${NC}"
  exit 1
fi

# Build and run the test
build_test "$TEST_NAME"
run_test "$TEST_NAME"

echo -e "${GREEN}Test completed.${NC}"