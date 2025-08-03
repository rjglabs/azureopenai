# Azure OpenAI Infrastructure - Development Makefile
.PHONY: help install install-dev clean format lint test security check-all deploy-dry deploy validate

# Default target
help: ## Show this help message
	@echo "🏗️ Azure OpenAI Infrastructure - Development Commands"
	@echo "===================================================="
	@echo ""
	@echo "🚀 Setup & Environment:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Install|Upgrade|Setup/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🎨 Code Quality:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Format|Lint|Test|Security|Quality/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "☁️ Azure Deployment:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Deploy|Azure|Validate/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🔧 Utilities & Status:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Show|Check|Verify|Clean/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

# Installation targets
install: ## Install production dependencies only
	@echo "📦 Installing production dependencies..."
	poetry install --only main

install-dev: ## Install all dependencies including dev tools
	@echo "🔧 Installing all dependencies (including dev tools)..."
	poetry install --with dev
	@echo "🪝 Setting up pre-commit hooks..."
	pre-commit install

install-pip: ## Install using pip (alternative to poetry)
	@echo "📦 Installing with pip..."
	pip install -r requirements.txt
	pip install -r dev-requirements.txt

upgrade-python: ## Upgrade to Python 3.13 (simple)
	@echo "🐍 Upgrading to Python 3.13..."
	powershell -ExecutionPolicy Bypass -File scripts/upgrade-python-simple-infra.ps1 -Force

upgrade-python-advanced: ## Upgrade to Python 3.13 (advanced diagnostics)
	@echo "🐍 Advanced Python 3.13 upgrade..."
	powershell -ExecutionPolicy Bypass -File scripts/upgrade-python-infra.ps1 -Force -VerboseOutput

# Code quality targets
format: ## Format code with black and isort
	@echo "🎨 Formatting code..."
	black --line-length 79 --extend-exclude="\.venv.*" .
	isort --profile black --line-length 79 --skip .venv .

lint: ## Run linting with flake8 and mypy
	@echo "🔍 Running linters..."
	flake8 . --max-line-length=79 --extend-ignore=E203,W503 --exclude=.venv*,__pycache__,.git
	mypy . --config-file=pyproject.toml --exclude=".venv.*"

# Testing targets
test: ## Run tests with pytest
	@echo "🧪 Running tests..."
	pytest --cov=. --cov-report=term-missing --cov-report=html --ignore=.venv*

test-verbose: ## Run tests with verbose output
	@echo "🧪 Running tests (verbose)..."
	pytest -v --cov=. --cov-report=term-missing --cov-report=html

# Security targets
security: ## Run security scans
	@echo "🔒 Running security scans..."
	bandit -r . -f txt --exclude './.venv*,./tests'
	safety check
	pip-audit

security-json: ## Run security scans with JSON output
	@echo "📊 Generating security reports..."
	mkdir -p reports
	bandit -r . -f json -o reports/bandit-report.json --exclude './.venv*,./tests'
	safety check --json > reports/safety-report.json
	pip-audit --format=json --output=reports/pip-audit-report.json
	@echo "Reports saved in reports/"

# Combined quality checks
check-all: format lint test security ## Run all quality checks
	@echo "✅ All quality checks completed!"

pre-commit: ## Run pre-commit hooks on all files
	@echo "🪝 Running pre-commit hooks..."
	pre-commit run --all-files

# Azure deployment targets
validate-env: ## Validate environment configuration
	@echo "🔧 Validating environment configuration..."
	python scripts/validate_env_config.py --verbose

deploy-dry: validate-env ## Run deployment dry-run
	@echo "🔍 Running deployment dry-run..."
	python create_ai_foundry_project.py --dry-run

deploy: validate-env ## Deploy to Azure
	@echo "🚀 Deploying to Azure..."
	python create_ai_foundry_project.py

validate: ## Validate deployed resources
	@echo "✅ Validating deployment..."
	python validate_ai_foundry_deployment.py

# Cleanup targets
clean: ## Clean up generated files
	@echo "🧹 Cleaning up..."
	rm -rf .pytest_cache
	rm -rf .mypy_cache
	rm -rf __pycache__
	rm -rf *.egg-info
	rm -rf .coverage
	rm -rf htmlcov
	rm -rf *.log
	rm -rf *-report.json
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete

