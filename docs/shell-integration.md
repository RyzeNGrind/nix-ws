# Void Editor Shell Integration

This document explains how the shell integration feature works with Void Editor and how to set it up for your terminals.

## Overview

Shell integration enhances your terminal experience when using Void Editor by enabling features such as:

- Command tracking and history navigation
- Improved prompt detection 
- Better terminal output handling
- Automatic directory tracking
- Enhanced terminal navigation

## Supported Shells

The shell integration works with the following shells:

- Bash
- Zsh
- Fish
- PowerShell

## Installation

### Automatic Installation

To install the shell integration scripts automatically, we provide installer scripts for both Unix-like systems and Windows.

#### For Unix-like systems (Linux, macOS)

1. Locate your Void Editor installation path
2. Run the installation script with the path as an argument:

```bash
chmod +x ./scripts/install-void-shell-integration.sh
./scripts/install-void-shell-integration.sh /path/to/void-editor
```

This will install the shell integration scripts for all supported shells that are detected on your system.

#### For Windows

1. Locate your Void Editor installation path
2. Run the PowerShell installation script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-void-shell-integration.ps1 -VoidEditorPath "C:\Path\to\Void Editor"
```

### Manual Installation

If you prefer to set up the integration manually, follow these steps:

1. Copy the shell integration scripts from your Void Editor installation to a convenient location:
   ```
   cp /path/to/void-editor/lib/void-editor/resources/app/shell-integration/* ~/.config/void-editor/shell-integration/
   ```

2. For each shell, add the appropriate line to your shell's configuration file:

   - Bash (`~/.bashrc`):
     ```bash
     source ~/.config/void-editor/shell-integration/shellIntegration-bash.sh
     ```

   - Zsh (`~/.zshrc`):
     ```zsh
     source ~/.config/void-editor/shell-integration/shellIntegration-rc.zsh
     ```

   - Fish (`~/.config/fish/config.fish`):
     ```fish
     source ~/.config/void-editor/shell-integration/shellIntegration.fish
     ```

   - PowerShell (`$PROFILE`):
     ```powershell
     . "$env:USERPROFILE\.config\void-editor\shell-integration\shellIntegration.ps1"
     ```

## Verifying Your Installation

To verify that the shell integration is working correctly:

1. Restart your terminal or source your configuration file
2. Open Void Editor and create a new terminal
3. You should see enhanced terminal features such as improved command highlighting and navigation

## Troubleshooting

If the shell integration doesn't appear to be working:

1. Verify that the integration scripts are properly sourced in your shell configuration files
2. Check that the paths in your configuration files match the actual location of the integration scripts
3. Make sure you have the correct permissions on the integration script files (they should be readable)
4. Try manually sourcing the integration script to see if there are any error messages:
   ```bash
   source ~/.config/void-editor/shell-integration/shellIntegration-bash.sh
   ```

## Advanced Configuration

### Custom installation directory

You can change the installation directory by modifying the environment variable `VOID_SHELL_INTEGRATION_PATH` before running the install scripts.

### Disabling specific features

Each integration script has options to disable specific features. Refer to the comments in the script files for details.

## How It Works

The shell integration scripts work by:

1. Adding special escape sequences that Void Editor can interpret to identify commands, prompts, and command outputs
2. Installing shell hooks that execute before and after commands
3. Setting up environment variables that Void Editor can use for enhanced terminal functionality

## Building from Source

When building Void Editor from source with Nix, the shell integration scripts are included automatically in the build. The scripts are located in the `resources/app/shell-integration` directory of the installed application.