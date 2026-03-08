#!/usr/bin/env pwsh
# OpenClaw Universal Installer for Windows
# Supports: Windows 10/11 (PowerShell 5.1+)
# Usage: iwr -useb https://openclaw.ai/install.ps1 | iex

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("npm", "git")]
    [string]$InstallMethod = $env:OPENCLAW_INSTALL_METHOD,

    [Parameter()]
    [string]$Version = $env:OPENCLAW_VERSION,

    [Parameter()]
    [switch]$Beta = ($env:OPENCLAW_BETA -eq "1"),

    [Parameter()]
    [string]$GitDir = $env:OPENCLAW_GIT_DIR,

    [Parameter()]
    [switch]$NoGitUpdate = ($env:OPENCLAW_GIT_UPDATE -eq "0"),

    [Parameter()]
    [switch]$NoOnboard = ($env:OPENCLAW_NO_ONBOARD -eq "1"),

    [Parameter()]
    [switch]$NoPrompt = ($env:OPENCLAW_NO_PROMPT -eq "1"),

    [Parameter()]
    [switch]$DryRun = ($env:OPENCLAW_DRY_RUN -eq "1"),

    [Parameter()]
    [switch]$Verbose = ($env:OPENCLAW_VERBOSE -eq "1"),

    [Parameter()]
    [switch]$Help
)

# Version
$script:InstallerVersion = "1.0.0"
$script:RequiredNodeVersion = 22

# Configuration
$script:DefaultTagline = "All your chats, one OpenClaw."
$script:InstallMethod = if ($InstallMethod) { $InstallMethod } else { "npm" }
$script:OpenClawVersion = if ($Version) { $Version } else { "latest" }
$script:GitDir = if ($GitDir) { $GitDir } else { "$env:USERPROFILE\openclaw" }
$script:GitUpdate = -not $NoGitUpdate
$script:NoOnboard = $NoOnboard
$script:NoPrompt = $NoPrompt
$script:DryRun = $DryRun
$script:Verbose = $Verbose
$script:UseBeta = $Beta

# Colors
$script:Colors = @{
    Accent = "`e[38;2;255;77;77m"
    Info = "`e[38;2;136;146;176m"
    Success = "`e[38;2;0;229;204m"
    Warn = "`e[38;2;255;176;32m"
    Error = "`e[38;2;230;57;70m"
    Muted = "`e[38;2;90;100;128m"
    Bold = "`e[1m"
    Reset = "`e[0m"
}

# Check if colors are supported
$script:UseColors = $host.UI.SupportsVirtualTerminal -and -not $env:NO_COLOR

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "Info",
        [switch]$NoNewline
    )

    if ($script:UseColors) {
        $colorCode = $script:Colors[$Color]
        $reset = $script:Colors.Reset
        if ($NoNewline) {
            Write-Host "${colorCode}${Message}${reset}" -NoNewline
        } else {
            Write-Host "${colorCode}${Message}${reset}"
        }
    } else {
        if ($NoNewline) {
            Write-Host $Message -NoNewline
        } else {
            Write-Host $Message
        }
    }
}

function Write-Info {
    param([string]$Message)
    if ($script:UseColors) {
        Write-Host "$($script:Colors.Muted)·$($script:Colors.Reset) $Message"
    } else {
        Write-Host ". $Message"
    }
}

function Write-Warn {
    param([string]$Message)
    if ($script:UseColors) {
        Write-Host "$($script:Colors.Warn)!$($script:Colors.Reset) $Message"
    } else {
        Write-Host "! $Message"
    }
}

function Write-Success {
    param([string]$Message)
    if ($script:UseColors) {
        Write-Host "$($script:Colors.Success)✓$($script:Colors.Reset) $Message"
    } else {
        Write-Host "✓ $Message"
    }
}

