#!/usr/bin/env bash
# Generate a combined visual graph showing migration from nix-pc to nix-cfg
# This script creates a DOT file visualizing the relationships and migration paths

set -eo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default output file
OUTPUT_FILE="nix-migration-topology.dot"
OUTPUT_SVG="nix-migration-topology.svg"
REPO_ROOT="$(pwd)"
NIX_PC_PATH="${NIX_PC_PATH:-$HOME/nix-pc}"

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
  ["nix_pc"]="#FDE0EF"
  ["nix_cfg"]="#DCEFFF"
  ["migration"]="#FFEC94"
)

show_usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Generate a visual graph showing migration path from nix-pc to nix-cfg.

Options:
  -p, --pc-path PATH   Path to nix-pc repository (default: $NIX_PC_PATH)
  -c, --cfg-path PATH  Path to nix-cfg repository (default: $REPO_ROOT)
  -o, --output FILE    Output DOT file (default: $OUTPUT_FILE)
  -s, --svg FILE       Output SVG file (default: $OUTPUT_SVG)
  -h, --help           Display this help message and exit
  
This script requires Graphviz to be installed for generating SVG files.
You can install it with: nix-env -iA nixpkgs.graphviz

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--pc-path)
      NIX_PC_PATH="$2"
      shift 2
      ;;
    -c|--cfg-path)
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

# Check if repositories exist
if [ ! -d "$NIX_PC_PATH" ]; then
  echo -e "${YELLOW}Warning: nix-pc repository not found at $NIX_PC_PATH${NC}"
  echo -e "${YELLOW}Use -p option to specify the correct path${NC}"
fi

if [ ! -d "$REPO_ROOT" ]; then
  echo -e "${RED}Error: nix-cfg repository not found at $REPO_ROOT${NC}"
  echo -e "${YELLOW}Use -c option to specify the correct path${NC}"
  exit 1
fi

echo -e "${BLUE}${BOLD}=== Generating Migration Topology ===${NC}"
echo -e "${BLUE}nix-pc Path:${NC} $NIX_PC_PATH"
echo -e "${BLUE}nix-cfg Path:${NC} $REPO_ROOT"
echo -e "${BLUE}Output DOT File:${NC} $OUTPUT_FILE"
if [ "$SKIP_SVG" = false ]; then
  echo -e "${BLUE}Output SVG File:${NC} $OUTPUT_SVG"
fi

