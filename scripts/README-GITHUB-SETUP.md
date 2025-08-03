# GitHub Repository Creation Guide

## File: `scripts/create-gh.ps1`

This PowerShell script automates the creation and configuration of GitHub repositories with proper settings for the Azure OpenAI project.

## Configuration Files

### Template Configuration: `scripts/.gh-config.env.template`

```bash
# GitHub Repository Configuration Template
# Copy this to .gh-config.env and customize for your organization

# GitHub Organization/User (required)
GITHUB_ORG=rjglabs

# Repository Settings (required)
REPO_NAME=azureopenai
REPO_DESCRIPTION=Azure OpenAI infrastructure deployment and AI agent development platform with enterprise security
REPO_VISIBILITY=private

# Repository Features
ENABLE_ISSUES=true
ENABLE_PROJECTS=true
ENABLE_WIKI=true
ENABLE_DISCUSSIONS=false

# Branch Protection Settings
DEFAULT_BRANCH=main
REQUIRE_PR_REVIEWS=true
REQUIRE_STATUS_CHECKS=true

# Repository Discovery
REPO_TOPICS=azure,openai,ai,infrastructure,devops,security,pyrit,nuclear-news

# Repository Templates
LICENSE=MIT
GITIGNORE_TEMPLATE=Python

# Organization Specific Settings
# Uncomment and customize as needed:
# TEAM_ACCESS=developers:write,admins:admin
# REQUIRED_REVIEWERS=2
# DISMISS_STALE_REVIEWS=true
# REQUIRE_CODE_OWNER_REVIEWS=true
```

### Your Configuration: `scripts/.gh-config.env`

```bash
# GitHub Repository Configuration
# Your specific settings for rjglabs organization

# GitHub Organization/User
GITHUB_ORG=rjglabs

# Repository Settings
REPO_NAME=azureopenai
REPO_DESCRIPTION=Azure OpenAI infrastructure deployment and AI agent development platform for nuclear industry analysis
REPO_VISIBILITY=private

# Repository Features
ENABLE_ISSUES=true
ENABLE_PROJECTS=true
ENABLE_WIKI=true
ENABLE_DISCUSSIONS=true

# Branch Protection Settings
DEFAULT_BRANCH=main
REQUIRE_PR_REVIEWS=true
REQUIRE_STATUS_CHECKS=true

# Repository Discovery
REPO_TOPICS=azure,openai,ai,infrastructure,devops,security,pyrit,nuclear-industry,news-analysis

# Repository Templates
LICENSE=MIT
GITIGNORE_TEMPLATE=Python
```

## Usage Examples

### Basic Repository Creation
```powershell
# Navigate to your repository
cd C:\AWSRepo\AzureOpenAI

# Create GitHub repository
.\scripts\create-gh.ps1
```

### Advanced Usage
```powershell
# Preview what will be created (dry run)
.\scripts\create-gh.ps1 -DryRun

# Force recreation if repository exists
.\scripts\create-gh.ps1 -Force

# Use custom configuration file
.\scripts\create-gh.ps1 -ConfigFile "custom-config.env"
```

## Prerequisites

### 1. Install GitHub CLI
```powershell
# Using winget (Windows)
winget install GitHub.cli

# Or download from https://cli.github.com/
```

### 2. Authenticate with GitHub
```powershell
# Login to GitHub
gh auth login

# Verify authentication
gh auth status
```

### 3. Ensure Git is Installed
```powershell
# Check git installation
git --version

# If not installed, download from https://git-scm.com/
```

## Features

### 🔧 **Automated Setup**
- Creates GitHub repository with proper settings
- Initializes local git repository
- Pushes initial commit with meaningful message
- Configures remote origin

### 🛡️ **Security Configuration**
- Configurable repository visibility
- Branch protection rules
- Required PR reviews
- Status checks enforcement

### 🏷️ **Repository Management**
- Automatic topic/tag assignment
- License and gitignore setup
- Issue and project board enablement
- Wiki and discussions configuration

### 📊 **Customizable Settings**
- Environment-based configuration
- Template generation for easy setup
- Organization-specific settings
- Dry-run mode for testing

## Integration with Repository Setup

Add this to your main setup workflow:

```powershell
# After running setup-environment.ps1
.\scripts\setup-environment.ps1

# Create GitHub repository
.\scripts\create-gh.ps1

# Deploy infrastructure
cd infra
.\.venv\Scripts\Activate.ps1
python create-ai-foundry-project.py
```

## Script Parameters

- `ConfigFile`: Path to the GitHub configuration file (default: `scripts/.gh-config.env`)
- `Force`: Force recreation of repository if it already exists
- `DryRun`: Show what would be done without actually executing

## Error Handling

The script includes comprehensive error handling for:
- Missing GitHub CLI
- Authentication issues
- Existing repositories
- Configuration file problems
- Git operation failures

## Security Features

- Private repository creation by default
- Branch protection rules
- Required pull request reviews
- Configurable access controls
- Automatic topic/tag assignment for discoverability

This script provides a complete GitHub repository creation solution that's configurable, secure, and integrated with your Azure OpenAI development workflow!
