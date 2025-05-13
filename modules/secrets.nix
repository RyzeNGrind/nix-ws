{ config, pkgs, lib, ... }:
{
  imports = [
    (import (pkgs.sops-nix + "/modules/sops"))
    (import (pkgs.agenix + "/modules/agenix"))
    (import (pkgs.opnix + "/modules/opnix"))
  ];

  # SOPS-Nix example
  sops = {
    defaultSopsFile = ../secrets/sops/secrets.yaml;
    age.keyFile = "/etc/age/keys.txt";
  };

  # Agenix example
  age.secrets = (age.secrets or { }) // {
    mysecret = {
      file = ../secrets/agenix/mysecret.age;
      owner = "root";
      group = "root";
    };
    zerotier-identity.secret = {
      file = ../secrets/agenix/zerotier-identity.secret.age;
      owner = "zerotier-one";
      group = "zerotier-one";
    };
    zerotier-identity.public = {
      file = ../secrets/agenix/zerotier-identity.public.age;
      owner = "zerotier-one";
      group = "zerotier-one";
    };
    tailscale-authkey = {
      file = ../secrets/agenix/tailscale-authkey.age;
      owner = "root";
      group = "root";
    };
    cloudflared-tunnel.json = {
      file = ../secrets/agenix/cloudflared-tunnel.json.age;
      owner = "cloudflared";
      group = "cloudflared";
    };
  };

  # Opnix (1Password) example
  opnix.secrets = {
    "my-1password-secret" = {
      vault = "Production";
      item = "NixOS Root Password";
      field = "password";
    };
  };
} 