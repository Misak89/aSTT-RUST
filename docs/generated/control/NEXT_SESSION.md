# NEXT_SESSION (Generated Control View)

Toto je generated view nad `docs_control/next_session.json` + `docs_control/next_session_note.md`.

**Cesta:** docs/generated/control/NEXT_SESSION.md
**Verze:** 5.8
**Vytvoreno:** 2026-02-15 19:36 (UTC+1)
**Posledni zmena:** 2026-02-26 18:58 (UTC+1)
**Status:** ROZPRACOVANE - workflow control plane D1-D6 + capability audit gate synced; ASR scope/zadani + reconcile stale P0 pred dalsim kodovanim
**Lifecycle state (control):** ROZPRACOVANE

## 0. Stav realizace

### Neprovedeno

- Implementace ASR modulu (Mic Capture + WhisperX integration)
- Uzamknout diagram + ASR zadani/scope a az pak pokracovat v implementaci (stav po predcasnem kodovani je zmrazen)

### Rozpracovane

- Migrace NEXT_SESSION z Markdown-first na JSON-first hybrid-strong
- Zavedeni traceability registru a integrity validatoru (P0 minimum)

### Provedeno

- Verify dashboard funguje jako canonical JSON (docs_control/verify_runs.json) -> generated docs views
- Jednotny verify orchestrator (verify_fast/verify_stage/verify_full) s fail-fast logikou je zaveden
- Batch A dokoncen: mkdocs --strict green + markdownlint blocking/backlog policy
- Procesni diagram JSON-first control plane doplnen v docs/core/GOVERNANCE.md
- Pilotni verify_fast na realnem projektu spusten; prvni blokujici FAIL je Vale prose lint (repo-wide)
- Vale Batch B: critical blocking + changed-file blocking + backlog report/no-regression baseline
- Verify orchestrator opraven pro npm.cmd (PowerShell npm.ps1 wrapper uz nedeformuje argumenty)
- Pilotni verify_fast po Vale Batch B dosel az na Rust fmt check (realny kodovy blocker)
- Claim=evidence guard zaveden: docs_control/task_status.json + preflight_state_discovery + verify_batch_status
  (napojeno do verify_fast/CI/governance)
- Pilotne zapnuto require_clean_worktree_for_verified pro claim=evidence batch + auto downgrade claimu pri dirty
  artefaktech
- cargo fmt provedeno, Vale backlog no-regression opraven a verify_fast se posunul z Rust fmt check na Rust clippy
- Opraven verify_stage logger pro PASS beh bez errors (empty ErrorsJson -> []), verify_fast PASS beh se korektne
  zaloguje
- Rust clippy chyby opraveny a plny verify_fast probehl do PASS vcetne zalogovani runu do docs_control/verify_runs.json
- Predcasne (procesne mimo poradi) doplnen ASR MVP kod: UI panel, Rust get/set config + dev python sidecar fallback,
  Python sidecar recording/config/error handling
- Po ASR kodovani znovu spusten verify_fast a PASS run zalogovan (vr-724c30a3a0774258bd88318d1b1b2b95); stav zmrazen
  pred diagramem/zadanim
- Novy diagramovy system workflow control plane: JSON SSOT + schema + coverage validator + observed manifests +
  alignment validator + generator/stale-check + napojeni do verify_fast/CI/MkDocs
- Capability Audit gate zaveden: docs_control/capability_audit.json + validate_capability_audit.ps1 + JSON evidence
  outputs + napojeni do verify_fast/CI + preflight write guard

### Poznamka

Ridici cast je v JSON. Markdown view se generuje a nesmi se rucne upravovat.

## 1. Aktualni kontext

JSON-first / hybrid-strong NEXT_SESSION + traceability P0 minimum jsou zavedene a verify_fast baseline byl overen. Po
predcasnem ASR kodovani (pred diagramem/scope) byl dodelan novy workflow control plane diagram system (JSON SSOT +
validace + alignment + stale-check + CI/verify integrace) a nyni take Capability Audit gate pro tvrzeni o externim SW
(zdrojove overeni + tool observation evidence + poradi pred preflightem). Dalsi krok je vratit se k procesu a uzamknout
ASR scope/zadani + udelat reconcile audit predcasneho kodu.

### Co je hotove

- JSON-first NEXT_SESSION + traceability validatory/generator + stale-check
- mkdocs build --strict green po oprave audit dashboard link generatoru
- markdownlint blocking scope (curated P0) + backlog report (non-blocking)
- Vale critical blocking + changed-file blocking + backlog report/no-regression baseline
- Claim=evidence guard: task_status registry + preflight state discovery + batch status verifier v verify_fast/CI
- Claim=evidence strict-clean pilot: require_clean_worktree_for_verified + auto downgrade pro guard batch (claim se
  snizi pri dirty artefaktech)
