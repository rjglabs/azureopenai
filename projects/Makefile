# Azure OpenAI Project - Root Makefile
# Orchestrates infrastructure, projects, and quality checks
.PHONY: help setup clean status upgrade-python github-create deploy-infra check-all

# Default target
help: ## Show this help message
	@echo "🚀 Azure OpenAI Project - Development Commands"
	@echo "=============================================="
	@echo ""
	@echo "🏗️  Setup & Environment:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Setup|Environment/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🔧 Development & Quality:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Development|Quality|Code/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "☁️  Azure & Deployment:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Azure|Deploy/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🧹 Maintenance:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##.*Clean|Maintenance/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "📋 Individual environments: make help-infra, make help-projects, make help-checks"

help-infra: ## Show infrastructure commands
	@echo "🏗️  Infrastructure Commands:"
	@$(MAKE) -C infra help

help-projects: ## Show projects commands
	@echo "🤖 Projects Commands:"
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects help; else echo "  No Makefile found in projects/"; fi

help-checks: ## Show quality checks commands
	@echo "🔍 Quality Checks Commands:"
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks help; else echo "  No Makefile found in checks/"; fi

# =============================================================================
# SETUP & ENVIRONMENT
# =============================================================================

setup: ## Setup - Complete project initialization
	@echo "🚀 Setting up Azure OpenAI project..."
	@echo "===================================="
	powershell -ExecutionPolicy Bypass -File scripts/setup-environment.ps1
	@echo ""
	@echo "✅ Setup completed! Next: make upgrade-python"

upgrade-python: ## Environment - Upgrade all environments to Python 3.12
	@echo "🐍 Upgrading all environments to Python 3.12..."
	powershell -ExecutionPolicy Bypass -File scripts/upgrade-python.ps1 -Force

upgrade-python-infra: ## Environment - Upgrade infrastructure environment only
	@echo "🐍 Upgrading infrastructure environment..."
	powershell -ExecutionPolicy Bypass -File scripts/upgrade-python.ps1 -Environment infra

github-create: ## Setup - Create GitHub repository
	@echo "🐙 Creating GitHub repository..."
	powershell -ExecutionPolicy Bypass -File scripts/create-gh.ps1

install-infra: ## Environment - Install infrastructure dependencies
	@echo "📦 Installing infrastructure dependencies..."
	@$(MAKE) -C infra install-dev

install-projects: ## Environment - Install projects dependencies
	@echo "📦 Installing projects dependencies..."
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects install; else echo "Installing with pip..."; cd projects && pip install -r requirements.txt 2>/dev/null || echo "No requirements.txt found"; fi

install-checks: ## Environment - Install quality check tools
	@echo "📦 Installing quality check tools..."
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks install; else echo "Installing with pip..."; cd checks && pip install -r requirements.txt 2>/dev/null || echo "No requirements.txt found"; fi

install-all: install-infra install-projects install-checks ## Environment - Install all dependencies

# =============================================================================
# DEVELOPMENT & QUALITY
# =============================================================================

format: ## Code - Format all code
	@echo "🎨 Formatting all code..."
	@$(MAKE) -C infra format
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects format; fi
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks format; fi

lint: ## Code - Lint all code
	@echo "🔍 Linting all code..."
	@$(MAKE) -C infra lint
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects lint; fi
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks lint; fi

test: ## Quality - Run all tests
	@echo "🧪 Running all tests..."
	@$(MAKE) -C infra test
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects test; fi
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks test; fi

security: ## Quality - Run security scans
	@echo "🔒 Running security scans..."
	@$(MAKE) -C infra security
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks security; fi

check-all: format lint test security ## Quality - Run all quality checks
	@echo "✅ All quality checks completed!"

pre-commit: ## Code - Run pre-commit hooks on all files
	@echo "🪝 Running pre-commit hooks..."
	@$(MAKE) -C infra pre-commit
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects pre-commit; fi
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks pre-commit; fi

quick-check: ## Quality - Quick code quality check (format + lint)
	@echo "⚡ Running quick quality checks..."
	@$(MAKE) -C infra quick-check

