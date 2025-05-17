# Void Editor Shell Integration Installation Script for Windows
# This script sets up shell integration for Void Editor in PowerShell

param (
    [Parameter(Mandatory=$true)]
    [string]$VoidEditorPath
)

# Define paths
$ShellIntegrationDir = "$env:USERPROFILE\.config\void-editor\shell-integration"
$SourcePath = "$VoidEditorPath\lib\void-editor\resources\app\shell-integration"

# Check if source path exists
if (-not (Test-Path $SourcePath)) {
    Write-Error "Error: Shell integration scripts not found at $SourcePath"
    Write-Error "Make sure you've provided the correct path to your Void Editor installation."
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path $ShellIntegrationDir)) {
    Write-Host "Creating shell integration directory..."
    New-Item -ItemType Directory -Path $ShellIntegrationDir -Force | Out-Null
}

# Copy shell integration scripts
Write-Host "Copying shell integration scripts..."
Copy-Item -Path "$SourcePath\*" -Destination $ShellIntegrationDir -Force
Write-Host "Shell integration scripts copied successfully."

# Setup for PowerShell
function Setup-PowerShell {
    # Check for PowerShell profile
    if (-not (Test-Path $PROFILE)) {
        Write-Host "Creating PowerShell profile..."
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }

    # Check if integration is already set up
    $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if ($profileContent -match "Void Editor Shell Integration") {
        Write-Host "PowerShell shell integration is already set up."
    }
    else {
        Write-Host "Setting up PowerShell integration..."
        Add-Content -Path $PROFILE -Value "`n# Void Editor Shell Integration"
        Add-Content -Path $PROFILE -Value "if (Test-Path `"$ShellIntegrationDir\shellIntegration.ps1`") {"
        Add-Content -Path $PROFILE -Value "    . `"$ShellIntegrationDir\shellIntegration.ps1`""
        Add-Content -Path $PROFILE -Value "}"
        Write-Host "PowerShell shell integration set up successfully."
    }
}

# Setup PowerShell integration
Setup-PowerShell

Write-Host "`nVoid Editor shell integration setup complete!"
Write-Host "Please restart your PowerShell session or run '. $PROFILE' to activate the integration."