- Procesni diagram JSON-first control plane v docs/core/GOVERNANCE.md
- Verify orchestrator fix: npm.cmd misto npm.ps1 wrapperu pro Node check step
- cargo fmt provedeno nad src-tauri a verify_fast se posunul az na Rust clippy
- Rust clippy chyby opraveny a plny verify_fast PASS run je korektne zalogovan v docs_control/verify_runs.json
  (vr-efd18ac7747242a8983c62987b43c7d7)
- verify_stage logger bug opraven: PASS beh s prazdnym seznamem errors uz neposila prazdny argument -ErrorsJson
- ASR MVP kod doplnen: Svelte UI panel (init/config/record/transcribe), Rust Tauri get/set config commandy, Python
  sidecar recording/config/error handling
- Tauri sidecar spawn preferuje v dev rezimu python src-python/sidecar.py (realny WhisperX), fallback na bundled sidecar
- Workflow control plane diagram system baseline: docs_control/workflow_control_plane.json +
  validate_workflow_control_plane + validate_workflow_control_alignment + generate_workflow_control_diagrams (napojeno
  do verify_fast/CI)
- Capability Audit gate: docs_control/capability_audit.json + validate_capability_audit.ps1 +
  toolchain_capabilities/capability_audit_summary evidence + enforcement pred preflightem

### Kriticky aktualni problem

- Procesni chyba: ASR kodovani probehlo pred uzavrenym zadanim/scope; diagramovy system baseline je hotovy, ale dalsi
  kodovani ma byt zastaveno do uzamceni ASR scope + reconcile auditu
- verify_fast baseline je aktualne green; dalsi realny blocker vznikne az pri navazujici implementacni praci
- Bundled sidecar .exe uz neni dummy, ale v aktualnim PyInstaller baleni bezi bez WhisperX zavislosti v placeholder
  rezimu (produkcniparity gap)
- Mic recording v Python sidecar vyzaduje sounddevice + PortAudio; bez nich vraci explicitni error (spravne, ale je to
  deployment zavislost)
- Node check uz probehne, ale deprecation warningy v Svelte config zustavaji technicky dluh ke zvazeni
- Claim-evidence strict-clean pilot batch zustava IMPLEMENTED_UNVERIFIED, dokud jsou jeho artefakty lokalne dirty
  (zamerne chovani)

## 2. Dalsi kroky (control)

### Zmrazeni kodu respektovat a uzamknout ASR zadani/scope + reconcile pred dalsi implementaci [P0]

- Pouzit novy workflow control plane system (generated views + validators) jako canonical diagramovy podklad pro
  schvaleni procesu
- Uzamknout ASR MVP zadani/scope (co je MVP, co neni MVP, co z predcasneho kodu se ponecha)
- Udelat reconcile audit predcasne napsaneho ASR kodu proti schvalenemu diagramu a zadani

Akceptace:

- Diagramovy system / generated views jsou schvalene a odpovidaji realnemu verify/control flow
- ASR scope je explicitne schvaleny (MVP / mimo MVP / open questions)
- Je rozhodnuto co z predcasneho ASR kodu ponechat/upravit/revertovat pred dalsi implementaci

### Udrzovat workflow control plane diagram system synchronni s verify/CI/hooky [P0]

- Overit po kazde zmene gate, ze docs_control/workflow_control_plane.json + generated views stale sedi na
  verify_stage/CI/hooky
- Pouzivat validate_workflow_control_alignment + generate_workflow_control_diagrams -CheckOnly jako standardni drift
  guard

### Otestovat novy model na realnem projektu (navrat k hlavni praci) [P0]

- Po odmrznuti (diagram + scope) pokracovat v implementaci a po kazde vetsi zmene spustit verify_fast bez skipu
- Zapsat evidence a traceability vazby na realne tasky a testy
- Overit, ze docs zustavaji synchronni s kodem a CI take pri realne implementacni praci

