# modules/mcp-configuration.nix
# Declarative MCP (Mission Control Panel) configuration for RooCode and Void Editor
# Provides cross-environment configuration with Venice/OpenRouter integration
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-configuration;

  # Helper functions
  escapeString = str: replaceStrings [ "\"" "\\" ] [ "\\\"" "\\\\" ] str;

  # Default command for connecting to local MCP servers in WSL
  wslConnectCommand = user: cmd: ''wsl -d NixOS -u ${user} /bin/bash -c "${escapeString cmd}"'';

  # Generate MCP server JSON configuration
  generateMcpServer = name: server: ''
    "${name}": {
      ${optionalString (server.command != null) ''
      "command": "${escapeString server.command}",
      ''}
      ${optionalString (server.url != null) ''
      "url": "${escapeString server.url}",
      ''}
      ${optionalString (server.args != null) ''
      "args": [
        ${concatStringsSep ",\n        " (map (arg: "\"${escapeString arg}\"") server.args)}
      ],
      ''}
      ${optionalString (server.allowedTools != []) ''
      "alwaysAllow": [
        ${concatStringsSep ",\n        " (map (tool: "\"${escapeString tool}\"") server.allowedTools)}
      ],
      ''}
      ${optionalString (server.autoApprove != []) ''
      "autoApprove": [
        ${concatStringsSep ",\n        " (map (tool: "\"${escapeString tool}\"") server.autoApprove)}
      ],
      ''}
      ${optionalString server.disabled ''
      "disabled": true${if server.extraConfig != {} then "," else ""}
      ''}
      ${concatStringsSep ",\n      " (mapAttrsToList (k: v: "\"${escapeString k}\": ${if isString v then "\"${escapeString v}\"" else toString v}") server.extraConfig)}
    }
  '';

  # Create a Bash script to set up the MCP configuration
  setupScript = pkgs.writeScriptBin "setup-mcp-configuration" ''
    #!/bin/bash
    set -e

    # Ensure .roo directory exists
    mkdir -p ~/.roo

    # Generate project-specific MCP configuration
    cat > ~/.roo/mcp.json << 'EOF'
    {
      "mcpServers": {
        ${concatStringsSep ",\n        " (mapAttrsToList generateMcpServer cfg.projectServers)}
      }
    }
    EOF
    chmod 0600 ~/.roo/mcp.json

    # Generate global MCP configuration if enabled
    ${optionalString cfg.manageGlobalSettings ''
    mkdir -p "${cfg.globalConfigPath}"
    cat > "${cfg.globalConfigPath}/mcp_settings.json" << 'EOF'
    {
      "mcpServers": {
        ${concatStringsSep ",\n        " (mapAttrsToList generateMcpServer cfg.globalServers)}
      }
    }
    EOF
    chmod 0600 "${cfg.globalConfigPath}/mcp_settings.json"
    ''}

    echo "MCP Configuration updated successfully."
    ${optionalString cfg.debug ''
    echo "Project MCP configuration:"
    cat ~/.roo/mcp.json
    ${optionalString cfg.manageGlobalSettings ''
    echo "Global MCP configuration:"
    cat "${cfg.globalConfigPath}/mcp_settings.json"
    ''}
    ''}
  '';

  # Venice Router helpers
  veniceRouterEnv = if cfg.veniceRouterIntegration.enable then ''
    export VENICE_API_KEY='${cfg.veniceRouterIntegration.veniceApiKey}'
    export OPENROUTER_API_KEY='${cfg.veniceRouterIntegration.openRouterApiKey}'
    export VENICE_API_ENDPOINT='${cfg.veniceRouterIntegration.veniceApiEndpoint}'
    export OPENROUTER_API_ENDPOINT='${cfg.veniceRouterIntegration.openRouterApiEndpoint}'
  '' else "";
  
in {
  options.services.mcp-configuration = {
    enable = mkEnableOption "Enable declarative MCP configuration management";
    
    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug mode to print MCP configuration";
    };

    user = mkOption {
      type = types.str;
      default = "ryzengrind";
      description = "User for whom the MCP configuration should be generated";
    };
    
    environmentType = mkOption {
      type = types.enum [ "nixos" "nixos-wsl" "windows" ];
      default = if config.wsl.enable or false then "nixos-wsl" else "nixos";
      description = "Environment type for MCP configuration (nixos, nixos-wsl, or windows)";
    };

    manageGlobalSettings = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to manage global MCP settings in addition to project-local ones";
    };
    
    globalConfigPath = mkOption {
      type = types.str;
      default = "/home/${cfg.user}/.config/Void/User/globalStorage/rooveterinaryinc.roo-cline/settings";
      description = "Path to global RooCode MCP configuration directory";
    };

    veniceRouterIntegration = {
      enable = mkEnableOption "Integrate with Venice Router for AI inference cost optimization";
      
      veniceApiKey = mkOption {
        type = types.str;
        default = "";
        description = "API key for Venice AI";
      };
      
      openRouterApiKey = mkOption {
        type = types.str;
        default = "";
        description = "API key for OpenRouter";
      };

      veniceApiEndpoint = mkOption {
        type = types.str;
        default = "http://localhost:8765/v1";
        description = "Venice Router API endpoint";
      };
      
      openRouterApiEndpoint = mkOption {
        type = types.str;
        default = "https://openrouter.ai/api/v1";
        description = "OpenRouter API endpoint (direct, not through Venice Router)";
      };
    };
    
    # Project-specific MCP servers (in .roo/mcp.json)
    projectServers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          command = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Command to run for the MCP server";
          };
          
          url = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "URL to connect to for the MCP server";
          };
          
          args = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Arguments for the MCP server command";
          };
          
          allowedTools = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tools to always allow for the MCP server";
          };
          
          autoApprove = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tools to auto-approve for the MCP server";
          };

          disabled = mkOption {
            type = types.bool;
            default = false;
            description = "Whether the MCP server is disabled";
          };
          
          extraConfig = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Additional configuration for the MCP server";
          };
        };
      });
      default = {};
      description = "Project-specific MCP servers configuration";
    };
    
    # Global MCP servers (in the global settings file)
    globalServers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          command = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Command to run for the MCP server";
          };
          
          url = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "URL to connect to for the MCP server";
          };
          
          args = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Arguments for the MCP server command";
          };
          
          allowedTools = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tools to always allow for the MCP server";
          };
          
          autoApprove = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tools to auto-approve for the MCP server";
          };
          
          disabled = mkOption {
            type = types.bool;
            default = false;
            description = "Whether the MCP server is disabled";
          };
          
          extraConfig = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Additional configuration for the MCP server";
          };
        };
      });
      default = {};
      description = "Global MCP servers configuration";
    };
    
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically start the MCP configuration service";
    };
    
    taskMaster = {
      enable = mkEnableOption "Enable TaskMaster integration";
      
      anthropicApiKey = mkOption {
        type = types.str;
        default = "";
        description = "Anthropic API key for TaskMaster";
      };
      
      perplexityApiKey = mkOption {
        type = types.str;
        default = "";
        description = "Perplexity API key for TaskMaster";
      };
      
      model = mkOption {
        type = types.str;
        default = "claude-3-7-sonnet-20250219";
        description = "Default model for TaskMaster";
      };
      
      perplexityModel = mkOption {
        type = types.str;
        default = "sonar-pro";
        description = "Perplexity model for TaskMaster";
      };
      
      maxTokens = mkOption {
        type = types.int;
        default = 64000;
        description = "Maximum tokens for TaskMaster";
      };
      
      temperature = mkOption {
        type = types.float;
        default = 0.2;
        description = "Temperature parameter for TaskMaster";
      };
      
      defaultSubtasks = mkOption {
        type = types.int;
        default = 5;
        description = "Default number of subtasks for TaskMaster";
      };
      
      defaultPriority = mkOption {
        type = types.str;
        default = "medium";
        description = "Default priority for TaskMaster tasks";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Install the setup script
    environment.systemPackages = [ setupScript ];
    
    # Create a systemd service that updates the configuration on boot
    systemd.services.setup-mcp-configuration = mkIf cfg.autoStart {
      description = "Set up MCP configuration";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
        ExecStart = "${setupScript}/bin/setup-mcp-configuration";
        RemainAfterExit = true;
      };
    };
    
    # Define default MCP servers based on environment type and user configuration
    services.mcp-configuration.projectServers = mkMerge [
      # MCP Router - Always enabled
      {
        "mcp-router" = {
          command = "wsl";
          args = [
            "-d"
            "NixOS"
            "-u"
            cfg.user
            "/bin/bash"
            "-c"
            "export MCPR_TOKEN='${cfg.veniceRouterIntegration.openRouterApiKey}'; export NIX_CONNECT_TIMEOUT=15; export NIXPKGS_ALLOW_UNFREE=1; export NIXPKGS_ALLOW_INSECURE=1; source /etc/profile; nix-shell --option substitute true --option builders '' --option builders-use-substitutes false -p nodejs --run 'NODE_TLS_REJECT_UNAUTHORIZED=0 npx -y mcpr-cli@latest connect'"
          ];
        };
      }
      
      # TaskMaster - Conditionally enabled
      (mkIf cfg.taskMaster.enable {
        "taskmaster-ai" = {
          command = "wsl";
          args = [
            "-d"
            "NixOS"
            "-u"
            cfg.user
            "/bin/bash"
            "-c"
            ''
              export ANTHROPIC_API_KEY="${cfg.taskMaster.anthropicApiKey}"
              export PERPLEXITY_API_KEY="${cfg.taskMaster.perplexityApiKey}"
              export MODEL="${cfg.taskMaster.model}"
              export PERPLEXITY_MODEL="${cfg.taskMaster.perplexityModel}"
              export MAX_TOKENS=${toString cfg.taskMaster.maxTokens}
              export TEMPERATURE=${toString cfg.taskMaster.temperature}
              export DEFAULT_SUBTASKS=${toString cfg.taskMaster.defaultSubtasks}
              export DEFAULT_PRIORITY="${cfg.taskMaster.defaultPriority}"
              ${veniceRouterEnv}
              source /etc/profile
              nix-shell --option substitute true --option builders "" --option builders-use-substitutes false -p nodejs --run "NODE_TLS_REJECT_UNAUTHORIZED=0 npx -y --package=task-master-ai task-master-ai"
            ''
          ];
          allowedTools = [];
        };
      })

      # Venice Router Client - Conditionally enabled
      (mkIf cfg.veniceRouterIntegration.enable {
        "venice-openai-client" = {
          command = "wsl";
          args = [
            "-d"
            "NixOS"
            "-u"
            cfg.user
            "/bin/bash"
            "-c"
            ''
              export VENICE_API_KEY='${cfg.veniceRouterIntegration.veniceApiKey}';
              export OPENROUTER_API_KEY='${cfg.veniceRouterIntegration.openRouterApiKey}';
              export VENICE_API_ENDPOINT='${cfg.veniceRouterIntegration.veniceApiEndpoint}';
              export OPENROUTER_API_ENDPOINT='${cfg.veniceRouterIntegration.openRouterApiEndpoint}';
              source /etc/profile;
              nix-shell --option substitute true --option builders '''''' --option builders-use-substitutes false \
                -p nodejs python3 \
                --run 'NODE_TLS_REJECT_UNAUTHORIZED=0 npx -y @smithery/cli@latest run @utensils/openai-compat-proxy --port 3001 --host 127.0.0.1 --target http://localhost:8765/v1'
            ''
          ];
          allowedTools = [
            "openai_chat_completions"
            "openai_text_completions"
            "openai_embeddings"
          ];
        };
      })
    ];

    # Define default global MCP servers based on environment type
    services.mcp-configuration.globalServers = mkIf cfg.manageGlobalSettings {
      # Extended Nix tooling
      "mcp-nixos" = {
        command = "wsl";
        args = [
          "-d"
          "NixOS"
          "-u"
          cfg.user
          "/bin/bash"
          "-c"
          "source /etc/profile; nix-shell -p nodejs --run 'npx -y @smithery/cli@latest run @utensils/mcp-nixos --key 96516e07-71c8-42f7-a8fd-c13a4256754a'"
        ];
        allowedTools = [
          "nixos_search"
          "nixos_info"
          "nixos_stats"
          "home_manager_search"
          "home_manager_info"
          "home_manager_stats"
          "home_manager_list_options"
          "home_manager_options_by_prefix"
          "discover_tools"
          "get_tool_usage"
        ];
      };
      
      # Fetch tool for external resources
      "Fetch" = {
        url = "https://mcpstore.co/sse/67f13b99b66f446c3d8bed92";
        allowedTools = [ "fetch" ];
        disabled = false;
      };
    };
  };
}