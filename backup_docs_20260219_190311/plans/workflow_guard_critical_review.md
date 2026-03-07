# Kritická analýza Workflow Execution Guard

**Cesta:** plans/workflow_guard_critical_review.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-16 14:38 (UTC+1)
**Posledni zmena:** 2026-02-16 14:59 (UTC+1)

## Stav

- [x] Analýza silných stránek
- [x] Analýza slabých stránek
- [x] Doporučení pro zlepšení
- [x] Cross-platform kompatibilita (Mac/Linux)

---

## 1. Přehled architektury

Workflow Execution Guard je systém pro automatickou validaci git operací skládající se z:

```
┌─────────────────────────────────────────────────────────────┐
│                    Git Hooks                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  pre-commit  │  │   pre-push   │  │   CI/CD      │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │                │
│         └─────────────────┼─────────────────┘                │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────┐      │
│  │           workflow_guard.ps1                        │      │
│  │  - Načte workflow-steps.json                        │      │
│  │  - Validuje proti JSON Schema                       │      │
│  │  - Spustí příslušné kroky                           │      │
│  │  - Uloží logy do logs/execution-log.json            │      │
│  └────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Silné stránky ✅

### 2.1 Architektura a design

| Aspekt | Hodnocení | Popis |
|--------|-----------|-------|
| **Modularita** | ⭐⭐⭐⭐⭐ | Konfigurace v JSON oddělená od logiky |
| **Rozšiřitelnost** | ⭐⭐⭐⭐⭐ | Snadné přidání nových kroků bez úpravy skriptu |
| **JSON Schema** | ⭐⭐⭐⭐ | Validace konfigurace před spuštěním |
| **Trigger-based** | ⭐⭐⭐⭐⭐ | pre-commit, pre-push, pre-build, ci |

### 2.2 Funkcionalita

| Aspekt | Hodnocení | Popis |
|--------|-----------|-------|
| **Retry mechanism** | ⭐⭐⭐⭐ | Podpora opakování s nastavitelným zpožděním |
| **Timeout handling** | ⭐⭐⭐⭐ | Každý krok má vlastní timeout |
| **DryRun mode** | ⭐⭐⭐⭐⭐ | Testování bez reálných změn |
| **Force override** | ⭐⭐⭐ | Možnost vynucení při selhání |
| **Log rotation** | ⭐⭐⭐⭐ | Automatická rotace po 30 záznamech |

### 2.3 Integrace

| Aspekt | Hodnocení | Popis |
|--------|-----------|-------|
| **Git hooks** | ⭐⭐⭐⭐ | Husky integrace s pre-commit a pre-push |
| **CI/CD** | ⭐⭐⭐⭐ | GitHub Actions workflow |
| **Graphviz** | ⭐⭐⭐ | Vizualizace workflow |
| **PR comments** | ⭐⭐⭐⭐ | Automatické komentáře v PR |

### 2.4 Uživatelská přívětivost

| Aspekt | Hodnocení | Popis |
|--------|-----------|-------|
| **Barevný výstup** | ⭐⭐⭐⭐ | Přehledné logování s barvami |
| **Detailní výstup** | ⭐⭐⭐⭐ | Přepínač -DetailedOutput |
| **Error messages** | ⭐⭐⭐ | Srozumitelné chybové zprávy |

---

## 3. Slabé stránky ⚠️

### 3.1 Kritické problémy 🔴

| Problém | Závažnost | Popis |
|---------|-----------|-------|
| **Žádné CI kroky** | 🔴 KRITICKÉ | `workflow-steps.json` nemá žádné kroky s `trigger: "ci"` |
| **Bash v PowerShell** | 🔴 KRITICKÉ | pre-commit/pre-push jsou bash skripty, ale projekt je Windows-only |
| **JSON Schema nevaliduje** | 🟡 STŘEDNÍ | `Test-JsonSchema` pouze základní kontrola, ne plná validace |

### 3.2 Architektonické problémy 🟡

| Problém | Závažnost | Popis |
|---------|-----------|-------|
| **Platformní závislost** | 🟡 STŘEDNÍ | PowerShell + Windows cesty (`\`) |
| **Žádná paralelizace** | 🟡 STŘEDNÍ | Kroky běží sekvenčně, ne paralelně |
| **Hardcoded cesty** | 🟡 STŘEDNÍ | `logs/execution-log.json` není konfigurovatelné |
| **Chybí dependency check** | 🟡 STŘEDNÍ | Neověřuje závislosti mezi kroky |

### 3.3 Bezpečnostní problémy 🟡

| Problém | Závažnost | Popis |
|---------|-----------|-------|
| **-Force přepínač** | 🟡 STŘEDNÍ | Umožňuje obejít všechny kontroly |
| **Žádné auditování** | 🟡 STŘEDNÍ | Neexistuje audit log pro -Force použití |
| **Command injection** | 🟢 NÍZKÉ | Příkazy z JSON se spouštějí přes `cmd /c` |

### 3.4 Udržovatelnost 🟡

| Problém | Závažnost | Popis |
|---------|-----------|-------|
| **Chybí testy** | 🟡 STŘEDNÍ | Žádné unit testy pro workflow_guard.ps1 |
| **Chybí dokumentace** | 🟡 STŘEDNÍ | Žádná API dokumentace |
| **Magic numbers** | 🟢 NÍZKÉ | `30` pro rotaci logů je hardcoded |

### 3.5 Výkonnostní problémy 🟢

| Problém | Závažnost | Popis |
|---------|-----------|-------|
| **Sekvenční spouštění** | 🟢 NÍZKÉ | Nevyužívá paralelizace |
| **Opakované načítání** | 🟢 NÍZKÉ | Každý skript se načítá znovu |

---

## 4. Detailní analýza problémů

### 4.1 Žádné CI kroky (KRITICKÉ)

```json
// workflow-steps.json - chybí kroky pro CI
{
  "steps": [
    // pre-commit kroky: 5
    // pre-push kroky: 3
    // ci kroky: 0 ❌
  ]
}
```

**Dopad:** CI/CD workflow v `.github/workflows/workflow-guard.yml` volá:
```yaml
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger ci
```

Toto vždy vrátí `exit 0` s hláškou "no steps" - **žádná validace se neprovede!**

**Řešení:** Přidat CI kroky:
```json
{
  "id": "ci-validate-all",
  "trigger": "ci",
  "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_document_metadata.ps1"
}
```

### 4.2 Bash skripty na Windows (KRITICKÉ)

```bash
# .husky/pre-commit - řádek 1
#!/bin/bash  // ❌ Bash na Windows?
```

**Problém:** Projekt je Windows-only (PowerShell skripty, Windows cesty), ale Husky hooks jsou bash.

**Realita:** Na Windows s Git Bash to funguje, ale:
- Není to konzistentní
- Může selhat na systémech bez Git Bash
- PowerShell by byl přirozenější

**Řešení:** Přepsat na PowerShell:
```powershell
# .husky/pre-commit.ps1
param()
& powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit
```

### 4.3 JSON Schema validace (STŘEDNÍ)

```powershell
# workflow_guard.ps1 - řádky 54-95
function Test-JsonSchema {
    # Pouze základní kontrola!
    if (-not $JsonData.version) { return $false }
    if (-not $JsonData.steps) { return $false }
    # Chybí: validace typů, povinných polí, enum hodnot...
}
```

**Problém:** Funkce `Test-JsonSchema` nepoužívá skutečnou JSON Schema validaci.

**Řešení:** Použít `Newtonsoft.Json.Schema` nebo PowerShell modul.

---

## 5. Doporučení

### 5.1 Okamžité opravy (P0)

1. **Přidat CI kroky** do `workflow-steps.json`
2. **Přepsat Husky hooks** na PowerShell nebo zajistit Git Bash kompatibilitu
3. **Implementovat plnou JSON Schema validaci**

### 5.2 Krátkodobá vylepšení (P1)

1. **Přidat unit testy** pro `workflow_guard.ps1`
2. **Implementovat paralelizaci** pro nezávislé kroky
3. **Přidat audit log** pro `-Force` použití
4. **Konfigurovatelné cesty** v `workflow-steps.json`

### 5.3 Dlouhodobá vylepšení (P2)

1. **Cross-platform podpora** (PowerShell Core)
2. **Web dashboard** pro zobrazení logů
3. **Notifikace** (Slack, Teams) při selhání
4. **Metriky a statistiky** úspěšnosti

---

## 6. Cross-platform kompatibilita (Mac/Linux)

### 6.1 Požadavky

Pro fungování na Mac a Linux je potřeba:

1. **PowerShell Core** (pwsh) - multiplatformní verze PowerShellu
2. **Upravené Husky hooks** - detekce platformy a spuštění příslušného příkazu

### 6.2 Instalace PowerShell Core

**Mac (Homebrew):**
```bash
brew install --cask powershell
```

**Linux (Ubuntu/Debian):**
```bash
# Ubuntu 20.04/22.04
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install powershell
```

### 6.3 Úprava Husky hooks pro cross-platform

**Původní .husky/pre-commit (bash-only):**
```bash
#!/bin/bash
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit
```

**Upravený .husky/pre-commit (cross-platform):**
```bash
#!/bin/bash

