#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple Python 3.13 upgrade script for Azure OpenAI project

.DESCRIPTION
    A simplified version that upgrades all virtual environments to Python 3.13
    using a more straightforward approach.

.PARAMETER Force
    Force recreation of virtual environments

.EXAMPLE
    .\scripts\upgrade-python-simple.ps1 -Force
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force
)

# Set error handling
$ErrorActionPreference = "Stop"

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param($Color, $Message)
    Write-Host "$Color$Message$Reset"
}

function Write-Separator {
    Write-ColorOutput $Blue ("=" * 60)
}

Write-ColorOutput $Blue "🐍 Azure OpenAI Project - Python 3.13 Simple Upgrade"
Write-Separator

# Check if we're in the right directory
if (-not (Test-Path "infra") -or -not (Test-Path "projects") -or -not (Test-Path "checks")) {
    Write-ColorOutput $Red "❌ Please run from repository root (should contain infra/, projects/, checks/)"
    exit 1
}

# Find Python 3.13
Write-ColorOutput $Blue "🔍 Searching for Python 3.13..."
$python = $null

$candidates = @("python3.13", "python", "py -3.13")
foreach ($candidate in $candidates) {
    try {
        $version = & $candidate --version 2>$null
        if ($version -match "Python 3\.13") {
            $python = $candidate
            Write-ColorOutput $Green "✅ Found: $version"
            break
        }
    } catch {
        continue
    }
}

if (-not $python) {
    Write-ColorOutput $Red "❌ Python 3.13 not found"
    Write-ColorOutput $Yellow "Install with: winget install Python.Python.3.13"
    exit 1
}

# Define environments
$environments = @(
    @{Name="Infrastructure"; Dir="infra"; VEnv=".venv_infra"},
    @{Name="Projects"; Dir="projects"; VEnv=".venv_projects"},
    @{Name="Quality Checks"; Dir="checks"; VEnv=".venv_checks"}
)

$results = @()

foreach ($env in $environments) {
    Write-ColorOutput $Blue "🔧 Processing $($env.Name)..."

    $envPath = Join-Path $env.Dir $env.VEnv

    # Remove existing environment if Force or if user confirms
    if (Test-Path $envPath) {
        if ($Force) {
            Write-ColorOutput $Yellow "🗑️ Removing existing environment..."
            Remove-Item -Recurse -Force $envPath
        } else {
            $response = Read-Host "Remove existing $($env.Name) environment? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Remove-Item -Recurse -Force $envPath
            }
        }
    }

    # Create new environment
    if (-not (Test-Path $envPath)) {
        Write-ColorOutput $Green "🏗️ Creating Python 3.13 virtual environment..."
        try {
            Push-Location $env.Dir
            & $python -m venv $env.VEnv
            Write-ColorOutput $Green "✅ Virtual environment created"
        } catch {
            Write-ColorOutput $Red "❌ Failed to create environment: $($_.Exception.Message)"
            $results += @{Name=$env.Name; Success=$false}
            Pop-Location
            continue
        } finally {
            Pop-Location
        }
    }

    # Install dependencies
    Write-ColorOutput $Blue "📦 Installing dependencies..."
    try {
        Push-Location $env.Dir

        # Activate environment and upgrade pip
        $activateScript = Join-Path $env.VEnv "Scripts\Activate.ps1"
        & $activateScript
        python -m pip install --upgrade pip setuptools wheel

        # Install requirements
        if (Test-Path "requirements.txt") {
            Write-ColorOutput $Blue "📦 Installing from requirements.txt..."
            pip install -r requirements.txt
        }

        if (Test-Path "dev-requirements.txt") {
            Write-ColorOutput $Blue "🔧 Installing dev dependencies..."
            pip install -r dev-requirements.txt
        }

        # Try Poetry if pyproject.toml exists
        if (Test-Path "pyproject.toml") {
            Write-ColorOutput $Blue "📦 Trying Poetry installation..."
            try {
                # Remove old poetry.lock for fresh resolution
                if (Test-Path "poetry.lock") {
                    Remove-Item "poetry.lock"
                }
                poetry install --with dev
                Write-ColorOutput $Green "✅ Poetry dependencies installed"
            } catch {
                Write-ColorOutput $Yellow "⚠️ Poetry failed, pip was used instead"
            }
        }

        Write-ColorOutput $Green "✅ $($env.Name) environment completed"
        $results += @{Name=$env.Name; Success=$true}

    } catch {
        Write-ColorOutput $Red "❌ Failed to install dependencies: $($_.Exception.Message)"
        $results += @{Name=$env.Name; Success=$false}
    } finally {
        Pop-Location
    }

    Write-Host ""
}

# Summary
Write-Separator
Write-ColorOutput $Green "🎉 Python 3.13 Upgrade Summary"
Write-Separator

$allSuccess = $true
foreach ($result in $results) {
    if ($result.Success) {
        Write-ColorOutput $Green "✅ $($result.Name): Success"
    } else {
        Write-ColorOutput $Red "❌ $($result.Name): Failed"
        $allSuccess = $false
    }
}

if ($allSuccess) {
    Write-ColorOutput $Green "🎉 All environments upgraded successfully!"
    Write-Host ""
    Write-ColorOutput $Blue "🚀 Next steps:"
    Write-ColorOutput $Yellow "  1. Test infrastructure: cd infra && make quick-check"
    Write-ColorOutput $Yellow "  2. Test projects: cd projects && python --version"
    Write-ColorOutput $Yellow "  3. Test checks: cd checks && python run-quality-checks.py"
} else {
    Write-ColorOutput $Yellow "⚠️ Some environments failed - check messages above"
}

Write-Host ""
Write-ColorOutput $Blue "💡 To activate environments:"
Write-ColorOutput $Cyan "   Infrastructure: cd infra && .\.venv_infra\Scripts\Activate.ps1"
Write-ColorOutput $Cyan "   Projects: cd projects && .\.venv_projects\Scripts\Activate.ps1"
Write-ColorOutput $Cyan "   Checks: cd checks && .\.venv_checks\Scripts\Activate.ps1"
