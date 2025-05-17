{ pkgs }:

let
  # Helper function to get the path to shell integration scripts
  getShellIntegrationPath = shell:
    if pkgs.stdenv.isDarwin then
      "${pkgs.void-editor}/Applications/Void Editor.app/Contents/Resources/app/shell-integration/${shell}"
    else
      "${pkgs.void-editor}/lib/void-editor/resources/app/shell-integration/${shell}";
      
  # We're explicitly using fish in this environment, so no need for shell detection
in
pkgs.mkShell {
  name = "void-editor-dev-env";
  buildInputs = with pkgs; [
    void-editor
    ghostty
    starship
    git
    nodejs
    gh
    direnv
    nix-direnv
  ];
  shellHook = ''
    # Set default shell to fish for this environment
    export SHELL=fish
    export TERMINAL=ghostty
    export XTERM_PROGRAM=ghostty
    
    # Configure shell integration for Void Editor
    export VSCODE_SHELL_INTEGRATION=1
    export VSCODE_SHELL_LOGIN=1

    # Source the fish shell integration script directly
    # We're explicitly using fish as set above, so no need for conditionals
    fish -c "test -e ${getShellIntegrationPath "shellIntegration.fish"} && source ${getShellIntegrationPath "shellIntegration.fish"} || echo 'Shell integration script not found'"
    
    echo "Welcome to your development environment with Void Editor from the jskrzypek nixpkgs fork!"
    echo "Shell integration is enabled"
  '';
}