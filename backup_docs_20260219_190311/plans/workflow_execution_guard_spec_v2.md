# Implementacni specifikace: Workflow Execution Guard v2

**Cesta:** plans\workflow_execution_guard_spec_v2.md
**Verze:** 1.0
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-02-15 19:28 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
## Kombinovany pristup: Husky + pre-commit + Danger.js

---

## 1. Architektura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW EXECUTION GUARD v2                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  LOKALNE U VYVOJARE                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                 │   │
│  │   git commit ──▶ Husky ──▶ pre-commit ──▶ WORKFLOW GUARD       │   │
│  │                              │                                  │   │
│  │                              ▼                                  │   │
│  │                    ┌─────────────────┐                         │   │
│  │                    │  Kontrola:      │                         │   │
│  │                    │  - Dokumentace  │                         │   │
│  │                    │  - Workflow     │                         │   │
│  │                    │  - Schema       │                         │   │
│  │                    │  - Povinne kroky│                         │   │
│  │                    └─────────────────┘                         │   │
│  │                              │                                  │   │
│  │                    ┌─────────▼─────────┐                       │   │
│  │                    │ PASS? │ FAIL?     │                       │   │
│  │                    │   │       │       │                       │   │
│  │                    │   ▼       ▼       │                       │   │
│  │                    │ commit  zrusit    │                       │   │
│  │                    └───────────────────┘                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  V CI/CD (GitHub Actions)                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                 │   │
│  │   PR created ──▶ Danger.js ──▶ WORKFLOW GUARD                  │   │
│  │                         │                                       │   │
│  │                         ▼                                       │   │
│  │                 ┌─────────────────┐                            │   │
│  │                 │  Kontrola:      │                            │   │
│  │                 │  - Vsechny      │                            │   │
│  │                 │    lokalni +    │                            │   │
│  │                 │  - PR specifick │                            │   │
│  │                 └─────────────────┘                            │   │
│  │                         │                                       │   │
│  │                 ┌───────▼───────┐                              │   │
│  │                 │ PASS? │ FAIL? │                              │   │
│  │                 │   │       │   │                              │   │
│  │                 │   ▼       ▼   │                              │   │
│  │                 │ merge  block  │                              │   │
│  │                 └───────────────┘                              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Soubory k vytvoreni

| # | Soubor | Popis | Vrstva |
|---|--------|-------|--------|
| 1 | `.pre-commit-config.yaml` | Konfigurace pre-commit hooku | Lokalni |
| 2 | `scripts/workflow_guard.py` | Hlavni kontrolni skript | Sdilena |
| 3 | `config/workflow-steps.json` | Definice povinnych kroku | Konfigurace |
| 4 | `config/workflow-schema.json` | JSON Schema validace | Konfigurace |
| 5 | `.github/workflows/workflow-guard.yml` | CI/CD workflow | CI/CD |
| 6 | `Dangerfile.js` (uprava) | Rozsireni o workflow kontroly | CI/CD |

---

## 3. Detailni specifikace souboru

### 3.1 `.pre-commit-config.yaml`

```yaml
# Pre-commit configuration for Workflow Execution Guard
# Install: pip install pre-commit && pre-commit install

repos:
  # Workflow Guard - hlavni kontrola
  - repo: local
    hooks:
      - id: workflow-guard
        name: Workflow Execution Guard
        entry: python scripts/workflow_guard.py
        language: system
        stages: [commit]
        pass_filenames: false
        always_run: true
        verbose: true
        
      - id: workflow-guard-push
        name: Workflow Execution Guard (pre-push)
        entry: python scripts/workflow_guard.py --trigger pre-push
        language: system
        stages: [push]
        pass_filenames: false
        always_run: true
        verbose: true

  # Standardni kontroly
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-json
      - id: check-yaml
      - id: check-merge-conflict
      - id: end-of-file-fixer
      - id: trailing-whitespace

  # JSON Schema validace
  - repo: https://github.com/python-jsonschema/check-jsonschema
    rev: 0.27.0
    hooks:
      - id: check-jsonschema
        name: Validate workflow-steps.json
        files: config/workflow-steps.json
        args: ["--schemafile", "config/workflow-schema.json"]
```

### 3.2 `scripts/workflow_guard.py`

