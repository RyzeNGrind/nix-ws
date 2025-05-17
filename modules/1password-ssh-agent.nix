{ config, lib, pkgs, ... }:

{
  options.services.onepassword-ssh-agent = {
    enable = lib.mkEnableOption "1Password SSH agent integration (minimal placeholder)";
    socketPath = lib.mkOption { type = lib.types.str; default = ""; };
    windowsPipeName = lib.mkOption { type = lib.types.str; default = ""; };
    autoStartAgent = lib.mkOption { type = lib.types.bool; default = false; };
    setEnvironmentVariable = lib.mkOption { type = lib.types.bool; default = false; };
  };

  config = lib.mkIf config.services.onepassword-ssh-agent.enable {
    # Module is present but does nothing for this test
  };
}