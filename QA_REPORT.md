# QA & Quality Dashboard (Autonomous)

**Project**: aSTT-RUST | **Current Phase**: 0 (Portable Bench) | **Status**: âš ď¸Ź DEFICIENT

---

## đź“Š Project Status Dashboard

### đź“Ť Current Priority: Phase 0 (Portable Bench)
**Goal**: Standalone HW benchmark for physicians (CPU-only).

| Status | Task | Description |
| :--- | :--- | :--- |
| âś… **DONE** | Basic Inference | WhisperX running in simple venv. |
| đźźˇ **READY** | Mic/Audio | Implemented in `demo.py` via `sounddevice`. |
| đźźˇ **READY** | Portable Env | Updated `setup.ps1` and `run_demo.bat` for portable use. |
| đź”´ **PENDING** | Real Data | Need 2-3 participant medical samples. |

---

## đź—şď¸Ź Roadmap & Future Plans

### Phase 1: Core Prototype (Next)
- [ ] Rust-Python JSON-RPC bridge.
- [ ] Svelte UI Scaffolding (Clean Swiss Style).
- [ ] Sidecar lifecycle management.

### Phase 2-4: Future
- [ ] Diarization Sync.
- [ ] LLM Clinical Notes.
- [ ] Product Alpha.

---

## đź›ˇď¸Ź Watchdog Health

| Component | Status | Source of Truth |
| :--- | :--- | :--- |
| **GitHub CI** | âś… OK | [.github/workflows/ci.yml](./.github/workflows/ci.yml) - Fixed: removed broken Rust setup |
| **MegaLinter** | âś… OK | [.mega-linter.yml](./.mega-linter.yml) - Added config to fix DevSkim false positives |
| **Danger JS** | âś… OK | [Dangerfile.js](./Dangerfile.js) - Fixed: null check bug in diff.added |
| **Governance** | âś… OK | [GOVERNANCE.md](./GOVERNANCE.md) |
| **Documentation** | âś… OK | Fixed paths: tests/portable_bench â†’ sandbox/portable_bench |
| **Spec-Kit** | âś… OK | Added Nine Articles compliance in spec.md/plan.md |
| **Main Track** | âš ď¸Ź BLOCKED | Rust not installed locally; CI validates on push |
| **Sandbox Track**| đźźˇ DEFICIENT | Needs real audio samples from physicians |

---

## đź“‘ Automated Test Log
*(Most recent system health checks)*

- **2026-02-14**: Fixed GitHub CI workflows, MegaLinter config, Danger JS null bug, path references (testsâ†’sandbox).
- **2026-02-11**: Reorganized documentation for "Ralph Wiggum" clarity.
- **2026-02-10**: INITIAL Audit: Identified "Python Sidecar Illusion" as critical risk.

---

## âš ď¸Ź Action Items (Blockers)

> âšˇ **POZNĂMKA**: Po instalaci Rust se OKAMĹ˝ITÄš vrĂˇtit k testĹŻm (krok 2-3).

1. **Rust Installation**: Required for any Progress in Main Track (Track 1).
   - Typical install location: `C:\Users\adamf\.rustup` or `C:\Program Files\Rust`
   - **Po instalaci spustit**: `rustc --version` pro ovÄ›Ĺ™enĂ­
   - **PotĂ© pokraÄŤovat**: kroky 2-3 (napsat a spustit testy)
2. **Phase 0 Audio**: Must implement Mic/System audio capture in sandbox.








