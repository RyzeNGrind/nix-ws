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

    # Cloudflare One (cloudflared) configuration
    services.cloudflared = {
      enable = true;
      tunnels = lib.mkIf (lib.hasAttr "age" config) {
        "YOUR_TUNNEL_ID" = {
          credentialsFile = "/run/agenix/cloudflared-tunnel.json";
          configFile = "/etc/cloudflared/config.yml";
        };
      };
    };

    # Cloudflared configuration file
    environment.etc = lib.mkIf (lib.hasAttr "age" config) {
      "cloudflared/config.yml".text = ''
        tunnel: YOUR_TUNNEL_ID
        credentials-file: /run/agenix/cloudflared-tunnel.json
        protocol: quic
        warp-routing:
          enabled: true
        logfile: /var/log/cloudflared.log
        loglevel: info
      '';
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