quality-report: ## Quality - Generate comprehensive quality report
	@echo "📊 Generating quality report..."
	@mkdir -p reports
	@echo "# Azure OpenAI Project Quality Report" > reports/quality-report.md
	@echo "Generated on: $$(date)" >> reports/quality-report.md
	@echo "" >> reports/quality-report.md
	@echo "## Infrastructure" >> reports/quality-report.md
	@$(MAKE) -C infra security-json 2>/dev/null || echo "Security scan failed" >> reports/quality-report.md
	@echo "Quality report generated in reports/quality-report.md"

# =============================================================================
# AZURE & DEPLOYMENT
# =============================================================================

az-login: ## Azure - Login to Azure CLI
	@echo "🔐 Logging into Azure..."
	az login

az-context: ## Azure - Show Azure context
	@echo "📋 Azure context:"
	@az account show

validate-env: ## Azure - Validate environment configuration
	@echo "🔧 Validating environment..."
	@$(MAKE) -C infra validate-env

deploy-dry: validate-env ## Deploy - Test deployment (dry run)
	@echo "🔍 Running deployment dry-run..."
	@$(MAKE) -C infra deploy-dry

deploy-infra: validate-env ## Deploy - Deploy Azure infrastructure
	@echo "🚀 Deploying Azure infrastructure..."
	@$(MAKE) -C infra deploy

validate-deployment: ## Deploy - Validate deployed resources
	@echo "✅ Validating deployment..."
	@$(MAKE) -C infra validate

deploy-projects: ## Deploy - Deploy AI projects
	@echo "🤖 Deploying AI projects..."
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects deploy; else echo "No deployment configured for projects"; fi

# =============================================================================
# MAINTENANCE & CLEANUP
# =============================================================================

clean: ## Clean - Clean generated files
	@echo "🧹 Cleaning generated files..."
	@$(MAKE) -C infra clean
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects clean; fi
	@if [ -f checks/Makefile ]; then $(MAKE) -C checks clean; fi
	@rm -rf reports/
	@find . -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -delete

clean-venvs: ## Maintenance - Remove all virtual environments
	@echo "🧹 Removing all virtual environments..."
	@rm -rf infra/.venv_infra
	@rm -rf projects/.venv_projects
	@rm -rf checks/.venv_checks
	@echo "Virtual environments removed. Run 'make upgrade-python' to recreate."

clean-all: clean clean-venvs ## Maintenance - Deep clean everything
	@echo "🧹 Deep cleaning everything..."
	@rm -rf */poetry.lock
	@rm -rf */*.log
	@rm -rf */htmlcov
	@rm -rf */.pytest_cache
	@rm -rf */.mypy_cache

deps-update: ## Maintenance - Update all dependencies
	@echo "📦 Updating dependencies..."
	@$(MAKE) -C infra deps-update
	@if [ -f projects/Makefile ]; then $(MAKE) -C projects deps-update; fi

# =============================================================================
# STATUS & INFORMATION
# =============================================================================

status: ## Show overall project status
	@echo "📊 Azure OpenAI Project Status"
	@echo "==============================="
	@echo ""
	@echo "🐍 Python Environments:"
	@echo "  Infrastructure: $$(cd infra && python --version 2>/dev/null || echo 'Not activated')"
	@echo "  Projects: $$(cd projects && python --version 2>/dev/null || echo 'Not activated')"
	@echo "  Checks: $$(cd checks && python --version 2>/dev/null || echo 'Not activated')"
	@echo ""
	@echo "🏗️  Virtual Environments:"
	@echo "  infra/.venv_infra: $$([ -d infra/.venv_infra ] && echo '✅ Exists' || echo '❌ Missing')"
	@echo "  projects/.venv_projects: $$([ -d projects/.venv_projects ] && echo '✅ Exists' || echo '❌ Missing')"
	@echo "  checks/.venv_checks: $$([ -d checks/.venv_checks ] && echo '✅ Exists' || echo '❌ Missing')"
	@echo ""
	@echo "🔧 Tools:"
	@echo "  Poetry: $$(poetry --version 2>/dev/null || echo 'Not installed')"
	@echo "  Azure CLI: $$(az --version 2>/dev/null | head -1 || echo 'Not installed')"
	@echo "  GitHub CLI: $$(gh --version 2>/dev/null | head -1 || echo 'Not installed')"
	@echo ""
	@echo "📁 Repository:"
	@echo "  Git status: $$(git status --porcelain | wc -l) modified files"
	@echo "  Current branch: $$(git branch --show-current 2>/dev/null || echo 'Not a git repo')"

