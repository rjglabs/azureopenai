# Quality Checks Environment Activation Helper
# Usage: .\activate_checks.ps1

Write-Host "🔍 Activating Quality Checks Environment" -ForegroundColor Cyan
Write-Host "Purpose: Code quality, security scanning, and AI safety testing" -ForegroundColor Gray

$VenvPath = Join-Path $PSScriptRoot "checks\.venv_checks\Scripts\Activate.ps1"
if (Test-Path $VenvPath) {
    & $VenvPath
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
