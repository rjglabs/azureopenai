#!/usr/bin/env python3
"""
Python Environment Verification Script

This script verifies the Python environment is properly configured.
"""

import subprocess
import sys


def main() -> None:
    """Main function to verify Python environment."""
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print(f"Python path: {sys.path[0]}")

    # Check if we're in a virtual environment
    if hasattr(sys, "real_prefix") or (
        hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix
    ):
        print("✅ Running in virtual environment")
        print(f"Virtual environment: {sys.prefix}")
    else:
        print("⚠️  Not running in virtual environment")

    # Check Poetry
    try:
        result = subprocess.run(
            ["poetry", "--version"], capture_output=True, text=True
        )
        if result.returncode == 0:
            print(f"✅ Poetry: {result.stdout.strip()}")
        else:
            print("❌ Poetry not found")
    except FileNotFoundError:
        print("❌ Poetry not found")

    print("✅ Python environment verification complete")


if __name__ == "__main__":
    main()
