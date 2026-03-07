# Implementacni specifikace: Workflow Execution Guard v2.01

**Cesta:** plans\workflow_execution_guard_spec_v2.01.md
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
## Souhrn pro prechod do noveho vlakna

---

## 1. Kontext

**Puvodni pozadavek:** Najit a nacist implementacni specifikaci Workflow Execution Guard a krok za krokem ji prodiskutovat.

**Rozhodnuti:** Po analyze existujicich nastroju (Husky, Danger.js, Mega-Linter) byl vybran **kombinovany pristup**:
- **Husky + pre-commit** pro lokalni kontrolu
- **Danger.js** pro CI/CD kontrolu

---

## 2. Architektura

```
LOKALNE U VYVOJARE:
git commit -> Husky -> pre-commit -> WORKFLOW GUARD -> PASS/FAIL

V CI/CD (GitHub Actions):
PR created -> Danger.js -> WORKFLOW GUARD -> PASS/BLOCK
```

---

## 3. Soubory k vytvoreni

| # | Soubor | Popis |
|---|--------|-------|
| 1 | `.pre-commit-config.yaml` | Konfigurace pre-commit hooku |
| 2 | `scripts/workflow_guard.py` | Hlavni kontrolni skript (Python) |
| 3 | `config/workflow-steps.json` | Definice povinnych kroku |
| 4 | `config/workflow-schema.json` | JSON Schema validace |
| 5 | `.github/workflows/workflow-guard.yml` | CI/CD workflow |
| 6 | `Dangerfile.js` (uprava) | Rozsireni o workflow kontroly |

---

## 4. Klicove vlastnosti

### Lokalni kontrola
- Spousti se **pred** `git commit`
- **Blokuje** commit pri selhani
- Kontrola: dokumentace, workflow kroky, schema validace

### CI/CD kontrola
- Spousti se pri **PR**
- **Blokuje** merge pri selhani
- Rozsirene kontroly + PR specificka

### Konfigurace
- JSON definice povinnych kroku
- JSON Schema validace
- Povinne/volitelne kroky
- Timeouty

---

## 5. Implementacni poradi

1. Vytvorit `config/` adresar a schema
2. Vytvorit `scripts/workflow_guard.py`
3. Vytvorit `.pre-commit-config.yaml`
4. Nainstalovat pre-commit (`pip install pre-commit && pre-commit install`)
5. Vytvorit `.github/workflows/workflow-guard.yml`
6. Upravit `Dangerfile.js`
7. Integrovat s Husky (`.husky/pre-commit`)

---

## 6. Verifikacni kriteria

- [ ] Lokalni kontrola se spousti pri `git commit`
- [ ] Commit je zablokovan pri zmene kodu bez dokumentace
- [ ] Schema validace funguje
- [ ] CI/CD kontrola se spousti pri PR
- [ ] Logovani do `logs/workflow-guard.log`

---

## 7. Rollback plan

```bash
# Odstraneni pre-commit
pre-commit uninstall
rm .pre-commit-config.yaml

# Odstraneni workflow guard
rm scripts/workflow_guard.py
rm -rf config/

# Obnova Dangerfile.js z git
git checkout HEAD -- Dangerfile.js
```

---

## 8. Dalsi kroky

1. Prepnout do **Code mode**
2. Vytvorit soubory dle specifikace
3. Otestovat lokalne
4. Vytvorit PR a otestovat CI/CD

---

## 9. Relevantni soubory

- [`plans/workflow_execution_guard_spec_v2.md`](plans/workflow_execution_guard_spec_v2.md) - Plna specifikace
- [`plans/workflow_guard_options_analysis.md`](plans/workflow_guard_options_analysis.md) - Analyza moznosti
- [`Dangerfile.js`](Dangerfile.js) - Existujici Danger.js konfigurace
- [`.husky/`](.husky/) - Existujici Husky konfigurace

---

*Vytvoreno: 2026-02-15 06:18 (UTC+1)*
*Verze: 2.01*
*Status: Pripraveno k implementaci*
*Last Updated: 2026-02-15 06:18 (UTC+1)*