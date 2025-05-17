#!/usr/bin/env bash
# identify-gpus.sh
# Utility script to identify GPU PCI IDs for VFIO passthrough configuration
# Usage: ./scripts/identify-gpus.sh

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}${BLUE}=== GPU Identification Utility for VFIO Configuration ===${RESET}\n"

# Check for required utilities
for cmd in lspci lsmod grep sort; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required command '$cmd' not found. Please install the pciutils and coreutils packages.${RESET}"
        exit 1
    fi
done

# Function to print a divider
print_divider() {
    printf "%.s-" {1..80}
    echo
}

# Function to check IOMMU status
check_iommu() {
    echo -e "${CYAN}Checking IOMMU status...${RESET}"
    
    local iommu_enabled=0
    
    # Check for Intel VT-d or AMD-Vi
    if dmesg | grep -E "DMAR|AMD-Vi" | grep -q enabled; then
        iommu_enabled=1
    elif grep -q "intel_iommu=on\|amd_iommu=on" /proc/cmdline; then
        iommu_enabled=1
    fi
    
    if [ $iommu_enabled -eq 1 ]; then
        echo -e "${GREEN}✓ IOMMU appears to be enabled${RESET}"
    else
        echo -e "${YELLOW}⚠ IOMMU might not be enabled! You need to enable VT-d/AMD-Vi in BIOS and add 'intel_iommu=on' or 'amd_iommu=on' to your kernel parameters.${RESET}"
    fi
    
    echo
}

# List all GPUs with their PCI IDs
list_gpus() {
    echo -e "${CYAN}Identifying all GPUs in the system...${RESET}"
    
    echo -e "${MAGENTA}GPU devices:${RESET}"
    lspci -nnk | grep -A 3 -E "VGA|3D|Display" | grep -v "^--" | sed 's/^/  /'
    
    echo
    echo -e "${BLUE}NVIDIA GPUs with their PCI IDs:${RESET}"
    lspci -nnvD | grep -A 1 NVIDIA | grep -v "^--" | grep -v "Subsystem" | sed 's/^/  /'
    
    echo
    echo -e "${BLUE}AMD GPUs with their PCI IDs:${RESET}"
    lspci -nnvD | grep -A 1 "AMD\|ATI" | grep -E "VGA|3D|Display" | grep -v "^--" | grep -v "Subsystem" | sed 's/^/  /'
    
    echo
    echo -e "${BLUE}Intel GPUs with their PCI IDs:${RESET}"
    lspci -nnvD | grep -A 1 "Intel Corporation" | grep -E "VGA|3D|Display" | grep -v "^--" | grep -v "Subsystem" | sed 's/^/  /'
    
    echo
}

# Show IOMMU grouping
show_iommu_groups() {
    echo -e "${CYAN}Checking IOMMU groups...${RESET}"
    
    if [ ! -d /sys/kernel/iommu_groups ]; then
        echo -e "${YELLOW}⚠ IOMMU groups directory not found. IOMMU might not be enabled.${RESET}"
        return
    fi
    
    echo -e "${BLUE}IOMMU Groups:${RESET}"
    for d in /sys/kernel/iommu_groups/*/devices/*; do
        if [ -e "$d" ]; then
            n=${d#*/iommu_groups/}
            n=${n%%/*}
            printf "  IOMMU Group %s " "$n"
            lspci -nns "${d##*/}"
        fi
    done | sort -V
    
    echo
}

