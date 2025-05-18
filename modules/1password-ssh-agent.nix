{ config, lib, pkgs, ... }:

let
  cfg = config.services.onepassword-ssh-agent;
  isWsl = pkgs.stdenv.hostPlatform.isWsl;
  socketPath = if cfg.socketPath != "" then cfg.socketPath else
    if isWsl then "//wsl$/NixOS/ssh-auth.sock" else "%t/1password/agent.sock";
in {
  options.services.onepassword-ssh-agent = {
    enable = lib.mkEnableOption "1Password SSH agent integration";
    
    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Custom socket path (auto-detects WSL by default)";
    };

    windowsPipeName = lib.mkOption {
      type = lib.types.str;
      default = "openssh-ssh-agent";
      description = "Windows named pipe name for WSL integration";
    };

    autoStartAgent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically start 1Password SSH agent";
    };

    setEnvironmentVariable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set SSH_AUTH_SOCK environment variable";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs._1password-gui-beta ];  # Updated to match 24.05 package name

    systemd.user.services."1password-ssh-agent" = lib.mkIf (cfg.autoStartAgent && config.home.file != "") {
      Unit = {
        Description = "1Password SSH Agent";
        Requires = if isWsl then [] else ["_1password-gui-beta.service"];
        After = if isWsl then [] else ["_1password-gui-beta.service"];
      };

      Service = {
        ExecStart = "${pkgs._1password-gui-beta}/bin/1password-ssh-agent --socket ${socketPath}";
        Restart = "on-failure";
      };

      Install.WantedBy = [ "default.target" ];
    };

    home.sessionVariables = lib.mkIf cfg.setEnvironmentVariable {
      SSH_AUTH_SOCK = socketPath;
    };

    warnings = lib.optional (isWsl && !cfg.autoStartAgent) 
      "WSL mode requires autoStartAgent=true for reliable operation";
  };
}