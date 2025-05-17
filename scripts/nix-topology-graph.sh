#!/usr/bin/env bash
# Generate a visual graph of the Nix project topology
# This script creates a DOT file visualizing the relationships between components

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default output file
OUTPUT_FILE="nix-topology.dot"
OUTPUT_SVG="nix-topology.svg"
REPO_ROOT="$(pwd)"

# Define groups and their colors
declare -A GROUP_COLORS=(
  ["flake"]="#CCE5FF"
  ["module"]="#D1F0C2" 
  ["home"]="#FFD1DC"
  ["script"]="#FFE5B4"
  ["doc"]="#E0CFFF"
  ["test"]="#C2E0F0"
  ["secret"]="#FFD1DC"
  ["config"]="#FFF0C2"
)

show_usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Generate a visual graph of the Nix project topology.

Options:
  -o, --output FILE   Output DOT file (default: $OUTPUT_FILE)
  -s, --svg FILE      Output SVG file (default: $OUTPUT_SVG)
  -h, --help          Display this help message and exit
  
This script requires Graphviz to be installed for generating SVG files.
You can install it with: nix-env -iA nixpkgs.graphviz

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -s|--svg)
      OUTPUT_SVG="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}" >&2
      show_usage
      exit 1
      ;;
  esac
done

# Check if graphviz is installed
if ! command -v dot &> /dev/null; then
  echo -e "${YELLOW}Warning: Graphviz not found. SVG generation will be skipped.${NC}"
  echo -e "${YELLOW}You can install it with: nix-env -iA nixpkgs.graphviz${NC}"
  SKIP_SVG=true
else
  SKIP_SVG=false
fi

echo -e "${BLUE}${BOLD}=== Generating Nix Project Topology ===${NC}"
echo -e "${BLUE}Repository Root:${NC} $REPO_ROOT"
echo -e "${BLUE}Output DOT File:${NC} $OUTPUT_FILE"
if [ "$SKIP_SVG" = false ]; then
  echo -e "${BLUE}Output SVG File:${NC} $OUTPUT_SVG"
fi

