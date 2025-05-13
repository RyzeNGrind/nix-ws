{ config, pkgs, ... }:
{
  users.users.ryzengrind = {
    isNormalUser = true;
    home = "/home/ryzengrind";
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
  };
}
