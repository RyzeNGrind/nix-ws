self: super: {
  vscode-generic-fn = import ./vscode-generic/generic.nix;
  vscode-generic = super.callPackage ./vscode-generic/generic.nix {
    commandLineArgs = "";
    executableName = "code";
    longName = "Visual Studio Code";
    shortName = "vscode";
    pname = "vscode-generic";
    version = "1.87.2";
    src = super.fetchurl {
      url = "https://update.code.visualstudio.com/1.87.2/linux-x64/stable";
      sha256 = "sha256-wul83GP/G8v7sQwie1OYYj0h8h5IcQj6HXQNq+fTeYU=";
      name = "vscode.tar.gz";
    };
    sourceRoot = "VSCode-linux-x64";
    updateScript = null;
    meta = with super.lib; {
      description = "Visual Studio Code (generic base)";
      homepage = "https://code.visualstudio.com/";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.all;
    };
    mesa = super.mesa;
    libdrm = if super ? libdrm then super.libdrm else null;
  };
} 