function Write-Error {
    param([string]$Message)
    if ($script:UseColors) {
        Write-Host "$($script:Colors.Error)✗$($script:Colors.Reset) $Message" -ForegroundColor Red
    } else {
        Write-Host "✗ $Message"
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput $Title "Accent" -NoNewline
    Write-ColorOutput "" "Reset"
}

function Write-Celebrate {
    param([string]$Message)
    Write-ColorOutput $Message "Success"
}

function Write-Banner {
    $taglines = @(
        "Your terminal just grew claws",
        "All your chats, one OpenClaw",
        "AI automation for the command line",
        "Your personal AI assistant"
    )
    $tagline = $taglines | Get-Random

    Write-ColorOutput "" "Accent"
    Write-ColorOutput "  🦞 OpenClaw Installer" "Accent"
    Write-ColorOutput "  $tagline" "Info"
    Write-ColorOutput "  v$script:InstallerVersion" "Muted"
    Write-ColorOutput "" "Reset"
}

function Test-IsAdministrator {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function Test-IsNonInteractive {
    return $script:NoPrompt -or -not $host.UI.RawUI.KeyAvailable
}

function Get-NodeVersion {
    try {
        $version = node --version 2>$null
        if ($version) {
            return $version.TrimStart('v')
        }
    } catch {}
    return $null
}

function Test-NodeVersion {
    $version = Get-NodeVersion
    if (-not $version) {
        return $false
    }
    $major = [int]($version.Split('.')[0])
    return $major -ge $script:RequiredNodeVersion
}

function Get-NpmVersion {
    try {
        return (npm --version 2>$null).Trim()
    } catch {}
    return $null
}

function Get-GitVersion {
    try {
        $ver = git --version 2>$null
        if ($ver -match 'git version (\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
    } catch {}
    return $null
}

function Install-NodeJS {
    Write-Section "Installing Node.js"

    # Check for winget
    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if ($winget) {
        Write-Info "Installing Node.js via winget..."
        try {
            winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
            # Refresh environment
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            return $true
        } catch {
            Write-Warn "winget installation failed: $_"
        }
    }

    # Check for chocolatey
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if ($choco) {
        Write-Info "Installing Node.js via Chocolatey..."
        try {
            choco install nodejs-lts -y
            # Refresh environment
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            return $true
        } catch {
            Write-Warn "Chocolatey installation failed: $_"
        }
    }

    # Check for scoop
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoop) {
        Write-Info "Installing Node.js via Scoop..."
        try {
            scoop install nodejs-lts
            return $true
        } catch {
            Write-Warn "Scoop installation failed: $_"
        }
    }

    # Direct installer
    Write-Info "Downloading Node.js installer..."
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $installerUrl = "https://nodejs.org/dist/latest-v22.x/node-v22-latest-win-$arch.msi"
    $installerPath = "$env:TEMP\nodejs-installer.msi"

    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-Info "Running installer..."
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "$installerPath", "/quiet", "/norestart" -Wait
        Remove-Item $installerPath -ErrorAction SilentlyContinue

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        return $true
    } catch {
        Write-Error "Failed to install Node.js: $_"
        return $false
    }
}

function Install-BuildTools {
    Write-Section "Installing Build Tools"

    # Check for Visual Studio Build Tools
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

    if (Test-Path $vsWhere) {
        $installations = & $vsWhere -products "*" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($installations) {
            Write-Success "Visual Studio Build Tools already installed"
            return $true
        }
    }

    # Try to install via chocolatey
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if ($choco) {
        Write-Info "Installing Visual Studio Build Tools via Chocolatey..."
        try {
            choco install visualstudio2022buildtools -y --package-parameters "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
            return $true
        } catch {
            Write-Warn "Chocolatey installation failed: $_"
        }
    }

    # Download and install manually
    Write-Info "Downloading Visual Studio Build Tools..."
    $installerUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
    $installerPath = "$env:TEMP\vs_buildtools.exe"

    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-Info "Installing Visual Studio Build Tools (this may take a while)..."
        Start-Process -FilePath $installerPath -ArgumentList "--quiet", "--wait", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--add", "Microsoft.VisualStudio.Component.Windows11SDK.22000" -Wait
        Remove-Item $installerPath -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Warn "Failed to install build tools: $_"
        Write-Warn "Some npm packages may fail to compile native modules"
        return $false
    }
}

function Resolve-Version {
    if ($script:UseBeta) {
        return "beta"
    }
    return $script:OpenClawVersion
}

