# Implementacni specifikace: Workflow Execution Guard v2.02

**Cesta:** plans\workflow_execution_guard_spec_v2.02.md
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
**Verze:** 2.02
**Vytvoreno:** 2026-02-15 07:35 (UTC+1)
**Posledni zmena:** 2026-02-15 07:39 (UTC+1)
**Status:** Pripraveno k implementaci

---

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-15 | 2.02 | Aktualizace metadat, pridana tabulka historie zmen |

## Stav

- [x] Specifikace kompletni
- [x] Diskuze dokoncena
- [ ] Implementace v Code modu

---

## 1. Souhrn diskuse

Tato specifikace je vysledkem krok za krokem diskuze o implementaci Workflow Execution Guard. Hlavni cile:

1. **Maximalni spolehlivost** - vsechny kroky s `onFailure: block`
2. **Kontrola dokumentace** - vsechny `.md` soubory musi mit metadata
3. **Verzovani a logovani** - kazdy dokument musi mit verzi, timestamp, historii zmen
4. **Archivace NEXT_SESSION** - automaticka archivace s timestampem

---

## 2. Prehled souboru k vytvoreni

| Soubor | Typ | Ucel |
|--------|-----|------|
| `workflow-steps.json` | JSON | Definice povinnych kroku |
| `workflow-steps.schema.json` | JSON Schema | Validace konfigurace |
| `scripts/workflow_guard.ps1` | PowerShell | Hlavni verifikacni skript |
| `scripts/validate_document_metadata.ps1` | PowerShell | Validace metadat dokumentu |
| `scripts/validate_constitution.ps1` | PowerShell | Kontrola souladu s ustavou |
| `scripts/validate_next_session.ps1` | PowerShell | Kontrola NEXT_SESSION.md |
| `scripts/archive_next_session.ps1` | PowerShell | Archivace NEXT_SESSION.md |
| `logs/.gitkeep` | Git | Adresar pro logy |
| `.husky/pre-commit` | Bash | Aktualizovany hook |
| `.husky/pre-push` | Bash | Novy hook |
| `.github/workflows/workflow-guard.yml` | YAML | CI/CD integrace |

---

## 3. Definice kroku workflow

### 3.1 Pre-commit kroky (6 kroku)

| ID | Nazev | Skript | onFailure |
|----|-------|--------|-----------|
| `check-duplicates` | Kontrola duplicit | `scripts/check_duplicates.ps1` | block |
| `validate-timestamps` | Validace timestampu | `scripts/validate_timestamps.ps1` | block |
| `validate-document-metadata` | Validace metadat | `scripts/validate_document_metadata.ps1` | block |
| `update-docs` | Aktualizace dokumentace | `scripts/update_docs.ps1` | block |
| `validate-constitution` | Kontrola ustavy | `scripts/validate_constitution.ps1` | block |

### 3.2 Pre-push kroky (3 kroky)

| ID | Nazev | Skript | onFailure | Retry |
|----|-------|--------|-----------|-------|
| `rust-tests` | Rust testy | `cargo test` | block | 2 pokusy, 8s pauza |
| `validate-next-session` | Kontrola NEXT_SESSION | `scripts/validate_next_session.ps1` | block | - |
| `archive-next-session` | Archivace NEXT_SESSION | `scripts/archive_next_session.ps1` | block | - |

---

## 4. Detailni specifikace souboru

### 4.1 `workflow-steps.json`

