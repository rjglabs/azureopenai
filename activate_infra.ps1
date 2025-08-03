# Infrastructure Environment Activation Helper
# Usage: .\activate_infra.ps1

Write-Host "🏗️ Activating Infrastructure Environment" -ForegroundColor Cyan
Write-Host "Purpose: Azure resource deployment and management" -ForegroundColor Gray

$VenvPath = Join-Path $PSScriptRoot "infra\.venv_infra\Scripts\Activate.ps1"
if (Test-Path $VenvPath) {
    & $VenvPath
    Write-Host "✅ Infrastructure environment activated" -ForegroundColor Green
    Write-Host "📋 Available commands:" -ForegroundColor Yellow
    Write-Host "   python create_ai_foundry_project.py --dry-run" -ForegroundColor White
    Write-Host "   python scripts/validate_env_config.py" -ForegroundColor White
    Write-Host "   python validate_ai_foundry_deployment.py" -ForegroundColor White
} else {
    Write-Host "❌ Infrastructure environment not found" -ForegroundColor Red
    Write-Host "💡 Run: .\scripts\setup-environment.ps1" -ForegroundColor Yellow
}
