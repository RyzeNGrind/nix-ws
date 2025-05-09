# Void Editor (VSCodium Fork) Configuration

This README explains how the Void Editor (VSCodium fork from the fork by jskrzypek) is configured in this flake.

## Overview

The Void Editor is a fork of VSCodium with some additional customizations. It's available in this flake through:

1. NixOS system configuration (`programs.void-editor.enable = true`)
2. Home Manager configuration (`programs.void-editor.enable = true`)
3. Development shell via `nix develop`

**Note:** The binary is named `void` (not `void-editor`), but the package name is `void-editor`.

## Using Void Editor from the flake

### System-wide installation

The Void Editor is available system-wide when enabled in your NixOS configuration:

```nix
# In your NixOS configuration
programs.void-editor = {
  enable = true;
  extensions = []; # Add VS Code extensions here
};
```

### Per-user installation with Home Manager

The Void Editor can be configured per-user with Home Manager:

```nix
# In your Home Manager configuration
programs.void-editor = {
  enable = true;
  enableExtensionUpdateCheck = false;
  enableUpdateCheck = false;
  extensions = with pkgs.vscode-extensions; [
    ms-vscode-remote.remote-containers
    # Add more extensions as needed
  ];
  userSettings = {
    "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace'";
    # Add more settings as needed
  };
};
```

### Using from the dev shell

The Void Editor is available in the development shell:

```bash
nix develop
which void  # Notice it's 'void', not 'void-editor'
void        # Launch the editor
```

## How it works

The flake imports the Void Editor package directly from jskrzypek's nixpkgs fork:

```nix
# In flake.nix inputs
void-editor-pkgs = {
  url = "github:jskrzypek/nixpkgs/void-editor";
  flake = true;
};
```

And then makes it available with an overlay:

```nix
# In flake.nix overlays
void-editor = final: prev: {
  void-editor = (import inputs.void-editor-pkgs {
    inherit (prev) system;
    config.allowUnfree = true;
  }).void-editor;
};
```

## Alternative access methods

If you just want to try Void Editor without rebuilding your system:

```bash
# From the flake
nix shell .#void-editor

# Directly from the fork
nix shell github:jskrzypek/nixpkgs/void-editor#void-editor
```

## Troubleshooting

If you encounter any issues with the Void Editor:

1. Check if the binary is available: `which void` (note it's named `void`, not `void-editor`)
2. Verify the package version: `void --version`
3. Try running with verbose logging: `void --verbose`

For more help, see the issues on the PR: [https://github.com/NixOS/nixpkgs/pull/398996](https://github.com/NixOS/nixpkgs/pull/398996) 