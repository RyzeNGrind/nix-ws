{ config, pkgs, lib, ... }:

{
  # Import the 1Password SSH agent module
  imports = [ ../../modules/1password-ssh-agent.nix ];

  # Configure 1Password SSH agent integration for WSL
  services.onepassword-ssh-agent = {
    enable = true;
    socketPath = "${config.home.homeDirectory}/.1password/agent.sock";
    windowsPipeName = "//./pipe/com.1password.1password.ssh";  # 1Password SSH pipe name on Windows
    autoStartAgent = true;
    setEnvironmentVariable = true;
  };

  # Ensure required packages are installed
  home.packages = with pkgs; [
    socat    # For socket relay
    unzip    # For unpacking npiperelay
    curl     # For downloading npiperelay
  ];

  # Create directory for profile.d scripts
  home.file.".profile.d/.keep".text = "";

  # Add shell integration to load all profile.d scripts
  programs.bash.initExtra = ''
    # Load all scripts from ~/.profile.d
    if [ -d "$HOME/.profile.d" ]; then
      for script in "$HOME/.profile.d/"*.sh; do
        if [ -r "$script" ]; then
          . "$script"
        fi
      done
      unset script
    fi
  '';

  # Create test scripts in bin directory
  home.file."bin/.keep".text = "";
}