```python
#!/usr/bin/env python3
"""
Workflow Execution Guard - Hlavni kontrolni skript

Funkce:
- Kontrola povinnych kroku pred commit/push
- Validace dokumentace
- Kontrola dodrzeni workflow
- Logovani vysledku

Pouziti:
    python scripts/workflow_guard.py [--trigger {commit|push|ci}]
"""

import json
import subprocess
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional
import argparse

# Konstanty
CONFIG_DIR = Path("config")
WORKFLOW_STEPS_FILE = CONFIG_DIR / "workflow-steps.json"
WORKFLOW_SCHEMA_FILE = CONFIG_DIR / "workflow-schema.json"
LOG_FILE = Path("logs/workflow-guard.log")

class WorkflowGuard:
    def __init__(self, trigger: str = "commit"):
        self.trigger = trigger
        self.results = []
        self.passed = 0
        self.failed = 0
        self.errors = 0
        
    def log(self, message: str, level: str = "INFO"):
        timestamp = datetime.now().isoformat()
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        
        # Zapis do log souboru
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
    
    def load_config(self) -> dict:
        try:
            with open(WORKFLOW_STEPS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            self.log(f"Config file not found: {WORKFLOW_STEPS_FILE}", "ERROR")
            return {}
    
    def check_documentation(self) -> bool:
        """Kontrola aktualizace dokumentace"""
        self.log("Checking documentation...")
        
        # Ziskej zmenene soubory
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            capture_output=True, text=True
        )
        changed_files = result.stdout.strip().split("\n")
        
        has_code_changes = any(f.startswith("src-") for f in changed_files)
        has_doc_changes = any(f.endswith(".md") for f in changed_files)
        
        if has_code_changes and not has_doc_changes:
            self.log("FAIL: Code changes without documentation update", "ERROR")
            return False
        
        self.log("PASS: Documentation check")
        return True
    
    def check_workflow_steps(self) -> bool:
        """Kontrola povinnych kroku"""
        self.log("Checking workflow steps...")
        
        config = self.load_config()
        if not config:
            return False
        
        steps = config.get("steps", [])
        trigger_steps = [s for s in steps if s.get("trigger") == self.trigger]
        
        all_passed = True
        for step in trigger_steps:
            step_name = step.get("name", "Unknown")
            step_command = step.get("command", "")
            required = step.get("required", True)
            
            self.log(f"Executing step: {step_name}")
            
            if step_command:
                result = subprocess.run(
                    step_command,
                    shell=True,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode == 0:
                    self.log(f"PASS: {step_name}")
                    self.passed += 1
                else:
                    if required:
                        self.log(f"FAIL: {step_name} - {result.stderr}", "ERROR")
                        self.failed += 1
                        all_passed = False
                    else:
                        self.log(f"WARN: {step_name} (optional) - {result.stderr}", "WARN")
                        self.passed += 1
            else:
                self.log(f"SKIP: {step_name} (no command)", "WARN")
        
        return all_passed
    
    def run(self) -> bool:
        """Spusti vsechny kontroly"""
        self.log(f"=== WORKFLOW GUARD STARTED (trigger: {self.trigger}) ===")
        
        # Kontrola dokumentace
        doc_result = self.check_documentation()
        self.results.append(("documentation", doc_result))
        
        # Kontrola workflow kroku
        workflow_result = self.check_workflow_steps()
        self.results.append(("workflow_steps", workflow_result))
        
        # Vypis souhrn
        self.log("=== WORKFLOW GUARD SUMMARY ===")
        self.log(f"Passed: {self.passed}")
        self.log(f"Failed: {self.failed}")
        self.log(f"Errors: {self.errors}")
        
        all_passed = all(r[1] for r in self.results)
        
        if all_passed:
            self.log("=== WORKFLOW GUARD PASSED ===")
            return True
        else:
            self.log("=== WORKFLOW GUARD FAILED ===", "ERROR")
            return False

def main():
    parser = argparse.ArgumentParser(description="Workflow Execution Guard")
    parser.add_argument(
        "--trigger",
        choices=["commit", "push", "ci"],
        default="commit",
        help="Trigger type"
    )
    args = parser.parse_args()
    
    guard = WorkflowGuard(trigger=args.trigger)
    success = guard.run()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
```

### 3.3 `config/workflow-steps.json`

