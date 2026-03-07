# Project Governance

**Cesta:** GOVERNANCE.md
**Verze:** 1.145
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-02-19 09:35 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-19 | 1.145 | Run on Save |
| 2026-02-19 | 1.4 | P0 governance zkracena a sjednocena pro quality gate |
| 2026-02-19 | 1.3 | P0 refactoring governance |
| 2026-02-17 | 1.2 | Automaticka aktualizace |
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [x] P0 governance sjednocena s aktualnim procesem
- [ ] P1 doplneni detailnich pravidel pro vsechny adresare

---

Tento dokument urcuje pravidla kvality dokumentace, kodu a bezpecnosti.

## Ridici princip

- Dokumentace se meni jen v overenem kontextu.
- Kontext je: SW inventura + health check + audit kodu.

## Governance matrix

- Dokumentace:
  - nastroj: `markdownlint-cli2`
  - trigger: PR / Push
  - zdroj: `INDEX.md`, `GOVERNANCE.md`
- Odkazy v dokumentaci:
  - nastroj: `lychee`
  - trigger: PR / Push
  - zdroj: `docs/` + root `.md`
- Styl textu:
  - nastroj: `Vale`
  - trigger: PR / Push
  - zdroj: `.vale.ini`
- Kod Node:
  - nastroj: `npm check/test`
  - trigger: PR / Push
  - zdroj: `package.json`
- Kod Rust:
  - nastroj: `fmt/clippy/test`
  - trigger: PR / Push
  - zdroj: `src-tauri/Cargo.toml`
- SW inventura:
  - nastroj: `scripts/inventory_project_sw.ps1`
  - trigger: denne 15:00 + CI
  - zdroj: `docs/software-inventory.md`
- Security posture:
  - nastroj: `OSSF Scorecard`
  - trigger: schedule + push main
  - zdroj: `.github/workflows/scorecard.yml`

## Provozni pravidla

1. Pred refactoringem dokumentace spustit inventuru.
2. Pri kritickem FAIL nejdriv opravit infrastrukturu.
3. Zmeny ridicich dokumentu delat po davkach (P0 -> P1).
4. Po kazde davce aktualizovat `NEXT_SESSION.md`.

## Aktivni soubory procesu

- `docs/inventory-refactor-playbook.md`
- `docs/software-inventory.md`
- `docs/software-audit-method.md`
- `scripts/inventory_project_sw.ps1`
- `scripts/run_on_save_health_check.ps1`
- `.github/workflows/quality-gate.yml`
- `.github/workflows/scorecard.yml`

## Nastroje v procesu

- `markdownlint-cli2`
- `lychee`
- `Vale`
- `pre-commit` (lokalne lze pouzit `SKIP=vale`)
- `OSSF Scorecard`

## Poznamka

- Toto je P0 verze pro nizkotokenovy, rizeny refactoring.
- Detailni roadmapa je v `NEXT_SESSION.md`.
