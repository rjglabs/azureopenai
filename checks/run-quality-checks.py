#!/usr/bin/env python3
"""
Comprehensive quality checks for Azure OpenAI repository
"""

import subprocess
import sys
import json
from pathlib import Path
from typing import Dict, List, Tuple, Any
import click
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

console = Console()


class QualityChecker:
    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root
        self.results: Dict[str, Any] = {}

    def run_command(
        self, cmd: List[str], cwd: Path = None
    ) -> Tuple[int, str, str]:
        """Run a command and return exit code, stdout, stderr"""
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd or self.repo_root,
                capture_output=True,
                text=True,
                timeout=300,
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except Exception as e:
            return 1, "", str(e)

    def check_black_formatting(self) -> Dict[str, Any]:
        """Check code formatting with Black"""
        console.print("🎨 Checking code formatting with Black...")

        code, stdout, stderr = self.run_command(
            [
                "python",
                "-m",
                "black",
                "--check",
                "--diff",
                "infra/",
                "projects/",
                "scripts/python/",
            ]
        )

        return {
            "name": "Black Formatting",
            "passed": code == 0,
            "output": stdout + stderr,
            "suggestions": (
                "Run 'black infra/ projects/ scripts/python/' to fix "
                "formatting issues"
                if code != 0
                else None
            ),
        }

    def check_import_sorting(self) -> Dict[str, Any]:
        """Check import sorting with isort"""
        console.print("📦 Checking import sorting with isort...")

        code, stdout, stderr = self.run_command(
            [
                "python",
                "-m",
                "isort",
                "--check-only",
                "--diff",
                "infra/",
                "projects/",
                "scripts/python/",
            ]
        )

        return {
            "name": "Import Sorting",
            "passed": code == 0,
            "output": stdout + stderr,
            "suggestions": (
                "Run 'isort infra/ projects/ scripts/python/' to fix "
                "import order"
                if code != 0
                else None
            ),
        }

    def check_linting(self) -> Dict[str, Any]:
        """Check code quality with flake8"""
        console.print("🔍 Running flake8 linting...")

        code, stdout, stderr = self.run_command(
            [
                "python",
                "-m",
                "flake8",
                "infra/",
                "projects/",
                "scripts/python/",
            ]
        )

        return {
            "name": "Flake8 Linting",
            "passed": code == 0,
            "output": stdout + stderr,
            "suggestions": (
                "Fix the linting issues shown above" if code != 0 else None
            ),
        }

    def check_type_hints(self) -> Dict[str, Any]:
        """Check type hints with mypy"""
        console.print("🔬 Checking type hints with mypy...")

        code, stdout, stderr = self.run_command(
            ["python", "-m", "mypy", "infra/", "projects/", "scripts/python/"]
        )

        return {
            "name": "Type Checking (MyPy)",
            "passed": code == 0,
            "output": stdout + stderr,
            "suggestions": (
                "Add missing type hints or fix type errors"
                if code != 0
                else None
            ),
        }

    def check_security(self) -> Dict[str, Any]:
        """Security check with bandit"""
        console.print("🛡️ Running security scan with Bandit...")

        code, stdout, stderr = self.run_command(
            [
                "python",
                "-m",
                "bandit",
                "-r",
                "infra/",
                "projects/",
                "scripts/python/",
                "-f",
                "json",
            ]
        )

        if code == 0:
            findings = "No security issues found"
        else:
            try:
                bandit_output = json.loads(stdout)
                findings = (
                    f"Found {len(bandit_output.get('results', []))} "
                    f"security issues"
                )
            except json.JSONDecodeError:
                findings = stderr or stdout

        return {
            "name": "Security Scan (Bandit)",
            "passed": code == 0,
            "output": findings,
            "suggestions": (
                "Review security findings and fix high/medium severity issues"
                if code != 0
                else None
            ),
        }

    def run_all_checks(self) -> Dict[str, Any]:
        """Run all quality checks"""
        checks = [
            self.check_black_formatting(),
            self.check_import_sorting(),
            self.check_linting(),
            self.check_type_hints(),
            self.check_security(),
        ]

        self.results = {
            "timestamp": "2024-01-01T00:00:00Z",
            "checks": checks,
            "summary": {
                "total": len(checks),
                "passed": sum(1 for check in checks if check["passed"]),
                "failed": sum(1 for check in checks if not check["passed"]),
            },
        }

        return self.results

    def generate_report(self) -> None:
        """Generate a visual report"""
        console.print("\n")
        console.print(Panel.fit("🔍 Quality Check Results", style="bold blue"))

        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Check", style="dim", width=20)
        table.add_column("Status", justify="center", width=10)
        table.add_column("Details", width=50)

        for check in self.results["checks"]:
            status = "✅ PASS" if check["passed"] else "❌ FAIL"
            status_style = "green" if check["passed"] else "red"

            details = check["suggestions"] or "All good!"
            if len(details) > 47:
                details = details[:44] + "..."

            table.add_row(
                check["name"],
                f"[{status_style}]{status}[/{status_style}]",
                details,
            )

        console.print(table)

        # Summary
        summary = self.results["summary"]
        if summary["failed"] == 0:
            console.print(
                f"\n🎉 All {summary['total']} checks passed!",
                style="bold green",
            )
        else:
            console.print(
                f"\n⚠️ {summary['failed']} out of {summary['total']} "
                f"checks failed",
                style="bold red",
            )

        # Save detailed report
        report_path = Path("checks/reports/quality-report.json")
        report_path.parent.mkdir(exist_ok=True)

        with open(report_path, "w") as f:
            json.dump(self.results, f, indent=2)

        console.print(f"\n📊 Detailed report saved to: {report_path}")


@click.command()
@click.option("--repo-root", default=".", help="Repository root directory")
@click.option("--json-output", is_flag=True, help="Output results as JSON")
def main(repo_root: str, json_output: bool) -> None:
    """Run comprehensive quality checks on the Azure OpenAI repository"""

    repo_path = Path(repo_root).resolve()
    checker = QualityChecker(repo_path)

    console.print("🚀 Starting comprehensive quality checks...\n")

    results = checker.run_all_checks()

    if json_output:
        console.print(json.dumps(results, indent=2))
    else:
        checker.generate_report()

    # Exit with appropriate code
    sys.exit(0 if results["summary"]["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
