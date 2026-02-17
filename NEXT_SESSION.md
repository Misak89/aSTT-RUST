# NEXT_SESSION - Workflow Execution Guard Implementace

**Cesta:** NEXT_SESSION.md
**Verze:** 1.9
**Vytvoreno:** 2026-02-15 19:36 (UTC+1)
**Posledni zmena:** 2026-02-16 18:04 (UTC+1)
**Status:** SPRINT 9 DOKONCEN, KVALITA VYLEPSENA

## Stav

- [x] Metadata pridana
- [x] Sprint 1-7 dokonceny
- [x] Validace: 40/40 projektu souboru proslo
- [x] Externi soubory: 345 vylouceno (spec-kit: 38, python-embed: 24, venv-system: 29, node_modules: 249, config: 5)
- [x] Kriticka analyza provedena (plans/workflow_guard_critical_review.md)
- [x] Cross-platform kompatibilita dokumentována
- [x] Sprint 8: CI kroky implementovany (P0)
- [x] Sprint 9: Vylepseni kvality (P1) ✅ NOVÉ
- [ ] Sprint 10: Cross-platform kompatibilita (P2)

---

## 1. Cil

Implementovat **Workflow Execution Guard** - automatizovany system pro validaci git operaci (pre-commit, pre-push) s integraci do CI/CD.

---

## 2. Aktualni stav

### Dokoncene ukoly:
- [x] Precteni specifikace `workflow_execution_guard_spec_v2.03.md`
- [x] Potvrzeni uzitecnosti Graphviz pro vizualizaci
- [x] Vytvoreni specifikace v2.03 s Graphviz integraci
- [x] Sprint 1: Základní infrastruktura
- [x] Sprint 2: Pre-commit integrace
- [x] Sprint 3: Pre-push rozšíření
- [x] Oprava metadat 22 dokumentů
- [x] Sprint 4: CI/CD integrace
- [x] Sprint 5: Graphviz vizualizace
- [x] Sprint 6: Testování - Workflow Guard funguje správně
- [x] Sprint 7: Dokončení metadat - 40/40 projektových souborů validováno
- [x] Přidána dokumentace metadat do GOVERNANCE.md
- [x] Opraven skript fix_document_metadata.ps1 (používá LastWriteTime)
- [x] Přidány konfigurační soubory do validace metadat
- [x] Kategorizace externích souborů (spec-kit, python-embed, venv-system, node_modules, config)
- [x] Kritická analýza Workflow Execution Guard (plans/workflow_guard_critical_review.md)

### Kriticka analyza - vysledky:

**Celkove hodnoceni: 3.45/5 ⭐⭐⭐**

**Silne stranky:**
- ⭐⭐⭐⭐⭐ Modularita a rozšiřitelnost
- ⭐⭐⭐⭐⭐ Trigger systém (pre-commit, pre-push, ci)
- ⭐⭐⭐⭐ Retry mechanism a DryRun mode
- ⭐⭐⭐⭐ CI/CD integrace s GitHub Actions

**Kriticke problemy (P0):**
- 🔴 Žádné CI kroky v workflow-steps.json (trigger: "ci" má 0 kroků)
- 🔴 Bash skripty v Husky hooks na Windows-only projektu

**Stredni problemy (P1):**
- 🟡 JSON Schema validace pouze základní
- 🟡 Žádná paralelizace kroků
- 🟡 Chybí unit testy
- 🟡 -Force přepínač bez audit logu

### Vytvorene soubory:

**Sprint 1:**
1. `workflow-steps.json` - definice 8 kroků
2. `workflow-steps.schema.json` - JSON Schema
3. `scripts/workflow_guard.ps1` - hlavní skript
4. `logs/.gitkeep` - adresář pro logy

**Sprint 2:**
5. `scripts/validate_document_metadata.ps1` - validace metadat
6. `scripts/fix_document_metadata.ps1` - automatická oprava metadat
7. `.husky/pre-commit` - aktualizovaný hook

