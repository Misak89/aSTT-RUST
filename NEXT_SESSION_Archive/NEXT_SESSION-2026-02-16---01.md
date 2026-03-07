# NEXT_SESSION - Workflow Execution Guard Implementace

**Cesta:** NEXT_SESSION.md
**Verze:** 1.4
**Vytvoreno:** 2026-02-15 19:36 (UTC+1)
**Posledni zmena:** 2026-02-16 14:27 (UTC+1)
**Status:** VSECHNY SPRINTY DOKONCENY

## Stav

- [x] Metadata pridana
- [x] Sprint 1-7 dokonceny
- [x] Validace: 40/40 projektu souboru proslo
- [x] Externi soubory: 345 vylouceno (spec-kit: 38, python-embed: 24, venv-system: 29, node_modules: 249, config: 5)

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
| 2026-02-16 | 1.4 | Sprint 7 dokončen - 40/40 projektových souborů validováno, 345 externích vyloučeno |
| 2026-02-16 | 1.3 | Dokončen Sprint 6, částečně Sprint 7, přidána dokumentace metadat |
| 2026-02-16 | 1.2 | Opraven BOM, přidán portable Graphviz |
| 2026-02-15 | 1.1 | Dokončen Sprint 4-5, přidány CI/CD a Graphviz |
| 2026-02-15 | 1.0 | Vytvoření dokumentu |

---

*Vytvoreno: 2026-02-15 19:36 (UTC+1)*