# Detekce platformy
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash)
    POWERSHELL_CMD="powershell"
else
    # Mac/Linux
    POWERSHELL_CMD="pwsh"
fi

# Kontrola dostupnosti PowerShell
if ! command -v $POWERSHELL_CMD &> /dev/null; then
    echo "ERROR: PowerShell is not available!"
    echo "Install PowerShell Core: https://docs.microsoft.com/powershell/scripting/install"
    exit 1
fi

# Spuštění Workflow Guard
$POWERSHELL_CMD -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit
```

### 6.4 Úprava workflow-steps.json

Příkazy musí být kompatibilní s oběma platformami:

```json
{
  "id": "validate-document-metadata",
  "command": "pwsh -ExecutionPolicy Bypass -File scripts/validate_document_metadata.ps1"
}
```

**Nebo s detekcí v hooku:**
```json
{
  "id": "validate-document-metadata",
  "command": "powershell -ExecutionPolicy Bypass -File scripts/validate_document_metadata.ps1"
}
```

### 6.5 Úprava skriptů pro cross-platform

Hlavní změny v `workflow_guard.ps1`:

```powershell
# Detekce platformy
$IsWindows = $PSVersionTable.Platform -eq "Win32NT" -or $PSVersionTable.PSEdition -eq "Desktop"
$IsMacOS = $PSVersionTable.Platform -eq "Unix" -and (uname) -eq "Darwin"
$IsLinux = $PSVersionTable.Platform -eq "Unix" -and (uname) -ne "Darwin"

