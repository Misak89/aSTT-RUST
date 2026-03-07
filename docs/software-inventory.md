Document Name: Software Inventory
Version: 0.3
Timestamp: 2026-02-19 Thu 08:57

# Software Inventory

## Runtime
- powershell: 7.5.4
- python_venv: Python 3.11.9
- node: v24.3.0
- npm: 11.4.2
- cargo: cargo 1.93.1 (083ac5135 2025-12-15)
- rustc: rustc 1.93.1 (01f6ddf75 2026-02-11)
- mkdocs_cli: C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\.venv\Scripts\python.exe: No module named mkdocs

## Python Packages
- mkdocs: not installed
- mkdocs_material: not installed
- mkdocs_awesome_pages_plugin: not installed
- pystray: not installed
- pillow: not installed

## Run on Save
- configured: True
- command_count: 1
- valid_command: True
- command: pwsh -NoProfile -ExecutionPolicy Bypass -File "${workspaceFolder}\scripts\run_on_save.ps1" -FilePath "${file}"

## Critical Checks
- [OK] Root path exists - C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST
- [OK] run_on_save.ps1 exists - scripts/run_on_save.ps1
- [OK] run_on_save_guard.ps1 exists - scripts/run_on_save_guard.ps1
- [OK] start_doc_automation.ps1 exists - scripts/start_doc_automation.ps1
- [OK] RunOnSave configured - .vscode/settings.json
- [OK] RunOnSave command valid - must include run_on_save.ps1 + ${file}
- [OK] run_on_save_health_check - exit code 0 required
- failed_checks: 0

## Health Check Output
- skipped

## Outputs
- JSON: logs/software-inventory.json
- Text summary: logs/software-audit-last.txt
- This report: docs/software-inventory.md

Previous Versions:
- 0.2 - critical checks added
