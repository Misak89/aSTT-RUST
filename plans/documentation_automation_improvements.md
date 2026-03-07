# Plán vylepšení automatické dokumentace

**Cesta:** plans\documentation_automation_improvements.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-02-17 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
**Datum:** 2026-02-14
**Autor:** Kilo Code (Architect mode)
**Verze:** 1.1

---

## 📊 Analýza současného stavu

### Existující nástroje

| Nástroj | Účel | Stav |
|---------|------|------|
| `scripts/update_docs.ps1` | Aktualizace QA_REPORT.md | ⚠️ Částečně funkční |
| Mega-Linter | CI/CD linting | ✅ OK |
| Dangerfile.js | PR validace | ✅ OK |
| Spec-Kit | Spec-driven development | ✅ OK |

### Identifikované problémy

1. **Duplicitní obsah v dokumentech**
   - `QA_REPORT.md` - řádky 75-107 duplicitní
   - `CHANGE_LOG.md` - duplicitní obsah
   - `NEXT_SESSION.md` - duplicitní obsah
   - Rust soubory - duplicitní definice

2. **Chybějící automatizace**
   - Žádný pre-commit hook
   - Žádná detekce duplicit
   - Rust není v PATH

3. **Nekonzistentní timestampy**
   - Smíšené formáty data/času
   - Chybějící timezone informace

---

## 🎯 Navrhovaná vylepšení

### 1. Pre-commit Hook

```yaml
# .git/hooks/pre-commit (nebo přes Husky)
#!/bin/bash
# Spustit před každým commit

echo "Running documentation checks..."

# 1. Kontrola duplicit
powershell -File scripts/check_duplicates.ps1

# 2. Update QA report
powershell -File scripts/update_docs.ps1

# 3. Validace timestampů
powershell -File scripts/validate_timestamps.ps1
```

### 2. Skript pro detekci duplicit

```powershell
# scripts/check_duplicates.ps1
$files = @(
    "CHANGE_LOG.md",
    "NEXT_SESSION.md", 
    "QA_REPORT.md",
    "src-tauri/src/rpc.rs",
    "src-tauri/tests/rpc_contract_test.rs"
)

foreach ($file in $files) {
    $content = Get-Content $file
    $lines = $content.Count
    $unique = ($content | Select-Object -Unique).Count
    
    if ($lines -gt $unique * 1.5) {
        Write-Error "DUPLICATE DETECTED: $file has $lines lines but only $unique unique"
        exit 1
    }
}
```

### 3. Automatická oprava duplicit

```powershell
# scripts/fix_duplicates.ps1
# Automaticky detekuje a odstraňuje duplicitní bloky
```

### 4. Vylepšení update_docs.ps1

```powershell
# Přidat:
# - Detekci a odstranění duplicit
# - Kontrolu Rust PATH
# - Automatický timestamp s timezone
# - Integraci s cargo test
```

### 5. GitHub Actions Workflow

```yaml
# .github/workflows/docs.yml
name: Documentation Check
on: [push, pull_request]

jobs:
  check:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check for duplicates
        run: powershell -File scripts/check_duplicates.ps1
        
      - name: Update QA Report
        run: powershell -File scripts/update_docs.ps1
        
      - name: Validate timestamps
        run: powershell -File scripts/validate_timestamps.ps1
```

---

## 📋 Implementační plán

### Fáze 1: Okamžité opravy
- [ ] Opravit duplicity v QA_REPORT.md
- [ ] Přidat Rust do PATH nebo upravit skripty
- [ ] Standardizovat timestamp formát (UTC+1)

### Fáze 2: Pre-commit hooks
- [ ] Vytvořit `check_duplicates.ps1`
- [ ] Vytvořit `validate_timestamps.ps1`
- [ ] Nastavit Git hooks

### Fáze 3: CI/CD integrace
- [ ] Přidat workflow pro dokumentaci
- [ ] Automatické generování changelogu
- [ ] Validace při PR

### Fáze 4: Monitoring
- [ ] Týdenní report o stavu dokumentace
- [ ] Alerty při detekci duplicit
- [ ] Dashboard v QA_REPORT.md

---

## 🔧 Technické detaily

### Timestamp formát
```
2026-02-14 16:37 (UTC+1)
```

### Struktura dokumentace
```
aSTT-RUST/
├── .github/workflows/
│   └── docs.yml           # CI/CD pro dokumentaci
├── scripts/
│   ├── update_docs.ps1    # Hlavní kontroler
│   ├── check_duplicates.ps1  # Detekce duplicit
│   ├── fix_duplicates.ps1    # Automatická oprava
│   └── validate_timestamps.ps1  # Validace časů
├── QA_REPORT.md           # Automaticky generováno
├── CHANGE_LOG.md          # Manuálně + automaticky
└── NEXT_SESSION.md        # Manuálně
```

---

## ⚠️ Rizika a mitigace

| Riziko | Mitigace |
|--------|----------|
| Pre-commit hook zpomalí commit | Spouštět pouze na změněných souborech |
| Falešné pozitivy v detekci | Nastavit práh na 1.5x duplicity |
| Konflikty s OneDrive | Přidat .gitignore pro dočasné soubory |

---

## 📈 Očekávané výsledky

1. **Konzistentní dokumentace** - žádné duplicity
2. **Automatická aktualizace** - při každém commit
3. **Validace v CI/CD** - před merge
4. **Týdenní reporty** - přehled o stavu

---

*Poslední aktualizace: 2026-02-14 16:37 (UTC+1)*
