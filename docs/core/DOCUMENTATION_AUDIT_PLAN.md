# Documentation Audit Plan

**Cesta:** docs/core/DOCUMENTATION_AUDIT_PLAN.md
**Verze:** 1.0
**Vytvoreno:** 2026-02-21 00:00 (UTC+1)
**Posledni zmena:** 2026-02-21 00:00 (UTC+1)
**Status:** AKTIVNI

## Cile

- Udelat maximalne deterministicky audit dokumentace.
- Drzet vazby `docs <-> scripts <-> hooks <-> CI` bez driftu.
- Vysledky vest jako checklist (done/blocked + duvod).

## Referencni ramec (overene zdroje)

- MkDocs CLI (`serve`, default lokalni server): https://www.mkdocs.org/user-guide/cli/
- MkDocs Getting Started (`http://127.0.0.1:8000/`): https://www.mkdocs.org/getting-started/
- Diataxis framework (struktura dokumentace): https://diataxis.fr/
- Docs as Code (GitLab docs workflow): https://docs.gitlab.com/development/documentation/
- Spec-Driven Development (projektovy standard): `docs/spec-kit/spec-driven.md`
- Superpowers workflow (evidence over claims): `tools/superpowers/README.md`

## Deterministicky postup

### Faze 1 - Baseline a pravidla

- [x] Nacist referencni metodiky.
- [x] Potvrdit, ze docs server je MkDocs (ne custom script).
- [x] Potvrdit, co je runtime (`mkdocs serve`) vs pomocne skripty.

### Faze 2 - Technicky audit

- [x] Overit dostupnost `http://127.0.0.1:8000/`.
- [x] Overit instalaci MkDocs v `.venv`.
- [x] Overit `mkdocs.yml` nav -> existence vsech souboru.
- [x] Overit governance enforcement (`hooks + CI + docs`).

### Faze 3 - Logika, vazby, podrizenost

- [x] Overit hierarchii: `CONSTITUTION -> GOVERNANCE -> ARCHITECTURE -> NEXT_SESSION`.
- [x] Overit stavovou logiku `PLANNED -> IMPLEMENTED` s dukazem PASS.
- [x] Overit canonical odkazy pro SSOT.

### Faze 4 - Nalezy a opravy

- [x] Opravit rozbity format `help.md`.
- [x] Sjednotit `INDEX/index` odkaz v `README.md`.
- [x] Sjednotit `INDEX/index` odkaz v `docs/core/GOVERNANCE.md`.
- [ ] Sjednotit historicke odkazy `INDEX.md` v auditnich historickych zaznamech.
  - Duvod: historicky log ma byt immutable; nutne rozhodnuti, zda migrovat historii.

### Faze 5 - Zaverecne overeni

- [ ] Spustit lokalni full quality gate (`pre-commit run --all-files`).
  - Duvod: v teto session nebylo pozadovano spoustet cely gate nad celym repem.
- [ ] Potvrdit PASS v CI po push.
  - Duvod: CI nelze potvrdit bez vzdaleneho behu po push.

## Aktualni nalezy (P0/P1/P2)

### P0

- `help.md` mel poskozeny markdown format (escapovane znaky) -> opraveno.
- `README.md` mel odkaz na `docs/core/INDEX.md` (case mismatch) -> opraveno.
- `docs/core/GOVERNANCE.md` mel odkaz na `docs/core/INDEX.md` -> opraveno.

### P1

- Dokumentacni portal ted nebezi (`127.0.0.1:8000` refused), i kdyz MkDocs je nainstalovan.
- Duplicitni governance kontroly v `ci.yml` a `quality-gate.yml` jsou funkcni, ale zvysuji dobu CI.

### P2

- Historicke logy obsahuji odkazy na starsi nazvy (`INDEX.md`) a historicke cesty.

## Odchylky od planu

- Pri predchozim pokusu o rychlou upravu doslo k rozbiti formatu `help.md`.
- Odchylka byla opravena v ramci Faze 4 a zanesena jako P0 incident.
