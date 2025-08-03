#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create GitHub repository with proper configuration
.DESCRIPTION
    Creates a GitHub repository in the specified organization with proper settings,
    initializes local git repository, and pushes initial content.
.PARAMETER ConfigFile
    Path to the GitHub configuration file (default: scripts/.gh-config.env)
.PARAMETER Force
    Force recreation of repository if it already exists
.PARAMETER DryRun
    Show what would be done without actually executing
.EXAMPLE
    .\scripts\create-gh.ps1
    .\scripts\create-gh.ps1 -Force
    .\scripts\create-gh.ps1 -DryRun
#>

param(
    [string]$ConfigFile = "scripts\.gh-config.env",
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Get repository root (parent of scripts folder)
$ScriptsRoot = $PSScriptRoot
$RepoRoot = Split-Path $ScriptsRoot -Parent

Write-Host "🚀 GitHub Repository Creation Script" -ForegroundColor Cyan
Write-Host "Repository Root: $RepoRoot" -ForegroundColor Gray

# Function to load environment configuration
function Get-GitHubConfig {
    param([string]$ConfigPath)
    
    $FullConfigPath = Join-Path $RepoRoot $ConfigPath
    
    if (-not (Test-Path $FullConfigPath)) {
        Write-Host "❌ Configuration file not found: $FullConfigPath" -ForegroundColor Red
        Write-Host "Creating template configuration file..." -ForegroundColor Yellow
        
        # Create template configuration
        $TemplateConfig = @'
# GitHub Repository Configuration
# Copy this to .gh-config.env and customize

# GitHub Organization/User
GITHUB_ORG=rjglabs

# Repository Settings
REPO_NAME=azureopenai
REPO_DESCRIPTION=Azure OpenAI infrastructure deployment and AI agent development platform
REPO_VISIBILITY=private

# Repository Features
ENABLE_ISSUES=true
ENABLE_PROJECTS=true
ENABLE_WIKI=true
ENABLE_DISCUSSIONS=false

# Branch Protection
DEFAULT_BRANCH=main
REQUIRE_PR_REVIEWS=true
REQUIRE_STATUS_CHECKS=true

# Topics for repository discovery
REPO_TOPICS=azure,openai,ai,infrastructure,devops,security,pyrit

# License
LICENSE=MIT

# Additional Settings
AUTO_INIT=false
GITIGNORE_TEMPLATE=Python
'@
        
        $TemplateConfigPath = Join-Path $RepoRoot "scripts\.gh-config.env.template"
        Set-Content -Path $TemplateConfigPath -Value $TemplateConfig -Encoding UTF8
        
        Write-Host "📄 Template created: $TemplateConfigPath" -ForegroundColor Green
        Write-Host "Please copy to .gh-config.env and customize, then run the script again." -ForegroundColor Yellow
        exit 1
    }
    
    # Load configuration
    $Config = @{}
    Get-Content $FullConfigPath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $Key = $Matches[1].Trim()
            $Value = $Matches[2].Trim()
            $Config[$Key] = $Value
        }
    }
    
    return $Config
}

# Function to check GitHub CLI authentication
function Test-GitHubAuth {
    try {
        $AuthStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ GitHub CLI not authenticated" -ForegroundColor Red
            Write-Host "Please run: gh auth login" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ GitHub CLI not found. Please install GitHub CLI." -ForegroundColor Red
        Write-Host "Download from: https://cli.github.com/" -ForegroundColor Yellow
        return $false
    }
}

