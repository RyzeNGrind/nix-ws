self: super: {
  vscodium = super.vscodium.overrideAttrs (old: {
    postInstall = ''
      # Create necessary directories
      mkdir -p $out/share/code-oss/resources/app/out/vs/workbench/contrib/terminal/browser/media
      mkdir -p $out/share/code-oss/resources/app/out/vs/workbench/contrib/terminal/browser/media/fish_xdg_data/fish/vendor_conf.d

      # Download shell integration scripts from upstream VS Code
      curl -L -o "$out/share/code-oss/resources/app/out/vs/workbench/contrib/terminal/browser/media/shellIntegration-bash.sh" \
        "https://raw.githubusercontent.com/microsoft/vscode/main/src/vs/workbench/contrib/terminal/browser/media/shellIntegration-bash.sh"
      curl -L -o "$out/share/code-oss/resources/app/out/vs/workbench/contrib/terminal/browser/media/fish_xdg_data/fish/vendor_conf.d/shellIntegration.fish" \
        "https://raw.githubusercontent.com/microsoft/vscode/main/src/vs/workbench/contrib/terminal/browser/media/fish_xdg_data/fish/vendor_conf.d/shellIntegration.fish"

      # Ensure scripts are executable
      chmod +x "$out/share/code-oss/resources/app/out/vs/workbench/contrib/terminal/browser/media/shellIntegration-bash.sh"
    '';
  });
}
