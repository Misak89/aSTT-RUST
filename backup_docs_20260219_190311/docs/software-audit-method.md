Document Name: Software Audit Method
Version: 0.3
Timestamp: 2026-02-19 Thu 08:57

# Software Audit Method

## What the audit does
- Reads runtime versions (PowerShell, Python, Node, npm, cargo, rustc, mkdocs).
- Reads Python package versions from .venv.
- Reads dependencies from package.json and src-tauri/Cargo.toml.
- Verifies Run on Save config in .vscode/settings.json.
- Runs run_on_save_health_check.ps1 as critical validation.
- Stores outputs to docs/software-inventory.md and logs/software-inventory.json.

## Daily automation
- Register scheduled task with scripts/register_daily_audit_task.ps1.
- Task writes latest summary to logs/software-audit-last.txt.

## Run manually
- pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/inventory_project_sw.ps1
- CI mode: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/inventory_project_sw.ps1 -SkipRunOnSaveHealthCheck

Previous Versions:
- 0.2 - added critical checks