```json
{
  "$schema": "./workflow-steps.schema.json",
  "version": "1.0",
  "steps": [
    {
      "id": "check-duplicates",
      "name": "Kontrola duplicit",
      "description": "Detekce duplicitnich radku v souborech",
      "trigger": "pre-commit",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/check_duplicates.ps1 -IgnoreEmptyLines",
      "timeout": 60,
      "expectedOutput": "--- DUPLICATE CHECK PASSED ---",
      "onFailure": "block"
    },
    {
      "id": "validate-timestamps",
      "name": "Validace timestampu",
      "description": "Kontrola, ze vsechny dokumenty maji aktualni timestamp",
      "trigger": "pre-commit",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_timestamps.ps1",
      "timeout": 30,
      "expectedOutput": "--- TIMESTAMP VALIDATION PASSED ---",
      "onFailure": "block"
    },
    {
      "id": "validate-document-metadata",
      "name": "Validace metadat dokumentu",
      "description": "Kontrola verze, timestampu a historie zmen vsech .md souboru",
      "trigger": "pre-commit",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_document_metadata.ps1",
      "timeout": 60,
      "expectedOutput": "--- DOCUMENT METADATA VALIDATION PASSED ---",
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
      "id": "validate-constitution",
      "name": "Kontrola souladu s ustavou",
      "description": "Overeni, ze zmeny jsou v souladu s CONSTITUTION.md",
      "trigger": "pre-commit",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_constitution.ps1",
      "timeout": 60,
      "expectedOutput": "--- CONSTITUTION VALIDATION PASSED ---",
      "onFailure": "block"
    },
    {
      "id": "rust-tests",
      "name": "Rust testy",
      "description": "Spusteni Rust unit testu",
      "trigger": "pre-push",
      "required": true,
      "command": "cd src-tauri && cargo test --quiet",
      "timeout": 300,
      "expectedOutput": "test result: ok",
      "retry": {
        "maxAttempts": 2,
        "delaySeconds": 8,
        "retryOn": ["error", "timeout"]
      },
      "onFailure": "block"
    },
    {
      "id": "validate-next-session",
      "name": "Kontrola NEXT_SESSION.md",
      "description": "Overeni, ze NEXT_SESSION.md je aktualni a obsahuje platne informace",
      "trigger": "pre-push",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_next_session.ps1",
      "timeout": 30,
      "expectedOutput": "--- NEXT SESSION VALIDATION PASSED ---",
      "onFailure": "block"
    },
    {
      "id": "archive-next-session",
      "name": "Archivace NEXT_SESSION.md",
      "description": "Archivace NEXT_SESSION.md s timestampem a vytvoreni noveho",
      "trigger": "pre-push",
      "required": true,
      "command": "powershell -ExecutionPolicy Bypass -File scripts/archive_next_session.ps1",
      "timeout": 30,
      "expectedOutput": "--- NEXT SESSION ARCHIVED ---",
      "onFailure": "block"
    }
  ]
}
```

