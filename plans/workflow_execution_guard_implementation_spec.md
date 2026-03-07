# Implementační specifikace: Workflow Execution Guard

**Cesta:** plans\workflow_execution_guard_implementation_spec.md
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
**Vytvořeno:** 2026-02-15 04:30 (UTC+1)
**Verze:** 1.0
**Status:** Připraveno pro implementaci

---

## 1. Přehled souborů k vytvoření

| Soubor | Typ | Účel |
|--------|-----|------|
| `workflow-steps.json` | JSON | Definice povinných kroků |
| `workflow-steps.schema.json` | JSON Schema | Validace konfigurace |
| `scripts/workflow_guard.ps1` | PowerShell | Hlavní verifikační skript |
| `logs/.gitkeep` | Git | Adresář pro logy |
| `.husky/pre-commit` | Bash | Aktualizovaný hook |
| `.husky/pre-push` | Bash | Nový hook |
| `.github/workflows/workflow-guard.yml` | YAML | CI/CD integrace |

---

## 2. Detailní specifikace souborů

### 2.1 `workflow-steps.json`

**Umístění:** Kořen projektu
**Účel:** Centralizovaná definice všech povinných kroků

```json
{
  "$schema": "./workflow-steps.schema.json",
  "version": "1.0",
  "steps": [
    {
      "id": "check-duplicates",
      "name": "Kontrola duplicit",
      "description": "Detekce duplicitních řádků v souborech",
      "trigger": "pre-commit",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/check_duplicates.ps1 -IgnoreEmptyLines",
      "timeout": 60,
      "expectedOutput": "--- DUPLICATE CHECK PASSED ---",
      "onFailure": "block"
    },
    {
      "id": "update-docs",
      "name": "Aktualizace dokumentace",
      "description": "Aktualizace QA_REPORT.md a CHANGE_LOG.md",
      "trigger": "pre-commit",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/update_docs.ps1",
      "timeout": 120,
      "expectedOutput": "--- CONTROLLER DONE ---",
      "onFailure": "block"
    },
    {
      "id": "rust-tests",
      "name": "Rust testy",
      "description": "Spuštění Rust unit testů",
      "trigger": "pre-push",
      "required": true,
      "command": "cd src-tauri && cargo test --quiet",
      "timeout": 300,
      "expectedOutput": "test result: ok",
      "onFailure": "warn"
    }
  ]
}
```

### 2.2 `workflow-steps.schema.json`

**Umístění:** Kořen projektu
**Účel:** JSON Schema pro validaci konfigurace

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Workflow Steps Configuration",
  "type": "object",
  "required": ["version", "steps"],
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+$"
    },
    "steps": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "name", "trigger", "required", "command"],
        "properties": {
          "id": {
            "type": "string",
            "pattern": "^[a-z0-9-]+$"
          },
          "name": {
            "type": "string",
            "minLength": 1
          },
          "description": {
            "type": "string"
          },
          "trigger": {
            "type": "string",
            "enum": ["pre-commit", "pre-push", "pre-build", "ci"]
          },
          "required": {
            "type": "boolean"
          },
          "command": {
            "type": "string",
            "minLength": 1
          },
          "timeout": {
            "type": "integer",
            "minimum": 1,
            "default": 60
          },
          "expectedOutput": {
            "type": "string"
          },
          "onFailure": {
            "type": "string",
            "enum": ["block", "warn", "ignore"],
            "default": "block"
          }
        }
      }
    }
  }
}
```

### 2.3 `scripts/workflow_guard.ps1`

**Umístění:** `scripts/`
**Účel:** Hlavní verifikační skript

```powershell
# scripts/workflow_guard.ps1
# Workflow Execution Guard - Garantuje provedení povinných kroků
# Verze: 1.0

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("pre-commit", "pre-push", "pre-build", "ci")]
    [string]$Trigger,
    
    [string]$ConfigPath = "$PSScriptRoot/../workflow-steps.json",
    [string]$SchemaPath = "$PSScriptRoot/../workflow-steps.schema.json",
    [string]$LogPath = "$PSScriptRoot/../logs/execution-log.json",
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Barvy pro výstup
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Inicializace
Write-ColorOutput "--- [WORKFLOW GUARD START] ---" "Cyan"
Write-ColorOutput "Trigger: $Trigger" "Yellow"
Write-ColorOutput "Config: $ConfigPath" "Gray"

if ($DryRun) {
    Write-ColorOutput "Mode: DRY RUN (no changes will be made)" "Yellow"
}
if ($Force) {
    Write-ColorOutput "Mode: FORCE (failures will be ignored)" "Red"
}

# 1. Kontrola existence konfigurace
if (-not (Test-Path $ConfigPath)) {
    Write-ColorOutput "ERROR: Configuration file not found: $ConfigPath" "Red"
    Write-ColorOutput "Please create workflow-steps.json first." "Yellow"
    exit 1
}

# 2. Načtení a validace konfigurace
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    Write-ColorOutput "Configuration loaded: version $($config.version)" "Green"
} catch {
    Write-ColorOutput "ERROR: Failed to parse configuration: $($_.Exception.Message)" "Red"
    exit 1
}

