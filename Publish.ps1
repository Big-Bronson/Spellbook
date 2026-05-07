# Publish.ps1
# Publishes Steve's Scriptorium to the PowerShell Gallery.
# Run this from the repo root when you're ready to release a new version.
#
# Before first publish:
#   1. Create a PS Gallery account at https://www.powershellgallery.com
#   2. Generate an API key in your PS Gallery profile
#   3. Update the GUID in StevesScriptorium.psd1 with [guid]::NewGuid()
#   4. Update ModuleVersion in StevesScriptorium.psd1
#   5. Update YOUR-ORG in LicenseUri and ProjectUri in the manifest
#
# Usage:
#   .\Publish.ps1 -ApiKey "your-gallery-api-key"
#   .\Publish.ps1 -ApiKey "your-gallery-api-key" -WhatIf   # dry run

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ApiKey
)

$moduleName = "StevesScriptorium"
$modulePath  = $PSScriptRoot

Write-Host ""
Write-Host "  Steve's Scriptorium — Publisher" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# Read current version from manifest
$manifest = Import-PowerShellDataFile (Join-Path $modulePath "$moduleName.psd1")
$version   = $manifest.ModuleVersion
Write-Host "  Module:  $moduleName"
Write-Host "  Version: $version"
Write-Host ""

# Validate manifest before attempting publish
Write-Host "  Validating module manifest..." -ForegroundColor Yellow
try {
    Test-ModuleManifest -Path (Join-Path $modulePath "$moduleName.psd1") | Out-Null
    Write-Host "  [OK] Manifest valid" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Manifest validation failed: $_" -ForegroundColor Red
    exit 1
}

# Check for placeholder values
$manifestRaw = Get-Content (Join-Path $modulePath "$moduleName.psd1") -Raw
if ($manifestRaw -match "YOUR-ORG") {
    Write-Host "  [ERROR] Replace YOUR-ORG placeholder in the manifest before publishing." -ForegroundColor Red
    exit 1
}
if ($manifestRaw -match "a1b2c3d4-e5f6-7890-abcd-ef1234567890") {
    Write-Host '  [ERROR] Replace the placeholder GUID with a real one: run [guid]::NewGuid() in PS' -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] No placeholder values detected" -ForegroundColor Green

# Confirm
Write-Host ""
if ($WhatIfPreference) {
    Write-Host "  [WHATIF] Would publish $moduleName v$version to PS Gallery" -ForegroundColor DarkYellow
    exit 0
}

$confirm = Read-Host "  Publish $moduleName v$version to PowerShell Gallery? (y/n)"
if ($confirm -ne "y") { Write-Host "  Aborted."; exit 0 }

# Publish
Write-Host ""
Write-Host "  Publishing..." -ForegroundColor Yellow
try {
    Publish-Module -Path $modulePath -NuGetApiKey $ApiKey -Repository PSGallery -Verbose
    Write-Host ""
    Write-Host "  [OK] Published $moduleName v$version to PS Gallery" -ForegroundColor Green
    Write-Host "  View at: https://www.powershellgallery.com/packages/$moduleName" -ForegroundColor Cyan
} catch {
    Write-Host "  [ERROR] Publish failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Team install command:" -ForegroundColor White
Write-Host "    Install-Module $moduleName -Scope CurrentUser" -ForegroundColor Yellow

Write-Host ""
