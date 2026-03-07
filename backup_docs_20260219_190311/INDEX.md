# Project Documentation Index

**Cesta:** INDEX.md
**Verze:** 1.137
**Vytvoreno:** 2026-02-16 12:23 (UTC+1)
**Posledni zmena:** 2026-02-19 09:33 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-19 | 1.137 | Run on Save |
| 2026-02-19 | 1.2 | P0 refactoring indexu a sjednoceni aktualnich odkazu |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-16 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [x] Obsah dokumentu aktualizovan (P0)
- [ ] P1 refactoring navazujicich dokumentu

---

Tento soubor je hlavni rozcestnik ridici dokumentace projektu `aSTT-RUST`.

## Prioritni dokumenty

| Tema | Soubor |
|------|--------|
| Vize projektu | [VISION.md](./VISION.md) |
| Ustavni pravidla | [CONSTITUTION.md](./CONSTITUTION.md) |
| Sprava kvality a kontrol | [GOVERNANCE.md](./GOVERNANCE.md) |
| Architektura | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| Organizace dokumentace | [ORGANIZATION.md](./ORGANIZATION.md) |

## Automatizace dokumentace

| Oblast | Soubor |
|--------|--------|
| Provozni postup inventury a refactoringu | [docs/inventory-refactor-playbook.md](./docs/inventory-refactor-playbook.md) |
| Posledni inventura SW | [docs/software-inventory.md](./docs/software-inventory.md) |
| Metodika auditu SW | [docs/software-audit-method.md](./docs/software-audit-method.md) |
| Auditni script | `scripts/inventory_project_sw.ps1` |
| Denni scheduler (15:00) | `scripts/register_daily_audit_task.ps1` |

## CI a quality gate

| Kontrola | Soubor |
|----------|--------|
| Sjednoceny quality gate | [.github/workflows/quality-gate.yml](./.github/workflows/quality-gate.yml) |
| Supply-chain security | [.github/workflows/scorecard.yml](./.github/workflows/scorecard.yml) |
| Workflow guard | [.github/workflows/workflow-guard.yml](./.github/workflows/workflow-guard.yml) |

## Operacni minimum

1. Pred vetsi zmenou dokumentace spustit `scripts/inventory_project_sw.ps1`.
2. Overit, ze kriticke kontroly nejsou ve stavu FAIL.
3. Udelat zmenu dokumentace.
4. Spustit cilenou kontrolu markdownu pro menene soubory.

## Poznamka

- Tento index je P0 verze pro nizkotokenovy, rizeny refactoring.
- Dalsi kroky jsou zapsane v `NEXT_SESSION.md`.
