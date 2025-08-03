#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initialize Azure OpenAI repository with proper virtual environments
.DESCRIPTION
    Sets up separate virtual environments for infrastructure, projects, and tools
    with their respective dependencies and configurations.
    
.NOTES
    This script is located in the /scripts folder and manages the entire repository setup.
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

# Function to create virtual environment
function New-VirtualEnvironment {
    param(
        [string]$Path,
        [string]$Name,
        [string]$RequirementsFile
    )
    
    Write-Host "📦 Creating virtual environment: $Name" -ForegroundColor Green
    
    $VenvPath = Join-Path $Path ".venv"
    
    if ((Test-Path $VenvPath) -and -not $Force) {
        Write-Host "   Virtual environment already exists. Use -Force to recreate." -ForegroundColor Yellow
        return
    }
    
    if (Test-Path $VenvPath) {
        Remove-Item $VenvPath -Recurse -Force
    }
    
    # Create virtual environment
    Set-Location $Path
    python -m venv .venv
    
    # Activate and install dependencies
    $ActivateScript = Join-Path $VenvPath "Scripts\Activate.ps1"
    if (Test-Path $ActivateScript) {
        & $ActivateScript
        
        # Upgrade pip
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
    
    Write-Host "   ✅ Virtual environment created: $VenvPath" -ForegroundColor Green
    
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

# Create essential configuration files
Write-Host "📄 Creating essential configuration files..." -ForegroundColor Green

# Root .gitignore
$GitIgnoreContent = @"
# Virtual environments
.venv/
venv/
env/

# Python cache
__pycache__/
*.py[cod]
*$py.class
*.so

# Environment files
.env
.env.local
.env.*.local

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

# Coverage reports
htmlcov/
.coverage
coverage.xml

# Test artifacts
.pytest_cache/
.tox/

# Distribution / packaging
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

# Security scan reports
checks/reports/*.json
checks/reports/*.html
checks/reports/*.xml

# Temporary files
*.tmp
*.temp
"@

New-FileWithContent ".gitignore" $GitIgnoreContent

# Root README.md
$ReadmeContent = @"
# Azure OpenAI Repository

A comprehensive repository for Azure OpenAI infrastructure deployment and AI project development.

## Repository Structure

- **/infra** - Azure infrastructure deployment scripts and templates
- **/projects** - AI agents and applications with their own dependencies
- **/checks** - Quality assurance, security tools, and PyRIT testing
- **/scripts** - Setup scripts, Azure CLI utilities, and maintenance tools
- **/docs** - Documentation and examples

## Quick Start

1. Initialize the repository:
   .\scripts\setup-environment.ps1

2. Deploy infrastructure:
   cd infra
   .\.venv\Scripts\Activate.ps1
   python create-ai-foundry-project.py

3. Run quality checks:
   cd checks
   .\.venv\Scripts\Activate.ps1
   python run-quality-checks.py

## Environment Management

Each component has its own isolated virtual environment:

- Infrastructure: infra\.venv
- AI Projects: projects\.venv
- Quality Tools: checks\.venv

## Make Commands

Use the provided Makefile for common operations:

make setup           # Initialize everything
make infra-deploy    # Deploy Azure infrastructure
make quality         # Run quality checks
make security        # Run security scans
make pyrit           # Run AI security tests

For more information, see the documentation in /docs.
"@

New-FileWithContent "README.md" $ReadmeContent

# Create virtual environments
Write-Host "🔧 Setting up virtual environments..." -ForegroundColor Green
New-VirtualEnvironment -Path (Join-Path $RepoRoot "infra") -Name "Infrastructure" -RequirementsFile "requirements.txt"
New-VirtualEnvironment -Path (Join-Path $RepoRoot "projects") -Name "Projects" -RequirementsFile "requirements.txt"
New-VirtualEnvironment -Path (Join-Path $RepoRoot "checks") -Name "Quality Tools" -RequirementsFile "requirements.txt"

Write-Host "✅ Repository setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Next steps:" -ForegroundColor Cyan
Write-Host "1. cd infra && .\.venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host "2. cd projects && .\.venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host "3. cd checks && .\.venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host ""
Write-Host "📚 Or use the Makefile for automation:" -ForegroundColor Cyan
Write-Host "   make setup" -ForegroundColor White
Write-Host "   make status" -ForegroundColor White
Write-Host "   make help" -ForegroundColor White