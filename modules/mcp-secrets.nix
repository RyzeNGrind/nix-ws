# modules/mcp-secrets.nix
# Secret management for MCP configuration and AI inference services
# Uses sops-nix for secure encryption and management of API keys
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-secrets;
in {
  options.services.mcp-secrets = {
    enable = mkEnableOption "Enable secure API key management for MCP and AI services";

    user = mkOption {
      type = types.str;
      default = "ryzengrind";
      description = "User who will have access to the secrets";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group who will have access to the secrets";
    };

    keysFile = mkOption {
      type = types.str;
      default = "/etc/mcp-secrets.yaml";
      description = "Path to the sops-encrypted YAML file containing API keys";
    };

    defaultFolder = mkOption {
      type = types.str;
      default = "/run/mcp-secrets";
      description = "Default folder for secret files";
    };
  };

  config = mkIf cfg.enable {
    # Import sops module
    imports = [ <sops-nix/modules/sops> ];

    # Define the secrets we want sops to manage
    sops = {
      defaultSopsFile = cfg.keysFile;
      # Actually define the secrets
      secrets = {
        "venice_api_key" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
        };
        "openrouter_api_key" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
        };
        "anthropic_api_key" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
        };
        "perplexity_api_key" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
        };
        "mcpr_token" = {
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
        };
      };
    };

    # Ensure the ai-inference service uses the sops-managed secrets if both are enabled
    services.ai-inference = mkIf config.services.ai-inference.enable {
      veniceApiKey = mkIf (config.sops.secrets ? "venice_api_key") (
        "${config.sops.secrets.venice_api_key.path}"
      );
      openRouterApiKey = mkIf (config.sops.secrets ? "openrouter_api_key") (
        "${config.sops.secrets.openrouter_api_key.path}"
      );
    };

    # Ensure the mcp-configuration service uses the sops-managed secrets if both are enabled
    services.mcp-configuration = mkIf config.services.mcp-configuration.enable {
      veniceRouterIntegration = mkIf config.services.ai-inference.enable {
        veniceApiKey = mkIf (config.sops.secrets ? "venice_api_key") (
          "${config.sops.secrets.venice_api_key.path}"
        );
        openRouterApiKey = mkIf (config.sops.secrets ? "openrouter_api_key") (
          "${config.sops.secrets.openrouter_api_key.path}"
        );
      };

      # TaskMaster API keys
      taskMaster = {
        anthropicApiKey = mkIf (config.sops.secrets ? "anthropic_api_key") (
          "${config.sops.secrets.anthropic_api_key.path}"
        );
        perplexityApiKey = mkIf (config.sops.secrets ? "perplexity_api_key") (
          "${config.sops.secrets.perplexity_api_key.path}"
        );
      };
    };

    # Create a systemd service to setup the .roo/mcp.json and global MCP settings
    systemd.services.mcp-secrets-setup = mkIf (config.services.mcp-configuration.enable && config.sops.secrets ? "mcpr_token") {
      description = "Setup MCP API tokens from secrets";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      before = [ "setup-mcp-configuration.service" ];

      script = ''
        # Ensure the token value is available to mcp-router
        export MCPR_TOKEN=$(cat ${config.sops.secrets.mcpr_token.path})
        
        # Update mcp-router token in user's .roo/mcp.json if it exists
        if [ -f "/home/${cfg.user}/.roo/mcp.json" ]; then
          ${pkgs.jq}/bin/jq --arg token "$MCPR_TOKEN" '.mcpServers."mcp-router".args[11] = .mcpServers."mcp-router".args[11] | sub("MCPR_TOKEN='\''[^'\'']*'\''"; "MCPR_TOKEN='\''" + $token + "'\''")' /home/${cfg.user}/.roo/mcp.json > /home/${cfg.user}/.roo/mcp.json.new
          mv /home/${cfg.user}/.roo/mcp.json.new /home/${cfg.user}/.roo/mcp.json
          chown ${cfg.user}:${cfg.group} /home/${cfg.user}/.roo/mcp.json
          chmod 0600 /home/${cfg.user}/.roo/mcp.json
        fi
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "root"; # Needs root to read secrets
        RemainAfterExit = true;
      };
    };

    # Documentation in /etc
    environment.etc."mcp-secrets/README.md" = {
      text = ''
        # MCP Secrets Management

        This system uses sops-nix for secure management of API keys needed by:
        
        1. The AI inference router (Venice + OpenRouter)
        2. MCP configuration tools
        3. TaskMaster integration

        ## Creating the Secrets File

        To create a new secrets file:

        ```bash
        # Generate a new secrets file (example)
        sops ${cfg.keysFile}
        ```

        Then add the following structure:

        ```yaml
        venice_api_key: your-venice-api-key
        openrouter_api_key: your-openrouter-api-key
        anthropic_api_key: your-anthropic-api-key
        perplexity_api_key: your-perplexity-api-key
        mcpr_token: your-mcpr-token
        ```

        ## Updating Secrets

        Edit the secrets file with:

        ```bash
        sops ${cfg.keysFile}
        ```

        After updating the secrets, rebuild your configuration for the changes to take effect:

        ```bash
        sudo nixos-rebuild switch
        ```
      '';
      mode = "0444";
    };
  };
}