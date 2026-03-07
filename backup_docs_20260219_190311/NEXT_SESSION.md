# NEXT_SESSION - Documentation Audit & Refactoring

**Cesta:** NEXT_SESSION.md
**Verze:** 3.4
**Vytvoreno:** 2026-02-15 19:36 (UTC+1)
**Posledni zmena:** 2026-02-19 10:31 (UTC+1)
**Status:** AKTIVNI - sjednoceny quality gate zaveden, refactoring dokumentace rozpracovan

## Stav

- [x] Denni software inventura nastavena (Scheduler 15:00)
- [x] Auditni script `scripts/inventory_project_sw.ps1` vylepsen (kriticke kontroly + CI mod)
- [x] Zaveden CI workflow `docs + code + security` (`.github/workflows/quality-gate.yml`)
- [x] Zapojeny nastroje: markdownlint-cli2, lychee, Vale (v CI), OSSF Scorecard
- [x] Zapsan provozni postup do `docs/inventory-refactor-playbook.md`
- [x] Zapsan odkaz do ridici dokumentace (`INDEX.md`, `GOVERNANCE.md`)
- [ ] Lokalni pre-commit quality gate stabilizovat (Husky + hooksPath + sitova omezeni)
- [ ] Postupny refactoring Markdown chyb podle priorit

---

## 1. Aktualni kontext

Projekt ma zavedenou automatizaci inventury, ale dokumentace je stale ve velkem technickem dluhu.

### Co je hotove
- `scripts/register_daily_audit_task.ps1` registroval denni audit v 15:00.
- `scripts/inventory_project_sw.ps1` generuje:
  - `docs/software-inventory.md`
  - `logs/software-inventory.json`
  - `logs/software-audit-last.txt`
  - `docs/software-audit-method.md`
- CI quality gate je pripraven (`quality-gate.yml`) a obsahuje docs lint, link audit, code checks a software inventory.
- Security workflow `scorecard.yml` je pridany.
- Konfigurace pridany:
  - `.pre-commit-config.yaml`
  - `.vale.ini`

### Kriticky aktualni problem
- Lokalni `pre-commit run --all-files` selhava:
  - `vale` nelze lokálně nainstalovat kvuli blokaci pristupu na `proxy.golang.org`.
  - `markdownlint-cli2` hlasi stovky chyb v `.md` souborech.
  - `lychee` byl puvodne vadny rev, opraven na `v0.15.1`.

---

## 2. Dalsi plan (vykonavaci)

### Faze A - Stabilizace local quality gate (P0)
1. Propojit pre-commit s Husky (`core.hooksPath` respektovat, neobchazet).
2. Nastavit lokalni fallback: pri lokalnim behu `SKIP=vale`, ale v CI ponechat Vale povinne.
3. Dodat kratky check script `scripts/check-local-quality-gate.ps1` (PASS/FAIL + duvod).

Akceptace:
- Lokalni check bezi konzistentne bez manualniho hackovani.
- CI zustava prisnejsi nez lokal.

### Faze B - Refactoring ridici dokumentace (P0)
1. Opravit nejdriv: `INDEX.md`, `GOVERNANCE.md`, `CONSTITUTION.md`, `NEXT_SESSION.md`.
2. Sjednotit metadata, historii verzi a sekce bez duplicit.
3. Opravit nejkritictejsi markdownlint pravidla:
- `MD022`, `MD024`, `MD032`, `MD013`, `MD031`, `MD040`.

Akceptace:
- Ridici dokumenty bez kritickych lint chyb.
- Konzistentni struktura + aktualni odkazy.

### Faze C - Refactoring zbytku dokumentace (P1)
1. Batch opravy po adresarich: root docs -> plans -> sandbox docs.
2. Omezit scope lintu pro externi/archivni dokumenty, ktere nejsou aktivni ridici dokumentace.
3. Po kazde batchi spustit inventory + pre-commit + CI.

Akceptace:
- Pocet lint chyb klesa po batchich, ne chaoticky.
- Neni regresni narust chyb mezi batchi.

### Faze D - Kontrolovany provoz (P1)
1. Tydne kontrolovat `logs/software-audit-last.txt`.
2. Pri failu audit checku zastavit refactoring a nejdriv opravit infrastrukturu.

Akceptace:
- Dokumentace se meni jen v overenem kontextu (audit + code check).

---

## 3. Prvni konkretni krok pristi session

Spustit tuto sekvenci a ulozit vysledek do logu:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/inventory_project_sw.ps1
$env:SKIP='vale'; .\.venv\Scripts\python.exe -m pre_commit run --all-files
```

Pak otevrit report a zacit opravou `INDEX.md` + `GOVERNANCE.md`.

---

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-19 | 3.4 | Run on Save |
| 2026-02-19 | 3.3 | Run on Save |
| 2026-02-19 | 3.2 | Run on Save |
| 2026-02-19 | 3.1 | Run on Save |
| 2026-02-19 | 3.0 | Prepsan dokument na aktualni kontext inventury, quality gate a plan refactoringu |
| 2026-02-17 | 2.5 | Sprint 12 dokoncen - automaticka aktualizace metadat |
| 2026-02-15 | 1.0 | Vytvoreni dokumentu |

## Session Checkpoint 2026-02-19 09:33 (UTC+1)

- Dokoncena P0 davka #1: `INDEX.md` + `GOVERNANCE.md`.
- Oba soubory prosly cilenym lintem:
  - `pre_commit run markdownlint-cli2 --files INDEX.md GOVERNANCE.md`
- Quality gate lokalne stale selhava na zbytku repozitare (ocekavano).
- Dalsi krok P0: refactoring `CONSTITUTION.md` + `VISION.md` stejnym postupem.

## Session Checkpoint 2026-02-19 09:39 (UTC+1) - P0 davka #2

- Dokoncena P0 davka #2: `CONSTITUTION.md` + `VISION.md`.
- Oba soubory prosly cilenym lintem:
  - `pre_commit run markdownlint-cli2 --files CONSTITUTION.md VISION.md`
- P0 ridici dokumenty jsou nyni sjednocene:
  - `INDEX.md`, `GOVERNANCE.md`, `CONSTITUTION.md`, `VISION.md`.
- Dalsi krok: P1 davka pro `ARCHITECTURE.md` + `ORGANIZATION.md`.

