#!/usr/bin/env bash
# Generate a visual graph of the nix-pc project topology
# This script creates a DOT file visualizing the relationships between components in nix-pc

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default output file
OUTPUT_FILE="nix-pc-topology.dot"
OUTPUT_SVG="nix-pc-topology.svg"
REPO_ROOT="${NIX_PC_PATH:-$HOME/nix-pc}"

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

Generate a visual graph of the nix-pc project topology.

Options:
  -p, --path PATH     Path to nix-pc repository (default: $REPO_ROOT)
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
    -p|--path)
      REPO_ROOT="$2"
      shift 2
      ;;
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

# Check if nix-pc repository exists
if [ ! -d "$REPO_ROOT" ]; then
  echo -e "${RED}Error: nix-pc repository not found at $REPO_ROOT${NC}"
  echo -e "${YELLOW}Use -p option to specify the correct path${NC}"
  exit 1
fi

# Check if flake.nix exists
if [ ! -f "$REPO_ROOT/flake.nix" ]; then
  echo -e "${RED}Error: flake.nix not found in $REPO_ROOT${NC}"
  echo -e "${YELLOW}Make sure you've specified the correct nix-pc repository path${NC}"
  exit 1
fi

echo -e "${BLUE}${BOLD}=== Generating nix-pc Project Topology ===${NC}"
echo -e "${BLUE}Repository Root:${NC} $REPO_ROOT"
echo -e "${BLUE}Output DOT File:${NC} $OUTPUT_FILE"
if [ "$SKIP_SVG" = false ]; then
  echo -e "${BLUE}Output SVG File:${NC} $OUTPUT_SVG"
fi

# Start creating the DOT file
cat > "$OUTPUT_FILE" << EOF
digraph "nix-pc NixOS Configuration Topology" {
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
  
  // Main configuration nodes
  flake [label="flake.nix\nNixOS Configuration", fillcolor="${GROUP_COLORS[flake]}", shape=folder];
  configuration [label="configuration.nix\nMain NixOS Config", fillcolor="${GROUP_COLORS[config]}", URL="configuration.nix"];
  home_ryzengrind [label="home-ryzengrind.nix\nHome Manager Config", fillcolor="${GROUP_COLORS[home]}", URL="home-ryzengrind.nix"];
  
  // Home Manager modules
  subgraph cluster_home {
    label="Home Manager Configuration";
    style=filled;
    color=lightgrey;
    
    home_1password_ssh_agent [label="home/1password-ssh-agent.nix", fillcolor="${GROUP_COLORS[home]}", URL="home/1password-ssh-agent.nix"];
    home_systemd_service [label="home/systemd/1password-ssh-bridge.service", fillcolor="${GROUP_COLORS[home]}", URL="home/systemd/1password-ssh-bridge.service"];
  }
  
  // Scripts
  subgraph cluster_scripts {
    label="Scripts";
    style=filled;
    color=lightgrey;
    
    script_1password_ssh_bridge [label="scripts/setup-1password-ssh-bridge.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/setup-1password-ssh-bridge.sh"];
    script_test_1password [label="scripts/test-1password-ssh.sh", fillcolor="${GROUP_COLORS[script]}", URL="scripts/test-1password-ssh.sh"];
  }
  
  // Modules
  subgraph cluster_modules {
    label="NixOS Modules";
    style=filled;
    color=lightgrey;
    
    modules_opnix [label="modules/opnix-config.nix", fillcolor="${GROUP_COLORS[module]}", URL="modules/opnix-config.nix"];
  }
  
  // Documentation
  subgraph cluster_docs {
    label="Documentation";
    style=filled;
    color=lightgrey;
    
    docs_1password_ssh [label="docs/1password-ssh-integration.md", fillcolor="${GROUP_COLORS[doc]}", URL="docs/1password-ssh-integration.md"];
  }
  
  // Overlays
  subgraph cluster_overlays {
    label="Overlays";
    style=filled;
    color=lightgrey;
    
    overlay_default [label="overlays/default.nix", fillcolor="${GROUP_COLORS[config]}", URL="overlays/default.nix"];
    overlay_default_bash [label="overlays/default-bash.nix", fillcolor="${GROUP_COLORS[config]}", URL="overlays/default-bash.nix"];
  }
  
  // Connections between components
  flake -> configuration [label="imports"];
  flake -> home_ryzengrind [label="imports"];
  flake -> overlay_default [label="uses"];
  
  home_ryzengrind -> home_1password_ssh_agent [label="imports"];
  home_1password_ssh_agent -> home_systemd_service [label="configures"];
  home_1password_ssh_agent -> script_1password_ssh_bridge [label="executes"];
  script_1password_ssh_bridge -> script_test_1password [label="tested by"];
  
  // opnix integration
  flake -> modules_opnix [label="imports"];
  home_ryzengrind -> modules_opnix [label="uses secrets from"];
  
  // Documentation connections
  docs_1password_ssh -> home_1password_ssh_agent [label="documents"];
  docs_1password_ssh -> script_1password_ssh_bridge [label="documents"];
  docs_1password_ssh -> script_test_1password [label="documents"];
  
  // Configuration connections
  configuration -> overlay_default [label="uses"];
  configuration -> overlay_default_bash [label="uses"];
  
  // Label
  labelloc="t";
  label="nix-pc Configuration Topology with 1Password SSH Agent Integration";
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
echo -e "${BLUE}The topology diagram shows the relationships between components in your nix-pc configuration.${NC}"
echo -e "${BLUE}Key components for 1Password SSH integration:${NC}"
echo -e "  - ${YELLOW}home/1password-ssh-agent.nix${NC}: Home Manager module for 1Password SSH"
echo -e "  - ${YELLOW}home/systemd/1password-ssh-bridge.service${NC}: Service definition"
echo -e "  - ${YELLOW}scripts/setup-1password-ssh-bridge.sh${NC}: SSH bridge script"
echo -e "  - ${YELLOW}scripts/test-1password-ssh.sh${NC}: Test script for SSH agent"
echo -e "  - ${YELLOW}docs/1password-ssh-integration.md${NC}: Documentation"

echo -e "\n${BLUE}To understand how these components migrated to nix-cfg:${NC}"
echo -e "  1. View the nix-cfg topology: ${YELLOW}./scripts/nix-topology-graph.sh${NC}"
echo -e "  2. Compare the two topologies to see how the components were integrated"
echo -e "  3. See the migration guide in ${YELLOW}docs/1password-nixos-deployment.md${NC}"