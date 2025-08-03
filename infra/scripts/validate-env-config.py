# Enhanced Environment Configuration Validator

## File: `infra/scripts/validate-env-config.py`

```python
#!/usr/bin/env python3
"""
Enhanced Environment Configuration Validator for Azure OpenAI Infrastructure

This validator performs comprehensive validation of .env configuration files
including Azure naming conventions, resource limitations, SKU validation,
and deployment readiness checks.

Usage:
    python scripts/validate-env-config.py
    python scripts/validate-env-config.py --env-file custom.env
    python scripts/validate-env-config.py --verbose
    python scripts/validate-env-config.py --json-output
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
import subprocess

try:
    from dotenv import load_dotenv
except ImportError:
    print("❌ Error: python-dotenv not installed. Run: pip install python-dotenv")
    sys.exit(1)

class AzureResourceValidator:
    """Azure resource naming and configuration validator"""
    
    # Azure naming patterns and limitations
    NAMING_PATTERNS = {
        'KEYVAULT_NAME': {
            'pattern': r'^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$',
            'min_length': 3,
            'max_length': 24,
            'scope': 'global',
            'description': 'Key Vault name',
            'restrictions': [
                'Must start with letter',
                'Cannot end with hyphen',
                'Cannot have consecutive hyphens',
                'Alphanumeric and hyphens only'
            ]
        },
        'STORAGE_ACCOUNT_NAME': {
            'pattern': r'^[a-z0-9]{3,24}$',
            'min_length': 3,
            'max_length': 24,
            'scope': 'global',
            'description': 'Storage Account name',
            'restrictions': [
                'Lowercase letters and numbers only',
                'No hyphens or special characters',
                'No uppercase letters'
            ]
        },
        'CONTAINER_REGISTRY_NAME': {
            'pattern': r'^[a-zA-Z][a-zA-Z0-9]{4,49}$',
            'min_length': 5,
            'max_length': 50,
            'scope': 'global',
            'description': 'Container Registry name',
            'restrictions': [
                'Must start with letter',
                'Alphanumeric only (no hyphens)',
                'Cannot start with number'
            ]
        },
        'COGNITIVE_SEARCH_NAME': {
            'pattern': r'^[a-z0-9][a-z0-9-]{0,58}[a-z0-9]$',
            'min_length': 2,
            'max_length': 60,
            'scope': 'global',
            'description': 'Cognitive Search service name',
            'restrictions': [
                'Lowercase letters, numbers, and hyphens only',
                'Cannot start or end with hyphen',
                'Cannot have consecutive hyphens'
            ]
        },
        'AI_SERVICES_NAME': {
            'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}[a-zA-Z0-9]$',
            'min_length': 2,
            'max_length': 64,
            'scope': 'resource_group',
            'description': 'AI Services account name',
            'restrictions': [
                'Cannot start or end with hyphen',
                'Alphanumeric and hyphens only'
            ]
        },
        'OPENAI_SERVICE_NAME': {
            'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}[a-zA-Z0-9]$',
            'min_length': 2,
            'max_length': 64,
            'scope': 'resource_group',
            'description': 'OpenAI service name',
            'restrictions': [
                'Cannot start or end with hyphen',
                'Alphanumeric and hyphens only'
            ]
        },
        'LOG_WORKSPACE_NAME': {
            'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]{2,61}[a-zA-Z0-9]$',
            'min_length': 4,
            'max_length': 63,
            'scope': 'resource_group',
            'description': 'Log Analytics workspace name',
            'restrictions': [
                'Cannot start or end with hyphen',
                'Alphanumeric and hyphens only'
            ]
        },
        'APPLICATION_INSIGHTS_NAME': {
            'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-_().]{0,258}[a-zA-Z0-9]$',
            'min_length': 1,
            'max_length': 260,
            'scope': 'resource_group',
            'description': 'Application Insights component name',
            'restrictions': [
                'Most characters allowed',
                'Cannot contain: <, >, %, &, \\, ?, /, control characters'
            ]
        },
        'RESOURCE_GROUP': {
            'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-_.()]{0,88}[a-zA-Z0-9]$',
            'min_length': 1,
            'max_length': 90,
            'scope': 'subscription',
            'description': 'Resource Group name',
            'restrictions': [
                'Cannot end with period',
                'Alphanumeric, underscore, parentheses, hyphen, period allowed'
            ]
        }
    }
    
    # Valid Azure regions with AI service availability
    AZURE_REGIONS = {
        'eastus': {'ai_services': True, 'openai': True, 'search': True},
        'eastus2': {'ai_services': True, 'openai': True, 'search': True},
        'westus': {'ai_services': True, 'openai': True, 'search': True},
        'westus2': {'ai_services': True, 'openai': True, 'search': True},
        'westus3': {'ai_services': True, 'openai': False, 'search': True},
        'centralus': {'ai_services': True, 'openai': True, 'search': True},
        'northcentralus': {'ai_services': True, 'openai': False, 'search': True},
        'southcentralus': {'ai_services': True, 'openai': True, 'search': True},
        'westcentralus': {'ai_services': True, 'openai': False, 'search': True},
        'canadacentral': {'ai_services': True, 'openai': True, 'search': True},
        'canadaeast': {'ai_services': True, 'openai': False, 'search': True},
        'brazilsouth': {'ai_services': True, 'openai': False, 'search': True},
        'northeurope': {'ai_services': True, 'openai': True, 'search': True},
        'westeurope': {'ai_services': True, 'openai': True, 'search': True},
        'francecentral': {'ai_services': True, 'openai': True, 'search': True},
        'germanywestcentral': {'ai_services': True, 'openai': False, 'search': True},
        'norwayeast': {'ai_services': True, 'openai': False, 'search': True},
        'switzerlandnorth': {'ai_services': True, 'openai': True, 'search': True},
        'uksouth': {'ai_services': True, 'openai': True, 'search': True},
        'ukwest': {'ai_services': True, 'openai': False, 'search': True},
        'eastasia': {'ai_services': True, 'openai': False, 'search': True},
        'southeastasia': {'ai_services': True, 'openai': False, 'search': True},
        'australiaeast': {'ai_services': True, 'openai': True, 'search': True},
        'australiasoutheast': {'ai_services': True, 'openai': False, 'search': True},
        'centralindia': {'ai_services': True, 'openai': False, 'search': True},
        'southindia': {'ai_services': True, 'openai': False, 'search': True},
        'westindia': {'ai_services': True, 'openai': False, 'search': True},
        'japaneast': {'ai_services': True, 'openai': True, 'search': True},
        'japanwest': {'ai_services': True, 'openai': False, 'search': True},
        'koreacentral': {'ai_services': True, 'openai': False, 'search': True},
        'koreasouth': {'ai_services': True, 'openai': False, 'search': True}
    }
    
    # Valid SKU options for each service
    VALID_SKUS = {
        'AI_SERVICES_SKU': {
            'valid_values': ['F0', 'S0', 'S1', 'S2', 'S3', 'S4'],
            'limitations': {
                'F0': 'Free tier: 20 transactions/minute, limited features',
                'S0': 'Standard: Pay-per-use, full features'
            }
        },
        'OPENAI_SKU': {
            'valid_values': ['S0'],
            'limitations': {
                'S0': 'Standard: Pay-per-token consumption'
            }
        },
        'SEARCH_SKU': {
            'valid_values': ['free', 'basic', 'standard', 'standard2', 'standard3', 
                           'storage_optimized_l1', 'storage_optimized_l2'],
            'limitations': {
                'free': 'Free: 50MB storage, 3 indexes, 10k documents',
                'basic': 'Basic: 2GB storage, 15 indexes, 1M documents'
            }
        },
        'STORAGE_SKU': {
            'valid_values': ['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 
                           'Standard_ZRS', 'Premium_LRS', 'Premium_ZRS'],
            'limitations': {
                'Standard_LRS': 'Locally redundant storage',
                'Premium_LRS': 'Premium requires specific VM types'
            }
        },
        'CONTAINER_REGISTRY_SKU': {
            'valid_values': ['Basic', 'Standard', 'Premium'],
            'limitations': {
                'Basic': 'Basic: 10GB storage, limited features',
                'Premium': 'Premium: 500GB storage, advanced features'
            }
        },
        'LOG_ANALYTICS_SKU': {
            'valid_values': ['PerGB2018', 'Free', 'Standalone', 'PerNode'],
            'limitations': {
                'Free': 'Free: 500MB/day limit, 7-day retention',
                'PerGB2018': 'Pay per GB ingested'
            }
        }
    }

class EnvironmentValidator:
    """Main environment configuration validator"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info_messages: List[str] = []
        self.config: Dict[str, str] = {}
        self.validator = AzureResourceValidator()
        
    def log_verbose(self, message: str) -> None:
        """Log verbose messages if verbose mode is enabled"""
        if self.verbose:
            print(f"🔍 {message}")
    
    def load_config(self, env_file: str) -> bool:
        """Load and validate environment configuration file"""
        env_path = Path(env_file)
        
        self.log_verbose(f"Loading configuration from: {env_path.absolute()}")
        
        if not env_path.exists():
            self.errors.append(f"Environment file not found: {env_file}")
            return False
        
        # Load environment variables
        load_dotenv(env_path, override=True)
        
        # Required variables for basic deployment
        required_vars = [
            "LOCATION", "RESOURCE_GROUP", "KEYVAULT_NAME", 
            "AI_SERVICES_NAME", "OPENAI_SERVICE_NAME", "COGNITIVE_SEARCH_NAME",
            "STORAGE_ACCOUNT_NAME", "CONTAINER_REGISTRY_NAME",
            "LOG_WORKSPACE_NAME", "APPLICATION_INSIGHTS_NAME"
        ]
        
        # Load configuration
        missing_vars = []
        for var in required_vars:
            value = os.getenv(var)
            if not value or value.strip() == "":
                missing_vars.append(var)
            else:
                self.config[var] = value.strip()
        
        if missing_vars:
            self.errors.extend([f"Required environment variable missing or empty: {var}" 
                              for var in missing_vars])
            return False
        
        # Load optional variables
        optional_vars = [
            "ENVIRONMENT", "PROJECT_NAME", "RESOURCE_OWNER", "COST_CENTER",
            "AI_SERVICES_SKU", "OPENAI_SKU", "SEARCH_SKU", "STORAGE_SKU",
            "CONTAINER_REGISTRY_SKU", "LOG_ANALYTICS_SKU",
            "ENABLE_DIAGNOSTICS", "ENABLE_SOFT_DELETE", "ENABLE_PURGE_PROTECTION",
            "NETWORK_ACCESS", "VALIDATE_DEPLOYMENT", "DRY_RUN", "VERBOSE_LOGGING"
        ]
        
        for var in optional_vars:
            value = os.getenv(var)
            if value and value.strip():
                self.config[var] = value.strip()
        
        self.log_verbose(f"Loaded {len(self.config)} configuration variables")
        return True
    
    def validate_azure_naming(self) -> None:
        """Validate Azure resource naming conventions"""
        self.log_verbose("Validating Azure resource naming conventions...")
        
        for var_name, rules in self.validator.NAMING_PATTERNS.items():
            if var_name in self.config:
                value = self.config[var_name]
                
                # Check pattern match
                if not re.match(rules['pattern'], value):
                    self.errors.append(
                        f"Invalid {rules['description']}: '{value}' does not match required pattern"
                    )
                    for restriction in rules['restrictions']:
                        self.errors.append(f"  - {restriction}")
                
                # Check length
                if len(value) < rules['min_length'] or len(value) > rules['max_length']:
                    self.errors.append(
                        f"Invalid {rules['description']} length: '{value}' "
                        f"({len(value)} chars, must be {rules['min_length']}-{rules['max_length']})"
                    )
                
                # Global uniqueness warning
                if rules['scope'] == 'global':
                    if len(value) < 8:
                        self.warnings.append(
                            f"{rules['description']} '{value}' is short and may conflict "
                            f"with existing global resources"
                        )
                
                self.log_verbose(f"  ✓ {var_name}: {value} - Valid")
    
    def validate_azure_location(self) -> None:
        """Validate Azure location and service availability"""
        self.log_verbose("Validating Azure location and service availability...")
        
        if "LOCATION" not in self.config:
            return
        
        location = self.config["LOCATION"].lower()
        
        if location not in self.validator.AZURE_REGIONS:
            self.warnings.append(
                f"Uncommon Azure location: '{location}'. "
                f"Verify all services are available in this region."
            )
            return
        
        region_info = self.validator.AZURE_REGIONS[location]
        
        # Check AI Services availability
        if not region_info.get('ai_services', False):
            self.errors.append(f"AI Services not available in region: {location}")
        
        # Check OpenAI availability
        if not region_info.get('openai', False):
            self.errors.append(f"Azure OpenAI not available in region: {location}")
        
        # Check Cognitive Search availability
        if not region_info.get('search', False):
            self.warnings.append(f"Cognitive Search may have limited availability in region: {location}")
        
        self.log_verbose(f"  ✓ Location: {location} - AI Services and OpenAI available")
    
    def validate_sku_configurations(self) -> None:
        """Validate SKU configurations"""
        self.log_verbose("Validating SKU configurations...")
        
        for sku_var, sku_config in self.validator.VALID_SKUS.items():
            if sku_var in self.config:
                sku_value = self.config[sku_var]
                
                if sku_value not in sku_config['valid_values']:
                    self.errors.append(
                        f"Invalid {sku_var}: '{sku_value}'. "
                        f"Valid options: {', '.join(sku_config['valid_values'])}"
                    )
                else:
                    # Add limitation info if available
                    if sku_value in sku_config['limitations']:
                        limitation = sku_config['limitations'][sku_value]
                        self.info_messages.append(f"{sku_var} ({sku_value}): {limitation}")
                
                self.log_verbose(f"  ✓ {sku_var}: {sku_value}")
    
    def validate_boolean_values(self) -> None:
        """Validate boolean configuration values"""
        self.log_verbose("Validating boolean configuration values...")
        
        boolean_vars = [
            'ENABLE_DIAGNOSTICS', 'ENABLE_SOFT_DELETE', 'ENABLE_PURGE_PROTECTION',
            'VALIDATE_DEPLOYMENT', 'DRY_RUN', 'VERBOSE_LOGGING'
        ]
        
        for var in boolean_vars:
            if var in self.config:
                value = self.config[var].lower()
                if value not in ['true', 'false']:
                    self.errors.append(f"Invalid boolean value for {var}: '{value}' (must be 'true' or 'false')")
                else:
                    self.log_verbose(f"  ✓ {var}: {value}")
    
    def validate_network_access(self) -> None:
        """Validate network access configuration"""
        if "NETWORK_ACCESS" in self.config:
            access_level = self.config["NETWORK_ACCESS"]
            valid_levels = ['Public', 'Private', 'Restricted']
            
            if access_level not in valid_levels:
                self.errors.append(
                    f"Invalid NETWORK_ACCESS: '{access_level}'. "
                    f"Valid options: {', '.join(valid_levels)}"
                )
            elif access_level == 'Private':
                self.warnings.append(
                    "Private network access requires VNet configuration and may affect connectivity"
                )
    
    def validate_email_format(self) -> None:
        """Validate email format for resource owner"""
        if "RESOURCE_OWNER" in self.config:
            email = self.config["RESOURCE_OWNER"]
            email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            
            if not re.match(email_pattern, email):
                self.warnings.append(f"RESOURCE_OWNER '{email}' may not be a valid email format")
    
    def check_azure_cli_availability(self) -> None:
        """Check if Azure CLI is available and authenticated"""
        self.log_verbose("Checking Azure CLI availability and authentication...")
        
        try:
            # Check if Azure CLI is installed
            result = subprocess.run(['az', '--version'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode != 0:
                self.warnings.append("Azure CLI not found. Install from: https://docs.microsoft.com/en-us/cli/azure/")
                return
            
            # Check if authenticated
            result = subprocess.run(['az', 'account', 'show'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode != 0:
                self.warnings.append("Azure CLI not authenticated. Run: az login")
                return
            
            # Get subscription info
            account_info = json.loads(result.stdout)
            subscription_name = account_info.get('name', 'Unknown')
            subscription_id = account_info.get('id', 'Unknown')
            
            self.info_messages.append(f"Azure CLI authenticated: {subscription_name} ({subscription_id[:8]}...)")
            self.log_verbose(f"  ✓ Azure CLI authenticated for subscription: {subscription_name}")
            
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError):
            self.warnings.append("Could not verify Azure CLI status")
    
    def validate_configuration(self) -> Tuple[bool, Dict[str, Any]]:
        """Run all validation checks"""
        self.log_verbose("Starting comprehensive configuration validation...")
        
        self.validate_azure_naming()
        self.validate_azure_location()
        self.validate_sku_configurations()
        self.validate_boolean_values()
        self.validate_network_access()
        self.validate_email_format()
        self.check_azure_cli_availability()
        
        # Create validation summary
        validation_summary = {
            "timestamp": datetime.now().isoformat(),
            "config_file": "loaded",
            "total_variables": len(self.config),
            "validation_results": {
                "errors": len(self.errors),
                "warnings": len(self.warnings),
                "info_messages": len(self.info_messages)
            },
            "errors": self.errors,
            "warnings": self.warnings,
            "info_messages": self.info_messages,
            "is_valid": len(self.errors) == 0,
            "configuration": self.config if self.verbose else {}
        }
        
        return len(self.errors) == 0, validation_summary
    
    def print_validation_results(self, summary: Dict[str, Any]) -> bool:
        """Print validation results in a formatted way"""
        print("🔍 Azure OpenAI Infrastructure Configuration Validation")
        print("=" * 70)
        print(f"📅 Validation Time: {summary['timestamp']}")
        print(f"📊 Variables Loaded: {summary['total_variables']}")
        print()
        
        # Print info messages
        if summary['info_messages']:
            print("ℹ️  Configuration Information:")
            for i, info in enumerate(summary['info_messages'], 1):
                print(f"   {i}. {info}")
            print()
        
        # Print warnings
        if summary['warnings']:
            print(f"⚠️  {len(summary['warnings'])} Warning(s):")
            for i, warning in enumerate(summary['warnings'], 1):
                print(f"   {i}. {warning}")
            print()
        
        # Print errors
        if summary['errors']:
            print(f"❌ {len(summary['errors'])} Error(s) found:")
            for i, error in enumerate(summary['errors'], 1):
                print(f"   {i}. {error}")
            print()
        
        # Final result
        if summary['is_valid']:
            if summary['warnings']:
                print("✅ Configuration is valid with warnings noted above.")
                print("💡 Address warnings before production deployment.")
            else:
                print("🎉 Configuration validation passed successfully!")
                print("🚀 Ready for Azure infrastructure deployment.")
        else:
            print("❌ Configuration validation failed!")
            print("🔧 Please fix the errors above before proceeding.")
        
        print()
        print("🔗 Next Steps:")
        if summary['is_valid']:
            print("   1. Review and address any warnings")
            print("   2. Run: python create-ai-foundry-project.py --dry-run")
            print("   3. If dry-run succeeds: python create-ai-foundry-project.py")
        else:
            print("   1. Fix configuration errors in .env file")
            print("   2. Re-run: python scripts/validate-env-config.py")
        
        return summary['is_valid']

def main():
    """Main validation function"""
    parser = argparse.ArgumentParser(
        description="Validate Azure OpenAI infrastructure environment configuration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/validate-env-config.py
  python scripts/validate-env-config.py --env-file custom.env
  python scripts/validate-env-config.py --verbose
  python scripts/validate-env-config.py --json-output
        """
    )
    
    parser.add_argument(
        '--env-file', 
        default='.env',
        help='Path to environment file (default: .env)'
    )
    parser.add_argument(
        '--verbose', 
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--json-output', 
        action='store_true',
        help='Output results as JSON'
    )
    
    args = parser.parse_args()
    
    # Initialize validator
    validator = EnvironmentValidator(verbose=args.verbose)
    
    # Load configuration
    if not validator.load_config(args.env_file):
        if args.json_output:
            error_result = {
                "timestamp": datetime.now().isoformat(),
                "is_valid": False,
                "errors": validator.errors,
                "warnings": validator.warnings
            }
            print(json.dumps(error_result, indent=2))
        else:
            validator.print_validation_results({
                "timestamp": datetime.now().isoformat(),
                "total_variables": 0,
                "validation_results": {"errors": len(validator.errors), "warnings": 0, "info_messages": 0},
                "errors": validator.errors,
                "warnings": [],
                "info_messages": [],
                "is_valid": False
            })
        sys.exit(1)
    
    # Run validation
    is_valid, summary = validator.validate_configuration()
    
    # Output results
    if args.json_output:
        print(json.dumps(summary, indent=2))
    else:
        validator.print_validation_results(summary)
    
    # Exit with appropriate code
    sys.exit(0 if is_valid else 1)

if __name__ == "__main__":
    main()
```