clean-all: clean ## Clean everything including virtual environment
	@echo "🧹 Deep cleaning..."
	rm -rf .venv_infra
	rm -rf poetry.lock

# Development helpers
deps-update: ## Update dependencies
	@echo "📦 Updating dependencies..."
	poetry update

deps-show: ## Show dependency tree
	@echo "📋 Dependency tree:"
	poetry show --tree

deps-export: ## Export requirements files
	@echo "📤 Exporting requirements..."
	poetry export -f requirements.txt --output requirements.txt --only main
	poetry export -f requirements.txt --output dev-requirements.txt --only dev

python-info: ## Show Python environment info
	@echo "🐍 Python Environment Information:"
	@echo "Python version: $$(python --version 2>/dev/null || echo 'Not available')"
	@echo "Python executable: $$(python -c 'import sys; print(sys.executable)' 2>/dev/null || echo 'Not available')"
	@echo "Virtual environment: $$(echo $$VIRTUAL_ENV || echo 'Not activated')"
	@echo "Poetry environment: $$(poetry env info --path 2>/dev/null || echo 'Not available')"

# Azure CLI helpers
az-login: ## Login to Azure CLI
	@echo "🔐 Logging into Azure..."
	az login

az-context: ## Show Azure context
	@echo "📋 Azure context:"
	az account show

# Quick development workflow
quick-check: format lint ## Quick code quality check
	@echo "⚡ Quick quality check completed!"

# Complete setup workflow
dev-setup: upgrade-python install-dev pre-commit ## Complete development setup
	@echo "🎉 Development environment ready!"

quick-start: install-dev format lint ## Quick start for existing environment
	@echo "⚡ Environment ready for development!"

# CI/CD simulation
ci-test: ## Simulate CI/CD pipeline
	@echo "🔄 Simulating CI/CD pipeline..."
	$(MAKE) clean
	$(MAKE) install-dev
	$(MAKE) format
	$(MAKE) lint
	$(MAKE) test
	$(MAKE) security
	$(MAKE) deploy-dry
	@echo "✅ CI/CD simulation completed!"

# Environment verification
verify-python: ## Verify Python 3.13 setup
	@echo "🔍 Verifying Python setup..."
	@python scripts/validate_env_config.py --python-check 2>/dev/null || python scripts/verify-python.py 2>/dev/null || echo "Python verification script not found"

check-tools: ## Check that all development tools are working
	@echo "🧪 Checking development tools..."
	@python -c "import sys; print(f'✅ Python {sys.version}')" 2>/dev/null || echo "❌ Python not working"
	@black --version >/dev/null 2>&1 && echo "✅ black" || echo "❌ black"
	@isort --version >/dev/null 2>&1 && echo "✅ isort" || echo "❌ isort"
	@flake8 --version >/dev/null 2>&1 && echo "✅ flake8" || echo "❌ flake8"
	@mypy --version >/dev/null 2>&1 && echo "✅ mypy" || echo "❌ mypy"
	@pytest --version >/dev/null 2>&1 && echo "✅ pytest" || echo "❌ pytest"
	@bandit --version >/dev/null 2>&1 && echo "✅ bandit" || echo "❌ bandit"

# Status checks
status: ## Show comprehensive status
	@echo "📊 Infrastructure Status"
	@echo "======================="
	@$(MAKE) python-info
	@echo ""
	@echo "🔧 Development Tools:"
	@$(MAKE) check-tools 2>/dev/null
	@echo ""
	@echo "📁 Files:"
	@echo "Virtual env: $$([ -d .venv_infra ] && echo '✅ .venv_infra exists' || echo '❌ .venv_infra missing')"
	@echo "Poetry config: $$([ -f pyproject.toml ] && echo '✅ pyproject.toml' || echo '❌ pyproject.toml missing')"
	@echo "Environment config: $$([ -f .env ] && echo '✅ .env exists' || echo '⚠️ .env missing (copy from .env.example)')"
	@echo ""
	@echo "☁️ Azure:"
	@echo "Azure CLI: $$(az --version 2>/dev/null | head -1 || echo 'Not installed')"
	@echo "Azure context: $$(az account show --query name -o tsv 2>/dev/null || echo 'Not logged in')"
	@echo ""
	@echo "📋 Git:"
	@git status --porcelain | wc -l | xargs -I {} echo "Modified files: {}"
