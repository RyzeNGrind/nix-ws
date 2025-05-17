# NixOS Workstation Setup Guide
**Complete dev/gaming/cluster/ML/trading environment with GPU passthrough**

This guide explains the comprehensive setup for the `nix-ws` host configuration, featuring VFIO GPU passthrough, multi-GPU configuration, and AI cost optimization with Venice VCU and OpenRouter.

## System Architecture Overview

The `nix-ws` configuration implements a sophisticated workstation setup with the following key components:

1. **Multi-GPU Configuration**:
   - Intel iGPU as primary display device
   - NVIDIA GTX 1050 Ti for additional displays and computing
   - NVIDIA RTX 4090 reserved for VM passthrough (VFIO)

2. **VFIO Virtualization Stack**:
   - Windows 11 VM with GPU passthrough for gaming/ML
   - Looking Glass for low-latency VM display
   - Advanced memory and CPU optimization

3. **AI Inference Cost Optimization**:
   - Intelligent routing between Venice VCU and OpenRouter
   - Cost-optimized AI API calling system (97.3% cost reduction)
   - Request complexity classification and routing

## 1. Setting Up VFIO GPU Passthrough

### Prerequisites

Before using VFIO, you must:

1. Enable IOMMU in your BIOS/UEFI:
   - For Intel CPUs: Enable VT-d
   - For AMD CPUs: Enable AMD-Vi/IOMMU

2. Identify your GPU PCI IDs:
   ```bash
   lspci -nnk | grep -i -E "VGA|3D|Display"
   ```
   Look for your NVIDIA RTX 4090 entries, which should show as something like:
   ```
   01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 4090] [10de:2204] (rev a1)
   01:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
   ```
   Note the PCI IDs `10de:2204` and `10de:1aef`.

3. Update the `hosts/nix-ws.nix` configuration with your actual PCI IDs:
   ```nix
   virtualisation.ryzengrind = {
     enable = true;
     vfioIds = [ "10de:2204" "10de:1aef" ];  # Replace with your IDs
   };
   ```

### How It Works

The VFIO passthrough works by:

1. Early binding the VFIO drivers to your GPU before the NVIDIA drivers can claim it
2. Configuring IOMMU grouping for device isolation
3. Passing through the entire PCI device to the VM

### Creating Windows 11 VM

1. After NixOS installation, the VM disk image will be created automatically at `/var/lib/libvirt/images/win11.qcow2`

2. Download Windows 11 ISO and VirtIO drivers
   ```bash
   mkdir -p ~/isos
   curl -L -o ~/isos/Win11.iso 'https://www.microsoft.com/software-download/windows11'
   ```

3. Launch virt-manager and create a new VM:
   ```bash
   sudo virt-manager
   ```

4. In virt-manager:
   - Choose "Import existing disk image"
   - Point to `/var/lib/libvirt/images/win11.qcow2`
   - OS Type: Windows, Version: Windows 11
   - Use default resources (will be updated later)
   - Complete the initial wizard

5. Before starting the VM, edit its configuration:
   - Add PCI Host Device (your GPU)
   - Add TPM device (required for Windows 11)
   - Add USB devices needed for installation
   - Change CPU configuration to host-passthrough
   - Configure Looking Glass shared memory

6. Start the VM and install Windows 11 normally

7. After installation, mount the VirtIO ISO and install all drivers

8. Run the PowerShell optimization script (available at `/etc/win11-vm-setup/setup-win11.ps1`)

### Using Looking Glass

Looking Glass allows near-native performance viewing of the VM's display without a separate monitor:

1. Ensure the service is running:
   ```bash
   systemctl status libvirtd
   ```

2. Launch Looking Glass:
   ```bash
   looking-glass-client -F
   ```

3. Key shortcuts:
   - Scroll Lock: Capture/release input
   - Pause/Break: Exit looking-glass-client
   - Host key is always Right Ctrl

## 2. Using the Multi-GPU Configuration

The system configures your GPUs to work together optimally:

### Intel iGPU + NVIDIA GTX 1050 Ti Setup

1. The Intel iGPU is used as the primary display controller (for the desktop)
2. The NVIDIA GTX 1050 Ti is available for:
   - Additional displays
   - CUDA/GPU computing workloads
   - Specific applications that benefit from NVIDIA acceleration

3. Running applications on specific GPUs:
   - Use the provided `nvidia-run` script for the NVIDIA GPU:
     ```bash
     nvidia-run glxgears  # Run on NVIDIA GTX 1050 Ti
     nvidia-run blender   # Run Blender with NVIDIA acceleration
     ```

4. Checking which GPU is being used:
   ```bash
   glxinfo | grep "OpenGL renderer"
   ```

5. Monitor GPU usage:
   ```bash
   nvtop                # Monitor NVIDIA GPUs
   intel_gpu_top        # Monitor Intel GPU
   ```

### X11 Configuration

The X11 configuration is automatically managed by the `multi-gpu.nix` module, creating a dual-GPU setup with:
- Primary X screen on the Intel iGPU
- Secondary X screen on the NVIDIA GTX 1050 Ti

