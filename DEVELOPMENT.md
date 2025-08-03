# Development Guide

This repository is structured as a Python monorepo with centralized development tooling and project-specific runtime environments.

## Repository Structure

```
AzureOpenAI/
├── pyproject.toml           # Root-level dev dependencies & tool configs
├── .pre-commit-config.yaml  # Pre-commit hooks for entire repo
├── .venv/                   # Development environment (gitignored)
├── infra/                   # Infrastructure deployment
│   ├── pyproject.toml       # Only runtime dependencies
│   └── .venv_infra/         # Runtime environment (gitignored)
├── projects/                # Application projects
│   ├── nuclear-news-agent/
│   ├── search-assistant/
│   └── shared/
├── scripts/                 # Utility scripts
└── checks/                  # Quality assurance
```

## Development Environment Setup

### 1. Root Development Environment

The root directory contains all development tools (linters, formatters, testing, pre-commit):

```powershell
# Create root development environment
python -m venv .venv
.venv\Scripts\Activate.ps1

# Install all development dependencies
pip install -e .
```

### 2. Project-Specific Runtime Environments

Each project has its own virtual environment with only runtime dependencies:

```powershell
# Infrastructure deployment environment
cd infra
python -m venv .venv_infra
.venv_infra\Scripts\Activate.ps1
pip install -e .

# Return to root for development
cd ..
.venv\Scripts\Activate.ps1
```

## Development Workflow

### Code Quality Automation

All code quality tools run from the root environment and are configured to:
- **Exclude all virtual environments** (`.venv*` patterns)
- **Check all project code** across the entire repository
- **Use consistent formatting** and style rules

```powershell
# Activate root development environment
.venv\Scripts\Activate.ps1

# Format code across entire repo
black .
isort .

# Lint code across entire repo
flake8 .
mypy .

# Run tests with coverage
pytest --cov=. --cov-report=html

# Security scanning
bandit -r . -x .venv*
safety check
```

### Pre-commit Hooks

Pre-commit hooks run automatically on commits and cover:
- **Code formatting** (black, isort)
- **Linting** (flake8, mypy)
- **Security checks** (bandit, secrets detection)
- **Azure-specific validations** (CLI auth, config validation)
- **Project-specific checks** (infrastructure validation)

```powershell
# Install pre-commit hooks (one-time setup)
.venv\Scripts\Activate.ps1
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

## Tool Configurations

### Centralized at Root Level

All development tools are configured in the root `pyproject.toml`:

- **black**: Code formatting (line length: 79)
- **isort**: Import sorting (black-compatible profile)
- **flake8**: Linting with plugins for docstrings, imports, black, isort
- **mypy**: Static type checking (strict mode)
- **pytest**: Testing with coverage, asyncio support
- **bandit**: Security scanning
- **coverage**: Code coverage reporting

### Virtual Environment Exclusions

All tools are configured to exclude virtual environments:
```toml
[tool.black]
extend-exclude = '''
/(\.venv.*|__pycache__|\.git|\.mypy_cache|\.pytest_cache)/
'''

[tool.isort]
skip_glob = ["*/.venv*/*", "*/__pycache__/*"]

[tool.mypy]
exclude = [".venv.*", "__pycache__"]
```

## Project Dependencies

### Root Level (Development)
- All linting, formatting, testing tools
- Pre-commit hooks and configurations
- Type stubs and development utilities

### Project Level (Runtime)
- Only packages needed to run the application
- Azure SDKs and service dependencies
- Business logic libraries

## Best Practices

### For Contributors

1. **Always work from root environment** for development tasks
2. **Use project environments** only for running/testing deployments
3. **Run pre-commit hooks** before pushing code
4. **Keep project dependencies minimal** (runtime only)
5. **Add new dev tools to root pyproject.toml** only

### For New Projects

1. Create project directory under `projects/` or appropriate location
2. Create project-specific `pyproject.toml` with only runtime dependencies
3. Add project-specific virtual environment (`.venv_projectname`)
4. Update root `.gitignore` to exclude new virtual environment
5. Consider adding project-specific pre-commit hooks to root config

### For CI/CD

1. Use root environment for all quality checks
2. Use project environments for deployment testing
3. Ensure all `.venv*` directories are properly excluded
4. Run full test suite from root environment

## Troubleshooting

### Tool Performance Issues
- Ensure `.venv*` patterns are excluded in all tool configs
- Virtual environments should never be scanned by linters
- Use `--exclude` flags if tools are scanning wrong directories

### Pre-commit Hook Failures
- Check that root environment is activated
- Verify all dependencies are installed with `pip install -e .`
- Run individual hooks with `pre-commit run <hook-id>`

### Environment Conflicts
- Deactivate other environments before activating target environment
- Use absolute paths when switching between project environments
- Ensure `PYTHONPATH` doesn't point to other project directories

## Azure-Specific Notes

### Authentication
- Azure CLI must be authenticated for deployment hooks
- Use `az login` for interactive authentication
- Service principal authentication for CI/CD pipelines

### Infrastructure Validation
- Infrastructure environment config is validated on each commit
- Azure resource deployment includes dry-run testing
- Secrets detection prevents accidental credential commits

### Key Vault Integration
- All secrets should be stored in Azure Key Vault
- Local `.env` files are for development defaults only
- Production secrets are retrieved at runtime from Key Vault