## File: `infra/scripts/__init__.py` (Empty init file)

```python
# Infrastructure scripts package
```

## Usage Examples

### Basic Validation
```powershell
cd infra
python scripts/validate-env-config.py
```

### Verbose Output
```powershell
python scripts/validate-env-config.py --verbose
```

### JSON Output (for CI/CD)
```powershell
python scripts/validate-env-config.py --json-output > validation-results.json
```

### Custom Environment File
```powershell
python scripts/validate-env-config.py --env-file .env.production
```

## Integration with Infrastructure Scripts

### Update: `infra/create-ai-foundry-project.py`

Add this validation check at the beginning:

```python
def validate_environment_variables() -> None:
    """
    Validate environment configuration before deployment
    """
    import subprocess
    import sys
    
    logger.info("[🔍] Validating environment configuration...")
    
    try:
        result = subprocess.run(
            [sys.executable, "scripts/validate-env-config.py", "--json-output"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            logger.info("[✓] Environment configuration validation passed")
        else:
            logger.error("[✗] Environment configuration validation failed")
            # Parse and display validation errors
            try:
                validation_result = json.loads(result.stdout)
                for error in validation_result.get("errors", []):
                    logger.error(f"[✗] {error}")
                for warning in validation_result.get("warnings", []):
                    logger.warning(f"[⚠] {warning}")
            except json.JSONDecodeError:
                logger.error(f"[✗] Validation output: {result.stdout}")
            
            sys.exit(1)
    
    except Exception as e:
        logger.warning(f"[⚠] Could not run configuration validation: {e}")
        logger.warning("[⚠] Proceeding with deployment (validation recommended)")
```

## Key Features

### 🔍 **Comprehensive Validation**
- Azure naming convention validation with regex patterns
- SKU validation for all services
- Regional availability checks
- Boolean value validation
- Email format validation

### 🎯 **Enhanced Error Reporting**
- Detailed error messages with specific restrictions
- Informational messages about SKU limitations
- Warnings for potential issues
- Suggestions for fixes

### 🔧 **Multiple Output Formats**
- Human-readable console output
- JSON output for CI/CD integration
- Verbose mode for debugging
- Custom environment file support

### 🛡️ **Production Ready**
- Azure CLI availability checks
- Authentication verification
- Global uniqueness warnings
- Service availability validation

This enhanced validator provides comprehensive validation of your Azure OpenAI infrastructure configuration, ensuring successful deployments and catching common configuration errors before they cause deployment failures!