## 3. Prvni konkretni krok pristi session

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate_workflow_control_plane.ps1 -RootPath .
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate_workflow_control_alignment.ps1 -RootPath . -RefreshObserved
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate_capability_audit.ps1 -RootPath .
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/generate_workflow_control_diagrams.ps1 -RootPath . -CheckOnly
```

- Uzamknout ASR zadani/scope a zapsat rozhodnuti o ponechani/uprave/revertu predcasneho kodu
- Teprve potom pokracovat v dalsim kodovani a zapsat novy verify run do NEXT_SESSION JSON

## Checkpoint (workflow alignment)

### Hook

- .pre-commit-config.yaml -> validate-workflow-alignment
- .pre-commit-config.yaml -> enforce-next-session-flow
- .pre-commit-config.yaml -> validate-workflow-alignment sleduje take task_status + claim/evidence guard skripty
- scripts/enforce_next_session_flow.ps1 -> validate_next_session.ps1 + generate_control_docs.ps1 -CheckOnly

### CI

- .github/workflows/ci.yml -> preflight_state_discovery.ps1
- .github/workflows/ci.yml -> validate_workflow_control_plane.ps1
- .github/workflows/ci.yml -> validate_workflow_control_alignment.ps1 -RefreshObserved
- .github/workflows/ci.yml -> validate_capability_audit.ps1
- .github/workflows/ci.yml -> generate_workflow_control_diagrams.ps1 -CheckOnly
- .github/workflows/ci.yml -> verify_batch_status.ps1
- .github/workflows/ci.yml -> validate_traceability.ps1
- .github/workflows/ci.yml -> validate_next_session.ps1
- .github/workflows/ci.yml -> generate_control_docs.ps1 -CheckOnly
- .github/workflows/quality-gate.yml -> validate_workflow_control_plane.ps1 + validate_workflow_control_alignment.ps1
  -RefreshObserved + validate_capability_audit.ps1 + generate_workflow_control_diagrams.ps1 -CheckOnly
- .github/workflows/quality-gate.yml -> preflight_state_discovery.ps1 + verify_batch_status.ps1 + stejne kontroly

### Docs

- docs/core/GOVERNANCE.md
- docs/generated/control/NEXT_SESSION.md
- docs/generated/control/TRACEABILITY_SUMMARY.md
- docs/generated/control/WORKFLOW_CONTROL_PLANE.md
- docs/generated/control/workflow_control_plane.verify_evidence_path.md

Poznamky:

- Generated NEXT_SESSION view obsahuje sekci 'Checkpoint (workflow alignment)' jako lidsky citelny checkpoint nad JSON
  daty.
- Markdown note (`docs_control/next_session_note.md`) nesmi obsahovat ridici checklists/stavy/metadata.

## Evidence policy

- IMPLEMENTED/HOTOVO vyzaduje: local_hook_pass
- IMPLEMENTED/HOTOVO vyzaduje: ci_pass
- IMPLEMENTED/HOTOVO vyzaduje: docs_sync_pass

## Evidence (current)

- `evidence.verify.fast.latest` | `PASS` | `verify_run` | docs_control/verify_runs.json
- `evidence.batch-status.verify.latest` | `PASS` | `batch_status_verify` | logs/verify/batch_status_verify_summary.json
- `evidence.capability-audit.latest` | `PASS` | `capability_audit` | logs/verify/capability_audit_summary.json

## Traceability refs (control IDs)

- `spec_ids`:
  - `spec.docs-control-json-first-p0`
- `plan_ids`:
  - `plan.deterministic-docs-automation-v0_5-draft`
- `task_ids`:
  - `task.next-session-json-first-hybrid-strong`
  - `task.traceability-p0-minimum`
  - `task.claim-evidence-guard-p0`
  - `task.capability-audit-gate-p0`
- `code_ref_ids`:
  - `code.scripts.validate_workflow_alignment`
  - `code.scripts.validate_capability_audit`
  - `code.scripts.assert_preflight_write_guard`
  - `code.scripts.preflight_state_discovery`
  - `code.scripts.verify_batch_status`
  - `code.scripts.validate_next_session`
  - `code.scripts.enforce_next_session_flow`
  - `code.scripts.generate_control_docs`
  - `code.scripts.validate_traceability`
  - `code.scripts.verify_stage`
- `test_ids`:
  - `test.verify.fast.stage`
  - `test.mkdocs.strict.build`
  - `test.batch_status.verify`
  - `test.capability_audit.validate`
- `doc_ids`:
  - `doc.control.next_session_json`
  - `doc.control.next_session_note`
  - `doc.generated.next_session_view`
  - `doc.control.traceability_json`
  - `doc.generated.traceability_summary`
  - `doc.control.task_status_json`
  - `doc.control.capability_audit_json`
- `log_ids`:
  - `log.verify_runs`
  - `log.capability_audit_summary`
- `evidence_ids`:
  - `evidence.verify.fast.latest`
  - `evidence.batch-status.verify.latest`
  - `evidence.capability-audit.latest`

## Narativni poznamka (manual, non-control)

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

## Source of Truth

- Canonical control data: `docs_control/next_session.json`
- Canonical schema: `docs_control/next_session.schema.json`
- Narrative note (manual): `docs_control/next_session_note.md`
- This file is generated. Manual edits are forbidden.
