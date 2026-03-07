# Verify Status (Generated)

Toto je generated view nad docs_control/verify_runs.json.

- Canonical source of truth: docs_control/verify_runs.json
- Render target: docs/generated/control/VERIFY_STATUS.md
- Rezim razeni: posledni zaznam po (scope, stage) (DESC podle casu)

## Summary

- Total runs: 23
- PASS: 8
- FAIL: 15
- SKIP: 0

## Latest Status By Scope + Stage

| Scope | Stage | Result | Timestamp (UTC) | Errors | Root cause | Task ID | Commit |
| :--- | :--- | :--- | :--- | ---: | :--- | :--- | :--- |
| repo | fast | PASS | 2026-02-26T18:45:55.402Z | 0 | - | verify-fast-20260226T184526Z | 2ef8b818874d |

## Notes

- Tato stranka je pouze view vrstva.
- Realne PASS/FAIL vysledky se maji zapisovat do canonical JSON a teprve potom renderovat do MkDocs.