**Sprint 3:**
8. `.husky/pre-push` - nový hook
9. `scripts/validate_constitution.ps1` - validace CONSTITUTION.md
10. `scripts/validate_next_session.ps1` - validace NEXT_SESSION.md
11. `scripts/archive_next_session.ps1` - archivace NEXT_SESSION.md

**Sprint 4:**
12. `.github/workflows/workflow-guard.yml` - CI/CD workflow

**Sprint 5:**
13. `scripts/generate_workflow_diagram.ps1` - generování diagramu
14. `docs/workflow-diagram.svg` - vygenerovaný diagram
15. `tools/graphviz/` - portable Graphviz (v .gitignore)

---

## 3. Rozhodnuti a duvody

| Rozhodnuti | Duvod |
|------------|-------|
| Graphviz: portable verze | Lokálně v `tools/graphviz/`, v CI přes `ts-graphviz/setup-graphviz@v2` |
| Rotace logů: 30 logovacích dní | Ne kalendářních - rotuje se po 30 záznamech |
| NEXT_SESSION: povinná validace | S formátem NEXT_SESSION_TimeStamp.md |
| Relativní cesta v metadatech | Každý dokument musí mít **Cesta:** v hlavičce |
| tools/graphviz/ v .gitignore | Graphviz se necommituje do repozitáře (~150 MB) |

---

## 4. Omezeni

- Architekt mod muze vytvaret/editovat pouze `.md` soubory
- Pro implementaci skriptu a JSON souboru je potreba Code mod
- Windows PowerShell skripty musi byt kompatibilni s cmd.exe
- 135 dokumentů stále nemá kompletní metadata (sandbox, docs/spec-kit)
- Graphviz portable v `tools/graphviz/` (necommituje se do repozitáře)

---

## 5. Relevantni soubory

| Soubor | Popis |
|--------|-------|
| `plans/workflow_execution_guard_spec_v2.03.md` | Aktualni specifikace |
| `plans/workflow_guard_critical_review.md` | Kritická analýza (NOVÉ) |
| `plans/implementation_priorities.md` | Priority implementace |
| `plans/sdd_complete_workflow_diagram.md` | Diagram SDD procesu |
| `workflow-steps.json` | Konfigurace kroků |
| `scripts/workflow_guard.ps1` | Hlavní skript |
| `.github/workflows/workflow-guard.yml` | CI/CD workflow |

---

## 6. Dalsi kroky (s akceptacnimi kriterii)

### Sprint 6: Testovani ✅ HOTOVO
- [x] Otestovat `workflow_guard.ps1 -Trigger pre-commit -DryRun`
- [x] Otestovat skutečný commit (selhal na duplicitách - správné chování)
- [x] Logy se ukládají do `logs/execution-log.json`

**Akceptacni kriteria:**
- ✅ Všechny hooky fungují správně
- ✅ Logy se ukládají do `logs/execution-log.json`

### Sprint 7: Dokončení metadat ✅ HOTOVO
- [x] Opravit metadata v projektových souborech (40/40 hotovo)
- [x] Přidat docs/spec-kit/ do .gitignore a ExcludePaths
- [x] Přidat konfigurační soubory do validace
- [x] Dokumentovat pravidla metadat v GOVERNANCE.md
- [x] Kategorizace externích souborů (spec-kit, python-embed, venv-system, node_modules, config)

**Akceptacni kriteria:**
- ✅ Všechny projektové .md soubory mají kompletní metadata (40/40)
- ✅ Externí knihovny jsou vyloučeny a kategorizovány (345 souborů)

### Sprint 8: CI kroky implementovány (P0) ✅ HOTOVO
- [x] Přidat CI kroky do workflow-steps.json (3 nové kroky)
- [x] Otestovat CI/CD pipeline s novými kroky (DryRun úspěšný)
- [x] Husky hooks: Bash wrapper + PowerShell je akceptovatelné řešení

**Akceptacni kriteria:**
- ✅ CI/CD pipeline skutečně validuje projekt (3 CI kroky)
- ✅ Husky hooks fungují na Windows s Git Bash
- ⏳ Všechny CI kroky projdou v GitHub Actions (čeká na push)

