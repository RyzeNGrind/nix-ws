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

- Stack: web3 interface, consider connecting to oracles like tradekeep.io private and public data sources. Users can provide custom ingests but all ingests and data should go through verification and sanitation to ensure agent quality improves over time but doesnt get creatively hindered in its own process or method.
  - Consider integration with [fractionai.xyz](fractionai.xyz) for agent automation on web3 and reward pooling.

## **trading plan**: only enter trades on 100K, 200K after ensuring MTA(Multi-Timeframe Analysis{1D>4H>1H>15m>5m>1m}) gives us higher TF direction and price action meets 3 strict criteria {C1,C2,C3}.

> Proof of Marked up TradingView Chart with Criterias:{C1:C3}=Proof of Permission to enter trade on account(live/paper demo). 
### *risk management*:  

# - __documentation philosophy__:**[Priority:Highest]**
  - implement [_`kattelhasen`_](https://srid.ca/zettelkasten) style site markdown for structured knowledge linking and retrieval
  - migrate documentation to [_`emanote`_](https://emanote.srid.ca/) for enhanced navigation, folgezettel sequencing, and bidirectional linking
  - develop site structure for [_`ryzengrind.xyz`_](http://ryzengrind.xyz) following networked thought principles
  - integrate LLM-friendly markdown patterns with explicitly tagged metadata and relation indicators
  - establish commonmark compliant document structure with semantic sectioning and typed links
  - implement knowledge graph visualization for related concepts and dependency chains
  - create frequent connection points between technical implementations and conceptual documentation
  - maintain "evergreen" living documentation that evolves alongside code implementations
  - use folgezettel numbering for establishing clear hierarchical relationships while preserving network linking
  - capture decision contexts with dated journal entries linked to implementation notes
  - design prompt templates embedded in documentation for consistent LLM guidance
  - establish clear separation between implementation details, conceptual understanding, and procedural knowledge

# - __nix build system__:**[Priority:High]**
  - adopt **nix-fast-build** as the default builder for all future flaking and nixing operations
  - integrate parallel evaluation with `nix-eval-jobs` for accelerated multi-system builds
  - implement remote building infrastructure with optimized source transfer protocols
  - configure Cachix and Attic binary cache integration for distributed team development
  - establish standardized CI output formatting with JUNIT reporting
  - implement build skipping for cached derivations to optimize development workflows
  - create specialized build profiles for different hardware targets (aarch64, x86_64)
  - set up flake-based automated testing integrated with nix-fast-build
  - configure the following command as the standard build pattern:
    ```nix
    nix-fast-build --skip-cached --systems "$(nix eval --raw --impure --expr builtins.currentSystem)" --result-format junit --result-file result.xml
    ```
  - evaluate parallel build resource requirements for local vs remote execution
  - document build process expectations for kotlin-generated-containers and flavor-backshots

# - __terminal_integration__:**[Priority:High]**
  - implement terminal emulator selection matrix prioritizing GPU-accelerated solutions and NixOS integration
  - configure [_`ghostty`_](https://ghostty.org) as primary terminal emulator for native performance and MCP protocol support
    ```nix
    # flake.nix terminal module snippet
    inputs.ghostty.url = "github:tryghost/ghostty-nix";
    outputs = { nixpkgs, ghostty, ... }: {
      nixosModules.terminals = { config, ... }: {
        imports = [ ghostty.nixosModules.default ];
        environment.systemPackages = [ ghostty.packages.${config.nixpkgs.system}.default ];
        programs.ghostty = {
          enable = true;
          settings = {
            font-family = "JetBrainsMono Nerd Font Mono";
            font-size = 12.5;
            window-padding-x = 15;
            window-padding-y = 15;
            cursor-style = "beam";
            cursor-blink-interval = 750;
            cursor-blink-mode = "on";
            background-opacity = 0.96;
          };
        };
      };
    };
    ```
  - add fallback support for Alacritty as lightweight cross-platform alternative
  - provide MCP-aware terminal integration with NixOS for seamless interaction between shells and development tools
  - configure WebSSH for secure remote terminal access from web browsers
    ```nix
    # webssh.nix
    { config, pkgs, ... }:
    {
      services.webssh = {
        enable = true;
        port = 8888;
        credentialless = false;
        host = "0.0.0.0";
        package = pkgs.python3Packages.webssh;
        extraArgs = "--xsrf=False --policy=reject"; # Strict security
      };
      networking.firewall.allowedTCPPorts = [ 8888 ];
    }
    ```
  - establish mobile-friendly terminal access via Qute/Termux for Android devices
  - create unified shell configuration management across all terminal types:
    ```nix
    # shared shell configuration
    home.file.".config/shell/common.sh".text = ''
      # Common shell settings across all terminals
      export EDITOR=nvim
      export VISUAL=nvim
      export TERM=xterm-256color
      export COLORTERM=truecolor
      
      # Path configuration for development tools
      export PATH=$HOME/.local/bin:$PATH
      
      # MCP integration helpers
      source ${config.xdg.configHome}/mcp/shell-integration.sh
    '';
    ```
  - implement terminal multiplexer auto-configuration (tmux, zellij) for persistent sessions across access methods
  - configure terminal-specific flake shells for development environment consistency:
    ```nix
    # Create project-specific environments
    devShells.${system}.terminals = pkgs.mkShell {
      buildInputs = with pkgs; [
        ghostty
        alacritty
        python3Packages.webssh
        zellij
        tmux
      ];
      shellHook = ''
        export TERM_INTEGRATION_PATH="$PWD/.terminal-integration"
        echo "Terminal development environment activated"
      '';
    };
