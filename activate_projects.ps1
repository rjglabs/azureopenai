# Projects Environment Activation Helper
# Usage: .\activate_projects.ps1

Write-Host "🤖 Activating Projects Environment" -ForegroundColor Cyan
Write-Host "Purpose: AI agents and applications development" -ForegroundColor Gray

$VenvPath = Join-Path $PSScriptRoot "projects\.venv_projects\Scripts\Activate.ps1"
if (Test-Path $VenvPath) {
    & $VenvPath
    Write-Host "✅ Projects environment activated" -ForegroundColor Green
    Write-Host "📋 Available commands:" -ForegroundColor Yellow
    Write-Host "   python nuclear-news-agent/main.py" -ForegroundColor White
    Write-Host "   python search-assistant/app.py" -ForegroundColor White
    Write-Host "   jupyter notebook" -ForegroundColor White
} else {
    Write-Host "❌ Projects environment not found" -ForegroundColor Red
    Write-Host "💡 Run: .\scripts\setup-environment.ps1" -ForegroundColor Yellow
}
