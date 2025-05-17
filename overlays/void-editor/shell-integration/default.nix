{ lib
, stdenv
, bash
, zsh
, fish
, powershell
}:

let
  # Determine if this is a Windows build
  isWindows = stdenv.hostPlatform.isWindows;
in
{
  # This function will copy all shell integration scripts to the target directory
  installShellIntegrationScripts = targetPath: ''
    echo "Installing shell integration scripts to $out/${targetPath}"

    # Create the target directory
    mkdir -p "$out/${targetPath}"

    # Copy all the shell integration scripts from the derivation to the target directory
    cp -v ${./shellIntegration-bash.sh} "$out/${targetPath}/shellIntegration-bash.sh"
    cp -v ${./shellIntegration.fish} "$out/${targetPath}/shellIntegration.fish"
    cp -v ${./shellIntegration-rc.zsh} "$out/${targetPath}/shellIntegration-rc.zsh"
    cp -v ${./shellIntegration-env.zsh} "$out/${targetPath}/shellIntegration-env.zsh"
    cp -v ${./shellIntegration-login.zsh} "$out/${targetPath}/shellIntegration-login.zsh"
    cp -v ${./shellIntegration-profile.zsh} "$out/${targetPath}/shellIntegration-profile.zsh"
    cp -v ${./shellIntegration.ps1} "$out/${targetPath}/shellIntegration.ps1"

    # Set appropriate permissions
    chmod 644 "$out/${targetPath}/"*

    # Log completion
    echo "Shell integration scripts installed successfully"
  '';

  # Helper function to generate correct paths for integration scripts based on platform
  getScriptPaths = basePath: {
    bash = "${basePath}/shellIntegration-bash.sh";
    zsh = {
      rc = "${basePath}/shellIntegration-rc.zsh";
      env = "${basePath}/shellIntegration-env.zsh";
      login = "${basePath}/shellIntegration-login.zsh";
      profile = "${basePath}/shellIntegration-profile.zsh";
    };
    fish = "${basePath}/shellIntegration.fish";
    powershell = "${basePath}/shellIntegration.ps1";
  };

  # Environment setup functions for different shells
  setupEnvironment = basePath: {
    bash = ''
      if [[ -f "${basePath}/shellIntegration-bash.sh" ]]; then
        source "${basePath}/shellIntegration-bash.sh"
      fi
    '';
    
    zsh = ''
      if [[ -f "${basePath}/shellIntegration-rc.zsh" ]]; then
        source "${basePath}/shellIntegration-rc.zsh"
      fi
    '';
    
    fish = ''
      if test -f "${basePath}/shellIntegration.fish"
        source "${basePath}/shellIntegration.fish"
      end
    '';
    
    powershell = ''
      if (Test-Path "${basePath}/shellIntegration.ps1") {
        . "${basePath}/shellIntegration.ps1"
      }
    '';
  };
}