function Install-ViaNpm {
    param([string]$Version)

    Write-Section "Installing OpenClaw via npm"

    $spec = if ($Version -eq "latest") { "openclaw" } else { "openclaw@$Version" }
    Write-Info "Package: $spec"

    $npmArgs = @("install", "-g", $spec, "--no-fund", "--no-audit")

    if ($script:Verbose) {
        $npmArgs += "--loglevel", "verbose"
    } else {
        $npmArgs += "--loglevel", "error"
    }

    try {
        & npm @npmArgs 2>&1 | ForEach-Object {
            if ($script:Verbose) {
                Write-Host $_
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed with exit code $LASTEXITCODE"
        }

        Write-Success "OpenClaw installed via npm"
        return $true
    } catch {
        Write-Error "npm install failed: $_"

        # Check for common issues
        if ($_ -match "python|gyp|build") {
            Write-Warn "This may be due to missing build tools for native modules"
            if (-not (Test-IsNonInteractive)) {
                $installTools = Read-Host "Install Visual Studio Build Tools? (Y/n)"
                if ($installTools -eq '' -or $installTools -match '^[Yy]$') {
                    Install-BuildTools
                    Write-Info "Retrying npm install..."
                    & npm @npmArgs
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "OpenClaw installed via npm"
                        return $true
                    }
                }
            }
        }

        return $false
    }
}

function Install-ViaGit {
    Write-Section "Installing OpenClaw from Git"

    # Check for git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Git is required for this installation method"

        # Try to install git
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Info "Installing Git via winget..."
            winget install Git.Git --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        } else {
            Write-Error "Please install Git manually from https://git-scm.com/download/win"
            return $false
        }
    }

    if (Test-Path $script:GitDir) {
        if ($script:GitUpdate) {
            Write-Info "Updating existing repository..."
            Push-Location $script:GitDir
            git pull --ff-only 2>&1 | Out-Null
            Pop-Location
        } else {
            Write-Info "Using existing repository (updates disabled)"
        }
    } else {
        Write-Info "Cloning repository to $script:GitDir..."
        git clone --depth 1 https://github.com/openclaw/openclaw.git $script:GitDir
    }

    Push-Location $script:GitDir

    Write-Info "Installing dependencies..."

    # Check for pnpm
    $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($pnpm) {
        & pnpm install --frozen-lockfile
    } else {
        & npm ci
    }

    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Error "Failed to install dependencies"
        return $false
    }

    Write-Info "Building OpenClaw..."
    if ($pnpm) {
        & pnpm build
    } else {
        & npm run build
    }

    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Error "Build failed"
        return $false
    }

    Write-Info "Linking globally..."
    if ($pnpm) {
        & pnpm link --global
    } else {
        & npm link
    }

    Pop-Location
    Write-Success "OpenClaw installed from source"
    return $true
}

function Invoke-Onboarding {
    if ($script:NoOnboard) {
        return
    }

    Write-Section "Starting Onboarding"

    $openclaw = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($openclaw) {
        & openclaw onboard
    } else {
        Write-Warn "openclaw command not found in PATH"
        Write-Info "You may need to restart PowerShell"
        Write-Info "Then run: openclaw onboard"
    }
}

function Show-Usage {
    @"
OpenClaw Universal Installer for Windows v$script:InstallerVersion

Usage:
  iwr -useb https://openclaw.ai/install.ps1 | iex
  iwr -useb https://openclaw.ai/install.ps1 | iex -Args "-InstallMethod git"

Parameters:
  -InstallMethod <npm|git>    Installation method (default: npm)
  -Version <version>          Specific version to install (default: latest)
  -Beta                       Use beta version
  -GitDir <path>              Directory for git clone (default: ~\openclaw)
  -NoGitUpdate                Don't update existing git checkout
  -NoOnboard                  Skip onboarding wizard
  -NoPrompt                   Non-interactive mode (for CI/CD)
  -DryRun                     Show what would be done
  -Verbose                    Enable verbose output
  -Help                       Show this help

Environment Variables:
  OPENCLAW_INSTALL_METHOD       npm or git
  OPENCLAW_VERSION              Version or dist-tag
  OPENCLAW_BETA=1               Use beta channel
  OPENCLAW_GIT_DIR              Git checkout directory
  OPENCLAW_NO_ONBOARD=1         Skip onboarding
  OPENCLAW_NO_PROMPT=1          Non-interactive mode
  OPENCLAW_DRY_RUN=1            Dry run mode
  OPENCLAW_VERBOSE=1            Verbose output

Examples:
  # Default install
  iwr -useb https://openclaw.ai/install.ps1 | iex

  # Install specific version
  iwr -useb https://openclaw.ai/install.ps1 | iex -Args "-Version 1.2.3"

  # Install from git
  iwr -useb https://openclaw.ai/install.ps1 | iex -Args "-InstallMethod git"

  # CI/CD non-interactive
  iwr -useb https://openclaw.ai/install.ps1 | iex -Args "-NoPrompt -NoOnboard"

For macOS/Linux:
  curl -fsSL https://openclaw.ai/install.sh | bash

"@
}

