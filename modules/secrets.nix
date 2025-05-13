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
  age.secrets = {
    mysecret = {
      file = ../secrets/agenix/mysecret.age;
      owner = "root";
      group = "root";
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