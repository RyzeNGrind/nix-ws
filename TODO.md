## - **repo**:_nix-cfg_**[Priority:Highest]**
  - refactor for DRY, remove unused code, git conventional commit based on current `git diff`
  - let user, nixconfig be defined at system level for minimal setup like live-usb, and proper home-manager managed user config across full setup machines
  - leverage frameworks: std, hive, flake-parts, flakelight, devmods
  - vm-test-run-liveusb-ssh-vpn seems to be stuck taking 10-20m running in a loop failing over tailscale?

- _hosts_:**[Priority:Higher]**
  - _liveusb_<_nix*_>: needs proven working ssh, static IP with WLAN DHCP fallback and VPN ssh remote accessibility. Address potential freezing issues during installation by booting with nomodeset at 1080p or a lower resolution, then configure NVIDIA driver properly in configuration.nix. Include rescue tools: gparted, testdisk, fsck, and boot-repair.
  - _nix-ws_: needs VFIO libvirtd for w11 sunshine host gaming with automated Powershell script to initialize IaC Windows VM. Ensure iGPU is set as primary in BIOS/UEFI for reliable boot display and configure NixOS to use both Intel and NVIDIA drivers for Xorg.

## - **device**:_openwrt1_**[Priority:Low]**
  - convert config to liminix <nixrtr0:4> rpi4 and build/test

## - **device**:_openwrt2_**[Priority:Low]**
  - convert config to liminix <nixrtr1:4> rpi4 and build/test

## - **device**:_nix-ws_**[Priority:Higher]**
  - migrate best working snippets of code from [github_repo:ryzengrind/_`nix-ws`_](https://github.com/RyzeNGrind/nix-ws) and recovered_etc and recovered_nix-ws, ensuring multi-GPU support with intel iGPU for host display and GTX 1050 Ti for additional display, while reserving RTX 4090 for VFIO passthrough.
  - add GPU drivers and configurations to configuration.nix for `nix-ws`:
    ```nix
    hardware.nvidia = {
      modesetting.enable = true;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    services.xserver.videoDrivers = [ "nvidia" ];
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];
    services.xserver = {
      enable = true;
      displayManager.sddm.enable = true;
      desktopManager.plasma5.enable = true;
    };
    hardware.nvidia.powerManagement.enable = true;
    services.logind.lidSwitch = "ignore";
    services.xserver.monitorSection = ''
      Modeline "3840x2160_60" 533.25 3840 3888 3920 4000 2160 2163 2168 2222 +hsync -vsync
    '';
    ```

# - **device**._nix-pc_**[Priority:Medium]**
  - migrate best working snippets of code from [github_repo:ryzengrind/_`nix-pc`_](https://github.com/RyzeNGrind/nix-pc) to [github_repo:ryzengrind/_nix-cfg_](https://github.com/RyzeNGrind/nix-cfg)
    - [<currently private repo, export 1password/agenix-**opnix** **PAT** accessible token>](https://github.com/brizzbuzz/opnix)

# - __llm_workflow__:**[Priority:Higher]**
  - integrate pre-commit validation infrastructure for AI-generated code
  - implement AI code generation guardrails including input sanitization and context-aware generation
  - set up Nix-specific testing framework for multi-level validation and continuous integration pipeline
  - establish rollback and recovery systems for AI-generated code failures
  - harden developer environment with editor integration and feedback-driven development mechanisms
  - deploy continuous validation infrastructure for cluster-wide monitoring and artifact verification
  -ensure roocode always allows and uses [_`mcp-nixos`_](https://github.com/utensils/mcp-nixos) to validate nix related generations
  -use context7 for just in time Docs context injection

# - __network__:**[Priority:Highest]** 
  - determine why no internet connectivity from openwrt2 LAN2 to nixos-liveusb in living room via PoE LAN eth connection despite `VLAN1` and static IP set. LAN1,3,4 working fine direct connections to _device_..
```[openwrt2](https://192.168.1.2/cgi-bin/luci/admin/network/diagnostics)
PING 192.168.1.15 (192.168.1.15): 56 data bytes

--- 192.168.1.15 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
traceroute to 192.168.1.15 (192.168.1.15), 20 hops max, 46 byte packets
 1  *
 2  *
 3  *
 4  192.168.1.2  77.764 ms !H
Server:		127.0.0.1
Address:	127.0.0.1:53

** server can't find 15.1.168.192.in-addr.arpa: NXDOMAIN


``` 
> **[TROUBLESHOOTING?]**(Yes > pass the `-L` / `--print-build-logs` flag.)
# git_repo trade-joural
- an app to automate and stick to your profitable trading plan and share with friends, use A2A to have them leverage [fraction.ai $FRAC](https://fraction-ai.gitbook.io/docs-v1)

- Stack: web3 interface, consider connecting to oracles like tradekeep.io private and public data sources. Users can provide custom ingests but all ingests and data should go through verification and sanitation to ensure agent quality improves over time but doesnt get creatively hindered in its own process or method

