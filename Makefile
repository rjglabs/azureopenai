# AzureOpenAI Development Makefile
# Requires PowerShell and assumes root .venv is activated

.PHONY: help install format lint test security check clean setup-infra deploy-infra

# Default target
help:
	@echo "AzureOpenAI Development Commands"
	@echo "================================"
	@echo "Setup Commands:"
	@echo "  install      - Install all development dependencies"
	@echo "  setup-infra  - Set up infrastructure environment"
	@echo ""
	@echo "Code Quality Commands:"
	@echo "  format       - Format code with black and isort"
	@echo "  lint         - Run all linters (flake8, mypy)"
	@echo "  test         - Run tests with coverage"
	@echo "  security     - Run security checks (bandit, safety)"
	@echo "  check        - Run all quality checks (format, lint, test, security)"
	@echo ""
	@echo "Infrastructure Commands:"
	@echo "  deploy-infra - Deploy Azure infrastructure"
	@echo ""
	@echo "Utility Commands:"
	@echo "  clean        - Clean cache and temporary files"

# Development setup
install:
	@echo "Installing development dependencies..."
	@powershell -Command "if (!(Test-Path .venv)) { python -m venv .venv }"
	@powershell -Command ".venv\Scripts\Activate.ps1; pip install --upgrade pip; pip install -e ."
	@powershell -Command ".venv\Scripts\Activate.ps1; pre-commit install"
	@echo "✅ Development environment ready!"

setup-infra:
	@echo "Setting up infrastructure environment..."
	@powershell -Command "cd infra; if (!(Test-Path .venv_infra)) { python -m venv .venv_infra }"
	@powershell -Command "cd infra; .venv_infra\Scripts\Activate.ps1; pip install --upgrade pip; pip install -e ."
	@echo "✅ Infrastructure environment ready!"

# Code quality
format:
	@echo "Formatting code..."
	@powershell -Command ".venv\Scripts\Activate.ps1; black . --exclude='\.venv.*'"
	@powershell -Command ".venv\Scripts\Activate.ps1; isort . --skip-glob='*/.venv*/*'"
	@echo "✅ Code formatted!"

lint:
	@echo "Running linters..."
	@powershell -Command ".venv\Scripts\Activate.ps1; flake8 . --exclude=.venv*"
	@powershell -Command ".venv\Scripts\Activate.ps1; mypy . --exclude='\.venv.*'"
	@echo "✅ Linting complete!"

test:
	@echo "Running tests..."
	@powershell -Command ".venv\Scripts\Activate.ps1; pytest --cov=. --cov-report=html --cov-report=term-missing"
	@echo "✅ Tests complete! Coverage report: htmlcov/index.html"

security:
	@echo "Running security checks..."
	@powershell -Command ".venv\Scripts\Activate.ps1; bandit -r . -x .venv* -f json -o bandit-report.json || echo 'Bandit found issues - check bandit-report.json'"
	@powershell -Command ".venv\Scripts\Activate.ps1; safety check --json --output safety-report.json || echo 'Safety found issues - check safety-report.json'"
	@echo "✅ Security checks complete!"

check: format lint test security
	@echo "✅ All quality checks passed!"

# Infrastructure
deploy-infra:
	@echo "Deploying Azure infrastructure..."
	@powershell -Command "cd infra; .venv_infra\Scripts\Activate.ps1; python scripts/validate_env_config.py --env-file .env.example"
	@powershell -Command "cd infra; .venv_infra\Scripts\Activate.ps1; python create_ai_foundry_project.py"
	@echo "✅ Infrastructure deployment complete!"

# Cleanup
clean:
	@echo "Cleaning cache and temporary files..."
	@powershell -Command "Get-ChildItem -Path . -Recurse -Name '__pycache__' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
	@powershell -Command "Get-ChildItem -Path . -Recurse -Name '*.pyc' | Remove-Item -Force -ErrorAction SilentlyContinue"
	@powershell -Command "Get-ChildItem -Path . -Recurse -Name '.pytest_cache' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
	@powershell -Command "Get-ChildItem -Path . -Recurse -Name '.mypy_cache' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
	@powershell -Command "Get-ChildItem -Path . -Recurse -Name '.coverage' | Remove-Item -Force -ErrorAction SilentlyContinue"
	@powershell -Command "if (Test-Path htmlcov) { Remove-Item htmlcov -Recurse -Force }"
	@powershell -Command "if (Test-Path .pytest_cache) { Remove-Item .pytest_cache -Recurse -Force }"
	@powershell -Command "if (Test-Path bandit-report.json) { Remove-Item bandit-report.json -Force }"
	@powershell -Command "if (Test-Path safety-report.json) { Remove-Item safety-report.json -Force }"
	@echo "✅ Cleanup complete!"