# Start creating the DOT file
cat > "$OUTPUT_FILE" << EOF
digraph "NixOS Configuration Migration" {
  rankdir=TB;
  node [shape=box, style=filled, fontname="Arial"];
  edge [fontname="Arial", fontsize=10];
  
  // Define subgraphs for repositories
  subgraph cluster_nix_pc {
    label="nix-pc Repository";
    style=filled;
    color="${GROUP_COLORS[nix_pc]}";
    bgcolor="${GROUP_COLORS[nix_pc]}";
    
    // Main configuration files
    pc_flake [label="flake.nix", fillcolor="${GROUP_COLORS[flake]}"];
    pc_config [label="configuration.nix", fillcolor="${GROUP_COLORS[config]}"];
    pc_home [label="home-ryzengrind.nix", fillcolor="${GROUP_COLORS[home]}"];
    
    // 1Password SSH components
    pc_1p_ssh_agent [label="home/1password-ssh-agent.nix", fillcolor="${GROUP_COLORS[home]}"];
    pc_1p_service [label="home/systemd/1password-ssh-bridge.service", fillcolor="${GROUP_COLORS[home]}"];
    pc_1p_bridge_script [label="scripts/setup-1password-ssh-bridge.sh", fillcolor="${GROUP_COLORS[script]}"];
    pc_1p_test_script [label="scripts/test-1password-ssh.sh", fillcolor="${GROUP_COLORS[script]}"];
    pc_1p_docs [label="docs/1password-ssh-integration.md", fillcolor="${GROUP_COLORS[doc]}"];
  }
  
  subgraph cluster_nix_cfg {
    label="nix-cfg Repository";
    style=filled;
    color="${GROUP_COLORS[nix_cfg]}";
    bgcolor="${GROUP_COLORS[nix_cfg]}";
    
    // Main configuration files
    cfg_flake [label="flake.nix", fillcolor="${GROUP_COLORS[flake]}"];
    cfg_hosts_nix_ws [label="hosts/nix-ws.nix", fillcolor="${GROUP_COLORS[config]}"];
    cfg_home_ryzengrind [label="home/ryzengrind.nix", fillcolor="${GROUP_COLORS[home]}"];
    
    // Core modules
    cfg_module_1p_ssh_agent [label="modules/1password-ssh-agent.nix", fillcolor="${GROUP_COLORS[module]}"];
    cfg_home_module_1p_ssh [label="home/modules/1password-ssh.nix", fillcolor="${GROUP_COLORS[home]}"];
    cfg_module_wsl_integration [label="modules/wsl-integration.nix", fillcolor="${GROUP_COLORS[module]}"];
    
    // Scripts 
    cfg_1p_bridge_script [label="scripts/setup-1password-ssh-bridge.sh", fillcolor="${GROUP_COLORS[script]}"];
    cfg_1p_test_script [label="scripts/test-1password-ssh-agent.sh", fillcolor="${GROUP_COLORS[script]}"];
    cfg_deploy_script [label="scripts/nixos-deploy-with-1password.sh", fillcolor="${GROUP_COLORS[script]}"];
    
    // Documentation
    cfg_1p_docs [label="docs/1password-ssh-agent.md", fillcolor="${GROUP_COLORS[doc]}"];
    cfg_deployment_docs [label="docs/1password-nixos-deployment.md", fillcolor="${GROUP_COLORS[doc]}"];
    cfg_migration_docs [label="docs/nix-pc-to-nix-cfg-migration.md", fillcolor="${GROUP_COLORS[doc]}"];
    
    // Visualization
    cfg_topology_script [label="scripts/nix-topology-graph.sh", fillcolor="${GROUP_COLORS[script]}"];
    cfg_pc_topology_script [label="scripts/nix-pc-topology-graph.sh", fillcolor="${GROUP_COLORS[script]}"];
    cfg_migration_script [label="scripts/visualize-migration.sh", fillcolor="${GROUP_COLORS[script]}"];
  }
  
  // Migration edges with distinctive style
  edge [color="#FF6600", penwidth=2.0, style=dashed];
  
  // 1Password SSH Agent module migration
  pc_1p_ssh_agent -> cfg_module_1p_ssh_agent [label="Moved & Enhanced"];
  
  // Home Manager configuration migration
  pc_home -> cfg_home_ryzengrind [label="Restructured"];
  
  // Service migration
  pc_1p_service -> cfg_module_1p_ssh_agent [label="Integrated into module"];
  
  // Script migrations
  pc_1p_bridge_script -> cfg_1p_bridge_script [label="Updated"];
  pc_1p_test_script -> cfg_1p_test_script [label="Enhanced"];
  
  // Documentation migration
  pc_1p_docs -> cfg_1p_docs [label="Updated"];
  
  // Restore default edge style for internal relationships
  edge [color="black", penwidth=1.0, style=solid];
  
  // nix-pc internal relationships
  pc_flake -> pc_config;
  pc_flake -> pc_home;
  pc_home -> pc_1p_ssh_agent;
  pc_1p_ssh_agent -> pc_1p_service;
  pc_1p_ssh_agent -> pc_1p_bridge_script;
  pc_1p_bridge_script -> pc_1p_test_script [label="tests"];
  
  // nix-cfg internal relationships
  cfg_flake -> cfg_hosts_nix_ws;
  cfg_flake -> cfg_home_ryzengrind;
  cfg_home_ryzengrind -> cfg_home_module_1p_ssh;
  cfg_home_module_1p_ssh -> cfg_module_1p_ssh_agent;
  cfg_hosts_nix_ws -> cfg_module_wsl_integration;
  cfg_module_wsl_integration -> cfg_module_1p_ssh_agent [label="integrates"];
  cfg_module_1p_ssh_agent -> cfg_1p_bridge_script [label="executes"];
  cfg_1p_test_script -> cfg_1p_bridge_script [label="tests"];
  cfg_deploy_script -> cfg_1p_test_script [label="uses"];
  
  // New components (green)
  edge [color="#009900", penwidth=1.5];
  cfg_hosts_nix_ws -> cfg_deploy_script [label="deploys to remote hosts"];
  cfg_deploy_script -> cfg_deployment_docs [label="documented in"];
  cfg_migration_docs -> cfg_pc_topology_script [label="refers to"];
  cfg_migration_docs -> cfg_topology_script [label="refers to"];
  cfg_pc_topology_script -> cfg_migration_script [label="combined in"];
  cfg_topology_script -> cfg_migration_script [label="combined in"];
  
  // Label
  labelloc="t";
  label="Migration Path: nix-pc → nix-cfg";
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

echo -e "${GREEN}${BOLD}=== Migration Visualization Complete ===${NC}"
echo -e "${BLUE}The migration diagram shows how components have moved and evolved from nix-pc to nix-cfg.${NC}"
echo -e "\n${BLUE}This diagram helps to understand:${NC}"
echo -e "  1. ${YELLOW}Which components were migrated${NC}" 
echo -e "  2. ${YELLOW}How they were enhanced${NC}"
echo -e "  3. ${YELLOW}What new components were added${NC}"
echo -e "  4. ${YELLOW}How everything fits together in the new architecture${NC}"
echo -e "\n${BLUE}For more details, see the migration guide:${NC} ${YELLOW}docs/nix-pc-to-nix-cfg-migration.md${NC}"