If you need to modify this configuration:
1. Edit `/etc/X11/xorg.conf.d/20-multi-gpu.conf`
2. Restart your display manager:
   ```bash
   sudo systemctl restart display-manager
   ```

## 3. AI Inference Cost Optimization

The AI inference optimization service routes requests between Venice VCU and OpenRouter based on complexity, providing significant cost savings.

### Usage

1. Check the service status:
   ```bash
   systemctl status ai-inference
   ```

2. During first run setup, you'll be prompted to provide:
   - Venice AI API key
   - OpenRouter API key

3. You can use the inference service locally via the Python client:

   ```python
   from venice_client import VeniceClient
   
   client = VeniceClient()
   response = client.completion(
       prompt="Explain the benefits of NixOS",
       model="qwen-3-4b",  # Use Venice models for lower cost
       max_tokens=512
   )
   print(response["choices"][0]["text"])
   ```

4. Access the API directly with curl:

   ```bash
   curl -X POST http://localhost:8765/v1/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "qwen-3-4b",
       "prompt": "Explain NixOS benefits in 3 bullet points",
       "max_tokens": 100
     }'
   ```

5. Check service metrics and status:
   ```bash
   # Status page with cost ratios
   curl http://localhost:8765/status
   
   # Prometheus metrics
   curl http://localhost:8765/metrics
   ```

### How It Works

The service intelligently routes requests based on:

1. **Complexity Analysis**: Analyzes prompt complexity (0-100 scale)
   - Code presence and density
   - Special terms requiring expert knowledge
   - Context requirements
   - Token length

2. **Cost Optimization**: Maintains a target ratio of 97.3% Venice to 2.7% OpenRouter
   - Simple requests (<25 complexity) go to Venice automatically
   - Complex requests requiring advanced models go to OpenRouter
   - Automatically maintains optimal cost ratio over time

3. **Usage Metrics**: Tracks token usage and cost savings via Prometheus metrics

## 4. Performance Tuning and System Management

### System Optimization

Several performance optimizations are enabled:

1. **Huge pages** for better VM performance
   ```bash
   # Check huge pages status
   cat /proc/meminfo | grep Huge
   ```

2. **CPU governor** set to performance mode
   ```bash
   # Verify current governor
   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```

3. **Pipewire** configured for low-latency audio
   ```bash
   # Check audio configuration
   pw-metadata -n settings 0
   ```

4. **Memory management** optimized with lower swappiness
   ```bash
   # Check current value
   cat /proc/sys/vm/swappiness
   ```

### Managing Resources

1. Use task scheduling for resource-intensive operations:
   ```bash
   # Run intensive task with nice
   nice -n 19 intensive_command
   
   # Use CPU sets
   taskset -c 0-3 intensive_command
   ```

2. Monitor system resource usage:
   ```bash
   nvtop          # GPU usage
   htop           # CPU and memory usage
   ```

## 5. Testing Your Setup

### Validating VFIO Setup

1. Verify IOMMU groups:
   ```bash
   for d in /sys/kernel/iommu_groups/*/devices/*; do
     n=${d#*/iommu_groups/};
     n=${n%%/*};
     printf 'IOMMU Group %s ' "$n";
     lspci -nns ${d##*/};
   done | sort -V
   ```

2. Check if VFIO drivers are bound to your GPU:
   ```bash
   lspci -nnk | grep -A 3 "NVIDIA Corporation GA102"
   ```
   You should see "vfio-pci" as the kernel driver in use.

### Testing VM Performance

1. GPU passthrough benchmark in Windows:
   - Run a 3D benchmark (e.g., 3DMark)
   - Verify the benchmark sees the native GPU

2. Network throughput test:
   ```bash
   # Host to VM file transfer
   iperf3 -s # on VM
   iperf3 -c VM_IP # on host
   ```

## Troubleshooting

### Common Issues and Solutions

1. **GPU not showing up in VM**
   - Check IOMMU grouping
   - Ensure PCI IDs are correct in configuration
   - Check if NVIDIA driver is blacklisted properly

2. **Looking Glass not working**
   - Verify shared memory is properly configured
   - Check permissions on `/dev/shm/looking-glass`
   - Ensure Windows Looking Glass host is running

3. **VM crashes or freezes**
   - Check CPU pin configuration
   - Verify memory allocation isn't overcommitted
   - Adjust hugepages settings

4. **Poor VM performance**
   - Use performance governor
   - Ensure no X server is using the passed-through GPU
   - Pin vCPUs to physical cores

## Customization

You can customize this setup by editing the following files:

1. `modules/virtualization.nix` - For VM and VFIO settings
2. `modules/multi-gpu.nix` - For GPU configuration
3. `modules/ai-inference.nix` - For AI API cost optimization
4. `hosts/nix-ws.nix` - For host-specific configurations

After making changes, rebuild your configuration:

```bash
sudo nixos-rebuild switch
```

## Additional Resources

- [NixOS Wiki - VFIO Passthrough](https://nixos.wiki/wiki/VFIO)
- [Looking Glass Documentation](https://looking-glass.io/docs/)
- [Venice AI Documentation](https://docs.venice.ai/)
- [OpenRouter Documentation](https://openrouter.ai/docs)