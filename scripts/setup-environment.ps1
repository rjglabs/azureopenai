#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initialize Azure OpenAI repository with context-aware virtual environments
.DESCRIPTION
    Sets up separate virtual environments with descriptive names based on their
    context and purpose, making it clear which environment serves which function.

.NOTES
    This script creates .venv_[context] directories for clear identification
    and better organization across the repository.
#>

param(
    [switch]$Force,
    [string]$PythonVersion = "3.11"
)

$ErrorActionPreference = "Stop"

# Get repository root (parent of scripts folder)
$ScriptsRoot = $PSScriptRoot
$RepoRoot = Split-Path $ScriptsRoot -Parent

Write-Host "🚀 Setting up Azure OpenAI Repository" -ForegroundColor Cyan
Write-Host "Scripts Location: $ScriptsRoot" -ForegroundColor Gray
Write-Host "Repository Root: $RepoRoot" -ForegroundColor Gray

# Function to create context-aware virtual environment
function New-ContextualVirtualEnvironment {
    param(
        [string]$Path,
        [string]$Context,
        [string]$Description,
        [string]$RequirementsFile
    )

    Write-Host "📦 Creating virtual environment: $Context" -ForegroundColor Green
    Write-Host "   Purpose: $Description" -ForegroundColor Gray

    $VenvPath = Join-Path $Path ".venv_$Context"

    if ((Test-Path $VenvPath) -and -not $Force) {
        Write-Host "   Virtual environment already exists. Use -Force to recreate." -ForegroundColor Yellow
        return
    }

    if (Test-Path $VenvPath) {
        Remove-Item $VenvPath -Recurse -Force
    }

    # Create virtual environment
    Set-Location $Path
    python -m venv ".venv_$Context"

    # Activate and install dependencies
    $ActivateScript = Join-Path $VenvPath "Scripts\Activate.ps1"
    if (Test-Path $ActivateScript) {
        & $ActivateScript

        # Upgrade pip
        Write-Host "   Upgrading pip..." -ForegroundColor Cyan
        python -m pip install --upgrade pip

        # Install requirements if they exist
        $ReqPath = Join-Path $Path $RequirementsFile
        if (Test-Path $ReqPath) {
            Write-Host "   Installing $RequirementsFile..." -ForegroundColor Cyan
            pip install -r $ReqPath
        }

        $DevReqPath = Join-Path $Path "dev-requirements.txt"
        if (Test-Path $DevReqPath) {
            Write-Host "   Installing dev-requirements.txt..." -ForegroundColor Cyan
            pip install -r $DevReqPath
        }

        deactivate
    }

    Write-Host "   ✅ Virtual environment created: .venv_$Context" -ForegroundColor Green

    # Return to repository root
    Set-Location $RepoRoot
}

# Function to create file with content
function New-FileWithContent {
    param(
        [string]$FilePath,
        [string]$Content
    )

    $FullPath = Join-Path $RepoRoot $FilePath
    $Directory = Split-Path $FullPath -Parent

    if (-not (Test-Path $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path $FullPath) -or $Force) {
        Set-Content -Path $FullPath -Value $Content -Encoding UTF8
        Write-Host "   Created: $FilePath" -ForegroundColor Gray
    } else {
        Write-Host "   Exists: $FilePath" -ForegroundColor Yellow
    }
}

# Create directory structure
$Directories = @(
    "infra",
    "infra\templates",
    "infra\scripts",
    "projects",
    "projects\nuclear-news-agent",
    "projects\nuclear-news-agent\agents",
    "projects\nuclear-news-agent\tools",
    "projects\nuclear-news-agent\templates",
    "projects\search-assistant",
    "projects\shared",
    "checks",
    "checks\configs",
    "checks\reports",
    "scripts\azure",
    "scripts\python",
    "scripts\maintenance",
    "docs",
    "docs\examples",
    ".github",
    ".github\workflows"
)

Write-Host "📁 Creating directory structure..." -ForegroundColor Green
foreach ($Dir in $Directories) {
    $FullPath = Join-Path $RepoRoot $Dir
    if (-not (Test-Path $FullPath)) {
        New-Item -Path $FullPath -ItemType Directory -Force | Out-Null
        Write-Host "   Created: $Dir" -ForegroundColor Gray
    }
}