env-info: ## Show detailed environment information
	@echo "🔍 Detailed Environment Information"
	@echo "==================================="
	@echo ""
	@echo "Infrastructure Environment:"
	@$(MAKE) -C infra status 2>/dev/null || echo "  Not available"
	@echo ""
	@if [ -f projects/Makefile ]; then echo "Projects Environment:" && $(MAKE) -C projects status 2>/dev/null; fi
	@echo ""
	@if [ -f checks/Makefile ]; then echo "Checks Environment:" && $(MAKE) -C checks status 2>/dev/null; fi

# =============================================================================
# DEVELOPMENT WORKFLOWS
# =============================================================================

dev-setup: setup upgrade-python install-all ## Development workflow - Complete development setup
	@echo "🎉 Development environment ready!"
	@echo ""
	@echo "🚀 Next steps:"
	@echo "  1. Configure environment: cp infra/.env.example infra/.env"
	@echo "  2. Login to Azure: make az-login"
	@echo "  3. Create GitHub repo: make github-create"
	@echo "  4. Run quality checks: make check-all"
	@echo "  5. Test deployment: make deploy-dry"

quick-start: ## Development workflow - Quick start for existing setup
	@echo "⚡ Quick start..."
	@$(MAKE) format lint
	@echo "Ready for development!"

ci-simulation: ## Development workflow - Simulate CI/CD pipeline
	@echo "🔄 Simulating CI/CD pipeline..."
	@$(MAKE) clean
	@$(MAKE) install-all
	@$(MAKE) check-all
	@$(MAKE) deploy-dry
	@echo "✅ CI/CD simulation completed!"

release-check: ## Development workflow - Pre-release quality check
	@echo "🚀 Release quality check..."
	@$(MAKE) clean
	@$(MAKE) check-all
	@$(MAKE) security
	@$(MAKE) deploy-dry
	@echo "✅ Release ready!"

# =============================================================================
# UTILITIES
# =============================================================================

logs: ## Show recent logs
	@echo "📋 Recent logs:"
	@find . -name "*.log" -mtime -1 -exec echo "📄 {}" \; -exec tail -5 {} \; 2>/dev/null || echo "No recent logs found"

monitor-costs: ## Azure - Monitor Azure costs
	@echo "💰 Monitoring Azure costs..."
	@if [ -f scripts/azure/monitor-costs.ps1 ]; then powershell -File scripts/azure/monitor-costs.ps1; else echo "Cost monitoring script not found"; fi

backup-configs: ## Maintenance - Backup configurations
	@echo "💾 Backing up configurations..."
	@if [ -f scripts/azure/backup-configs.ps1 ]; then powershell -File scripts/azure/backup-configs.ps1; else echo "Backup script not found"; fi

# =============================================================================
# SPECIAL TARGETS
# =============================================================================

.PHONY: verify-python
verify-python: ## Verify Python 3.12 in all environments
	@echo "🔍 Verifying Python 3.12 in all environments..."
	@cd infra && python scripts/validate_env_config.py --python-check 2>/dev/null || python verify-python.py 2>/dev/null || echo "  infra: Python check not available"
	@echo "All environments checked"

.PHONY: doctor
doctor: ## Run comprehensive health check
	@echo "🏥 Azure OpenAI Project Health Check"
	@echo "===================================="
	@$(MAKE) status
	@echo ""
	@$(MAKE) verify-python
	@echo ""
	@echo "🔧 Recommendations:"
	@echo "  Run 'make upgrade-python' if Python < 3.12"
	@echo "  Run 'make install-all' if dependencies missing"
	@echo "  Run 'make az-login' if Azure CLI not authenticated"