**Poznámka:** Původní kritický problém "Bash v Husky hooks" byl revidován. Bash wrapper volající PowerShell je akceptovatelné řešení pro Windows s Git Bash.

### Sprint 9: Vylepšení kvality (P1) ✅ HOTOVO
- [x] Implementovat plnou JSON Schema validaci
- [x] Implementovat audit log pro -Force přepínač
- [x] Přidat konfigurovatelné cesty do workflow-steps.json
- [ ] Přidat unit testy pro workflow_guard.ps1 (volitelné)

**Akceptacni kriteria:**
- ✅ JSON Schema validace kontroluje všechny povinné pole
- ✅ -Force použití se loguje do logs/force-audit.log
- ✅ Cesty konfigurovatelné v workflow-steps.json (config sekce)

### Sprint 10: Cross-platform kompatibilita (P2) ⚠️ NOVÉ
- [ ] Upravit Husky hooks pro detekci platformy (Windows/Mac/Linux)
- [ ] Použít `pwsh` místo `powershell` pro cross-platform
- [ ] Upravit cesty ve skriptech na cross-platform ([System.IO.Path])
- [ ] Otestovat na Mac/Linux (volitelně v CI/CD matrix)

**Akceptacni kriteria:**
- [ ] Hooks fungují na Windows, Mac i Linux
- [ ] CI/CD matrix testuje na všech platformách
- [ ] Dokumentace pro instalaci PowerShell Core na Mac/Linux

**Postup úpravy Husky hooks:**
```bash
#!/bin/bash
# Detekce platformy
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    POWERSHELL_CMD="powershell"  # Windows
else
    POWERSHELL_CMD="pwsh"        # Mac/Linux
fi
$POWERSHELL_CMD -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit
```

### Budoucí úkoly (po Sprintu 10)

**Extrakce Workflow Guard do opakovatelně použitelného modulu:**
- [ ] Analýza požadavků na opakovatelnou použitelnost
- [ ] Diskuse o architektuře (samostatný adresář, repozitář, npm balíček?)
- [ ] Návrh instalačního mechanismu pro jiné projekty
- [ ] Vytvoření dokumentace a šablon

**Poznámka:** Tento úkol musí začít důkladnou analýzou a diskusí před jakoukoliv implementací.

---

## 7. Otevrene otazky

1. Mají se logy rotovat automaticky při každém 30. záznamu? **ANO - implementováno**
2. Má být validace rust-tests povinná v CI/CD? **ANO - v pre-push hooku**
3. Má se Graphviz instalovat automaticky v CI? **ANO - přes ts-graphviz/setup-graphviz@v2**
4. Mají se externí knihovny (docs/spec-kit) validovat? **NE - vyloučeny z .gitignore**

---

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-16 | 1.9 | Sprint 9 dokončen - JSON Schema validace, audit log, konfigurovatelné cesty |
| 2026-02-16 | 1.8 | Sprint 8 dokončen - CI kroky implementovány (3 nové kroky) |
| 2026-02-16 | 1.7 | Přidány budoucí úkoly pro extrakci modulu |
| 2026-02-16 | 1.6 | Přidána cross-platform kompatibilita (Sprint 10), dokumentace pro Mac/Linux |
| 2026-02-16 | 1.5 | Kritická analýza provedena, identifikovány Sprint 8-9 |
| 2026-02-16 | 1.4 | Sprint 7 dokončen - 40/40 projektových souborů validováno, 345 externích vyloučeno |
| 2026-02-16 | 1.3 | Dokončen Sprint 6, částečně Sprint 7, přidána dokumentace metadat |
| 2026-02-16 | 1.2 | Opraven BOM, přidán portable Graphviz |
| 2026-02-15 | 1.1 | Dokončen Sprint 4-5, přidány CI/CD a Graphviz |
| 2026-02-15 | 1.0 | Vytvoření dokumentu |

---

*Vytvoreno: 2026-02-15 19:36 (UTC+1)*