# Generate NixOS configuration snippets
generate_nixos_snippet() {
    echo -e "${CYAN}Generating NixOS configuration snippets...${RESET}"
    
    # Get all NVIDIA GPU PCI IDs
    local nvidia_ids=$(lspci -nn | grep -i "NVIDIA" | grep -v "Audio" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}\]' | tr -d '[]')
    local nvidia_audio_ids=$(lspci -nn | grep -i "NVIDIA" | grep "Audio" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}\]' | tr -d '[]')
    
    echo -e "${MAGENTA}NixOS configuration for VFIO GPU passthrough:${RESET}"
    
    echo -e "${GREEN}For virtualization.nix module:${RESET}"
    echo -e "  virtualisation.ryzengrind = {"
    echo -e "    enable = true;"
    echo -e "    vfioIds = [${YELLOW} # For RTX 4090 (replace with actual IDs)${RESET}"
    
    # If we found any NVIDIA IDs, include them
    if [ -n "$nvidia_ids" ]; then
        for id in $nvidia_ids; do
            echo -e "      \"$id\""
        done
    else
        echo -e "      \"10de:2204\" # Replace with your GPU ID"
    fi
    
    if [ -n "$nvidia_audio_ids" ]; then
        for id in $nvidia_audio_ids; do
            echo -e "      \"$id\""
        done
    else
        echo -e "      \"10de:1aef\" # Replace with your GPU audio controller ID"
    fi
    
    echo -e "    ];"
    echo -e "  };"
    
    echo
    
    # Identify PCI bus IDs for multi-gpu.nix
    local intel_busid=$(lspci -D | grep -i "VGA.*Intel" | head -n 1 | cut -d' ' -f1)
    local nvidia_busid=$(lspci -D | grep -i "VGA.*NVIDIA" | grep -v "Audio" | head -n 1 | cut -d' ' -f1)
    local nvidia_busid2=$(lspci -D | grep -i "VGA.*NVIDIA" | grep -v "Audio" | tail -n 1 | cut -d' ' -f1)
    
    if [ -z "$intel_busid" ]; then intel_busid="PCI:0:2:0"; fi
    if [ -z "$nvidia_busid" ]; then nvidia_busid="PCI:1:0:0"; fi
    if [ -z "$nvidia_busid2" ]; then nvidia_busid2="PCI:2:0:0"; fi

    # Convert the PCI bus ID format from XX:XX.X to PCI:X:XX:X
    format_pci_id() {
        local id="$1"
        if [[ $id == *":"* && $id == *"."* ]]; then
            local domain=$(echo $id | cut -d':' -f1)
            local bus=$(echo $id | cut -d':' -f2 | cut -d'.' -f1)
            local slot_func=$(echo $id | cut -d'.' -f2)
            echo "PCI:$bus:$domain:$slot_func"
        else
            echo "$id"
        fi
    }

    intel_busid_formatted=$(format_pci_id "$intel_busid")
    nvidia_busid_formatted=$(format_pci_id "$nvidia_busid")
    nvidia_busid2_formatted=$(format_pci_id "$nvidia_busid2")
    
    echo -e "${GREEN}For multi-gpu.nix module:${RESET}"
    echo -e "  hardware.nvidia-multi-gpu = {"
    echo -e "    enable = true;"
    echo -e "    intelPrimary = true;"
    echo -e "    intelPciBusId = \"$intel_busid_formatted\";       # Intel iGPU"
    echo -e "    nvidia1050PciBusId = \"$nvidia_busid_formatted\";  # GTX 1050 Ti"
    echo -e "    nvidia4090PciBusId = \"$nvidia_busid2_formatted\";  # RTX 4090 (for passthrough)"
    echo -e "  };"
    
    echo
    echo -e "${YELLOW}Note: Always double-check these values with 'lspci -nnk'${RESET}"
    echo
}

# Main script execution
print_divider
check_iommu
print_divider
list_gpus
print_divider
show_iommu_groups
print_divider
generate_nixos_snippet
print_divider

echo -e "${BOLD}${GREEN}Complete! Use this information to configure your VFIO setup in your NixOS configuration.${RESET}"
echo -e "${BOLD}Next steps:${RESET}"
echo -e "1. Edit ${CYAN}modules/virtualization.nix${RESET} with the correct PCI IDs"
echo -e "2. Edit ${CYAN}modules/multi-gpu.nix${RESET} with the correct PCI bus IDs"
echo -e "3. Run ${CYAN}sudo nixos-rebuild switch${RESET} to apply the configuration"
echo -e "4. Reboot and verify your VFIO setup"
echo