# Start creating the DOT file
cat > "$OUTPUT_FILE" << EOF
digraph "NixOS Configuration Topology" {
  rankdir=TB;
  node [shape=box, style=filled, fontname="Arial"];
  edge [fontname="Arial", fontsize=10];
  
  // Define groups
  subgraph cluster_legend {
    label="Legend";
    node [shape=box, style=filled];
    legend_flake [label="Flake", fillcolor="${GROUP_COLORS[flake]}"];
    legend_module [label="Module", fillcolor="${GROUP_COLORS[module]}"];
    legend_home [label="Home Manager", fillcolor="${GROUP_COLORS[home]}"];
    legend_script [label="Script", fillcolor="${GROUP_COLORS[script]}"];
    legend_doc [label="Documentation", fillcolor="${GROUP_COLORS[doc]}"];
    legend_test [label="Test", fillcolor="${GROUP_COLORS[test]}"];
    legend_secret [label="Secret", fillcolor="${GROUP_COLORS[secret]}"];
    legend_config [label="Configuration", fillcolor="${GROUP_COLORS[config]}"];
  }
  
  // Main flake node
  flake [label="flake.nix\nNixOS Configurations", fillcolor="${GROUP_COLORS[flake]}", shape=folder];
  
  // Host configurations
  subgraph cluster_hosts {
    label="Host Configurations";
    style=filled;
    color=lightgrey;
    
    hosts_nix_ws [label="hosts/nix-ws.nix", fillcolor="${GROUP_COLORS[config]}", URL="hosts/nix-ws.nix"];
    hosts_liveusb [label="hosts/liveusb.nix", fillcolor="${GROUP_COLORS[config]}", URL="hosts/liveusb.nix"];
  }
  
  // NixOS modules
  subgraph cluster_modules {
    label="NixOS Modules";
    style=filled;
    color=lightgrey;
    
    module_common [label="modules/common-config.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/common-config.nix"];
    module_virtualization [label="modules/virtualization.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/virtualization.nix"];
    module_multi_gpu [label="modules/multi-gpu.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/multi-gpu.nix"];
    module_ai_inference [label="modules/ai-inference.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/ai-inference.nix"];
    module_overlay_networks [label="modules/overlay-networks.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/overlay-networks.nix"];
    module_wsl_integration [label="modules/wsl-integration.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/wsl-integration.nix"];
  }
  
  // Home Manager
  subgraph cluster_home {
    label="Home Manager Configuration";
    style=filled;
    color=lightgrey;
    
    home_ryzengrind [label="home/ryzengrind.nix", fillcolor="${GROUP_COLORS[home]}", URL="home/ryzengrind.nix"];
    home_1password_ssh [label="home/modules/1password-ssh.nix", fillcolor="${GROUP_COLORS[home]}", URL="home/modules/1password-ssh.nix"];
    module_1password_ssh_agent [label="modules/1password-ssh-agent.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/1password-ssh-agent.nix"];
  }
  
  // 1Password Integration
  subgraph cluster_1password {
    label="1Password Integration";
    style=filled;
    color=lightgrey;
    
    script_1password_ssh_bridge [label="scripts/setup-1password-ssh-bridge.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/setup-1password-ssh-bridge.sh"];
    script_1password_test [label="scripts/test-1password-ssh-agent.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/test-1password-ssh-agent.sh"];
    script_deploy [label="scripts/nixos-deploy-with-1password.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/nixos-deploy-with-1password.sh"];
    doc_1password_integration [label="docs/1password-nixos-deployment.md", fillcolor="${GROUP_COLORS[doc]}", URL="docs/1password-nixos-deployment.md"];
    module_mcp_1password [label="modules/mcp-1password.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/mcp-1password.nix"];
    module_mcp_secrets [label="modules/mcp-secrets.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/mcp-secrets.nix"];
  }

  // Testing
  subgraph cluster_testing {
    label="Testing";
    style=filled;
    color=lightgrey;
    
    script_run_vm_tests [label="scripts/run-vm-tests.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/run-vm-tests.sh"];
    test_nix_ws_min [label="tests/nix-ws-min.nix", fillcolor="${GROUP_COLORS[test]}", URL="tests/nix-ws-min.nix"];
    doc_testing_strategy [label="docs/testing-strategy.md", fillcolor="${GROUP_COLORS[doc]}", URL="docs/testing-strategy.md"];
  }
  
  // MCP Configuration
  subgraph cluster_mcp {
    label="MCP Configuration";
    style=filled;
    color=lightgrey;
    
    module_mcp_configuration [label="modules/mcp-configuration.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/mcp-configuration.nix"];
    script_test_mcp [label="scripts/test-mcp-connection.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/test-mcp-connection.sh"];
  }
  
  // Connections between components
  flake -> hosts_nix_ws [label="imports"];
  flake -> hosts_liveusb [label="imports"];
  
  hosts_nix_ws -> module_common [label="imports"];
  hosts_nix_ws -> module_virtualization [label="imports"];
  hosts_nix_ws -> module_multi_gpu [label="imports"];
  hosts_nix_ws -> module_ai_inference [label="imports"];
  hosts_nix_ws -> module_wsl_integration [label="imports"];
  
  // Home Manager connections
  flake -> home_ryzengrind [label="imports"];
  home_ryzengrind -> home_1password_ssh [label="imports"];
  home_1password_ssh -> module_1password_ssh_agent [label="imports"];
  
  // 1Password connections
  module_1password_ssh_agent -> script_1password_ssh_bridge [label="executes"];
  script_1password_test -> script_1password_ssh_bridge [label="tests"];
  script_deploy -> script_1password_test [label="uses"];
  
  // MCP connections
  module_mcp_configuration -> module_mcp_1password [label="integrates"];
  module_mcp_configuration -> module_mcp_secrets [label="uses"];
  
  // Testing connections
  flake -> script_run_vm_tests [label="runs"];
  script_run_vm_tests -> test_nix_ws_min [label="executes"];
  
  // OPNix integration
  flake -> module_mcp_1password [label="imports via common"];
  
  // Deployment flow
  script_deploy -> hosts_nix_ws [label="deploys"];
  script_deploy -> hosts_liveusb [label="deploys"];
  
  // Label
  labelloc="t";
  label="NixOS Configuration Topology with 1Password Integration and Remote Deployment";
}
EOF

echo -e "${GREEN}✓ DOT file generated: $OUTPUT_FILE${NC}"

# Generate SVG file if graphviz is installed
if [ "$SKIP_SVG" = false ]; then
  echo -e "${BLUE}Generating SVG diagram...${NC}"
  if dot -Tsvg "$OUTPUT_FILE" -o "$OUTPUT_SVG"; then
    echo -e "${GREEN}✓ SVG file generated: $OUTPUT_SVG${NC}"
    echo -e "${BLUE}You can view the diagram with any SVG viewer${NC}"
  else
    echo -e "${RED}✗ Failed to generate SVG file${NC}"
  fi
fi

echo -e "${GREEN}${BOLD}=== Topology Generation Complete ===${NC}"
echo -e "${BLUE}The topology diagram shows the relationships between components in your NixOS configuration.${NC}"
echo -e "${BLUE}Key components for 1Password SSH integration:${NC}"
echo -e "  - ${YELLOW}modules/1password-ssh-agent.nix${NC}: Home Manager module"
echo -e "  - ${YELLOW}home/modules/1password-ssh.nix${NC}: 1Password SSH configuration"
echo -e "  - ${YELLOW}scripts/setup-1password-ssh-bridge.sh${NC}: SSH bridge script"
echo -e "  - ${YELLOW}scripts/nixos-deploy-with-1password.sh${NC}: Deployment script with SSH agent"
echo -e "  - ${YELLOW}docs/1password-nixos-deployment.md${NC}: Comprehensive documentation"