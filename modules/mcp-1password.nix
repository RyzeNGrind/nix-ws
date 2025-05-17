# modules/mcp-1password.nix
# 1Password integration for MCP configuration and AI inference
# Leverages opnix for secure credential management within NixOS
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-1password;

  # Helper to convert a 1Password reference to an expression
  op1 = name: vaultUuid: uuid: itemUuid: field: type:
    "op1:${name}=${vaultUuid}:${uuid}:${itemUuid}:${field}:${type}";
in {
  options.services.mcp-1password = {
    enable = mkEnableOption "Enable 1Password integration for MCP and AI services";

    # Define vaultUuid for MCP secrets
    vaultUuid = mkOption {
      type = types.str;
      default = ""; # User must specify their vault UUID
      description = "1Password vault UUID containing MCP API keys";
    };

    # MCP Router token
    mcprToken = {
      uuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for MCPR token";
      };
      
      itemUuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for MCPR token";
      };
      
      field = mkOption {
        type = types.str;
        default = "password"; # Default field for API key storage
        description = "Field name in 1Password item containing the MCPR token";
      };
    };

    # Venice API key
    veniceApiKey = {
      uuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for Venice API key";
      };
      
      itemUuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for Venice API key";
      };
      
      field = mkOption {
        type = types.str;
        default = "password";
        description = "Field name in 1Password item containing the Venice API key";
      };
    };

    # OpenRouter API key
    openRouterApiKey = {
      uuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for OpenRouter API key";
      };
      
      itemUuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for OpenRouter API key";
      };
      
      field = mkOption {
        type = types.str;
        default = "password";
        description = "Field name in 1Password item containing the OpenRouter API key";
      };
    };

    # Anthropic API key
    anthropicApiKey = {
      uuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for Anthropic API key";
      };
      
      itemUuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for Anthropic API key";
      };
      
      field = mkOption {
        type = types.str;
        default = "password";
        description = "Field name in 1Password item containing the Anthropic API key";
      };
    };

    # Perplexity API key
    perplexityApiKey = {
      uuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for Perplexity API key";
      };
      
      itemUuid = mkOption {
        type = types.str;
        default = "";
        description = "1Password item UUID for Perplexity API key";
      };
      
      field = mkOption {
        type = types.str;
        default = "password";
        description = "Field name in 1Password item containing the Perplexity API key";
      };
    };
    
    user = mkOption {
      type = types.str;
      default = "ryzengrind";
      description = "User who will have access to the 1Password secrets";
    };
  };

  config = mkIf cfg.enable {
    # Ensure opnix is enabled
    op = {
      # Enable opnix
      enable = true;
      
      # Configure 1Password for CLI use
      cli = {
        serviceAccountToken = mkIf (cfg.mcprToken.uuid != "") (
          op1 "mcpr" cfg.vaultUuid cfg.mcprToken.uuid cfg.mcprToken.itemUuid cfg.mcprToken.field "password"
        );
      };
      
      # Define secret references
      secrets = {
        "mcp/venice_api_key" = mkIf (cfg.veniceApiKey.uuid != "") {
          value = op1 "venice" cfg.vaultUuid cfg.veniceApiKey.uuid cfg.veniceApiKey.itemUuid cfg.veniceApiKey.field "password";
          owner = cfg.user;
          group = "users";
          mode = "0400";
        };
        
        "mcp/openrouter_api_key" = mkIf (cfg.openRouterApiKey.uuid != "") {
          value = op1 "openrouter" cfg.vaultUuid cfg.openRouterApiKey.uuid cfg.openRouterApiKey.itemUuid cfg.openRouterApiKey.field "password";
          owner = cfg.user;
          group = "users";
          mode = "0400";
        };
        
        "mcp/anthropic_api_key" = mkIf (cfg.anthropicApiKey.uuid != "") {
          value = op1 "anthropic" cfg.vaultUuid cfg.anthropicApiKey.uuid cfg.anthropicApiKey.itemUuid cfg.anthropicApiKey.field "password";
          owner = cfg.user;
          group = "users";
          mode = "0400";
        };
        
        "mcp/perplexity_api_key" = mkIf (cfg.perplexityApiKey.uuid != "") {
          value = op1 "perplexity" cfg.vaultUuid cfg.perplexityApiKey.uuid cfg.perplexityApiKey.itemUuid cfg.perplexityApiKey.field "password";
          owner = cfg.user;
          group = "users";
          mode = "0400";
        };
      };
    };
    
    # Integrate with AI inference if enabled
    services.ai-inference = mkIf (config.services.ai-inference.enable or false) {
      veniceApiKey = mkIf (cfg.veniceApiKey.uuid != "") "/run/op/mcp/venice_api_key";
      openRouterApiKey = mkIf (cfg.openRouterApiKey.uuid != "") "/run/op/mcp/openrouter_api_key";
    };
    
    # Integrate with MCP configuration if enabled
    services.mcp-configuration = mkIf (config.services.mcp-configuration.enable or false) {
      veniceRouterIntegration = mkIf (config.services.mcp-configuration.veniceRouterIntegration.enable or false) {
        veniceApiKey = mkIf (cfg.veniceApiKey.uuid != "") "/run/op/mcp/venice_api_key";
        openRouterApiKey = mkIf (cfg.openRouterApiKey.uuid != "") "/run/op/mcp/openrouter_api_key";
      };
      
      taskMaster = mkIf (config.services.mcp-configuration.taskMaster.enable or false) {
        anthropicApiKey = mkIf (cfg.anthropicApiKey.uuid != "") "/run/op/mcp/anthropic_api_key";
        perplexityApiKey = mkIf (cfg.perplexityApiKey.uuid != "") "/run/op/mcp/perplexity_api_key";
      };
    };
    
    # Ensure the 1Password agent is installed and configured
    environment.systemPackages = with pkgs; [
      _1password
    ];
    
    # Documentation
    environment.etc."mcp-1password/README.md" = {
      text = ''
        # 1Password Integration for MCP Configuration
        
        This system uses 1Password for secure management of API keys needed by:
        
        1. The AI inference router (Venice + OpenRouter)
        2. MCP configuration tools
        3. TaskMaster integration
        
        ## Setup Steps
        
        1. Ensure 1Password CLI is installed and authenticated
        2. Create items in 1Password for each API key:
           - Venice API key
           - OpenRouter API key
           - Anthropic API key
           - Perplexity API key
           - MCPR token
        3. Get the item UUIDs and vault UUID from 1Password
        4. Update the NixOS configuration with these UUIDs
        
        ## Using 1Password CLI
        
        To view available secrets:
        
        ```bash
        op item list
        ```
        
        To view an item's details:
        
        ```bash
        op item get "Item Name" --format=json
        ```
        
        ## Troubleshooting
        
        If secrets are not available, check:
        
        1. 1Password status: `op whoami`
        2. Service account token validity
        3. UUIDs in configuration match 1Password
        
        For more info, see: https://github.com/brizzbuzz/opnix
      '';
      mode = "0444";
    };
  };
}