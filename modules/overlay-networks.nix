{ config, pkgs, lib, ... }:

{
  options.age = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Agenix secrets configuration.";
  };

  config = {
    # ZeroTier configuration
    services.zerotierone = {
      enable = true;
      joinNetworks = [ "fada62b0158621fe" ]; # Replace with your actual network ID
    };

    # Conditional agenix integration for ZeroTier
    systemd.services.zerotierone.preStart = lib.mkIf (lib.hasAttr "age" config) (lib.mkDefault ''
      install -m 600 /run/agenix/zerotier-identity.secret /var/lib/zerotier-one/identity.secret
      install -m 644 /run/agenix/zerotier-identity.public /var/lib/zerotier-one/identity.public
      chown zerotier-one:zerotier-one /var/lib/zerotier-one/identity.*
    '');

    # Tailscale configuration
    services.tailscale = {
      enable = true;
      extraUpFlags = lib.mkIf (lib.hasAttr "age" config) [ "--authkey=$(cat /run/agenix/tailscale-authkey)" ];
    };

    # Cloudflare One (cloudflared) configuration - with required default service
    services.cloudflared = {
      enable = true;
      # Use the tunnel ID as obtained from `cloudflared tunnel list`
      tunnels = lib.mkIf (lib.hasAttr "age" config) {
        "6d2d34a6-c981-4d1b-9710-05d3d79aca84" = {
          # Required configuration attributes
          credentialsFile = "/run/agenix/cloudflared-tunnel.json";
          # Default service setting is required by the module
          default = "http_status:404";
        };
      };
      # No additional settings to avoid incompatibilities with the custom module
    };
    
    # Define the age secrets with a low priority (only if age is available)
    age = lib.mkOverride 1500 {
      secrets = {
        # ZeroTier secrets
        "zerotier-identity.secret" = {
          file = ../secrets/agenix/zerotier-identity.secret.age;
        };
        "zerotier-identity.public" = {
          file = ../secrets/agenix/zerotier-identity.public.age;
        };
        
        # Tailscale secret
        tailscale-authkey = {
          file = ../secrets/agenix/tailscale-authkey.age;
        };
        
        # Cloudflared secret
        "cloudflared-tunnel.json" = {
          file = ../secrets/agenix/cloudflared-tunnel.json.age;
        };
      };
    };
  };
}
