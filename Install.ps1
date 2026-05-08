# Install.ps1
# Bootstrap installer for Steve's Scriptorium.
# Run this after cloning the repo — it installs dependencies,
# copies the module to your PS module path, and adds toolkit()
# to your PowerShell profile so it's available everywhere.
#
# Usage:
#   git clone https://github.com/Big-Bronson/Steves-Scriptorium.git
#   cd Steves-Scriptorium
#   .\Install.ps1

[CmdletBinding()]
param(
    [switch]$Force  # Re-install even if already present
)

$ErrorActionPreference = "Stop"
$moduleName = "StevesScriptorium"

Write-Host ""
Write-Host "  Steve's Scriptorium — Installer" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Check PowerShell version ---
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "  [ERROR] PowerShell 5.1 or higher required. You're running $($PSVersionTable.PSVersion)." -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

# --- 2. Set execution policy ---
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  [OK] Execution policy set to RemoteSigned (CurrentUser)" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not set execution policy: $_" -ForegroundColor Yellow
}

# --- 3. Install required modules (CurrentUser scope — no admin needed) ---
$requiredModules = @(
    "ExchangeOnlineManagement"
    "Microsoft.Graph.Users"
    "Microsoft.Graph.Identity.SignIns"
    "Microsoft.Graph.Authentication"
    "Microsoft.Graph.Groups"
    "Microsoft.Graph.Reports"
)

Write-Host ""
Write-Host "  Installing required modules (CurrentUser scope)..." -ForegroundColor Yellow

foreach ($mod in $requiredModules) {
    if (Get-Module -Name $mod -ListAvailable) {
        Write-Host "  [OK] $mod (already installed)" -ForegroundColor Green
    } else {
        Write-Host "  [..] Installing $mod..." -ForegroundColor DarkGray
        try {
            Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
            Write-Host "  [OK] $mod installed" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] $mod — $_" -ForegroundColor Red
        }
    }
}

# --- 4. Copy module to CurrentUser module path ---
$moduleDestination = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\$moduleName"

if ((Test-Path $moduleDestination) -and -not $Force) {
    Write-Host ""
    Write-Host "  [INFO] Module already installed at $moduleDestination" -ForegroundColor DarkGray
    Write-Host "         Run .\Install.ps1 -Force to overwrite." -ForegroundColor DarkGray
} else {
    Write-Host ""
    Write-Host "  Copying module to $moduleDestination..." -ForegroundColor Yellow

    if (Test-Path $moduleDestination) { Remove-Item -Path $moduleDestination -Recurse -Force }

    Copy-Item -Path $PSScriptRoot -Destination $moduleDestination -Recurse -Force
    Write-Host "  [OK] Module installed" -ForegroundColor Green
}

# --- 5. Add Import-Module to PS profile ---
$profileLine = "Import-Module $moduleName"

if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Write-Host "  [OK] Created PowerShell profile at $PROFILE" -ForegroundColor Green
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -notmatch [regex]::Escape($profileLine)) {
    Add-Content -Path $PROFILE -Value "`n# Steve's Scriptorium`n$profileLine"
    Write-Host "  [OK] Added to PowerShell profile" -ForegroundColor Green
} else {
    Write-Host "  [OK] Already in PowerShell profile" -ForegroundColor Green
}

# --- Done ---
Write-Host ""
Write-Host "  Installation complete." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Restart your terminal, then run:" -ForegroundColor White
Write-Host "    toolkit" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Or import immediately in this session:" -ForegroundColor White
Write-Host "    Import-Module $moduleName" -ForegroundColor Yellow
Write-Host ""