# 3. Filtrování kroků pro daný trigger
$steps = @($config.steps | Where-Object { $_.trigger -eq $Trigger })

if ($steps.Count -eq 0) {
    Write-ColorOutput "No steps defined for trigger: $Trigger" "Green"
    Write-ColorOutput "--- [WORKFLOW GUARD DONE] ---" "Cyan"
    exit 0
}

Write-ColorOutput "`nFound $($steps.Count) steps for trigger: $Trigger" "White"

# 4. Provedení kroků
$results = @()
$failed = @()
$passed = 0
$errors = 0

foreach ($step in $steps) {
    Write-ColorOutput "`n[$($step.id)] $($step.name)" "Cyan"
    
    if ($Verbose) {
        Write-ColorOutput "  Command: $($step.command)" "Gray"
        Write-ColorOutput "  Timeout: $($step.timeout)s" "Gray"
        Write-ColorOutput "  Required: $($step.required)" "Gray"
    }
    
    $result = @{
        id = $step.id
        name = $step.name
        trigger = $Trigger
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        status = "pending"
        output = ""
        duration = 0
    }
    
    if ($DryRun) {
        Write-ColorOutput "  [DRY RUN] Would execute: $($step.command)" "Yellow"
        $result.status = "skipped"
        $results += $result
        continue
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Spuštění příkazu s timeoutem
        $output = Invoke-Expression $step.command 2>&1
        $stopwatch.Stop()
        
        $result.duration = $stopwatch.ElapsedMilliseconds
        $result.output = ($output | Out-String)
        
        # Kontrola očekávaného výstupu
        $outputString = $output -join "`n"
        if ($step.expectedOutput -and ($outputString -notmatch [regex]::Escape($step.expectedOutput))) {
            $result.status = "failed"
            $failed += $step
            Write-ColorOutput "  FAILED: Expected output not found" "Red"
            if ($Verbose) {
                Write-ColorOutput "  Expected: $($step.expectedOutput)" "Gray"
            }
        } else {
            $result.status = "passed"
            $passed++
            Write-ColorOutput "  PASSED ($($result.duration)ms)" "Green"
        }
    } catch {
        $stopwatch.Stop()
        $result.duration = $stopwatch.ElapsedMilliseconds
        $result.status = "error"
        $result.output = $_.Exception.Message
        $errors++
        $failed += $step
        Write-ColorOutput "  ERROR: $($_.Exception.Message)" "Red"
    }
    
    $results += $result
}

# 5. Uložení logu
$logEntry = @{
    trigger = $Trigger
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    hostname = $env:COMPUTERNAME
    username = $env:USERNAME
    results = $results
    summary = @{
        total = $steps.Count
        passed = $passed
        failed = $failed.Count
        errors = $errors
    }
}

# Zajistit existenci adresáře
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Přidat do existujícího logu nebo vytvořit nový
if (Test-Path $LogPath) {
    try {
        $existingLog = Get-Content $LogPath -Raw | ConvertFrom-Json
        $existingLog.executions += $logEntry
        $existingLog | ConvertTo-Json -Depth 10 | Out-File $LogPath -Encoding utf8
    } catch {
        # Pokud je log poškozený, vytvořit nový
        @{
            version = "1.0"
            executions = @($logEntry)
        } | ConvertTo-Json -Depth 10 | Out-File $LogPath -Encoding utf8
    }
} else {
    @{
        version = "1.0"
        executions = @($logEntry)
    } | ConvertTo-Json -Depth 10 | Out-File $LogPath -Encoding utf8
}

Write-ColorOutput "`nLog saved to: $LogPath" "Gray"

# 6. Výsledek
Write-ColorOutput "`n--- [WORKFLOW GUARD SUMMARY] ---" "Cyan"
Write-ColorOutput "Total:   $($logEntry.summary.total)" "White"
Write-ColorOutput "Passed:  $passed" "Green"
Write-ColorOutput "Failed:  $($failed.Count)" "Red"
Write-ColorOutput "Errors:  $errors" "Red"

if ($failed.Count -gt 0) {
    Write-ColorOutput "`nFailed steps:" "Red"
    $failed | ForEach-Object { 
        Write-ColorOutput "  - $($_.name) [$($_.id)]" "Red"
    }
    
    # Kontrola onFailure akce
    $blockers = @($failed | Where-Object { $_.onFailure -eq "block" -and $_.required -eq $true })
    
    if ($blockers.Count -gt 0 -and -not $Force) {
        Write-ColorOutput "`nBLOCKING: Cannot proceed due to failed required steps" "Red"
        Write-ColorOutput "Use -Force to override (not recommended)" "Yellow"
        Write-ColorOutput "`n--- [WORKFLOW GUARD FAILED] ---" "Red"
        exit 1
    } elseif ($Force) {
        Write-ColorOutput "`nWARNING: Proceeding despite failures (-Force used)" "Yellow"
    }
}

