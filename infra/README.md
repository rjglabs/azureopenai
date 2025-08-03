# Azure OpenAI Infrastructure

This directory contains the infrastructure-as-code (IaC) configuration and automation scripts for deploying Azure OpenAI resources.

## Overview

The infrastructure setup provides:
- Azure OpenAI service deployment
- AI Foundry project configuration
- Environment validation and verification
- Automated deployment scripts
- Code quality and security checks

## Prerequisites

- Python 3.13+
- Poetry package manager
- Azure CLI
- Azure subscription with appropriate permissions
- PowerShell (for Windows automation scripts)

## Quick Start

1. **Setup Environment**
   ```powershell
   # Activate virtual environment
   .\.venv_infra\Scripts\Activate.ps1

   # Install dependencies
   poetry install
   ```

2. **Configure Environment**
   ```bash
   # Copy example configuration
   cp .env.example .env

   # Edit .env with your Azure settings
   # See Environment Variables section below
   ```

3. **Validate Configuration**
   ```bash
   # Run environment validation
   python scripts/validate_env_config.py

   # Verify Python environment
   python scripts/verify_python.py
   ```

4. **Deploy Infrastructure**
   ```bash
   # Create AI Foundry project (dry-run first)
   python create_ai_foundry_project.py --dry-run

   # Deploy for real
   python create_ai_foundry_project.py
   ```

## Environment Variables

Configure these variables in your `.env` file:

### Required Azure Settings
```bash
# Azure Subscription and Identity
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_RESOURCE_GROUP=your-resource-group
AZURE_LOCATION=eastus

# Azure OpenAI Configuration
AZURE_OPENAI_SERVICE_NAME=your-openai-service
AZURE_OPENAI_ENDPOINT=https://your-service.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_API_VERSION=2024-02-01

# AI Foundry Project
AI_FOUNDRY_PROJECT_NAME=your-project-name
AI_FOUNDRY_HUB_NAME=your-hub-name
```

### Optional Settings
```bash
# Model Deployments
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_MODEL_NAME=gpt-4o
AZURE_OPENAI_MODEL_VERSION=2024-08-06

# Additional Services
AZURE_KEY_VAULT_NAME=your-keyvault
AZURE_STORAGE_ACCOUNT_NAME=your-storage
```

## Directory Structure

```
infra/
├── README.md                    # This file
├── .env.example                 # Environment configuration template
├── .pre-commit-config.yaml      # Pre-commit hooks configuration
├── pyproject.toml              # Python project configuration
├── Makefile                    # Build automation
├── create_ai_foundry_project.py # Main deployment script
├── scripts/                    # Utility scripts
│   ├── validate_env_config.py  # Environment validation
│   └── verify_python.py        # Python environment verification
└── .venv_infra/                # Virtual environment (auto-generated)
```

## Scripts

### `create_ai_foundry_project.py`
Main deployment script for Azure AI Foundry projects.
```bash
# Options
python create_ai_foundry_project.py --dry-run    # Test without deploying
python create_ai_foundry_project.py --verbose    # Detailed output
python create_ai_foundry_project.py --help       # Show all options
```

### `scripts/validate_env_config.py`
Comprehensive environment configuration validator.
```bash
# Validate default .env file
python scripts/validate_env_config.py

# Validate specific file
python scripts/validate_env_config.py --env-file .env.prod

# Show detailed validation rules
python scripts/validate_env_config.py --show-rules
```

### `scripts/verify_python.py`
Python environment verification utility.
```bash
python scripts/verify_python.py
```

## Development Workflow

### Code Quality Tools

We use several tools to maintain code quality:

```bash
# Format code
make format

# Run linters
make lint

# Type checking
make typecheck

# Quick quality check (all tools)
make quick-check

# Run tests
make test
```

### Pre-commit Hooks

Pre-commit hooks are configured to run automatically on git commits:

```bash
# Install hooks
pre-commit install

# Run all hooks manually
pre-commit run --all-files

# Run specific hook
pre-commit run black
pre-commit run mypy
pre-commit run bandit
```

#### Configured Hooks
- **File formatting**: trailing-whitespace, end-of-file-fixer
- **Syntax validation**: check-yaml, check-toml, check-json
- **Code formatting**: black, isort
- **Linting**: flake8, mypy
- **Security**: bandit, detect-private-key, azure-secrets-check
- **Azure validation**: azure-cli-check, validate-env-config
- **Deployment testing**: deployment-dry-run (pre-push only)

### Makefile Targets

```bash
make help           # Show available targets
make install        # Install dependencies
make format         # Format code with black and isort
make lint           # Run flake8 linting
make typecheck      # Run mypy type checking
make security       # Run bandit security checks
make test           # Run pytest tests
make quick-check    # Run format, lint, and typecheck
make clean          # Clean up generated files
```

## Azure Naming Conventions

The infrastructure follows Azure naming conventions:

### Resource Naming Pattern
- **Storage Account**: `st{projectname}{environment}{region}{uniqueid}`
- **Key Vault**: `kv-{projectname}-{environment}-{region}`
- **AI Hub**: `aih-{projectname}-{environment}-{region}`
- **AI Project**: `aip-{projectname}-{environment}-{region}`

### Validation Rules
- Names must be alphanumeric with hyphens
- Cannot start or end with hyphen
- Length restrictions vary by resource type
- Must be globally unique where required

## Security Considerations

### Secrets Management
- Never commit secrets to version control
- Use Azure Key Vault for production secrets
- Environment variables for development only
- Pre-commit hooks scan for potential secrets

### Access Control
- Use Azure managed identities where possible
- Follow principle of least privilege
- Regular access reviews and rotation

### Network Security
- Deploy in private networks where applicable
- Use Azure Private Endpoints for sensitive services
- Enable network security groups and firewalls

## Troubleshooting

### Common Issues

**Environment Validation Fails**
```bash
# Check Azure CLI authentication
az account show

# Verify subscription access
az account list

# Test resource group access
az group show --name $AZURE_RESOURCE_GROUP
```

**Pre-commit Hooks Failing**
```bash
# Update pre-commit hooks
pre-commit autoupdate

# Clear cache if needed
pre-commit clean

# Run specific failing hook
pre-commit run <hook-name> --all-files
```

**Python Environment Issues**
```bash
# Recreate virtual environment
Remove-Item .venv_infra -Recurse -Force
poetry install

# Verify Python version
python --version

# Check installed packages
poetry show
```

### Getting Help

1. Check the [Azure OpenAI documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/)
2. Review Azure CLI error messages and logs
3. Validate your `.env` configuration with the validator
4. Ensure all prerequisites are installed and configured

## Contributing

1. Follow the established code style (enforced by pre-commit hooks)
2. Add type hints to all Python functions
3. Update documentation when making changes
4. Run `make quick-check` before committing
5. Test deployment with `--dry-run` flag first

## License

This project follows the same license as the parent repository.