function Show-SystemInfo {
    Write-Section "System Information"

    $nodeVersion = Get-NodeVersion
    $npmVersion = Get-NpmVersion
    $gitVersion = Get-GitVersion

    $os = "Windows $([Environment]::OSVersion.Version)"
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

    Write-Host "  OS:        $os"
    Write-Host "  Arch:      $arch"
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
    Write-Host "  Node.js:   $(if ($nodeVersion) { $nodeVersion } else { "Not installed" })"
    Write-Host "  npm:       $(if ($npmVersion) { $npmVersion } else { "Not installed" })"
    Write-Host "  Git:       $(if ($gitVersion) { $gitVersion } else { "Not installed" })"
    Write-Host "  Installer: $script:InstallMethod"
    Write-Host "  Version:   $(Resolve-Version)"
}

# Main
if ($Help) {
    Show-Usage
    exit 0
}

Write-Banner

if ($DryRun) {
    Write-Info "DRY RUN MODE - No changes will be made"
    Show-SystemInfo
    exit 0
}

if ($Verbose) {
    $VerbosePreference = "Continue"
}

Show-SystemInfo

# Check prerequisites
Write-Section "Checking Prerequisites"

# Check Node.js
if (-not (Test-NodeVersion)) {
    $currentVersion = Get-NodeVersion
    if ($currentVersion) {
        Write-Warn "Node.js v$currentVersion found, but v$script:RequiredNodeVersion+ is required"
    } else {
        Write-Warn "Node.js v$script:RequiredNodeVersion+ is required but not found"
    }

    if (Test-IsNonInteractive) {
        Write-Error "Cannot install Node.js in non-interactive mode"
        Write-Info "Please install Node.js v$script:RequiredNodeVersion+ from https://nodejs.org/"
        exit 1
    }

    $install = Read-Host "Install Node.js v$script:RequiredNodeVersion+? (Y/n)"
    if ($install -eq '' -or $install -match '^[Yy]$') {
        if (-not (Install-NodeJS)) {
            Write-Error "Failed to install Node.js"
            exit 1
        }
    } else {
        Write-Error "Node.js is required. Exiting."
        exit 1
    }
} else {
    Write-Success "Node.js v$(Get-NodeVersion) ✓"
}

# Check for build tools (only for npm install)
if ($script:InstallMethod -eq "npm") {
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $hasBuildTools = Test-Path $vsWhere -and (& $vsWhere -products "*" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 2>$null)

    if (-not $hasBuildTools) {
        Write-Warn "Visual Studio Build Tools may be needed for native dependencies"
        if (-not (Test-IsNonInteractive)) {
            $installTools = Read-Host "Install Visual Studio Build Tools? (Y/n)"
            if ($installTools -eq '' -or $installTools -match '^[Yy]$') {
                Install-BuildTools | Out-Null
            }
        }
    }
}

# Install OpenClaw
$version = Resolve-Version

switch ($script:InstallMethod) {
    "npm" {
        if (-not (Install-ViaNpm -Version $version)) {
            exit 1
        }
    }
    "git" {
        if (-not (Install-ViaGit)) {
            exit 1
        }
    }
    default {
        Write-Error "Unknown install method: $script:InstallMethod"
        exit 1
    }
}

# Verify installation
Write-Section "Verifying Installation"

$openclaw = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclaw) {
    try {
        $installedVersion = & openclaw --version 2>$null
        Write-Success "OpenClaw $installedVersion is ready!"
    } catch {
        Write-Success "OpenClaw is installed!"
    }

    Write-Host ""
    Write-Info "Next steps:"
    Write-Info "  1. Run 'openclaw onboard' to set up your AI assistant"
    Write-Info "  2. Run 'openclaw --help' to see available commands"
    Write-Info "  3. Visit https://docs.openclaw.ai for documentation"

    # Run onboarding
    Invoke-Onboarding
} else {
    Write-Warn "openclaw command not found after installation"
    Write-Info "You may need to:"
    Write-Info "  1. Restart PowerShell"
    Write-Info "  2. Add npm global bin to your PATH:"
    Write-Info "     [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + (npm config get prefix) + '\bin', 'User')"
}

Write-Host ""
Write-Celebrate "🦞 OpenClaw installation complete!"
Write-Host ""