# Cesty - použít [System.IO.Path]::Combine místo hardcoded \
$ConfigPath = [System.IO.Path]::Combine($PSScriptRoot, "..", "workflow-steps.json")

# Oddělovač cest
$PathSeparator = [System.IO.Path]::DirectorySeparatorChar
```

### 6.6 Shrnutí změn pro cross-platform

| Soubor | Změna |
|--------|-------|
| `.husky/pre-commit` | Detekce `pwsh` vs `powershell` |
| `.husky/pre-push` | Detekce `pwsh` vs `powershell` |
| `workflow-steps.json` | Příkazy s `pwsh` nebo detekcí |
| `scripts/*.ps1` | Cesty přes `[System.IO.Path]` |
| CI/CD | Použít `pwsh` shell místo `powershell` |

### 6.7 CI/CD pro cross-platform

```yaml
# .github/workflows/workflow-guard.yml
jobs:
  guard:
    strategy:
      matrix:
        os: [windows-latest, macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    
    steps:
      - name: Setup PowerShell (Mac/Linux)
        if: runner.os != 'Windows'
        shell: bash
        run: |
          if [[ "$RUNNER_OS" == "macOS" ]]; then
            brew install --cask powershell
          elif [[ "$RUNNER_OS" == "Linux" ]]; then
            sudo apt-get install -y powershell
          fi
      
      - name: Run Workflow Guard
        shell: pwsh
        run: |
          pwsh -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger ci
```

---

## 7. Hodnocení celkem

| Kritérium | Skóre | Váha | Výsledek |
|-----------|-------|------|----------|
| Funkcionalita | 4/5 | 30% | 1.2 |
| Architektura | 4/5 | 25% | 1.0 |
| Kvalita kódu | 3/5 | 20% | 0.6 |
| Dokumentace | 3/5 | 15% | 0.45 |
| Testovatelnost | 2/5 | 10% | 0.2 |
| **CELKEM** | | **100%** | **3.45/5** |

### Závěr

Workflow Execution Guard je **dobře navržený systém** s kvalitní modulární architekturou. Hlavní slabinou je **nedokončená CI integrace** a **platformní nekonzistence** (bash vs PowerShell). Po opravě kritických problémů bude systém připraven pro produkční použití.

---

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-16 | 1.1 | Přidána sekce pro cross-platform kompatibilitu (Mac/Linux) |
| 2026-02-16 | 1.0 | Vytvoření kritické analýzy |

---

*Vytvoreno: 2026-02-16 14:38 (UTC+1)*
