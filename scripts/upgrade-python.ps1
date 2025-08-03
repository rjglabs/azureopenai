#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Upgrade all Python environments to Python 3.12 for Azure OpenAI project

.DESCRIPTION
    This script upgrades all virtual environments in the Azure OpenAI project to use
    Python 3.12 for enhanced security and latest features. It handles:
    - infra/.venv_infra (Infrastructure deployment)
    - projects/.venv_projects (AI agents and applications)
    - checks/.venv_checks (Quality assurance and security)

.PARAMETER Force
    Force recreation of all virtual environments

.PARAMETER Environment
    Specific environment to upgrade: 'infra', 'projects', 'checks', or 'all' (default)

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    .\scripts\upgrade-python.ps1
    .\scripts\upgrade-python.ps1 -Force -VerboseOutput
    .\scripts\upgrade-python.ps1 -Environment infra
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [ValidateSet('infra', 'projects', 'checks', 'all')]
    [string]$Environment = 'all',

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
$Magenta = "`e[35m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param($Color, $Message)
    Write-Host "$Color$Message$Reset"
}

function Write-Separator {
    param($Color = $Blue, $Length = 70)
    $separator = "=" * $Length
    Write-ColorOutput $Color $separator
}

function Test-PythonVersion {
    param($PythonExe)

    try {
        $version = & $PythonExe --version 2>$null
        if ($version -match "Python 3\.13") {
            return @{
                Success = $true
                Version = $version
                Executable = $PythonExe
            }
        }
        return @{Success = $false; Version = $version; Executable = $PythonExe}
    } catch {
        return @{Success = $false; Error = $_.Exception.Message; Executable = $PythonExe}
    }
}

function Find-Python313 {
    Write-ColorOutput $Blue "🔍 Searching for Python 3.13..."

    # Common Python 3.13 executable names/paths
    $pythonCandidates = @(
        "python3.13",
        "python",
        "py -3.13",
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:PROGRAMFILES\Python313\python.exe"
    )

    foreach ($candidate in $pythonCandidates) {
        $result = Test-PythonVersion $candidate
        if ($result.Success) {
            Write-ColorOutput $Green "✅ Found Python 3.13: $($result.Version)"
            return $result.Executable
        }
    }

    Write-ColorOutput $Red "❌ Python 3.13 not found"
    Write-ColorOutput $Yellow "💡 Please install Python 3.13:"
    Write-ColorOutput $Yellow "   Download: https://www.python.org/downloads/"
    Write-ColorOutput $Yellow "   Winget: winget install Python.Python.3.13"
    throw "Python 3.13 not found"
}

