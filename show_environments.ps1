# Environment Information Display
# Usage: .\show_environments.ps1

Write-Host "🌍 Azure OpenAI Repository Environments" -ForegroundColor Cyan
Write-Host ("=" * 50)

$Environments = @(
    @{Name="Infrastructure"; Path="infra\.venv_infra"; Purpose="Azure resource deployment"},
    @{Name="Projects"; Path="projects\.venv_projects"; Purpose="AI agents and applications"},
    @{Name="Quality Checks"; Path="checks\.venv_checks"; Purpose="Code quality and security"}
)

foreach ($env in $Environments) {
    $envPath = Join-Path $PSScriptRoot $env.Path
    $status = if (Test-Path $envPath) { "✅ Ready" } else { "❌ Missing" }

    Write-Host "
📦 $($env.Name)" -ForegroundColor Green
    Write-Host "   Purpose: $($env.Purpose)" -ForegroundColor Gray
    Write-Host "   Status: $status" -ForegroundColor Red
    Write-Host "   Path: $($env.Path)" -ForegroundColor Gray
}

Write-Host "
🚀 Quick Activation:" -ForegroundColor Yellow
Write-Host "   .\activate_infra.ps1      # Infrastructure work" -ForegroundColor White
Write-Host "   .\activate_projects.ps1   # AI development" -ForegroundColor White
Write-Host "   .\activate_checks.ps1     # Quality assurance" -ForegroundColor White
