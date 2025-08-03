# Development Workflow Guide

## 🚀 Quick Start

### 1. Initial Setup
```powershell
# Clone and navigate to the infrastructure directory
cd C:\AWSRepo\AzureOpenAI\infra

# Option A: Using Poetry (Recommended)
poetry install --with dev
poetry shell

# Option B: Using pip
python -m venv .venv_infra
.\.venv_infra\Scripts\Activate.ps1
pip install -r requirements.txt
pip install -r dev-requirements.txt

# Setup pre-commit hooks
pre-commit install
```

### 2. Using the Makefile (Easy Way)
```powershell
# Complete development setup
make dev-setup

# Quick quality check
make quick-check

# Run all checks
make check-all

# Deploy (dry run first)
make deploy-dry
make deploy
```

## 📋 Development Dependencies

### Production Dependencies (`requirements.txt`)
- Azure SDK packages
- Core utilities (pydantic, rich, click, python-dotenv)

### Development Dependencies (`dev-requirements.txt`)
- **Code Quality**: black, isort, flake8, mypy
- **Testing**: pytest, pytest-cov, pytest-asyncio
- **Security**: bandit, safety, pip-audit
- **Development**: pre-commit, ipython, sphinx

## 🔧 Common Development Tasks

### Code Formatting
```powershell
# Format code
make format
# or manually:
black --line-length 79 .
isort --profile black --line-length 79 .
```

### Code Quality Checks
```powershell
# Lint code
make lint
# or manually:
flake8 . --max-line-length=79
mypy . --config-file=pyproject.toml
```

### Testing
```powershell
# Run tests
make test
# or manually:
pytest --cov=. --cov-report=html
```

### Security Scanning
```powershell
# Security checks
make security
# or manually:
bandit -r . --exclude './.venv*'
safety check
pip-audit
```

## 🔄 Typical Development Workflow

### Before Committing Code
```powershell
# 1. Format and check code
make quick-check

# 2. Run tests
make test

# 3. Security scan
make security

# 4. Test deployment
make deploy-dry
```

### Pre-commit Hooks (Automatic)
The following runs automatically on `git commit`:
- Code formatting (black, isort)
- Linting (flake8)
- Type checking (mypy)
- Security scanning (bandit)
- Environment validation

### CI/CD Simulation
```powershell
# Test the complete CI/CD pipeline locally
make ci-test
```

## 🛠️ Dependency Management

### Using Poetry (Recommended)
```powershell
# Add new dependency
poetry add azure-some-new-package

# Add development dependency
poetry add --group dev some-dev-tool

# Update dependencies
poetry update

# Export to requirements.txt
poetry export -f requirements.txt --output requirements.txt --only main
poetry export -f requirements.txt --output dev-requirements.txt --only dev
```

### Using pip
```powershell
# Install specific version
pip install azure-some-package==1.2.3

# Update requirements files
pip freeze > requirements.txt
```

## 🔒 Security Best Practices

### Secret Management
- Never commit `.env` files
- Use Azure Key Vault for all secrets
- Use `.env.example` for templates

### Code Security
- Run `bandit` for security vulnerabilities
- Use `safety` for known CVEs in dependencies
- Use `pip-audit` for dependency vulnerabilities

### Pre-deployment Validation
```powershell
# Always run dry-run first
make deploy-dry

# Validate environment
make validate-env

# Check Azure authentication
make az-context
```

## 📊 Quality Metrics

### Code Coverage Target
- Minimum: 80%
- Run: `make test` to generate coverage report
- View: Open `htmlcov/index.html`

### Code Quality Checks
- **Black**: Code formatting
- **isort**: Import sorting
- **flake8**: PEP 8 compliance + additional checks
- **mypy**: Type checking
- **bandit**: Security scanning

### Security Scanning
- **bandit**: Python security issues
- **safety**: Known vulnerabilities
- **pip-audit**: Dependency vulnerabilities

## 🚨 Troubleshooting

### Dependency Conflicts
```powershell
# Clear Poetry cache
poetry cache clear --all pypi
rm poetry.lock
poetry install

# Or recreate virtual environment
rm -rf .venv_infra
poetry install
```

### Pre-commit Issues
```powershell
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Run manually
pre-commit run --all-files
```

### Azure Authentication
```powershell
# Check Azure CLI
az account show

# Re-authenticate
az login
```

## 🎯 Tips for Efficient Development

1. **Use the Makefile**: `make help` shows all commands
2. **Run checks frequently**: `make quick-check`
3. **Test before deploying**: Always use `make deploy-dry`
4. **Keep dependencies updated**: `make deps-update`
5. **Monitor security**: Run `make security` regularly

## 📈 Continuous Improvement

### Weekly Tasks
- Update dependencies: `make deps-update`
- Security scan: `make security`
- Review coverage: `make test`

### Monthly Tasks
- Audit dependencies: `pip-audit`
- Review and update dev tools
- Update documentation

This workflow ensures high code quality, security, and reliability for your Azure OpenAI infrastructure deployment!
