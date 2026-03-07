# Restart Context: Diagram System (JSON SSOT) 20260226_200041

## Co je hotové (diagram system)
- Nový diagramový systém běží na `docs_control/workflow_control_plane.json` (canonical SSOT).
- Diagramy se generují automaticky do `docs/generated/control/*` (`.mmd`, `.dot`, `.svg`, `.md`).
- Je zapojený `stale-check` a `alignment` proti realitě (`verify_stage`, CI, hooks).
- `Capability Audit gate` je blocking krok před `preflight` a je už dosynchronizovaný i do diagram SSOT.

## Co je automatické vs. neautomatické
- Automaticky:
  - `extract_*_manifest` -> `docs_control/observed_workflow/*.json`
  - generování diagramů/views ze SSOT
  - stale-check + alignment validace
- Neautomaticky (záměrně):
  - změny canonical SSOT `docs_control/workflow_control_plane.json`
  - tj. procesní záměr, grouping, barvy, legenda, popisky

## Hlavní soubory (diagram)
- SSOT: `docs_control/workflow_control_plane.json`
- Schema: `docs_control/workflow_control_plane.schema.json`
- Note (narativ): `docs_control/workflow_control_plane_note.md`
- Validator: `scripts/validate_workflow_control_plane.ps1`
- Alignment: `scripts/validate_workflow_control_alignment.ps1`
- Generator: `scripts/generate_workflow_control_diagrams.ps1`
- Observed manifests:
  - `docs_control/observed_workflow/verify_stage.json`
  - `docs_control/observed_workflow/ci_jobs.json`
  - `docs_control/observed_workflow/hooks.json`

## Kde uvidím diagram
- Full SVG: `docs/generated/control/workflow_control_plane.full.svg`
- Hlavní generated page: `docs/generated/control/WORKFLOW_CONTROL_PLANE.md`
- Focused view: `docs/generated/control/workflow_control_plane.verify_evidence_path.md`
- Web (MkDocs): `Workflow Control Plane`, `Workflow Verify+Evidence View`

## Stav toolingu (důležité)
- Graphviz `dot` je nainstalovaný (portable), ale nemusí být v `PATH`.
- Generator umí common-path lookup (portable Graphviz).
- Mermaid CLI (`mmdc`) je zatím **optional**.
- Capability audit má pin policy pro `mmdc`: `@mermaid-js/mermaid-cli@11.12.0` (zatím warning-only, ne blocking).

## Důležité procesní minimum (moje "základy", které musím držet)
- Tvrdé pořadí: `indexace/preflight -> rozhodnutí -> změna` (nikdy opačně).
- `Claim = evidence`: bez čerstvého důkazu netvrdit "hotovo".
- `unknown` je default stav, ne domněnka.
- Generated artefakty neupravovat ručně.
- Před write/generate běžet správnou sekvenci (hlídá `assert_preflight_write_guard`).

## Guard / gate soubory (kvůli disciplíně)
- `scripts/assert_preflight_write_guard.ps1`
- `scripts/preflight_state_discovery.ps1`
- `scripts/verify_batch_status.ps1`
- `scripts/validate_capability_audit.ps1`
- `scripts/verify_stage.ps1`
- `scripts/validate_workflow_alignment.ps1`

## Doporučený resume postup po restartu (bez kódování hned)
1. State discovery (jen audit):
   - `pwsh -File scripts/validate_workflow_control_alignment.ps1 -RefreshObserved`
   - `pwsh -File scripts/validate_capability_audit.ps1`
2. Preflight + claim/evidence:
   - `pwsh -File scripts/preflight_state_discovery.ps1`
   - `pwsh -File scripts/verify_batch_status.ps1`
3. Teprve potom práce na diagramu:
   - návrh dílčích view skupin
   - barvy podle domén
   - popisky "kde se loguje/testuje/validuje"
   - legenda

## Co je potřeba dodělat pro srozumitelný diagram (priorita)
1. Dílčí pohledy po skupinách/procesech (4-8 view)
2. Barevné rozlišení domén (validate/test/log/evidence/hooks/ci/generate/manual)
3. Legenda + explicitní popisky uzlů/hran (log/test/blocking/non-blocking)
4. Po ověření přidat odkazy do `mkdocs.yml` menu

## Návrh skupin (výchozí)
- Verify/Test flow
- Logging + Evidence
- Docs generation + stale-check
- Hooks + CI enforcement
- Traceability + NEXT_SESSION control
- Exceptions / backlog non-blocking

## Kde jsou čerstvé důkazy (evidence)
- Latest `verify_fast` PASS (docs-heavy smoke) je zalogovaný v `docs_control/verify_runs.json`
- `task_status` je dosynchronizovaný na latest PASS run
- Capability audit summary: `logs/verify/capability_audit_summary.json`
- Batch verifier summary: `logs/verify/batch_status_verify_summary.json`

## Poznámka pro další práci
- Uživatel výslovně chce nejdřív diagram/scope a až potom další kódování.
- Cíl teď: zlepšit čitelnost diagramů (ne rozšiřovat ASR kód).
