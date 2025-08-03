#!/usr/bin/env pwsh
param([switch]$Force)

# Colors for output formatting
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

Write-ColorOutput $Blue "Python 3.13 Infrastructure Upgrade"
Write-ColorOutput $Blue ("=" * 50)

# Find Python 3.13
Write-ColorOutput $Blue "Searching for Python 3.13..."
$python = $null
$candidates = @("python3.13", "python", "py -3.13")

foreach ($candidate in $candidates) {
    try {
        $version = & $candidate --version 2>$null
        if ($version -match "Python 3\.13") {
            $python = $candidate
            Write-ColorOutput $Green "Found: $version"
            break
        }
    } catch {
        continue
    }
}

if (-not $python) {
    Write-ColorOutput $Red "Python 3.13 not found"
    Write-ColorOutput $Yellow "Install with: winget install Python.Python.3.13"
    exit 1
}

# Handle existing virtual environment
$venvPath = ".venv_infra"
if (Test-Path $venvPath) {
    if ($Force) {
        Write-ColorOutput $Yellow "Removing existing virtual environment..."
        Remove-Item -Recurse -Force $venvPath
    } else {
        $response = Read-Host "Remove existing virtual environment? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Remove-Item -Recurse -Force $venvPath
        }
    }
}

# Create new virtual environment
if (-not (Test-Path $venvPath)) {
    Write-ColorOutput $Green "Creating Python 3.13 virtual environment..."
    try {
        & $python -m venv $venvPath
        Write-ColorOutput $Green "Virtual environment created"
    } catch {
        Write-ColorOutput $Red "Failed to create virtual environment: $($_.Exception.Message)"
        exit 1
    }
}

# Install dependencies
Write-ColorOutput $Blue "Installing dependencies..."
try {
    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
    & $activateScript

    Write-ColorOutput $Blue "Upgrading pip..."
    python -m pip install --upgrade pip setuptools wheel

    if (Test-Path "poetry.lock") {
        Remove-Item "poetry.lock"
        Write-ColorOutput $Yellow "Removed old poetry.lock"
    }

    if (Test-Path "pyproject.toml") {
        Write-ColorOutput $Blue "Installing with Poetry..."
        try {
            poetry install --with dev
            Write-ColorOutput $Green "Poetry dependencies installed"
        } catch {
            Write-ColorOutput $Yellow "Poetry failed, trying pip..."
            if (Test-Path "requirements.txt") {
                pip install -r requirements.txt
            }
            if (Test-Path "dev-requirements.txt") {
                pip install -r dev-requirements.txt
            }
            Write-ColorOutput $Green "Pip dependencies installed"
        }
    } else {
        Write-ColorOutput $Blue "Installing with pip..."
        if (Test-Path "requirements.txt") {
            pip install -r requirements.txt
        }
        if (Test-Path "dev-requirements.txt") {
            pip install -r dev-requirements.txt
        }
        Write-ColorOutput $Green "Pip dependencies installed"
    }
} catch {
    Write-ColorOutput $Red "Dependency installation failed: $($_.Exception.Message)"
    exit 1
}

# Test tools
Write-ColorOutput $Blue "Testing key tools..."
$tools = @("black", "isort", "flake8", "mypy", "pytest", "bandit")
$allGood = $true

foreach ($tool in $tools) {
    try {
        $null = & $tool --version 2>$null
        Write-ColorOutput $Green "  OK: $tool"
    } catch {
        Write-ColorOutput $Red "  FAIL: $tool (not working)"
        $allGood = $false
    }
}

# Setup pre-commit
Write-ColorOutput $Blue "Setting up pre-commit hooks..."
try {
    pre-commit install
    Write-ColorOutput $Green "Pre-commit hooks installed"
} catch {
    Write-ColorOutput $Yellow "Pre-commit setup failed (optional)"
}

# Summary
Write-ColorOutput $Blue ("=" * 50)
if ($allGood) {
    Write-ColorOutput $Green "Infrastructure environment upgraded successfully!"
    Write-Host ""
    Write-ColorOutput $Blue "Next steps:"
    Write-ColorOutput $Yellow "  1. Test: make quick-check"
    Write-ColorOutput $Yellow "  2. Validate config: make validate-env"
    Write-ColorOutput $Yellow "  3. Deploy: make deploy-dry"
} else {
    Write-ColorOutput $Yellow "Some tools need attention"
}

Write-Host ""
Write-ColorOutput $Cyan "Tip: Activate environment with: .\.venv_infra\Scripts\Activate.ps1"
Write-ColorOutput $Cyan "Tip: Check Python version with: python --version"
