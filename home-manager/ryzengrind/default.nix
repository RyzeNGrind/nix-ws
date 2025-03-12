{
  config,
  pkgs,
  ...
}: {
  # Home Manager needs a bit of information about you and the paths it should manage.
  home = {
    username = "ryzengrind";
    homeDirectory = "/home/ryzengrind";
    # Basic configuration for packages and programs
    packages = with pkgs; [
      # Development tools
      git
      gh
      vim

      # System tools
      htop
      ripgrep
      fd

      # Shell utilities
      fzf
      zoxide
      direnv
    ];

    sessionVariables = {
      STARSHIP_SHELL = "bash";
      SHELL = "${pkgs.bash}/bin/bash";
    };

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    stateVersion = "24.11"; # Please read the comment before changing this value
  };

  programs = {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;

    bash = {
      enableCompletion = true;
      initExtra = ''
        # Source bash-preexec for better Starship integration
        source ${pkgs.bash-preexec}/share/bash/bash-preexec.sh

        # Initialize Starship
        eval "$(${pkgs.starship}/bin/starship init bash)"
      '';
    };

    # Shell configuration
    fish = {
      enable = true;
      interactiveShellInit = ''
        # Manual starship init for fish
        ${pkgs.starship}/bin/starship init fish | source
      '';
    };

    starship = {
      enable = true;
      settings = {
        add_newline = true;
        command_timeout = 5000;
        character = {
          error_symbol = "[❯](bold red)";
          success_symbol = "[❯](bold green)";
          vicmd_symbol = "[❮](bold blue)";
        };
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    git = {
      enable = true;
      userName = "ryzengrind";
      userEmail = "ryzengrind@example.com"; # Replace with your email
    };

    vscode = {
      enable = true;
      enableExtensionUpdateCheck = false;
      enableUpdateCheck = false;
      package = pkgs.vscode;
      extensions = with pkgs.vscode-extensions; [
        ms-vscode-remote.remote-containers
        ms-vscode-remote.remote-wsl
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
      ];
    };
  };
}