```json
{
  "$schema": "./workflow-schema.json",
  "version": "1.0.0",
  "description": "Povinne kroky workflow pro aSTT-RUST projekt",
  
  "steps": [
    {
      "id": "check-duplicates",
      "name": "Kontrola duplicit",
      "description": "Kontrola duplicitnich souboru pred commitem",
      "trigger": "commit",
      "command": "powershell -ExecutionPolicy Bypass -File scripts/check_duplicates.ps1",
      "required": true,
      "timeout": 60
    },
    {
      "id": "update-docs",
      "name": "Aktualizace dokumentace",
      "description": "Automaticka aktualizace dokumentace",
      "trigger": "commit",
      "command": "powershell -ExecutionPolicy Bypass -File scripts/update_docs.ps1",
      "required": false,
      "timeout": 120
    },
    {
      "id": "validate-timestamps",
      "name": "Validace timestampu",
      "description": "Kontrola timestampu v dokumentaci",
      "trigger": "push",
      "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_timestamps.ps1",
      "required": true,
      "timeout": 30
    },
    {
      "id": "schema-validation",
      "name": "JSON Schema validace",
      "description": "Validace vsech JSON souboru proti schematu",
      "trigger": "push",
      "command": "python -m jsonschema --instance config/workflow-steps.json config/workflow-schema.json",
      "required": true,
      "timeout": 30
    }
  ],
  
  "documentation_rules": {
    "require_doc_update_on_code_change": true,
    "code_patterns": ["src-", "src/"],
    "doc_patterns": [".md", "docs/"],
    "exceptions": ["CHANGE_LOG.md", "QA_REPORT.md"]
  },
  
  "enforcement": {
    "block_commit_on_failure": true,
    "block_push_on_failure": true,
    "allow_skip_with_flag": false
  }
}
```

### 3.4 `config/workflow-schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "workflow-schema.json",
  "title": "Workflow Steps Configuration",
  "description": "JSON Schema for workflow-steps.json",
  
  "type": "object",
  "required": ["version", "steps"],
  
  "properties": {
    "$schema": {
      "type": "string",
      "format": "uri"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "description": {
      "type": "string",
      "maxLength": 500
    },
    "steps": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "name", "trigger"],
        "properties": {
          "id": {
            "type": "string",
            "pattern": "^[a-z0-9-]+$"
          },
          "name": {
            "type": "string",
            "minLength": 1,
            "maxLength": 100
          },
          "description": {
            "type": "string",
            "maxLength": 500
          },
          "trigger": {
            "type": "string",
            "enum": ["commit", "push", "ci"]
          },
          "command": {
            "type": "string"
          },
          "required": {
            "type": "boolean",
            "default": true
          },
          "timeout": {
            "type": "integer",
            "minimum": 1,
            "maximum": 600
          }
        }
      }
    },
    "documentation_rules": {
      "type": "object",
      "properties": {
        "require_doc_update_on_code_change": {
          "type": "boolean"
        },
        "code_patterns": {
          "type": "array",
          "items": {"type": "string"}
        },
        "doc_patterns": {
          "type": "array",
          "items": {"type": "string"}
        },
        "exceptions": {
          "type": "array",
          "items": {"type": "string"}
        }
      }
    },
    "enforcement": {
      "type": "object",
      "properties": {
        "block_commit_on_failure": {
          "type": "boolean"
        },
        "block_push_on_failure": {
          "type": "boolean"
        },
        "allow_skip_with_flag": {
          "type": "boolean"
        }
      }
    }
  }
}
```

### 3.5 `.github/workflows/workflow-guard.yml`

```yaml
name: Workflow Execution Guard

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  workflow-guard:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: |
          pip install jsonschema
          pip install pre-commit
          
      - name: Run Workflow Guard
        run: |
          python scripts/workflow_guard.py --trigger ci
          
      - name: Run pre-commit
        run: |
          pre-commit run --all-files
          
      - name: Upload logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: workflow-guard-logs
          path: logs/
```

### 3.6 `Dangerfile.js` (uprava)

```javascript
// Dangerfile.js - Rozsireno o Workflow Execution Guard

const { danger, warn, fail, message } = require("danger")

// Puvodni kontroly
const hasCodeChanges = danger.git.modified_files.some(
  (file) => file.startsWith("src-") || file.startsWith("src/")
)
const hasDocChanges = danger.git.modified_files.some(
  (file) => file.endsWith(".md")
)

// 1. Kontrola dokumentace
if (hasCodeChanges && !hasDocChanges) {
  warn(
    "Zmenil jsi kod, ale neaktualizoval jsi dokumentaci. " +
    "Zva pridani nebo aktualizaci .md souboru."
  )
}

