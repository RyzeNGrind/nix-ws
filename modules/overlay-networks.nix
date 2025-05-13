{ config, pkgs, lib, ... }:
{
  # ZeroTier via opnix, headless, agenix secrets
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "fada62b0158621fe" ]; # Replace with your actual network ID
  };
  systemd.services.zerotierone.preStart = ''
    install -m 600 /run/agenix/zerotier-identity.secret /var/lib/zerotier-one/identity.secret
    install -m 644 /run/agenix/zerotier-identity.public /var/lib/zerotier-one/identity.public
    chown zerotier-one:zerotier-one /var/lib/zerotier-one/identity.*
  '';
  age.secrets.zerotier-identity.secret.file = ../secrets/agenix/zerotier-identity.secret.age;
  age.secrets.zerotier-identity.public.file = ../secrets/agenix/zerotier-identity.public.age;

  # Tailscale, headless, agenix secret
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--authkey=$(cat /run/agenix/tailscale-authkey)" ];
  };
  age.secrets.tailscale-authkey.file = ../secrets/agenix/tailscale-authkey.age;

  # Cloudflare One (cloudflared), headless, agenix secret
  services.cloudflared = {
    enable = true;
    tunnels = {
      "YOUR_TUNNEL_ID" = {
        credentialsFile = "/run/agenix/cloudflared-tunnel.json";
        configFile = "/etc/cloudflared/config.yml";
      };
    };
  };
  environment.etc."cloudflared/config.yml".text = ''
    tunnel: YOUR_TUNNEL_ID
    credentials-file: /run/agenix/cloudflared-tunnel.json
    protocol: quic
    warp-routing:
      enabled: true
    logfile: /var/log/cloudflared.log
    loglevel: info
  '';
  age.secrets.cloudflared-tunnel.json.file = ../secrets/agenix/cloudflared-tunnel.json.age;
}
