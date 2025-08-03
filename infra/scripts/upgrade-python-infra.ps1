#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Upgrade Infrastructure Python environment to Python 3.13

.DESCRIPTION
    This script upgrades just the infrastructure virtual environment to Python 3.13
    for enhanced security and latest features.

.PARAMETER Force
    Force recreation of virtual environment

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    .\upgrade-python-infra.ps1
    .\upgrade-python-infra.ps1 -Force -VerboseOutput
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$VerboseOutput
)

# Set error handling
$ErrorActionPreference = "Stop"

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param($Color, $Message)
    Write-Host "$Color$Message$Reset"
}

function Write-Separator {
    param($Length = 60)
    Write-ColorOutput $Blue ("=" * $Length)
}

Write-ColorOutput $Blue "🐍 Infrastructure Python 3.13 Upgrade"
Write-Separator

# Check current Python version
try {
    $currentPython = python --version 2>$null
    Write-ColorOutput $Cyan "📋 Current Python: $currentPython"
} catch {
    Write-ColorOutput $Red "❌ Python not found in PATH"
}

# Find Python 3.13
$python313 = $null
$pythonCandidates = @("python3.13", "python")

foreach ($candidate in $pythonCandidates) {
    try {
        $version = & $candidate --version 2>$null
        if ($version -match "Python 3\.13") {
            $python313 = $candidate
            Write-ColorOutput $Green "✅ Found Python 3.13: $version"
            break
        }
    } catch {
        continue
    }
}

if (-not $python313) {
    Write-ColorOutput $Red "❌ Python 3.13 not found"
    Write-ColorOutput $Yellow "💡 Install Python 3.13:"
    Write-ColorOutput $Yellow "   winget install Python.Python.3.13"
    exit 1
}

# Handle existing virtual environment
$venvPath = ".venv_infra"
if (Test-Path $venvPath) {
    if ($Force) {
        Write-ColorOutput $Yellow "🗑️ Removing existing virtual environment..."
        Remove-Item -Recurse -Force $venvPath
    } else {
        Write-ColorOutput $Yellow "⚠️ Virtual environment exists"
        $recreate = Read-Host "Recreate? (y/N)"
        if ($recreate -eq 'y' -or $recreate -eq 'Y') {
            Remove-Item -Recurse -Force $venvPath
        }
    }
}

# Create new virtual environment
if (-not (Test-Path $venvPath)) {
    Write-ColorOutput $Green "🏗️ Creating Python 3.13 virtual environment..."
    try {
        & $python313 -m venv $venvPath
        Write-ColorOutput $Green "✅ Virtual environment created"
    } catch {
        Write-ColorOutput $Red "❌ Failed to create virtual environment: $($_.Exception.Message)"
        exit 1
    }
}

# Activate and install dependencies
Write-ColorOutput $Blue "📦 Installing dependencies..."
try {
    & "$venvPath\Scripts\Activate.ps1"

    # Upgrade pip
    python -m pip install --upgrade pip setuptools wheel

    # Remove old poetry lock file
    if (Test-Path "poetry.lock") {
        Remove-Item "poetry.lock"
        Write-ColorOutput $Yellow "🗑️ Removed old poetry.lock"
    }

    # Install with Poetry if available
    try {
        if ($VerboseOutput) {
            poetry install --with dev --verbose
        } else {
            poetry install --with dev
        }
        Write-ColorOutput $Green "✅ Poetry dependencies installed"
    } catch {
        Write-ColorOutput $Yellow "⚠️ Poetry failed, trying pip..."

        if (Test-Path "requirements.txt") {
            pip install -r requirements.txt
        }
        if (Test-Path "dev-requirements.txt") {
            pip install -r dev-requirements.txt
        }
        Write-ColorOutput $Green "✅ Pip dependencies installed"
    }

} catch {
    Write-ColorOutput $Red "❌ Dependency installation failed: $($_.Exception.Message)"
    exit 1
}

# Test tools
Write-ColorOutput $Blue "🧪 Testing tools..."
$tools = @("black", "isort", "flake8", "mypy", "pytest", "bandit")
$allGood = $true

foreach ($tool in $tools) {
    try {
        $null = & $tool --version 2>$null
        Write-ColorOutput $Green "  ✅ $tool"
    } catch {
        Write-ColorOutput $Red "  ❌ $tool"
        $allGood = $false
    }
}

# Setup pre-commit
try {
    pre-commit install
    Write-ColorOutput $Green "✅ Pre-commit hooks installed"
} catch {
    Write-ColorOutput $Yellow "⚠️ Pre-commit setup failed (optional)"
}

# Final summary
Write-Separator
if ($allGood) {
    Write-ColorOutput $Green "🎉 Infrastructure environment upgraded successfully!"
    Write-ColorOutput $Blue "🚀 Next steps:"
    Write-ColorOutput $Yellow "  1. Test: make quick-check"
    Write-ColorOutput $Yellow "  2. Deploy: make deploy-dry"
} else {
    Write-ColorOutput $Yellow "⚠️ Some tools need attention"
}

Write-ColorOutput $Cyan "💡 Activate: .\.venv_infra\Scripts\Activate.ps1"
