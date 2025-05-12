{ pkgs }:

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
    export SHELL=fish
    export TERMINAL=ghostty
    export XTERM_PROGRAM=ghostty
    echo "Welcome to your development environment with Void Editor from the jskrzypek nixpkgs fork!"
  '';
} 