Write-ColorOutput "`n--- [WORKFLOW GUARD DONE] ---" "Cyan"
exit 0
```

### 2.4 `.husky/pre-commit` (aktualizovaný)

**Umístění:** `.husky/`
**Účel:** Pre-commit hook s Workflow Guard

```bash
#!/bin/bash
echo "=== Pre-commit Hook ==="

# Spuštění Workflow Guard
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Workflow Guard blocked the commit!"
    echo "Fix the issues above or use -Force to override."
    exit 1
fi

echo ""
echo "All checks passed!"
```

### 2.5 `.husky/pre-push` (nový)

**Umístění:** `.husky/`
**Účel:** Pre-push hook s Workflow Guard

```bash
#!/bin/bash
echo "=== Pre-push Hook ==="

# Spuštění Workflow Guard
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-push

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Workflow Guard blocked the push!"
    echo "Fix the issues above or use -Force to override."
    exit 1
fi

echo ""
echo "All checks passed!"
```

### 2.6 `.github/workflows/workflow-guard.yml`

**Umístění:** `.github/workflows/`
**Účel:** CI/CD integrace

```yaml
name: Workflow Guard

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  guard:
    runs-on: windows-latest
    permissions:
      contents: read
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Setup PowerShell
        shell: pwsh
        run: |
          Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
      
      - name: Run Workflow Guard - CI
        shell: pwsh
        run: |
          powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger ci -Verbose
      
      - name: Upload Execution Log
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: execution-log
          path: logs/execution-log.json
          retention-days: 30
      
      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const log = JSON.parse(fs.readFileSync('logs/execution-log.json', 'utf8'));
            const latest = log.executions[log.executions.length - 1];
            
            const body = `## Workflow Guard Report
            
            | Metric | Value |
            |--------|-------|
            | Total | ${latest.summary.total} |
            | Passed | ${latest.summary.passed} |
            | Failed | ${latest.summary.failed} |
            | Errors | ${latest.summary.errors} |
            
            ${latest.summary.failed > 0 ? '### Failed Steps\n' + latest.results.filter(r => r.status === 'failed').map(r => `- ${r.name}`).join('\n') : ''}
            `;
            
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
```

### 2.7 `logs/.gitkeep`

**Umístění:** `logs/`
**Účel:** Zajistit existenci adresáře pro logy

```
# Tento soubor zajišťuje, že adresář logs je sledován gitem
# Skutečné logy jsou v .gitignore
```

---

## 3. Aktualizace `.gitignore`

Přidat následující řádky:

```
# Workflow Guard logs
logs/execution-log.json
```

---

## 4. Aktualizace `QA_REPORT.md`

Přidat novou sekci pro Workflow Guard:

```markdown
## Workflow Execution History

| Timestamp | Trigger | Passed | Failed | Status |
| :--- | :--- | :--- | :--- | :--- |
| *Auto-generated by workflow_guard.ps1* |
```

---

## 5. Implementační pořadí

### Fáze 1: Základní infrastruktura
1. Vytvořit `workflow-steps.json`
2. Vytvořit `workflow-steps.schema.json`
3. Vytvořit `scripts/workflow_guard.ps1`
4. Vytvořit `logs/.gitkeep`

### Fáze 2: Integrace s hooks
5. Aktualizovat `.husky/pre-commit`
6. Vytvořit `.husky/pre-push`
7. Aktualizovat `.gitignore`

### Fáze 3: CI/CD integrace
8. Vytvořit `.github/workflows/workflow-guard.yml`

### Fáze 4: Testování
9. Otestovat `workflow_guard.ps1 -Trigger pre-commit -DryRun`
10. Otestovat skutečný commit
11. Otestovat push

---

## 6. Verifikační kritéria

### 6.1 Funkční kritéria
- [ ] `workflow_guard.ps1` se spustí bez chyb
- [ ] Pre-commit hook volá Workflow Guard
- [ ] Pre-push hook volá Workflow Guard
- [ ] Logy se ukládají do `logs/execution-log.json`
- [ ] CI/CD spouští Workflow Guard

### 6.2 Nefunkční kritéria
- [ ] Pre-commit trvá < 30s
- [ ] Pre-push trvá < 120s
- [ ] Výstup je čitelný a informativní
- [ ] Chybové zprávy jsou užitečné

### 6.3 Bezpečnostní kritéria
- [ ] Logy neobsahují citlivé údaje
- [ ] Konfigurace je validována proti schématu
- [ ] Force option je dokumentována s varováním

---

## 7. Rollback plán

Pokud implementace selže:

1. **Okamžitě:**
   - Odstranit volání Workflow Guard z `.husky/pre-commit`
   - Obnovit původní pre-commit hook
   - Commitovat s `--no-verify`

2. **Dlouhodobě:**
   - Analyzovat logy pro identifikaci problému
   - Opravit problém
   - Znovu nasadit

---

*Specifikace vytvořena: 2026-02-15 04:30 (UTC+1)*
*Verze: 1.0*
*Status: Připraveno pro implementaci v Code módu*