# Create enhanced .gitignore
Write-Host "📄 Creating enhanced .gitignore..." -ForegroundColor Green
$GitIgnoreContent = @"
# Virtual environments (context-aware naming)
.venv_*/
.venv/
venv/
env/

# Python cache and artifacts
__pycache__/
*.py[cod]
*`$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Environment files
.env
.env.*
!.env.example
!.env*.template

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Azure files
*.publishsettings

# Logs
*.log
logs/
ai_foundry_deployment_*.log

# Coverage reports
htmlcov/
.coverage
coverage.xml
*.cover

# Test artifacts
.pytest_cache/
.tox/

# Security scan reports
checks/reports/*.json
checks/reports/*.html
checks/reports/*.xml

# Temporary files
*.tmp
*.temp

# Local configuration overrides
local_config/
.local/

# Deployment artifacts
deployment_summary.json
validation-results.json
"@

New-FileWithContent ".gitignore" $GitIgnoreContent

# Create context-aware virtual environments
Write-Host "🔧 Setting up context-aware virtual environments..." -ForegroundColor Green

New-ContextualVirtualEnvironment -Path (Join-Path $RepoRoot "infra") -Context "infra" -Description "Azure infrastructure deployment and management" -RequirementsFile "requirements.txt"
New-ContextualVirtualEnvironment -Path (Join-Path $RepoRoot "projects") -Context "projects" -Description "AI agents and applications development" -RequirementsFile "requirements.txt"
New-ContextualVirtualEnvironment -Path (Join-Path $RepoRoot "checks") -Context "checks" -Description "Quality assurance, security tools, and PyRIT testing" -RequirementsFile "requirements.txt"

# Create activation helper scripts
Write-Host "📜 Creating environment activation helpers..." -ForegroundColor Green

$InfraActivateScript = @"
# Infrastructure Environment Activation Helper
# Usage: .\activate_infra.ps1

Write-Host "🏗️ Activating Infrastructure Environment" -ForegroundColor Cyan
Write-Host "Purpose: Azure resource deployment and management" -ForegroundColor Gray

`$VenvPath = Join-Path `$PSScriptRoot "infra\.venv_infra\Scripts\Activate.ps1"
if (Test-Path `$VenvPath) {
    & `$VenvPath
    Write-Host "✅ Infrastructure environment activated" -ForegroundColor Green
    Write-Host "📋 Available commands:" -ForegroundColor Yellow
    Write-Host "   python create_ai_foundry_project.py --dry-run" -ForegroundColor White
    Write-Host "   python scripts/validate_env_config.py" -ForegroundColor White
    Write-Host "   python validate_ai_foundry_deployment.py" -ForegroundColor White
} else {
    Write-Host "❌ Infrastructure environment not found" -ForegroundColor Red
    Write-Host "💡 Run: .\scripts\setup-environment.ps1" -ForegroundColor Yellow
}
"@

$ProjectsActivateScript = @"
# Projects Environment Activation Helper
# Usage: .\activate_projects.ps1

Write-Host "🤖 Activating Projects Environment" -ForegroundColor Cyan
Write-Host "Purpose: AI agents and applications development" -ForegroundColor Gray

`$VenvPath = Join-Path `$PSScriptRoot "projects\.venv_projects\Scripts\Activate.ps1"
if (Test-Path `$VenvPath) {
    & `$VenvPath
    Write-Host "✅ Projects environment activated" -ForegroundColor Green
    Write-Host "📋 Available commands:" -ForegroundColor Yellow
    Write-Host "   python nuclear-news-agent/main.py" -ForegroundColor White
    Write-Host "   python search-assistant/app.py" -ForegroundColor White
    Write-Host "   jupyter notebook" -ForegroundColor White
} else {
    Write-Host "❌ Projects environment not found" -ForegroundColor Red
    Write-Host "💡 Run: .\scripts\setup-environment.ps1" -ForegroundColor Yellow
}
"@

$ChecksActivateScript = @"
# Quality Checks Environment Activation Helper
# Usage: .\activate_checks.ps1

Write-Host "🔍 Activating Quality Checks Environment" -ForegroundColor Cyan
Write-Host "Purpose: Code quality, security scanning, and AI safety testing" -ForegroundColor Gray

`$VenvPath = Join-Path `$PSScriptRoot "checks\.venv_checks\Scripts\Activate.ps1"
if (Test-Path `$VenvPath) {
    & `$VenvPath
    Write-Host "✅ Quality checks environment activated" -ForegroundColor Green
    Write-Host "📋 Available commands:" -ForegroundColor Yellow
    Write-Host "   python run_quality_checks.py" -ForegroundColor White
    Write-Host "   python run_security_scan.py" -ForegroundColor White
    Write-Host "   python run_pyrit_tests.py" -ForegroundColor White
    Write-Host "   black --check ." -ForegroundColor White
    Write-Host "   flake8 ." -ForegroundColor White
    Write-Host "   mypy ." -ForegroundColor White
} else {
    Write-Host "❌ Quality checks environment not found" -ForegroundColor Red
    Write-Host "💡 Run: .\scripts\setup-environment.ps1" -ForegroundColor Yellow
}
"@

New-FileWithContent "activate_infra.ps1" $InfraActivateScript
New-FileWithContent "activate_projects.ps1" $ProjectsActivateScript
New-FileWithContent "activate_checks.ps1" $ChecksActivateScript

# Create environment info script
$EnvInfoScript = @"
# Environment Information Display
# Usage: .\show_environments.ps1

Write-Host "🌍 Azure OpenAI Repository Environments" -ForegroundColor Cyan
Write-Host "=" * 50

`$Environments = @(
    @{Name="Infrastructure"; Path="infra\.venv_infra"; Purpose="Azure resource deployment"},
    @{Name="Projects"; Path="projects\.venv_projects"; Purpose="AI agents and applications"},
    @{Name="Quality Checks"; Path="checks\.venv_checks"; Purpose="Code quality and security"}
)

foreach (`$env in `$Environments) {
    `$envPath = Join-Path `$PSScriptRoot `$env.Path
    `$status = if (Test-Path `$envPath) { "✅ Ready" } else { "❌ Missing" }

    Write-Host "`n📦 `$(`$env.Name)" -ForegroundColor Green
    Write-Host "   Purpose: `$(`$env.Purpose)" -ForegroundColor Gray
    Write-Host "   Status: `$status" -ForegroundColor $(if (Test-Path `$envPath) { "Green" } else { "Red" })
    Write-Host "   Path: `$(`$env.Path)" -ForegroundColor Gray
}

Write-Host "`n🚀 Quick Activation:" -ForegroundColor Yellow
Write-Host "   .\activate_infra.ps1      # Infrastructure work" -ForegroundColor White
Write-Host "   .\activate_projects.ps1   # AI development" -ForegroundColor White
Write-Host "   .\activate_checks.ps1     # Quality assurance" -ForegroundColor White
"@

New-FileWithContent "show_environments.ps1" $EnvInfoScript

Write-Host "✅ Repository setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Environment Summary:" -ForegroundColor Cyan
Write-Host "   📦 .venv_infra    - Azure infrastructure deployment" -ForegroundColor White
Write-Host "   📦 .venv_projects - AI agents and applications" -ForegroundColor White
Write-Host "   📦 .venv_checks   - Quality assurance and security" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Quick Start Commands:" -ForegroundColor Cyan
Write-Host "   .\show_environments.ps1   # Show environment status" -ForegroundColor White
Write-Host "   .\activate_infra.ps1      # Start infrastructure work" -ForegroundColor White
Write-Host "   .\activate_projects.ps1   # Start AI development" -ForegroundColor White
Write-Host "   .\activate_checks.ps1     # Run quality checks" -ForegroundColor White
Write-Host ""
Write-Host "📚 Or use the Makefile for automation:" -ForegroundColor Cyan
Write-Host "   make setup" -ForegroundColor White
Write-Host "   make status" -ForegroundColor White
Write-Host "   make help" -ForegroundColor White
