# Session Report Standard

Ukladani pro analyzu/testovani tohoto projektu:

- adresar: `docs/plans/sessions/`
- jeden report = jeden coding blok
- povinny casovy rozsah: `od-do` v UTC

## Nazev souboru

Pouzij format:

`YYYY-MM-DD--HH-mm_to_HH-mm--tema.md`

Priklad:

`2026-03-02--14-10_to_15-25--determinism-workflow-fix.md`

## Minimalni obsah reportu

```md
# Session Report: <tema>

- coding_from_utc: YYYY-MM-DDTHH:mm:ssZ
- coding_to_utc: YYYY-MM-DDTHH:mm:ssZ
- scope: <co bylo v scope>
- branch: <vtev>
- commit: <sha nebo n/a>
- test_commands:
  - <prikaz 1>
  - <prikaz 2>
- result: PASS | FAIL
- evidence:
  - <artefakt/log/link>
```

## CI evidence

`Project Unified` workflow uklada automaticky run report artefakt:

- `project-unified-run-report-<run_id>-<run_attempt>`
- obsahuje `coding_from_utc` a `coding_to_utc`
- soubory: `project_unified_run_report.md`, `project_unified_run_report.json`