# Function to check if repository exists
function Test-GitHubRepository {
    param(
        [string]$Organization,
        [string]$RepositoryName
    )
    
    try {
        $RepoInfo = gh repo view "$Organization/$RepositoryName" --json name 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to create GitHub repository
function New-GitHubRepository {
    param(
        [hashtable]$Config,
        [switch]$DryRun
    )
    
    $Organization = $Config['GITHUB_ORG']
    $RepoName = $Config['REPO_NAME']
    $Description = $Config['REPO_DESCRIPTION']
    $Visibility = $Config['REPO_VISIBILITY']
    $Topics = $Config['REPO_TOPICS']
    
    # Build GitHub CLI command with correct flags
    $CreateCommand = @(
        "gh", "repo", "create", "$Organization/$RepoName"
        "--description", "`"$Description`""
    )
    
    # Add visibility flag
    if ($Visibility -eq 'private') { 
        $CreateCommand += "--private"
    } elseif ($Visibility -eq 'public') { 
        $CreateCommand += "--public"
    } elseif ($Visibility -eq 'internal') { 
        $CreateCommand += "--internal"
    }
    
    # Add optional flags (using correct GitHub CLI syntax)
    if ($Config['GITIGNORE_TEMPLATE']) { 
        $CreateCommand += "--gitignore", $Config['GITIGNORE_TEMPLATE'] 
    }
    if ($Config['LICENSE']) { 
        $CreateCommand += "--license", $Config['LICENSE'] 
    }
    
    # Note: GitHub CLI doesn't support --enable-issues, --enable-projects, --enable-wiki flags
    # These need to be configured after repository creation via the API or web interface
    
    Write-Host "🔨 Creating GitHub repository..." -ForegroundColor Green
    Write-Host "   Organization: $Organization" -ForegroundColor Gray
    Write-Host "   Repository: $RepoName" -ForegroundColor Gray
    Write-Host "   Visibility: $Visibility" -ForegroundColor Gray
    
    if ($DryRun) {
        Write-Host "🔍 DRY RUN - Would execute:" -ForegroundColor Yellow
        Write-Host "   $($CreateCommand -join ' ')" -ForegroundColor Gray
        return $true
    }
    
    try {
        & $CreateCommand[0] $CreateCommand[1..($CreateCommand.Length-1)]
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Repository created successfully" -ForegroundColor Green
            
            # Configure repository settings via GitHub API (since CLI doesn't support all flags)
            Write-Host "🔧 Configuring repository settings..." -ForegroundColor Cyan
            
            # Enable/disable issues (if specified)
            if ($Config['ENABLE_ISSUES']) {
                $issuesEnabled = $Config['ENABLE_ISSUES'].ToLower() -eq 'true'
                try {
                    if ($issuesEnabled) {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_issues=true | Out-Null
                        Write-Host "   ✅ Issues enabled" -ForegroundColor Green
                    } else {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_issues=false | Out-Null
                        Write-Host "   ✅ Issues disabled" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "   ⚠️ Could not configure issues setting" -ForegroundColor Yellow
                }
            }
            
            # Enable/disable wiki (if specified)
            if ($Config['ENABLE_WIKI']) {
                $wikiEnabled = $Config['ENABLE_WIKI'].ToLower() -eq 'true'
                try {
                    if ($wikiEnabled) {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_wiki=true | Out-Null
                        Write-Host "   ✅ Wiki enabled" -ForegroundColor Green
                    } else {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_wiki=false | Out-Null
                        Write-Host "   ✅ Wiki disabled" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "   ⚠️ Could not configure wiki setting" -ForegroundColor Yellow
                }
            }
            
            # Enable/disable projects (if specified)
            if ($Config['ENABLE_PROJECTS']) {
                $projectsEnabled = $Config['ENABLE_PROJECTS'].ToLower() -eq 'true'
                try {
                    if ($projectsEnabled) {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_projects=true | Out-Null
                        Write-Host "   ✅ Projects enabled" -ForegroundColor Green
                    } else {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_projects=false | Out-Null
                        Write-Host "   ✅ Projects disabled" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "   ⚠️ Could not configure projects setting" -ForegroundColor Yellow
                }
            }
            
            # Enable/disable discussions (if specified)
            if ($Config['ENABLE_DISCUSSIONS']) {
                $discussionsEnabled = $Config['ENABLE_DISCUSSIONS'].ToLower() -eq 'true'
                try {
                    if ($discussionsEnabled) {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_discussions=true | Out-Null
                        Write-Host "   ✅ Discussions enabled" -ForegroundColor Green
                    } else {
                        gh api "repos/$Organization/$RepoName" --method PATCH --field has_discussions=false | Out-Null
                        Write-Host "   ✅ Discussions disabled" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "   ⚠️ Could not configure discussions setting" -ForegroundColor Yellow
                }
            }
            
            # Add topics if specified
            if ($Topics) {
                Write-Host "🏷️ Adding repository topics..." -ForegroundColor Cyan
                $TopicList = $Topics.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                try {
                    $topicsJson = $TopicList | ConvertTo-Json
                    if ($TopicList.Count -eq 1) {
                        $topicsJson = "[$topicsJson]"
                    }
                    gh api "repos/$Organization/$RepoName/topics" --method PUT --field names="$topicsJson" | Out-Null
                    Write-Host "   ✅ Topics added: $($TopicList -join ', ')" -ForegroundColor Green
                } catch {
                    Write-Host "   ⚠️ Could not add topics: $Topics" -ForegroundColor Yellow
                }
            }
            
            return $true
        } else {
            Write-Host "❌ Failed to create repository" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error creating repository: $_" -ForegroundColor Red
        return $false
    }
}

# Function to initialize local git repository
function Initialize-LocalGitRepository {
    param(
        [hashtable]$Config,
        [switch]$DryRun
    )
    
    $Organization = $Config['GITHUB_ORG']
    $RepoName = $Config['REPO_NAME']
    $DefaultBranch = $Config['DEFAULT_BRANCH'] -or 'main'
    
    Write-Host "📦 Initializing local git repository..." -ForegroundColor Green
    
    Set-Location $RepoRoot
    
    if ($DryRun) {
        Write-Host "🔍 DRY RUN - Would execute git commands" -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Initialize git if not already initialized
        if (-not (Test-Path ".git")) {
            git init
            Write-Host "✅ Git repository initialized" -ForegroundColor Green
        }
        
        # Set default branch
        git branch -M $DefaultBranch
        
        # Add remote origin
        $RemoteUrl = "https://github.com/$Organization/$RepoName.git"
        
        # Remove existing origin if it exists
        $ExistingRemote = git remote get-url origin 2>$null
        if ($ExistingRemote) {
            git remote remove origin
        }
        
        git remote add origin $RemoteUrl
        Write-Host "✅ Remote origin set to: $RemoteUrl" -ForegroundColor Green
        
        # Create initial commit if no commits exist
        $CommitCount = git rev-list --count HEAD 2>$null
        if (-not $CommitCount -or $CommitCount -eq 0) {
            # Stage all files
            git add .
            
            # Create initial commit
            git commit -m "Initial commit: Azure OpenAI repository setup
            
🚀 Repository Features:
- Infrastructure deployment scripts
- AI agent development environment  
- Quality assurance and security tools
- Comprehensive documentation
- CI/CD workflows ready

Created with automated setup script."
            
            Write-Host "✅ Initial commit created" -ForegroundColor Green
        }
        
        # Push to GitHub
        git push -u origin $DefaultBranch
        Write-Host "✅ Code pushed to GitHub" -ForegroundColor Green
        
        return $true
    } catch {
        Write-Host "❌ Error with git operations: $_" -ForegroundColor Red
        return $false
    }
}

# Function to configure branch protection
function Set-BranchProtection {
    param(
        [hashtable]$Config,
        [switch]$DryRun
    )
    
    if ($Config['REQUIRE_PR_REVIEWS'] -ne 'true' -and $Config['REQUIRE_STATUS_CHECKS'] -ne 'true') {
        return $true
    }
    
    $Organization = $Config['GITHUB_ORG']
    $RepoName = $Config['REPO_NAME']
    $DefaultBranch = $Config['DEFAULT_BRANCH'] -or 'main'
    
    Write-Host "🛡️ Configuring branch protection..." -ForegroundColor Green
    
    if ($DryRun) {
        Write-Host "🔍 DRY RUN - Would configure branch protection" -ForegroundColor Yellow
        return $true
    }
    
    try {
        $ProtectionCommand = @(
            "gh", "api", "repos/$Organization/$RepoName/branches/$DefaultBranch/protection"
            "--method", "PUT"
            "--field", "required_status_checks={`"strict`":true,`"contexts`":[]}"
            "--field", "enforce_admins=true"
            "--field", "required_pull_request_reviews={`"required_approving_review_count`":1,`"dismiss_stale_reviews`":true}"
            "--field", "restrictions=null"
        )
        
        & $ProtectionCommand[0] $ProtectionCommand[1..($ProtectionCommand.Length-1)] >$null 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Branch protection configured" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Branch protection setup skipped (may require admin permissions)" -ForegroundColor Yellow
        }
        
        return $true
    } catch {
        Write-Host "⚠️ Could not configure branch protection: $_" -ForegroundColor Yellow
        return $true  # Don't fail the entire process
    }
}

