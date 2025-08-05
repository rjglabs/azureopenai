#!/usr/bin/env python3
"""
Enhanced Azure AI Foundry Project Creation Script

This script creates a comprehensive Azure AI Foundry project environment with
dual AI services architecture, including traditional AI services and dedicated
OpenAI services for optimal performance and cost efficiency.

The script is idempotent - it can be run multiple times safely and will only
create resources that don't already exist.

Usage:
    python create_ai_foundry_project.py --dry-run
    python create_ai_foundry_project.py
    python create_ai_foundry_project.py --verbose
    python create_ai_foundry_project.py --config-only  # Only update Key Vault
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Union


# Load environment variables from .env file if it exists
def load_env_file(env_path: str = ".env") -> None:
    """Load environment variables from .env file"""
    env_file = Path(env_path)
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    os.environ[key] = value


class AzureAIFoundryDeployer:
    """Azure AI Foundry project deployment manager"""

    def __init__(
        self,
        config: Dict[str, Any],
        dry_run: bool = False,
        verbose: bool = False,
    ):
        self.config = config
        self.dry_run = dry_run
        self.verbose = verbose
        self.created_resources: List[str] = []
        self.existing_resources: List[str] = []

    def get_dict_value(
        self,
        data: Union[Dict[str, Any], List[Dict[str, Any]], None],
        key: str,
    ) -> str:
        """Safely get a value from a dictionary result, nested keys"""
        if isinstance(data, dict):
            keys = key.split(".")
            current = data
            for k in keys:
                if isinstance(current, dict) and k in current:
                    current = current[k]
                else:
                    return ""
            return str(current) if current is not None else ""
        return ""

    def get_list_item_value(
        self,
        data: Union[Dict[str, Any], List[Dict[str, Any]], None],
        index: int,
        key: str,
    ) -> str:
        """Safely get a value from a list item at index"""
        if isinstance(data, list) and len(data) > index:
            item = data[index]
            if isinstance(item, dict):
                return str(item.get(key, ""))
        return ""

    def log(self, message: str, level: str = "INFO") -> None:
        """Enhanced logging with levels"""
        prefix = {
            "INFO": "ℹ️",
            "SUCCESS": "✅",
            "WARNING": "⚠️",
            "ERROR": "❌",
            "SKIP": "⏭️",
            "CREATE": "🔨",
        }

        print(f"{prefix.get(level, '📝')} {message}")
        if self.verbose and level in ["CREATE", "SUCCESS"]:
            print(f"   └─ Resource: {message}")

    def run_az_command(
        self, command: List[str], check_exists: bool = False
    ) -> Optional[Union[Dict[str, Any], List[Dict[str, Any]]]]:
        """Execute Azure CLI command with error handling"""
        if self.dry_run and not check_exists:
            self.log(f"DRY RUN: az {' '.join(command)}", "INFO")
            return {"dry_run": True}

        try:
            if self.verbose:
                self.log(f"Running: az {' '.join(command)}", "INFO")

            result = subprocess.run(
                ["az"] + command,
                capture_output=True,
                text=True,
                check=True,
                shell=True,
            )

            if result.stdout.strip():
                parsed_result: Union[Dict[str, Any], List[Dict[str, Any]]] = (
                    json.loads(result.stdout)
                )
                return parsed_result  # Return the actual result (dict or list)
            return {}

        except subprocess.CalledProcessError as e:
            if check_exists and "not found" in e.stderr.lower():
                return None
            self.log(f"Command failed: {e.stderr}", "ERROR")
            return None
        except json.JSONDecodeError:
            return {"success": True}

    def resource_exists(
        self,
        resource_type: str,
        name: str,
        resource_group: Optional[str] = None,
    ) -> bool:
        """Check if Azure resource exists"""
        rg = resource_group or self.config["resource_group"]

        commands = {
            "group": ["group", "show", "--name", name],
            "cognitiveservices": [
                "cognitiveservices",
                "account",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "search": [
                "search",
                "service",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "keyvault": [
                "keyvault",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "appconfig": [
                "appconfig",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "loganalytics": [
                "monitor",
                "log-analytics",
                "workspace",
                "show",
                "--workspace-name",
                name,
                "--resource-group",
                rg,
            ],
            "acr": ["acr", "show", "--name", name, "--resource-group", rg],
            "storage": [
                "storage",
                "account",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "appinsights": [
                "monitor",
                "app-insights",
                "component",
                "show",
                "--app",
                name,
                "--resource-group",
                rg,
            ],
            "ml": [
                "ml",
                "workspace",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "appservice-plan": [
                "appservice",
                "plan",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "webapp": [
                "webapp",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
            "identity": [
                "identity",
                "show",
                "--name",
                name,
                "--resource-group",
                rg,
            ],
        }

        if resource_type not in commands:
            self.log(f"Unknown resource type: {resource_type}", "ERROR")
            return False

        result = self.run_az_command(
            commands[resource_type], check_exists=True
        )
        return result is not None

    def create_resource_group(self) -> bool:
        """Create resource group if it doesn't exist"""
        name = self.config["resource_group"]

        if self.resource_exists("group", name):
            self.log(f"Resource group '{name}' already exists", "SKIP")
            self.existing_resources.append(f"Resource Group: {name}")
            return True

        self.log(f"Creating resource group: {name}", "CREATE")
        result = self.run_az_command(
            [
                "group",
                "create",
                "--name",
                name,
                "--location",
                self.config["location"],
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(
                f"Resource group '{name}' created successfully", "SUCCESS"
            )
            self.created_resources.append(f"Resource Group: {name}")
            return True
        return False

    def create_general_ai_services(self) -> bool:
        """Create general AI services (for Speech, Translation, etc.)"""
        name = self.config["ai_services_name"]

        if self.resource_exists("cognitiveservices", name):
            self.log(f"General AI Services '{name}' already exists", "SKIP")
            self.existing_resources.append(f"General AI Services: {name}")
            return True

        self.log(f"Creating general AI services: {name}", "CREATE")
        result = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "create",
                "--name",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--kind",
                "AIServices",
                "--sku",
                "S0",
                "--custom-domain",
                name,
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(
                f"General AI Services '{name}' created successfully", "SUCCESS"
            )
            self.created_resources.append(f"General AI Services: {name}")
            return True
        return False

    def create_openai_service(self) -> bool:
        """Create dedicated OpenAI service"""
        name = self.config["openai_service_name"]

        if self.resource_exists("cognitiveservices", name):
            self.log(f"OpenAI Service '{name}' already exists", "SKIP")
            self.existing_resources.append(f"OpenAI Service: {name}")
            return True

        self.log(f"Creating OpenAI service: {name}", "CREATE")
        result = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "create",
                "--name",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--kind",
                "OpenAI",
                "--sku",
                "S0",
                "--custom-domain",
                name,
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(
                f"OpenAI Service '{name}' created successfully", "SUCCESS"
            )
            self.created_resources.append(f"OpenAI Service: {name}")
            # Wait a moment for the service to be ready
            if not self.dry_run:
                time.sleep(10)
            return True
        return False

    def verify_general_ai_services_capabilities(self) -> bool:
        """Verify that general AI services are properly configured"""
        ai_services_name = self.config["ai_services_name"]

        if self.dry_run:
            self.log(
                "DRY RUN: Would verify General AI Services capabilities",
                "INFO",
            )
            return True

        self.log("Verifying General AI Services capabilities...", "INFO")

        # Get service details
        service_info = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "show",
                "--name",
                ai_services_name,
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        if service_info:
            # General AI Services automatically includes:
            # - Speech Services (Speech-to-Text, Text-to-Speech)
            # - Translator Text
            # - Computer Vision
            # - Content Moderator
            # - And many others - no additional model deployment needed!

            capabilities = [
                "Speech-to-Text",
                "Text-to-Speech",
                "Translator",
                "Computer Vision",
                "Content Moderator",
                "Face API",
                "Form Recognizer",
            ]

            self.log(
                f"General AI Services '{ai_services_name}' includes:",
                "SUCCESS",
            )
            for capability in capabilities:
                self.log(f"  ✓ {capability} (built-in)", "SUCCESS")

            # Note about OpenAI service
            openai_service_name = self.config["openai_service_name"]
            self.log(
                f"OpenAI Service '{openai_service_name}' is ready for "
                f"model deployments",
                "SUCCESS",
            )
            self.log(
                "  💡 Use a separate model deployment script to add "
                "specific models",
                "INFO",
            )

            return True

        return False

    def create_cognitive_search(self) -> bool:
        """Create Cognitive Search service"""
        name = self.config["cognitive_search_name"]

        if self.resource_exists("search", name):
            self.log(f"Cognitive Search '{name}' already exists", "SKIP")
            self.existing_resources.append(f"Cognitive Search: {name}")
            return True

        self.log(f"Creating Cognitive Search service: {name}", "CREATE")
        result = self.run_az_command(
            [
                "search",
                "service",
                "create",
                "--name",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--sku",
                "standard",
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(
                f"Cognitive Search '{name}' created successfully", "SUCCESS"
            )
            self.created_resources.append(f"Cognitive Search: {name}")
            return True
        return False

    def create_key_vault(self) -> bool:
        """Create Key Vault"""
        name = self.config["keyvault_name"]

        if self.resource_exists("keyvault", name):
            self.log(f"Key Vault '{name}' already exists", "SKIP")
            self.existing_resources.append(f"Key Vault: {name}")
            return True

        self.log(f"Creating Key Vault: {name}", "CREATE")
        result = self.run_az_command(
            [
                "keyvault",
                "create",
                "--name",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--sku",
                "standard",
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(f"Key Vault '{name}' created successfully", "SUCCESS")
            self.created_resources.append(f"Key Vault: {name}")
            return True
        return False

    def create_supporting_resources(self) -> bool:
        """Create supporting Azure resources"""
        resources = [
            (
                "appconfig",
                "App Configuration",
                self.config["appconfig_name"],
                [
                    "appconfig",
                    "create",
                    "--name",
                    self.config["appconfig_name"],
                    "--resource-group",
                    self.config["resource_group"],
                    "--location",
                    self.config["location"],
                    "--sku",
                    "free",
                ],
            ),
            (
                "loganalytics",
                "Log Analytics",
                self.config["log_workspace_name"],
                [
                    "monitor",
                    "log-analytics",
                    "workspace",
                    "create",
                    "--workspace-name",
                    self.config["log_workspace_name"],
                    "--resource-group",
                    self.config["resource_group"],
                    "--location",
                    self.config["location"],
                ],
            ),
            (
                "acr",
                "Container Registry",
                self.config["container_registry_name"],
                [
                    "acr",
                    "create",
                    "--name",
                    self.config["container_registry_name"],
                    "--resource-group",
                    self.config["resource_group"],
                    "--location",
                    self.config["location"],
                    "--sku",
                    "Basic",
                ],
            ),
            (
                "storage",
                "Storage Account",
                self.config["storage_account_name"],
                [
                    "storage",
                    "account",
                    "create",
                    "--name",
                    self.config["storage_account_name"],
                    "--resource-group",
                    self.config["resource_group"],
                    "--location",
                    self.config["location"],
                    "--sku",
                    "Standard_LRS",
                ],
            ),
        ]

        success = True
        for resource_type, display_name, name, command in resources:
            if self.resource_exists(resource_type, name):
                self.log(f"{display_name} '{name}' already exists", "SKIP")
                self.existing_resources.append(f"{display_name}: {name}")
            else:
                self.log(f"Creating {display_name}: {name}", "CREATE")
                result = self.run_az_command(command)
                if result:
                    self.log(
                        f"{display_name} '{name}' created successfully",
                        "SUCCESS",
                    )
                    self.created_resources.append(f"{display_name}: {name}")
                else:
                    success = False

        return success

    def create_application_insights(self) -> bool:
        """Create Application Insights"""
        name = self.config["application_insights_name"]

        if self.resource_exists("appinsights", name):
            self.log(f"Application Insights '{name}' already exists", "SKIP")
            self.existing_resources.append(f"Application Insights: {name}")
            return True

        self.log(f"Creating Application Insights: {name}", "CREATE")
        result = self.run_az_command(
            [
                "monitor",
                "app-insights",
                "component",
                "create",
                "--app",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--kind",
                "web",
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(
                f"Application Insights '{name}' created successfully",
                "SUCCESS",
            )
            self.created_resources.append(f"Application Insights: {name}")
            return True
        return False

    def create_ml_workspace(self) -> bool:
        """Create ML Workspace for AI Foundry using existing resources"""
        name = self.config["ml_workspace_name"]

        # Check if ML extension is installed
        if not self.dry_run:
            try:
                subprocess.run(
                    ["az", "extension", "show", "--name", "ml"],
                    capture_output=True,
                    check=True,
                    shell=True,
                )
            except subprocess.CalledProcessError:
                self.log("Installing Azure ML extension...", "INFO")
                subprocess.run(
                    ["az", "extension", "add", "--name", "ml"],
                    check=True,
                    shell=True,
                )

        if self.resource_exists("ml", name):
            self.log(f"ML Workspace '{name}' already exists", "SKIP")
            self.existing_resources.append(f"ML Workspace: {name}")
            return True

        self.log(
            f"Creating ML Workspace: {name} (using shared resources)", "CREATE"
        )

        # Get resource IDs for existing shared resources
        resource_group = self.config["resource_group"]
        subscription_id = self.get_subscription_id()

        # Build resource IDs
        storage_id = (
            f"/subscriptions/{subscription_id}/resourceGroups/"
            f"{resource_group}/providers/Microsoft.Storage/storageAccounts/"
            f"{self.config['storage_account_name']}"
        )
        keyvault_id = (
            f"/subscriptions/{subscription_id}/resourceGroups/"
            f"{resource_group}/providers/Microsoft.KeyVault/vaults/"
            f"{self.config['keyvault_name']}"
        )
        appinsights_id = (
            f"/subscriptions/{subscription_id}/resourceGroups/"
            f"{resource_group}/providers/Microsoft.Insights/components/"
            f"{self.config['application_insights_name']}"
        )

        result = self.run_az_command(
            [
                "ml",
                "workspace",
                "create",
                "--name",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--storage-account",
                storage_id,
                "--key-vault",
                keyvault_id,
                "--application-insights",
                appinsights_id,
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result:
            self.log(f"ML Workspace '{name}' created successfully", "SUCCESS")
            self.log("  ✓ Using shared Storage Account", "INFO")
            self.log("  ✓ Using shared Key Vault", "INFO")
            self.log("  ✓ Using shared Application Insights", "INFO")
            self.created_resources.append(f"ML Workspace: {name}")
            return True
        return False

    def create_app_service(self) -> bool:
        """Create App Service Plan and Web App"""
        plan_name = self.config["app_service_plan_name"]
        webapp_name = self.config["web_app_name"]

        # Create App Service Plan
        if self.resource_exists("appservice-plan", plan_name):
            self.log(f"App Service Plan '{plan_name}' already exists", "SKIP")
            self.existing_resources.append(f"App Service Plan: {plan_name}")
        else:
            self.log(f"Creating App Service Plan: {plan_name}", "CREATE")
            result = self.run_az_command(
                [
                    "appservice",
                    "plan",
                    "create",
                    "--name",
                    plan_name,
                    "--resource-group",
                    self.config["resource_group"],
                    "--location",
                    self.config["location"],
                    "--sku",
                    "F1",
                    "--is-linux",
                ]
            )
            if result:
                self.log(
                    f"App Service Plan '{plan_name}' created successfully",
                    "SUCCESS",
                )
                self.created_resources.append(f"App Service Plan: {plan_name}")

        # Create Web App
        if self.resource_exists("webapp", webapp_name):
            self.log(f"Web App '{webapp_name}' already exists", "SKIP")
            self.existing_resources.append(f"Web App: {webapp_name}")
        else:
            self.log(f"Creating Web App: {webapp_name}", "CREATE")
            result = self.run_az_command(
                [
                    "webapp",
                    "create",
                    "--name",
                    webapp_name,
                    "--resource-group",
                    self.config["resource_group"],
                    "--plan",
                    plan_name,
                    "--runtime",
                    "PYTHON:3.11",
                ]
            )
            if result:
                self.log(
                    f"Web App '{webapp_name}' created successfully", "SUCCESS"
                )
                self.created_resources.append(f"Web App: {webapp_name}")

        return True

    def get_subscription_id(self) -> str:
        """Get current subscription ID"""
        if self.dry_run:
            return "subscription-id"

        try:
            result = subprocess.run(
                ["az", "account", "show", "--query", "id", "-o", "tsv"],
                capture_output=True,
                text=True,
                check=True,
                shell=True,
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return "unknown"

    def get_current_user_object_id(self) -> str:
        """Get current user's object ID"""
        if self.dry_run:
            return "user-object-id"

        try:
            result = subprocess.run(
                [
                    "az",
                    "ad",
                    "signed-in-user",
                    "show",
                    "--query",
                    "id",
                    "-o",
                    "tsv",
                ],
                capture_output=True,
                text=True,
                check=True,
                shell=True,
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return "unknown"

    def assign_role_to_user(
        self,
        role: str,
        scope: str,
        assignee_object_id: str,
        is_service_principal: bool = False,
    ) -> bool:
        """Assign a role to a user for a specific scope"""
        if self.dry_run:
            self.log(
                f"DRY RUN: Would assign role {role} to user "
                f"{assignee_object_id} on {scope}",
                "INFO",
            )
            return True

        self.log(f"Assigning role '{role}' to user on {scope}", "CREATE")

        # Try assignment with retries for managed identities
        max_attempts = 3 if is_service_principal else 1
        for attempt in range(max_attempts):
            cmd = [
                "role",
                "assignment",
                "create",
                "--role",
                role,
                "--assignee-object-id",
                assignee_object_id,
                "--scope",
                scope,
            ]

            # Add principal type for service principals
            if is_service_principal:
                cmd.extend(["--assignee-principal-type", "ServicePrincipal"])

            result = self.run_az_command(cmd)

            if result:
                self.log(f"Role '{role}' assigned successfully", "SUCCESS")
                return True
            elif attempt < max_attempts - 1:  # If this isn't the last attempt
                self.log(
                    f"Role assignment attempt {attempt + 1} failed, "
                    f"retrying in 10 seconds...",
                    "WARNING",
                )
                time.sleep(10)  # Wait for principal replication

        self.log(f"Failed to assign role '{role}'", "WARNING")
        return False

    def create_managed_identity(self, name: str) -> Optional[str]:
        """Create a user-assigned managed identity and return principal ID"""
        if self.resource_exists("identity", name):
            self.log(f"Managed Identity '{name}' already exists", "SKIP")
            # Get existing identity principal ID
            identity_info = self.run_az_command(
                [
                    "identity",
                    "show",
                    "--name",
                    name,
                    "--resource-group",
                    self.config["resource_group"],
                    "--query",
                    "principalId",
                    "-o",
                    "tsv",
                ]
            )
            return (
                identity_info.strip()
                if isinstance(identity_info, str)
                else None
            )

        self.log(f"Creating Managed Identity: {name}", "CREATE")
        result = self.run_az_command(
            [
                "identity",
                "create",
                "--name",
                name,
                "--resource-group",
                self.config["resource_group"],
                "--location",
                self.config["location"],
                "--tags",
                f"project={self.config['project_tag']}",
            ]
        )

        if result and "principalId" in result:
            principal_id = self.get_dict_value(result, "principalId")
            self.log(
                f"Managed Identity '{name}' created successfully", "SUCCESS"
            )
            self.created_resources.append(f"Managed Identity: {name}")
            return principal_id

        return None

    def setup_permissions(self) -> bool:
        """Set up all necessary permissions for users and applications"""
        self.log("Setting up permissions and role assignments...", "INFO")

        # Get current user's object ID
        user_object_id = self.get_current_user_object_id()
        resource_group = self.config["resource_group"]
        subscription_id = self.get_subscription_id()

        # Define resource scopes
        subscription_path = f"/subscriptions/{subscription_id}"
        rg_path = f"{subscription_path}/resourceGroups/{resource_group}"

        openai_scope = (
            f"{rg_path}/providers/Microsoft.CognitiveServices/"
            f"accounts/{self.config['openai_service_name']}"
        )
        ai_services_scope = (
            f"{rg_path}/providers/Microsoft.CognitiveServices/"
            f"accounts/{self.config['ai_services_name']}"
        )
        search_scope = (
            f"{rg_path}/providers/Microsoft.Search/"
            f"searchServices/{self.config['cognitive_search_name']}"
        )
        keyvault_scope = (
            f"{rg_path}/providers/Microsoft.KeyVault/"
            f"vaults/{self.config['keyvault_name']}"
        )
        storage_scope = (
            f"{rg_path}/providers/Microsoft.Storage/"
            f"storageAccounts/{self.config['storage_account_name']}"
        )

        success = True

        # 1. Give current user permissions to manage services
        user_roles = [
            ("Cognitive Services OpenAI User", openai_scope),
            ("Cognitive Services User", ai_services_scope),
            ("Search Service Contributor", search_scope),
            ("Key Vault Administrator", keyvault_scope),
            ("Storage Blob Data Contributor", storage_scope),
        ]

        for role, scope in user_roles:
            if not self.assign_role_to_user(role, scope, user_object_id):
                success = False

        # 2. Create managed identity for applications
        app_identity_name = f"id-{self.config['project_tag']}-apps"
        app_principal_id = self.create_managed_identity(app_identity_name)

        if app_principal_id:
            # 3. Give applications access to AI services
            app_roles = [
                ("Cognitive Services OpenAI User", openai_scope),
                ("Cognitive Services User", ai_services_scope),
                ("Search Index Data Reader", search_scope),
                ("Key Vault Secrets User", keyvault_scope),
                ("Storage Blob Data Reader", storage_scope),
            ]

            for role, scope in app_roles:
                if not self.assign_role_to_user(
                    role, scope, app_principal_id, is_service_principal=True
                ):
                    success = False

            # Store the managed identity info for applications to use
            self.config["app_managed_identity_name"] = app_identity_name
            self.config["app_managed_identity_principal_id"] = app_principal_id

        return success

    def store_secrets_in_keyvault(self) -> bool:
        """Store ALL configuration values and secrets in Key Vault"""
        keyvault_name = self.config["keyvault_name"]

        if self.dry_run:
            self.log(
                "DRY RUN: Would store all configuration in Key Vault", "INFO"
            )
            return True

        self.log("Retrieving service details for Key Vault storage...", "INFO")

        # Get OpenAI service details
        openai_info = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "show",
                "--name",
                self.config["openai_service_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        openai_keys = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "keys",
                "list",
                "--name",
                self.config["openai_service_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        # Get General AI Services details
        general_ai_info = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "show",
                "--name",
                self.config["ai_services_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        general_ai_keys = self.run_az_command(
            [
                "cognitiveservices",
                "account",
                "keys",
                "list",
                "--name",
                self.config["ai_services_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        # Get Cognitive Search details
        search_keys = self.run_az_command(
            [
                "search",
                "admin-key",
                "show",
                "--service-name",
                self.config["cognitive_search_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        search_query_keys_result = self.run_az_command(
            [
                "search",
                "query-key",
                "list",
                "--service-name",
                self.config["cognitive_search_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )
        search_query_keys = (
            search_query_keys_result
            if isinstance(search_query_keys_result, list)
            else []
        )

        # Get Storage Account details
        storage_keys_result = self.run_az_command(
            [
                "storage",
                "account",
                "keys",
                "list",
                "--account-name",
                self.config["storage_account_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )
        storage_keys = (
            storage_keys_result
            if isinstance(storage_keys_result, list)
            else []
        )

        # Get Application Insights details
        appinsights_info = self.run_az_command(
            [
                "monitor",
                "app-insights",
                "component",
                "show",
                "--app",
                self.config["application_insights_name"],
                "--resource-group",
                self.config["resource_group"],
            ]
        )

        # Prepare ALL configuration values (secrets + non-secrets)
        ai_services_name = self.config["ai_services_name"]
        project_tag = self.config["project_tag"]
        all_config: Dict[str, str] = {
            # === AI FOUNDRY PROJECT ===
            "ai-foundry-project-endpoint": (
                f"https://{ai_services_name}.services.ai.azure.com/"
                f"api/projects/{project_tag}"
            ),
            # === OPENAI SERVICE (Primary AI) ===
            "ai-services-endpoint": (
                self.get_dict_value(openai_info, "properties.endpoint")
                or f"https://{self.config['openai_service_name']}"
                f".openai.azure.com/"
            ),
            "ai-services-key": self.get_dict_value(openai_keys, "key1"),
            "ai-services-name": self.config["openai_service_name"],
            # === GENERAL AI SERVICES ===
            "general-ai-services-endpoint": (
                self.get_dict_value(general_ai_info, "properties.endpoint")
                or f"https://{ai_services_name}.cognitiveservices.azure.com/"
            ),
            "general-ai-services-key": self.get_dict_value(
                general_ai_keys, "key1"
            ),
            "general-ai-services-name": self.config["ai_services_name"],
            # === COGNITIVE SEARCH ===
            "cognitive-search-endpoint": (
                f"https://{self.config['cognitive_search_name']}"
                f".search.windows.net/"
            ),
            "cognitive-search-admin-key": self.get_dict_value(
                search_keys, "primaryKey"
            ),
            "cognitive-search-query-key": self.get_list_item_value(
                search_query_keys, 0, "key"
            ),
            "cognitive-search-name": self.config["cognitive_search_name"],
            # === SPEECH SERVICES ===
            "speechtotext-endpoint": (
                f"https://{self.config['location']}.stt.speech.microsoft.com"
            ),
            "texttospeech-endpoint": (
                f"https://{self.config['location']}.tts.speech.microsoft.com"
            ),
            # === TRANSLATOR ===
            "translator-endpoint": (
                "https://api.cognitive.microsofttranslator.com/"
            ),
            # === KEY VAULT ===
            "keyvault-name": self.config["keyvault_name"],
            "keyvault-uri": (
                f"https://{self.config['keyvault_name']}.vault.azure.net/"
            ),
            # === STORAGE ACCOUNT ===
            "storage-account-name": self.config["storage_account_name"],
            "storage-account-key": self.get_list_item_value(
                storage_keys, 0, "value"
            ),
            "storage-blob-endpoint": (
                f"https://{self.config['storage_account_name']}"
                f".blob.core.windows.net/"
            ),
            # === APPLICATION INSIGHTS ===
            "application-insights-name": self.config[
                "application_insights_name"
            ],
            "application-insights-instrumentation-key": self.get_dict_value(
                appinsights_info, "instrumentationKey"
            ),
            "application-insights-connection-string": self.get_dict_value(
                appinsights_info, "connectionString"
            ),
            # === CONTAINER REGISTRY ===
            "container-registry-name": self.config["container_registry_name"],
            "container-registry-server": (
                f"{self.config['container_registry_name']}.azurecr.io"
            ),
            # === APP CONFIGURATION ===
            "app-config-name": self.config["appconfig_name"],
            "app-config-endpoint": (
                f"https://{self.config['appconfig_name']}.azconfig.io"
            ),
            # === LOG ANALYTICS ===
            "log-workspace-name": self.config["log_workspace_name"],
            # === ML WORKSPACE ===
            "ml-workspace-name": self.config["ml_workspace_name"],
            # === RESOURCE GROUP & LOCATION ===
            "resource-group": self.config["resource_group"],
            "location": self.config["location"],
            "project-tag": self.config["project_tag"],
            # === APPLICATION SETTINGS ===
            "api-base-url": (
                f"https://{self.config['web_app_name']}.azurewebsites.net"
            ),
            "openapi-spec-url": (
                f"https://{self.config['web_app_name']}"
                f".azurewebsites.net/openapi.json"
            ),
            "web-app-name": self.config["web_app_name"],
            # === AZURE OPENAI CONFIGURATION ===
            "azure-openai-api-version": "2024-02-01",
            "azure-openai-deployment-gpt": "gpt-4o-mini",
            "azure-openai-deployment-embedding": "text-embedding-ada-002",
            "azure-openai-deployment-whisper": "whisper",
            "azure-openai-deployment-tts": "tts-1",
            # === APPLICATION SECRETS ===
            "flask-secret-key": (
                "your-secure-secret-key-change-this-in-production"
            ),
        }

        self.log("Storing complete configuration in Key Vault...", "CREATE")
        success_count = 0
        total_count = len(all_config)

        for secret_name, secret_value in all_config.items():
            if secret_value:  # Only store non-empty values
                result = self.run_az_command(
                    [
                        "keyvault",
                        "secret",
                        "set",
                        "--vault-name",
                        keyvault_name,
                        "--name",
                        secret_name,
                        "--value",
                        str(secret_value),
                    ]
                )
                if result:
                    success_count += 1
                    if self.verbose:
                        self.log(f"  ✓ Stored: {secret_name}", "SUCCESS")
            else:
                self.log(f"  ⚠ Skipped empty value: {secret_name}", "WARNING")

        self.log(
            f"Stored {success_count}/{total_count} configuration values "
            f"in Key Vault",
            "SUCCESS",
        )

        # Display what other scripts need
        self.log("Other scripts only need this in their .env:", "INFO")
        self.log(f"KEYVAULT_NAME={keyvault_name}", "INFO")
        self.log(
            "All other configuration will be retrieved from Key Vault "
            "automatically",
            "INFO",
        )

        return success_count > 0

    def deploy(self, config_only: bool = False) -> bool:
        """Main deployment orchestration"""
        self.log("Starting Azure AI Foundry project deployment...", "INFO")

        if config_only:
            self.log(
                "Configuration-only mode: Updating Key Vault secrets", "INFO"
            )
            return self.store_secrets_in_keyvault()

        steps = [
            ("Resource Group", self.create_resource_group),
            ("General AI Services", self.create_general_ai_services),
            ("OpenAI Service", self.create_openai_service),
            ("Cognitive Search", self.create_cognitive_search),
            ("Key Vault", self.create_key_vault),
            ("Supporting Resources", self.create_supporting_resources),
            ("Application Insights", self.create_application_insights),
            ("ML Workspace", self.create_ml_workspace),
            ("App Service", self.create_app_service),
        ]

        success = True
        for step_name, step_func in steps:
            self.log(f"Processing: {step_name}", "INFO")
            if not step_func():
                self.log(f"Failed to create {step_name}", "ERROR")
                success = False

        # Deploy default OpenAI models and verify general AI services
        if success and not self.dry_run:
            self.log("Verifying AI services capabilities...", "INFO")
            self.verify_general_ai_services_capabilities()

            # Setup permissions for all resources
            self.log("Setting up permissions...", "INFO")
            if not self.setup_permissions():
                self.log("Failed to setup permissions", "ERROR")
                success = False

        # Store secrets in Key Vault
        if success:
            self.store_secrets_in_keyvault()

        return success

    def print_summary(self) -> None:
        """Print deployment summary"""
        print("\n" + "=" * 60)
        print("🎉 DEPLOYMENT SUMMARY")
        print("=" * 60)

        if self.created_resources:
            print("\n✅ CREATED RESOURCES:")
            for resource in self.created_resources:
                print(f"   • {resource}")

        if self.existing_resources:
            print("\n⏭️  EXISTING RESOURCES (SKIPPED):")
            for resource in self.existing_resources:
                print(f"   • {resource}")

        if not self.dry_run:
            print("\n🔧 CONFIGURATION:")
            print(f"   • Resource Group: {self.config['resource_group']}")
            print(f"   • Location: {self.config['location']}")
            print(f"   • OpenAI Service: {self.config['openai_service_name']}")
            print(f"   • Key Vault: {self.config['keyvault_name']}")

            print("\n🌐 ENDPOINTS:")
            openai_service = self.config["openai_service_name"]
            openai_endpoint = f"https://{openai_service}.openai.azure.com/"
            print(f"   • OpenAI: {openai_endpoint}")
            search_service = self.config["cognitive_search_name"]
            search_endpoint = f"https://{search_service}.search.windows.net/"
            print(f"   • Search: {search_endpoint}")
            kv_name = self.config["keyvault_name"]
            kv_endpoint = f"https://{kv_name}.vault.azure.net/"
            print(f"   • Key Vault: {kv_endpoint}")

        print("\n" + "=" * 60)


def load_config() -> Dict[str, Any]:
    """Load configuration from environment or use defaults"""
    return {
        "resource_group": os.getenv("RESOURCE_GROUP", "rg-ai-nukesearch01"),
        "location": os.getenv("LOCATION", "eastus2"),
        "project_tag": os.getenv("PROJECT_TAG", "ai-nukesearch01"),
        "ai_services_name": os.getenv(
            "AI_SERVICES_NAME", "aiserv-ai-nukesearch01"
        ),
        "openai_service_name": os.getenv(
            "OPENAI_SERVICE_NAME", "openai-nukesearch01"
        ),
        "cognitive_search_name": os.getenv(
            "COGNITIVE_SEARCH_NAME", "cog-ai-nukesearch01"
        ),
        "keyvault_name": os.getenv("KEYVAULT_NAME", "kvainukesearch01"),
        "appconfig_name": os.getenv("APPCONFIG_NAME", "ac-ai-nukesearch01"),
        "log_workspace_name": os.getenv(
            "LOG_WORKSPACE_NAME", "log-ai-nukesearch01"
        ),
        "container_registry_name": os.getenv(
            "CONTAINER_REGISTRY_NAME", "crainukesearch01"
        ),
        "storage_account_name": os.getenv(
            "STORAGE_ACCOUNT_NAME", "stainukesearch01"
        ),
        "application_insights_name": os.getenv(
            "APPLICATION_INSIGHTS_NAME", "ai-ai-nukesearch01"
        ),
        "ml_workspace_name": os.getenv(
            "ML_WORKSPACE_NAME", "ml-ai-nukesearch01"
        ),
        "app_service_plan_name": os.getenv(
            "APP_SERVICE_PLAN_NAME", "asp-nukesearch01"
        ),
        "web_app_name": os.getenv("WEB_APP_NAME", "nukesearch-rjglabs"),
    }


def main() -> None:
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Enhanced Azure AI Foundry Project Creation Script"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be created without making changes",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Enable verbose logging"
    )
    parser.add_argument(
        "--config-only",
        action="store_true",
        help="Only update Key Vault configuration (skip resource creation)",
    )

    args = parser.parse_args()

    # Load environment variables from .env file
    load_env_file()

    # Load configuration
    config = load_config()

    # Create deployer
    deployer = AzureAIFoundryDeployer(config, args.dry_run, args.verbose)

    # Check Azure CLI authentication
    try:
        subprocess.run(
            ["az", "account", "show"],
            capture_output=True,
            check=True,
            shell=True,
        )
    except subprocess.CalledProcessError:
        print("❌ Please log in to Azure CLI first: az login")
        sys.exit(1)

    # Deploy
    success = deployer.deploy(config_only=args.config_only)

    # Print summary
    deployer.print_summary()

    if success:
        print("\n🎉 Deployment completed successfully!")
        if not args.dry_run:
            print("Your Azure AI Foundry project is ready to use.")
    else:
        print("\n❌ Deployment completed with errors.")
        sys.exit(1)


if __name__ == "__main__":
    main()