function Update-VirtualEnvironment {
    param(
        [string]$EnvName,
        [string]$EnvPath,
        [string]$PythonExe,
        [string]$RequirementsFile,
        [string]$DevRequirementsFile = $null,
        [string]$WorkingDirectory
    )

    Write-ColorOutput $Magenta "🔧 Processing $EnvName environment..."
    Write-Separator $Cyan 50

    $fullEnvPath = Join-Path $WorkingDirectory $EnvPath

    # Check if environment exists
    if (Test-Path $fullEnvPath) {
        if ($Force) {
            Write-ColorOutput $Yellow "🗑️ Removing existing $EnvName environment..."
            Remove-Item -Recurse -Force $fullEnvPath
        } else {
            Write-ColorOutput $Yellow "⚠️ $EnvName environment exists at $fullEnvPath"
            $recreate = Read-Host "Recreate $EnvName environment? (y/N)"
            if ($recreate -eq 'y' -or $recreate -eq 'Y') {
                Remove-Item -Recurse -Force $fullEnvPath
            } else {
                Write-ColorOutput $Blue "🔄 Using existing $EnvName environment..."
                return $true
            }
        }
    }

    # Create new virtual environment
    Write-ColorOutput $Green "🏗️ Creating $EnvName virtual environment with Python 3.13..."
    try {
        Push-Location $WorkingDirectory
        & $PythonExe -m venv $EnvPath
        Write-ColorOutput $Green "✅ $EnvName virtual environment created"
    } catch {
        Write-ColorOutput $Red "❌ Failed to create $EnvName environment: $($_.Exception.Message)"
        return $false
    } finally {
        Pop-Location
    }

    # Activate and verify
    $activateScript = Join-Path $fullEnvPath "Scripts\Activate.ps1"
    if (-not (Test-Path $activateScript)) {
        Write-ColorOutput $Red "❌ Activation script not found for $EnvName"
        return $false
    }

    Write-ColorOutput $Blue "⚡ Setting up $EnvName environment..."
    try {
        Push-Location $WorkingDirectory

        # Activate virtual environment and install dependencies
        $activateScript = Join-Path $fullEnvPath "Scripts\Activate.ps1"

        # Create a script block to run in the virtual environment
        $installCommands = @()
        $installCommands += "& '$activateScript'"
        $installCommands += "Write-Host 'Virtual environment activated'"
        $installCommands += "python -m pip install --upgrade pip setuptools wheel"

        # Add requirements installation
        if ($RequirementsFile -and (Test-Path (Join-Path $WorkingDirectory $RequirementsFile))) {
            $reqFile = Join-Path $WorkingDirectory $RequirementsFile
            $installCommands += "pip install -r '$reqFile'"
            Write-ColorOutput $Blue "📦 Installing from $RequirementsFile"
        }

        if ($DevRequirementsFile -and (Test-Path (Join-Path $WorkingDirectory $DevRequirementsFile))) {
            $devReqFile = Join-Path $WorkingDirectory $DevRequirementsFile
            $installCommands += "pip install -r '$devReqFile'"
            Write-ColorOutput $Blue "🔧 Installing dev dependencies from $DevRequirementsFile"
        }

        # Check for Poetry and install if pyproject.toml exists
        if (Test-Path (Join-Path $WorkingDirectory "pyproject.toml")) {
            $installCommands += @"
try {
    poetry install --with dev
    Write-Host "✅ Poetry dependencies installed"
} catch {
    Write-Host "⚠️ Poetry failed, pip was used instead"
}
"@
        }

        # Execute all commands in sequence
        $scriptBlock = $installCommands -join "`n"

        # Use PowerShell to execute the script block
        $tempScript = Join-Path $env:TEMP "install-deps-$EnvName.ps1"
        $scriptBlock | Out-File -FilePath $tempScript -Encoding UTF8

        # Execute the temporary script
        powershell -ExecutionPolicy Bypass -File $tempScript

        # Clean up
        Remove-Item $tempScript -ErrorAction SilentlyContinue

        Write-ColorOutput $Green "✅ $EnvName environment setup completed"
        return $true

    } catch {
        Write-ColorOutput $Red "❌ Failed to setup $EnvName environment: $($_.Exception.Message)"
        return $false
    } finally {
        Pop-Location
    }
}

function Test-EnvironmentTools {
    param(
        [string]$EnvName,
        [string]$EnvPath,
        [string]$WorkingDirectory,
        [string[]]$ExpectedTools
    )

    Write-ColorOutput $Blue "🧪 Testing $EnvName tools..."

    $fullEnvPath = Join-Path $WorkingDirectory $EnvPath
    $activateScript = Join-Path $fullEnvPath "Scripts\Activate.ps1"

    if (-not (Test-Path $activateScript)) {
        Write-ColorOutput $Red "❌ $EnvName environment not found"
        return $false
    }

    $allGood = $true
    foreach ($tool in $ExpectedTools) {
        try {
            # Create a temporary script to test the tool
            $testScript = @"
& '$activateScript'
$tool --version
"@
            $tempFile = Join-Path $env:TEMP "test-$tool-$EnvName.ps1"
            $testScript | Out-File -FilePath $tempFile -Encoding UTF8

            $result = powershell -ExecutionPolicy Bypass -File $tempFile 2>$null
            Remove-Item $tempFile -ErrorAction SilentlyContinue

            if ($result -and $result.Length -gt 0) {
                Write-ColorOutput $Green "  ✅ $tool"
                if ($VerboseOutput) {
                    Write-ColorOutput $Cyan "     $($result[0])"
                }
            } else {
                Write-ColorOutput $Red "  ❌ $tool (no output)"
                $allGood = $false
            }
        } catch {
            Write-ColorOutput $Red "  ❌ $tool (error: $($_.Exception.Message))"
            $allGood = $false
        }
    }

    return $allGood
}

# Main script execution
Write-ColorOutput $Blue "🐍 Azure OpenAI Project - Python 3.13 Upgrade"
Write-Separator $Blue
Write-ColorOutput $Blue "Upgrading virtual environments for enhanced security and performance"
Write-Separator $Blue

# Verify we're in the correct directory
$currentPath = Get-Location
if (-not (Test-Path "infra") -or -not (Test-Path "projects") -or -not (Test-Path "checks")) {
    Write-ColorOutput $Red "❌ Please run this script from the repository root directory"
    Write-ColorOutput $Yellow "💡 Expected structure: infra/, projects/, checks/ directories"
    exit 1
}

Write-ColorOutput $Green "✅ Repository structure verified"

# Find Python 3.13
try {
    $python313 = Find-Python313
} catch {
    Write-ColorOutput $Red "❌ Cannot proceed without Python 3.13"
    exit 1
}

