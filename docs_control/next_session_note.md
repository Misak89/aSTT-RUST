# NEXT_SESSION note (narrative only)

Tato poznamka je pouze narativni doplnek k ridicim datam v `docs_control/next_session.json`.

Aktualni stav po Batch A + Batch B + claim=evidence guard (strict-clean pilot) +
post-ASR-coding freeze + workflow-control-plane D1-D6 baseline + Capability Audit gate:

- JSON-first / hybrid-strong `NEXT_SESSION` + traceability P0 minimum je zavedene,
- `mkdocs --strict` je green a markdownlint je rozdelen na blocking scope + backlog report,
- procesni diagram JSON-first control plane je doplnen v `docs/core/GOVERNANCE.md`,
- novy workflow control plane diagram system je zaveden
  (`docs_control/workflow_control_plane.json` + schema + coverage validator +
  observed manifests + alignment validator + generator/stale-check),
- Vale Batch B (critical + changed-file + backlog no-regression) je zaveden,
- claim=evidence guard je zaveden (`docs_control/task_status.json` + `scripts/preflight_state_discovery.ps1` + `scripts/verify_batch_status.ps1`),
- Capability Audit gate je zaveden (`docs_control/capability_audit.json` +
  `scripts/validate_capability_audit.ps1` + JSON evidence outputs do
  `logs/verify/toolchain_capabilities.json` a `logs/verify/capability_audit_summary.json`),
- capability audit je napojen do `verify_fast/CI` pred `preflight` a je vynucen take
  v `scripts/assert_preflight_write_guard.ps1`,
- pro claim=evidence batch je pilotne zapnut `require_clean_worktree_for_verified` + auto downgrade claimu pri dirty artefaktech,
- `cargo fmt` nad `src-tauri/*` je provedeno,
- Rust `clippy` chyby byly opraveny,
- byl opraven bug v `scripts/verify_stage.ps1` (PASS beh s prazdnym `ErrorsJson`),
- pilotni plny `verify_fast` na realnem projektu uz probehl do `PASS` a run se korektne zalogoval do `docs_control/verify_runs.json`,
- probehlo predcasne ASR kodovani (mimo dohodnute poradi) a stav je nyni zamerne zmrazen pred diagramem + zadanim,
- ASR MVP kod je funkcni v dev flow (UI -> Rust -> Python sidecar -> WhisperX),
  ale bundled sidecar `.exe` ma zatim packaging gap (placeholder rezim bez
  WhisperX bundlingu).

Fokus dalsiho postupu (bez dalsiho ASR kodovani):

- pouzit nove generated workflow control plane views jako canonical diagramovy podklad pro schvaleni procesu,
- udrzovat Capability Audit gate synchronni s workflow control plane diagram SSOT a traceability,
- uzamknout ASR zadani / scope (MVP vs mimo MVP),
- udelat reconcile audit predcasne napsaneho ASR kodu (ponechat / upravit / revertovat),
- teprve potom pokracovat v dalsim kodovani s aktivnim traceability/evidence flow.

Dulezity operacni bod:

- verify orchestrator, verify dashboard
  (`docs_control/verify_runs.json` -> `docs/generated/control/*`)
  uz existuji a slouzi jako referencni pattern pro dalsi control docs.

Tato poznamka nesmi obsahovat ridici metadata, stavy nebo checklisty.
Ty patri pouze do canonical JSON.
