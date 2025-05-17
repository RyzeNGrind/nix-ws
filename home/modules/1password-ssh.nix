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
  # home.packages are mostly handled by the agent module itself if needed for its scripts.
  # socat is listed in modules/1password-ssh-agent.nix.
  # unzip and curl are not needed if npiperelay is fetched by Nix.
  # home.packages = with pkgs; [
  #   socat    # For socket relay
  #   unzip    # For unpacking npiperelay
  #   curl     # For downloading npiperelay
  # ];

  home.file = {
    # Create directory for profile.d scripts
    ".profile.d/.keep".text = "";
    # Create bin directory
    "bin/.keep".text = "";
  };

  # Add shell integration to load all profile.d scripts
  # Temporarily remove bash.initExtra to simplify further
  # programs.bash.initExtra = ''
  #   # Load all scripts from ~/.profile.d
  #   if [ -d "$HOME/.profile.d" ]; then
  #     for script in "$HOME/.profile.d/"*.sh; do
  #       if [ -r "$script" ]; then
  #         . "$script"
  #       fi
  #     done
  #     unset script
  #   fi
  # '';
}