# Main execution
function Main {
    Write-Host ""
    
    # Load configuration
    try {
        $Config = Get-GitHubConfig -ConfigPath $ConfigFile
        Write-Host "✅ Configuration loaded from: $ConfigFile" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to load configuration: $_" -ForegroundColor Red
        exit 1
    }
    
    # Validate GitHub CLI and authentication
    if (-not (Test-GitHubAuth)) {
        exit 1
    }
    
    # Check if repository already exists
    $Organization = $Config['GITHUB_ORG']
    $RepoName = $Config['REPO_NAME']
    
    if (Test-GitHubRepository -Organization $Organization -RepositoryName $RepoName) {
        if ($Force) {
            Write-Host "⚠️ Repository exists. Deleting and recreating..." -ForegroundColor Yellow
            if (-not $DryRun) {
                gh repo delete "$Organization/$RepoName" --confirm
            }
        } else {
            Write-Host "❌ Repository $Organization/$RepoName already exists" -ForegroundColor Red
            Write-Host "Use -Force to delete and recreate" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Create GitHub repository
    if (-not (New-GitHubRepository -Config $Config -DryRun:$DryRun)) {
        exit 1
    }
    
    # Initialize local git repository
    if (-not (Initialize-LocalGitRepository -Config $Config -DryRun:$DryRun)) {
        exit 1
    }
    
    # Configure branch protection
    Set-BranchProtection -Config $Config -DryRun:$DryRun | Out-Null
    
    # Final success message
    Write-Host ""
    Write-Host "🎉 GitHub repository setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Repository Details:" -ForegroundColor Cyan
    Write-Host "   URL: https://github.com/$Organization/$RepoName" -ForegroundColor White
    Write-Host "   Clone: git clone https://github.com/$Organization/$RepoName.git" -ForegroundColor White
    Write-Host "   SSH: git clone git@github.com:$Organization/$RepoName.git" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Configure repository settings in GitHub web interface" -ForegroundColor White
    Write-Host "   2. Set up GitHub Actions secrets if needed" -ForegroundColor White
    Write-Host "   3. Invite collaborators to the repository" -ForegroundColor White
    Write-Host "   4. Configure branch protection rules if needed" -ForegroundColor White
    Write-Host ""
}

# Execute main function
Main