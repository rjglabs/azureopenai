# Azure OpenAI Repository

A comprehensive repository for Azure OpenAI infrastructure deployment and AI project development.

## Repository Structure

- **/infra** - Azure infrastructure deployment scripts and templates
- **/projects** - AI agents and applications with their own dependencies
- **/checks** - Quality assurance, security tools, and PyRIT testing
- **/scripts** - Setup scripts, Azure CLI utilities, and maintenance tools
- **/docs** - Documentation and examples

## Quick Start

1. Initialize the repository:
   .\scripts\setup-environment.ps1

2. Deploy infrastructure:
   cd infra
   .\.venv\Scripts\Activate.ps1
   python create-ai-foundry-project.py

3. Run quality checks:
   cd checks
   .\.venv\Scripts\Activate.ps1
   python run-quality-checks.py

## Environment Management

Each component has its own isolated virtual environment:

- Infrastructure: infra\.venv
- AI Projects: projects\.venv
- Quality Tools: checks\.venv

## Make Commands

Use the provided Makefile for common operations:

make setup           # Initialize everything
make infra-deploy    # Deploy Azure infrastructure
make quality         # Run quality checks
make security        # Run security scans
make pyrit           # Run AI security tests

For more information, see the documentation in /docs.
