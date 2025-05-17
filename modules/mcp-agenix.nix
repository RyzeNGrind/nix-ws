# modules/mcp-agenix.nix
# Agenix integration for MCP configuration and AI inference
# Provides age-based encryption with optional YubiKey support
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-agenix;
  
  # Location where age-encrypted secrets will be stored
  secretsDir = "/run/agenix/mcp";
in {
  options.services.mcp-agenix = {
    enable = mkEnableOption "Enable Agenix integration for MCP and AI services";

    user = mkOption {
      type = types.str;
      default = "ryzengrind";
      description = "User who will have access to the agenix-decrypted secrets";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group who will have access to the agenix-decrypted secrets";
    };

    secretsDirectory = mkOption {
      type = types.str;
      default = ../secrets/agenix;
      description = "Directory containing agenix-encrypted secrets";
    };

    yubikey = {
      enable = mkEnableOption "Enable YubiKey support for agenix";
      
      slot = mkOption {
        type = types.int;
        default = 1;
        description = "YubiKey PIV slot to use (default: 1)";
      };
    };

    keys = {
      venice = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Venice API key management with agenix";
      };

      openRouter = mkOption {
        type = types.bool;
        default = true;
        description = "Enable OpenRouter API key management with agenix";
      };

      anthropic = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Anthropic API key management with agenix";
      };

      perplexity = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Perplexity API key management with agenix";
      };

      mcpr = mkOption {
        type = types.bool;
        default = true;
        description = "Enable MCPR token management with agenix";
      };
    };
  };

  config = mkIf cfg.enable {
    # Define agenix secrets
    age.secrets = {
      # Venice API key
      "mcp-venice-api-key" = mkIf cfg.keys.venice {
        file = "${cfg.secretsDirectory}/mcp-venice-api-key.age";
        path = "${secretsDir}/venice_api_key";
        owner = cfg.user;
        group = cfg.group;
        mode = "0400";
      };
      
      # OpenRouter API key
      "mcp-openrouter-api-key" = mkIf cfg.keys.openRouter {
        file = "${cfg.secretsDirectory}/mcp-openrouter-api-key.age";
        path = "${secretsDir}/openrouter_api_key";
        owner = cfg.user;
        group = cfg.group;
        mode = "0400";
      };
      
      # Anthropic API key
      "mcp-anthropic-api-key" = mkIf cfg.keys.anthropic {
        file = "${cfg.secretsDirectory}/mcp-anthropic-api-key.age";
        path = "${secretsDir}/anthropic_api_key";
        owner = cfg.user;
        group = cfg.group;
        mode = "0400";
      };
      
      # Perplexity API key
      "mcp-perplexity-api-key" = mkIf cfg.keys.perplexity {
        file = "${cfg.secretsDirectory}/mcp-perplexity-api-key.age";
        path = "${secretsDir}/perplexity_api_key";
        owner = cfg.user;
        group = cfg.group;
        mode = "0400";
      };
      
      # MCPR token
      "mcp-mcpr-token" = mkIf cfg.keys.mcpr {
        file = "${cfg.secretsDirectory}/mcp-mcpr-token.age";
        path = "${secretsDir}/mcpr_token";
        owner = cfg.user;
        group = cfg.group;
        mode = "0400";
      };
    };
    
    # Optional YubiKey integration
    age.identityPaths = mkIf (!cfg.yubikey.enable) [ 
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/${cfg.user}/.ssh/id_ed25519"
    ];
    
    # YubiKey SSH agent integration
    programs.ssh.startAgent = mkIf cfg.yubikey.enable true;
    
    # Integrate with AI inference if enabled
    services.ai-inference = mkIf (config.services.ai-inference.enable or false) {
      veniceApiKey = mkIf (cfg.keys.venice && config.age.secrets ? "mcp-venice-api-key") 
        config.age.secrets."mcp-venice-api-key".path;
        
      openRouterApiKey = mkIf (cfg.keys.openRouter && config.age.secrets ? "mcp-openrouter-api-key") 
        config.age.secrets."mcp-openrouter-api-key".path;
    };
    
    # Integrate with MCP configuration if enabled
    services.mcp-configuration = mkIf (config.services.mcp-configuration.enable or false) {
      veniceRouterIntegration = mkIf (config.services.mcp-configuration.veniceRouterIntegration.enable or false) {
        veniceApiKey = mkIf (cfg.keys.venice && config.age.secrets ? "mcp-venice-api-key") 
          config.age.secrets."mcp-venice-api-key".path;
          
        openRouterApiKey = mkIf (cfg.keys.openRouter && config.age.secrets ? "mcp-openrouter-api-key") 
          config.age.secrets."mcp-openrouter-api-key".path;
      };
      
      taskMaster = mkIf (config.services.mcp-configuration.taskMaster.enable or false) {
        anthropicApiKey = mkIf (cfg.keys.anthropic && config.age.secrets ? "mcp-anthropic-api-key") 
          config.age.secrets."mcp-anthropic-api-key".path;
          
        perplexityApiKey = mkIf (cfg.keys.perplexity && config.age.secrets ? "mcp-perplexity-api-key") 
          config.age.secrets."mcp-perplexity-api-key".path;
      };
    };

    # Ensure required packages are installed
    environment.systemPackages = with pkgs; [
      age
      rage
      agenix
    ] ++ (optionals cfg.yubikey.enable [
      yubikey-manager
      pcsclite
    ]);
    
    # Enable pcscd if using YubiKey
    services.pcscd.enable = cfg.yubikey.enable;

    # Documentation
    environment.etc."mcp-agenix/README.md" = {
      text = ''
        # Agenix Integration for MCP Configuration
        
        This system uses agenix (age-encrypted secrets) for secure management of API keys needed by:
        
        1. The AI inference router (Venice + OpenRouter)
        2. MCP configuration tools
        3. TaskMaster integration
        
        ## Setup Steps
        
        1. Create age-encrypted secrets:
        
        ```bash
        mkdir -p ${cfg.secretsDirectory}
        
        # Add recipient keys (public keys that can decrypt the secrets)
        # Example: SSH keys
        agenix -e ${cfg.secretsDirectory}/mcp-venice-api-key.age -i ~/.ssh/id_ed25519
        # Enter the Venice API key when prompted
        
        # Repeat for other API keys
        agenix -e ${cfg.secretsDirectory}/mcp-openrouter-api-key.age -i ~/.ssh/id_ed25519
        agenix -e ${cfg.secretsDirectory}/mcp-anthropic-api-key.age -i ~/.ssh/id_ed25519
        agenix -e ${cfg.secretsDirectory}/mcp-perplexity-api-key.age -i ~/.ssh/id_ed25519
        agenix -e ${cfg.secretsDirectory}/mcp-mcpr-token.age -i ~/.ssh/id_ed25519
        ```
        ${optionalString cfg.yubikey.enable ''
        
        ## YubiKey Integration
        
        This system is configured to use YubiKey for decryption. Ensure:
        
        1. Your YubiKey is inserted
        2. The PIV module is configured (slot ${toString cfg.yubikey.slot})
        3. The pcscd service is running
        
        To test YubiKey integration:
        
        ```bash
        # Check if YubiKey is detected
        ykman list
        ```
        ''}
        
        ## Managing Secrets
        
        To reencrypt secrets (e.g., after adding a new recipient):
        
        ```bash
        agenix -r
        ```
        
        To edit an existing secret:
        
        ```bash
        agenix -e ${cfg.secretsDirectory}/mcp-venice-api-key.age
        ```
        
        For more info, see: https://github.com/ryantm/agenix
      '';
      mode = "0444";
    };
    
    # Create template secrets if they don't exist
    system.activationScripts.createAgenixTemplates = ''
      mkdir -p ${cfg.secretsDirectory}
      
      # Create instruction file if it doesn't exist
      if [ ! -f ${cfg.secretsDirectory}/README.md ]; then
        cat > ${cfg.secretsDirectory}/README.md << 'EOF'
# Agenix Encrypted Secrets

This directory should contain the following age-encrypted secret files:
- mcp-venice-api-key.age
- mcp-openrouter-api-key.age
- mcp-anthropic-api-key.age
- mcp-perplexity-api-key.age
- mcp-mcpr-token.age

## Creating Secrets

To create each secret file (replace KEY_NAME with the actual name):

```bash
agenix -e secrets/agenix/mcp-KEY_NAME.age
```

When prompted, paste the corresponding API key or token value.

## Public Keys (Recipients)

To add a new recipient (someone who can decrypt these secrets):

1. Add their public key to the project's key list
2. Re-encrypt the secrets with:

```bash
agenix -r
```

## YubiKey Support

For YubiKey-based encryption (optional):

```bash
# Use yubikey as SSH agent
ssh-add -s ${pkgs.opensc}/lib/opensc-pkcs11.so
```
EOF
      fi
    '';
  };
}