# Define environments to process
$environments = @()

if ($Environment -eq 'all' -or $Environment -eq 'infra') {
    $environments += @{
        Name = "Infrastructure"
        Path = ".venv_infra"
        WorkingDir = "infra"
        Requirements = "requirements.txt"
        DevRequirements = "dev-requirements.txt"
        Tools = @("black", "flake8", "mypy", "pytest", "bandit")
    }
}

if ($Environment -eq 'all' -or $Environment -eq 'projects') {
    $environments += @{
        Name = "Projects"
        Path = ".venv_projects"
        WorkingDir = "projects"
        Requirements = "requirements.txt"
        DevRequirements = $null
        Tools = @("openai", "langchain", "fastapi")
    }
}

if ($Environment -eq 'all' -or $Environment -eq 'checks') {
    $environments += @{
        Name = "Quality Checks"
        Path = ".venv_checks"
        WorkingDir = "checks"
        Requirements = "requirements.txt"
        DevRequirements = $null
        Tools = @("black", "flake8", "mypy", "pytest", "bandit", "safety", "pyrit")
    }
}

# Process each environment
$results = @()
foreach ($env in $environments) {
    $success = Update-VirtualEnvironment -EnvName $env.Name -EnvPath $env.Path -PythonExe $python313 -RequirementsFile $env.Requirements -DevRequirementsFile $env.DevRequirements -WorkingDirectory $env.WorkingDir

    if ($success) {
        $toolsWorking = Test-EnvironmentTools -EnvName $env.Name -EnvPath $env.Path -WorkingDirectory $env.WorkingDir -ExpectedTools $env.Tools
        $results += @{
            Name = $env.Name
            Success = $success
            ToolsWorking = $toolsWorking
        }
    } else {
        $results += @{
            Name = $env.Name
            Success = $false
            ToolsWorking = $false
        }
    }

    Write-Host ""
}

# Final summary
Write-Separator $Blue
Write-ColorOutput $Green "🎉 Python 3.12 Upgrade Summary"
Write-Separator $Blue

$allSuccess = $true
foreach ($result in $results) {
    if ($result.Success -and $result.ToolsWorking) {
        Write-ColorOutput $Green "✅ $($result.Name): Fully functional"
    } elseif ($result.Success) {
        Write-ColorOutput $Yellow "⚠️ $($result.Name): Created but some tools need attention"
        $allSuccess = $false
    } else {
        Write-ColorOutput $Red "❌ $($result.Name): Failed to create"
        $allSuccess = $false
    }
}

Write-Host ""
if ($allSuccess) {
    Write-ColorOutput $Green "🎉 All environments upgraded successfully!"
    Write-Host ""
    Write-ColorOutput $Blue "🚀 Next steps:"
    Write-ColorOutput $Yellow "  1. Test infrastructure: cd infra && make quick-check"
    Write-ColorOutput $Yellow "  2. Test projects: cd projects && python -m pytest"
    Write-ColorOutput $Yellow "  3. Test checks: cd checks && python run-quality-checks.py"
    Write-ColorOutput $Yellow "  4. Configure environments as needed"
} else {
    Write-ColorOutput $Yellow "⚠️ Some environments need attention - see details above"
    Write-Host ""
    Write-ColorOutput $Blue "🔧 Common fixes:"
    Write-ColorOutput $Yellow "  1. Check Python installation: python --version"
    Write-ColorOutput $Yellow "  2. Verify requirements files exist in each directory"
    Write-ColorOutput $Yellow "  3. Install missing tools manually in each environment"
}

Write-Host ""
Write-ColorOutput $Blue "🔐 Security benefits of Python 3.13:"
Write-ColorOutput $Yellow "  • Latest security patches and CVE fixes"
Write-ColorOutput $Yellow "  • Enhanced memory safety and protection"
Write-ColorOutput $Yellow "  • Improved cryptographic support and performance"
Write-ColorOutput $Yellow "  • Better dependency security scanning"
Write-ColorOutput $Yellow "  • Modern packaging with security validation"
Write-ColorOutput $Yellow "  • Performance improvements and optimizations"

Write-Host ""
Write-ColorOutput $Cyan "💡 To activate environments:"
Write-ColorOutput $Cyan "   Infrastructure: cd infra && .\.venv_infra\Scripts\Activate.ps1"
Write-ColorOutput $Cyan "   Projects: cd projects && .\.venv_projects\Scripts\Activate.ps1"
Write-ColorOutput $Cyan "   Checks: cd checks && .\.venv_checks\Scripts\Activate.ps1"

if (-not $allSuccess) {
    exit 1
}
