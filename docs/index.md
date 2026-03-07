# Project Documentation Index

**Cesta:** docs/index.md
**Verze:** 1.3
**Vytvoreno:** 2026-02-16 12:23 (UTC+1)
**Posledni zmena:** 2026-02-28 16:42 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
| :--- | :--- | :--- |
| 2026-02-28 | 1.3 | Doplneny determinism + clean clone smoke workflow a odkaz na required-check branch protection pravidla |
| 2026-02-19 | 1.2 | Refaktoring pro SSOT a oprava navigace MkDocs |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-16 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [x] Obsah dokumentu aktualizovan
- [x] Navigace MkDocs opravena

---

Tento soubor je hlavni rozcestnik ridici dokumentace projektu `aSTT-RUST`.

## Prioritni dokumenty

| Tema | Soubor |
| :--- | :--- |
| Vize projektu | [VISION.md](./core/VISION.md) |
| Ustavni pravidla | [CONSTITUTION.md](./core/CONSTITUTION.md) |
| Sprava kvality a kontrol | [GOVERNANCE.md](./core/GOVERNANCE.md) |
| Architektura | [ARCHITECTURE.md](./core/ARCHITECTURE.md) |
| Organizace dokumentace | [ORGANIZATION.md](./core/ORGANIZATION.md) |

## 📖 Řídící dokumentace (Spec-Kit)

| Oblast | Soubor / Odkaz |
| :--- | :--- |
| **Spec-Kit Core** | [README.md (Spec-Kit)](./spec-kit/README.md) |
| **Metodika** | [Spec-Driven Development](./spec-kit/spec-driven.md) |
| **Plány** | [Aktuální implementační plány](./plans/2026-02-19-refactor-batch-c.md) |
| **Session reporty (od-do)** | [Standard ukladani + naming](./plans/sessions/README.md) |
| **Změnový deník** | [Spec-Kit CHANGELOG](./spec-kit/CHANGELOG.md) |

## Automatizace dokumentace

| Oblast | Soubor |
| :--- | :--- |
| Provozni postup inventury | [docs/inventory-refactor-playbook.md](./inventory-refactor-playbook.md) |
| Posledni inventura SW | [docs/software-inventory.md](./software-inventory.md) |
| Metodika auditu SW | [docs/software-audit-method.md](./software-audit-method.md) |
| Auditni script | `scripts/inventory_project_sw.ps1` |
| Denni scheduler (15:00) | `scripts/register_daily_audit_task.ps1` |

## CI a quality gate

| Kontrola | Soubor |
| :--- | :--- |
| Jednotny orchestrator (repo + sandbox) | `.github/workflows/project-unified.yml` |
| Zakladni CI testy | `.github/workflows/ci.yml` |
| Sjednoceny quality gate | `.github/workflows/quality-gate.yml` |
| Determinism gate (matrix + hash snapshot) | `.github/workflows/determinism.yml` |
| Clean clone smoke (CI-like fresh clone) | `.github/workflows/clean-clone-smoke.yml` |
| Supply chain security | `.github/workflows/scorecard.yml` |
| Workflow guard | `.github/workflows/workflow-guard.yml` |

Required-check branch protection checklist je v [docs/core/GOVERNANCE.md](./core/GOVERNANCE.md) v sekci
`Branch protection (required checks)`.

## Operacni minimum

1. Pred vetsi zmenou dokumentace spustit `scripts/inventory_project_sw.ps1`.
2. Overit, ze kriticke kontroly nejsou ve stavu FAIL.
3. Udelat zmenu dokumentace.
4. Spustit cilenou kontrolu markdownu pro menene soubory.

## Poznamka

- Tento index je P0 verze pro nizkotokenovy, rizeny refactoring.
- Dalsi kroky jsou zapsane v generated view `docs/generated/control/NEXT_SESSION.md`
  (ridici data jsou v `docs_control/next_session.json`).
