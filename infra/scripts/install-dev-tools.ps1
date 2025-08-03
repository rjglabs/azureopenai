#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install development tools for Azure OpenAI Infrastructure project

.DESCRIPTION
    This script installs all development dependencies needed for code quality,
    testing, and security scanning in the infrastructure environment.

.PARAMETER Method
    Installation method: 'poetry' (default) or 'pip'

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    .\install-dev-tools.ps1
    .\install-dev-tools.ps1 -Method pip
    .\install-dev-tools.ps1 -Verbose
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('poetry', 'pip')]
    [string]$Method = 'poetry',

    [Parameter()]
    [switch]$Verbose
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

function Test-InVirtualEnv {
    return $env:VIRTUAL_ENV -or $env:CONDA_DEFAULT_ENV -or (Get-Command python -ErrorAction SilentlyContinue).Source -like "*\.venv*"
}

Write-ColorOutput $Blue "🔧 Azure OpenAI Infrastructure - Development Tools Setup"
Write-ColorOutput $Blue "=" * 60

# Check if we're in a virtual environment
if (-not (Test-InVirtualEnv)) {
    Write-ColorOutput $Yellow "⚠️  Warning: Not in a virtual environment"
    Write-ColorOutput $Yellow "💡 Consider activating .venv_infra first:"
    Write-ColorOutput $Yellow "   .\.venv_infra\Scripts\Activate.ps1"
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-ColorOutput $Red "❌ Installation cancelled"
        exit 1
    }
}

try {
    if ($Method -eq 'poetry') {
        Write-ColorOutput $Green "📦 Installing development dependencies with Poetry..."

        # Check if poetry is available
        if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
            Write-ColorOutput $Red "❌ Poetry not found. Please install Poetry first:"
            Write-ColorOutput $Yellow "   pip install poetry"
            exit 1
        }

        # Install all dependencies including dev group
        if ($Verbose) {
            poetry install --with dev --verbose
        } else {
            poetry install --with dev
        }

        Write-ColorOutput $Green "✅ Poetry dependencies installed successfully"

        # Show installed packages
        Write-ColorOutput $Blue "📋 Installed development tools:"
        poetry show --only dev | ForEach-Object {
            if ($_ -match "^(\S+)\s+(\S+)") {
                Write-ColorOutput $Yellow "  • $($matches[1]) $($matches[2])"
            }
        }

    } else {
        Write-ColorOutput $Green "📦 Installing development dependencies with pip..."

        # Install production dependencies first
        if (Test-Path "requirements.txt") {
            Write-ColorOutput $Blue "📦 Installing production dependencies..."
            pip install -r requirements.txt
        }

        # Install development dependencies
        if (Test-Path "dev-requirements.txt") {
            Write-ColorOutput $Blue "🔧 Installing development dependencies..."
            if ($Verbose) {
                pip install -r dev-requirements.txt --verbose
            } else {
                pip install -r dev-requirements.txt
            }
        } else {
            Write-ColorOutput $Red "❌ dev-requirements.txt not found"
            exit 1
        }

        Write-ColorOutput $Green "✅ pip dependencies installed successfully"
    }

    # Test that key tools are available
    Write-ColorOutput $Blue "🧪 Testing development tools..."

    $tools = @(
        @{Name="black"; Test="black --version"},
        @{Name="isort"; Test="isort --version"},
        @{Name="flake8"; Test="flake8 --version"},
        @{Name="mypy"; Test="mypy --version"},
        @{Name="pytest"; Test="pytest --version"},
        @{Name="bandit"; Test="bandit --version"},
        @{Name="pre-commit"; Test="pre-commit --version"}
    )

    $allGood = $true
    foreach ($tool in $tools) {
        try {
            $null = Invoke-Expression $tool.Test 2>$null
            Write-ColorOutput $Green "  ✅ $($tool.Name)"
        } catch {
            Write-ColorOutput $Red "  ❌ $($tool.Name) - not working"
            $allGood = $false
        }
    }

    if ($allGood) {
        Write-ColorOutput $Green "🎉 All development tools installed and working!"
    } else {
        Write-ColorOutput $Yellow "⚠️  Some tools may need troubleshooting"
    }

    # Setup pre-commit hooks
    Write-ColorOutput $Blue "🪝 Setting up pre-commit hooks..."
    try {
        pre-commit install
        Write-ColorOutput $Green "✅ Pre-commit hooks installed"
    } catch {
        Write-ColorOutput $Yellow "⚠️  Could not install pre-commit hooks: $($_.Exception.Message)"
    }

    Write-ColorOutput $Blue "=" * 60
    Write-ColorOutput $Green "✅ Development environment setup complete!"
    Write-ColorOutput $Blue ""
    Write-ColorOutput $Blue "🚀 Next steps:"
    Write-ColorOutput $Yellow "  1. Run code quality checks: pre-commit run --all-files"
    Write-ColorOutput $Yellow "  2. Run tests: pytest"
    Write-ColorOutput $Yellow "  3. Format code: black ."
    Write-ColorOutput $Yellow "  4. Sort imports: isort ."
    Write-ColorOutput $Yellow "  5. Check types: mypy ."

} catch {
    Write-ColorOutput $Red "❌ Installation failed: $($_.Exception.Message)"
    exit 1
}