### 4.2 `workflow-steps.schema.json`

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
      "minItems": 1,
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
          "retry": {
            "type": "object",
            "properties": {
              "maxAttempts": {
                "type": "integer",
                "minimum": 1,
                "default": 1
              },
              "delaySeconds": {
                "type": "integer",
                "minimum": 0,
                "default": 0
              },
              "retryOn": {
                "type": "array",
                "items": {
                  "type": "string",
                  "enum": ["error", "timeout", "failed"]
                }
              }
            }
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

---

## 5. Povinna metadata pro vsechny .md soubory

### 5.1 Format metadat

Kazdy `.md` soubor v projektu musi obsahovat:

```markdown
# Nazev dokumentu (musi odpovidat nazvu souboru)

**Verze:** X.X
**Vytvoreno:** YYYY-MM-DD HH:MM (UTC+X)
**Posledni zmena:** YYYY-MM-DD HH:MM (UTC+X)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| YYYY-MM-DD | X.X | Popis... |

## Stav

- [x] Hotovo
- [ ] Rozpracovano
- [ ] Naplanovano

## Pristi kroky

1. Krok 1
2. Krok 2
```

### 5.2 Validacni pravidla

| Pravidlo | Popis |
|----------|-------|
| Nazev souboru | Musi odpovidat nadpisu dokumentu |
| Verze | Format X.X, musi se zvysovat pri zmene |
| Timestamp | Format YYYY-MM-DD HH:MM (UTC+X) |
| Historie zmen | Kazda zmena musi byt zaznamenana |
| Stav | Jedna z moznosti: Hotovo/Rozpracovano/Naplanovano |

---

## 6. Husky hooks

### 6.1 `.husky/pre-commit`

```bash
#!/bin/bash

echo "=== Pre-commit Hook ==="
echo "Workflow Execution Guard v2.02"
echo ""

# Kontrola dostupnosti PowerShell
if ! command -v powershell &> /dev/null; then
    echo "ERROR: PowerShell is not available!"
    echo "Please install PowerShell or use --no-verify to skip."
    exit 1
fi

# Kontrola existence skriptu
SCRIPT="scripts/workflow_guard.ps1"
if [ ! -f "$SCRIPT" ]; then
    echo "ERROR: Workflow Guard script not found: $SCRIPT"
    echo "Please run setup first."
    exit 1
fi

# Spusteni Workflow Guard
echo "Running Workflow Guard (pre-commit)..."
powershell -ExecutionPolicy Bypass -File "$SCRIPT" -Trigger pre-commit

if [ $? -ne 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Workflow Guard blocked the commit!"
    echo "=========================================="
    echo ""
    echo "Failed steps must be fixed before committing."
    echo "Use 'git commit --no-verify' to skip (not recommended)."
    exit 1
fi

echo ""
echo "All pre-commit checks passed! Commit allowed."
```

### 6.2 `.husky/pre-push`

```bash
#!/bin/bash

echo "=== Pre-push Hook ==="
echo "Workflow Execution Guard v2.02"
echo ""

# Kontrola dostupnosti PowerShell
if ! command -v powershell &> /dev/null; then
    echo "ERROR: PowerShell is not available!"
    echo "Please install PowerShell or use --no-verify to skip."
    exit 1
fi

# Kontrola existence skriptu
SCRIPT="scripts/workflow_guard.ps1"
if [ ! -f "$SCRIPT" ]; then
    echo "ERROR: Workflow Guard script not found: $SCRIPT"
    echo "Please run setup first."
    exit 1
fi

# Spusteni Workflow Guard
echo "Running Workflow Guard (pre-push)..."
powershell -ExecutionPolicy Bypass -File "$SCRIPT" -Trigger pre-push

if [ $? -ne 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Workflow Guard blocked the push!"
    echo "=========================================="
    echo ""
    echo "Failed steps must be fixed before pushing."
    echo "Use 'git push --no-verify' to skip (not recommended)."
    exit 1
fi

echo ""
echo "All pre-push checks passed! Push allowed."
```

---

## 7. GitHub Actions workflow

### `.github/workflows/workflow-guard.yml`

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
            
            ${latest.summary.failed > 0 ? '### Failed Steps\n' + latest.results.filter(r => r.status === 'failed').map(r => '- ${r.name}').join('\n') : ''}
            `;
            
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
```

---

## 8. Aktualizace `.gitignore`

Pridat nasledujici radky:

```
# Workflow Guard logs
logs/execution-log.json
```

---

## 9. Implementacni poradi

### Faze 1: Zakladni infrastruktura
1. Vytvorit `workflow-steps.json`
2. Vytvorit `workflow-steps.schema.json`
3. Vytvorit `scripts/workflow_guard.ps1`
4. Vytvorit `logs/.gitkeep`

### Faze 2: Nove validacni skripty
5. Vytvorit `scripts/validate_document_metadata.ps1`
6. Vytvorit `scripts/validate_constitution.ps1`
7. Vytvorit `scripts/validate_next_session.ps1`
8. Vytvorit `scripts/archive_next_session.ps1`

### Faze 3: Integrace s hooks
9. Aktualizovat `.husky/pre-commit`
10. Vytvorit `.husky/pre-push`
11. Aktualizovat `.gitignore`

### Faze 4: CI/CD integrace
12. Vytvorit `.github/workflows/workflow-guard.yml`

### Faze 5: Testovani
13. Otestovat `workflow_guard.ps1 -Trigger pre-commit -DryRun`
14. Otestovat skutecny commit
15. Otestovat push

---

## 10. Verifikacni kriteria

### 10.1 Funkcni kriteria
- [ ] `workflow_guard.ps1` se spusti bez chyb
- [ ] Pre-commit hook vola Workflow Guard
- [ ] Pre-push hook vola Workflow Guard
- [ ] Logy se ukladaji do `logs/execution-log.json`
- [ ] CI/CD spousti Workflow Guard
- [ ] Vsechny `.md` soubory maji povinna metadata
- [ ] NEXT_SESSION.md se archivuje s timestampem

### 10.2 Nefunkcni kriteria
- [ ] Pre-commit trva < 60s
- [ ] Pre-push trva < 300s
- [ ] Vystup je citelny a informativni
- [ ] Chybove zpravy jsou uzitecne

### 10.3 Bezpecnostni kriteria
- [ ] Logy neobsahuji citlive udaje
- [ ] Konfigurace je validovana proti schematu
- [ ] Force option je dokumentovana s varovanim

---

## 11. Rollback plan

Pokud implementace selze:

1. **Okamzite:**
   - Odstranit volani Workflow Guard z `.husky/pre-commit`
   - Obnovit puvodni pre-commit hook
   - Commitovat s `--no-verify`

2. **Dlouhodobe:**
   - Analyzovat logy pro identifikaci problemu
   - Opravit problem
   - Znovu nasadit

---

## 12. Rozhodnuti z diskuze

| Tema | Rozhodnuti |
|------|------------|
| Umisteni konfigurace | Koren projektu (jednodussi) |
| Kontrola dokumentu | Vsechny `.md` soubory (nejprisnejsi) |
| onFailure | Vsechny kroky `block` |
| Retry mechanismus | Jen pro `rust-tests` (2 pokusy, 8s pauza) |
| Cache v CI/CD | Bez cache (nejbezpecnejsi) |
| Paralelni spousteni | Ne, sekvenecni (bezpecnejsi) |
| Archivace NEXT_SESSION | Ano, s timestampem |

---

*Vytvoreno: 2026-02-15 07:35 (UTC+1)*
*Verze: 2.02*
*Status: Pripraveno k implementaci*
*Posledni zmena: 2026-02-15 07:39 (UTC+1)*