// 2. Velke PR
const bigPRThreshold = 500
if (danger.github.pr.additions + danger.github.pr.deletions > bigPRThreshold) {
  warn(
    `Velke PR: ${danger.github.pr.additions} additions, ${danger.github.pr.deletions} deletions. ` +
    "Zva rozdeleni na mensi PR."
  )
}

// 3. TODO detekce
danger.git.modified_files.forEach((file) => {
  if (file.endsWith(".js") || file.endsWith(".ts") || file.endsWith(".py")) {
    danger.git.diffForFile(file).then((diff) => {
      if (diff && diff.added && diff.added.includes("TODO")) {
        warn(`Nove TODO v ${file}`)
      }
    })
  }
})

// NOVE: Workflow Execution Guard kontroly

// 4. Kontrola workflow-steps.json
const fs = require("fs")
const path = require("path")

const workflowStepsPath = path.join(process.cwd(), "config", "workflow-steps.json")
const workflowSchemaPath = path.join(process.cwd(), "config", "workflow-schema.json")

if (fs.existsSync(workflowStepsPath)) {
  try {
    const workflowSteps = JSON.parse(fs.readFileSync(workflowStepsPath, "utf8"))
    
    // Validace verze
    if (!workflowSteps.version) {
      fail("workflow-steps.json musi mit definovanou verzi")
    }
    
    // Validace kroku
    if (!workflowSteps.steps || workflowSteps.steps.length === 0) {
      fail("workflow-steps.json musi mit alespon jeden krok")
    }
    
    // Kontrola povinnych poli
    workflowSteps.steps.forEach((step, index) => {
      if (!step.id) {
        fail(`Krok ${index} nema definovane id`)
      }
      if (!step.name) {
        fail(`Krok ${index} nema definovane name`)
      }
      if (!step.trigger) {
        fail(`Krok ${index} nema definovane trigger`)
      }
    })
    
    message(`Workflow Guard: Nalezeno ${workflowSteps.steps.length} kroku`)
  } catch (e) {
    fail(`Chyba pri nacitani workflow-steps.json: ${e.message}`)
  }
} else {
  warn("workflow-steps.json nenalezen - Workflow Guard nebude aktivni")
}

// 5. Kontrola zmen v config/
const configChanges = danger.git.modified_files.filter(
  (file) => file.startsWith("config/")
)
if (configChanges.length > 0) {
  message(`Zmeny v config/: ${configChanges.join(", ")}`)
}
```

---

## 4. Implementacni poradi

1. **Faze 1: Zaklad**
   - Vytvorit `config/` adresar
   - Vytvorit `config/workflow-schema.json`
   - Vytvorit `config/workflow-steps.json`

2. **Faze 2: Skript**
   - Vytvorit `scripts/workflow_guard.py`
   - Otestovat lokalne

3. **Faze 3: pre-commit**
   - Vytvorit `.pre-commit-config.yaml`
   - Nainstalovat pre-commit
   - Otestovat s `pre-commit run --all-files`

4. **Faze 4: CI/CD**
   - Vytvorit `.github/workflows/workflow-guard.yml`
   - Upravit `Dangerfile.js`
   - Otestovat s PR

5. **Faze 5: Integrace s Husky**
   - Upravit `.husky/pre-commit`
   - Upravit `.husky/pre-push`

---

## 5. Verifikacni kriteria

| Kriterium | Test | Ocekavany vysledek |
|-----------|------|-------------------|
| Lokalni kontrola | `git commit` | Workflow Guard se spusti |
| Blokovani commitu | Zmena kodu bez doc | Commit zrusen |
| Validace schema | Spusteni s neplatnym JSON | Chyba validace |
| CI/CD integrace | Vytvoreni PR | Danger.js kontrola |
| Logovani | Zkontrolovat logs/ | Log soubor existuje |

---

## 6. Rollback plan

1. **Odstraneni pre-commit**
   ```bash
   pre-commit uninstall
   rm .pre-commit-config.yaml
   ```

2. **Odstraneni workflow guard**
   ```bash
   rm scripts/workflow_guard.py
   rm -rf config/
   ```

3. **Obnova Dangerfile.js**
   - Vratit puvodni verzi z git

---

*Vytvoreno: 2026-02-15*
*Verze: 2.0*
