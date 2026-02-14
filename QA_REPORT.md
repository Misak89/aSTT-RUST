# QA & Quality Dashboard (Autonomous)

**Project**: aSTT-RUST | **Current Phase**: 0 (Portable Bench) | **Status**: DEFICIENT

---

## Documentation Metrics (Auto-Generated)

| Metric | Value |
| :--- | :--- |
| **MD Files** | 42 |
| **Scripts** | 4 |
| **Workflows** | 5 |
| **Rust Tests** | 15 |

---

## System Health (Agent-Monitored)

| Component | Track | Status |
| :--- | :--- | :--- |
| **Backend (Rust)** | Main | MISSING |
| **Frontend (Node)** | Main | OK |
| **STT Sandbox (Python)** | Sandbox | OK |
| **Dev Environment** | Shared | OK |
| **Git** | Shared | OK |

---

## Project Status Dashboard

### Current Priority: Phase 0 (Portable Bench)
**Goal**: Standalone HW benchmark for physicians (CPU-only).

| Status | Task | Description |
| :--- | :--- | :--- |
| DONE | Basic Inference | WhisperX running in simple venv. |
| READY | Mic/Audio | Implemented in `demo.py` via `sounddevice`. |
| READY | Portable Env | Updated `setup.ps1` and `run_demo.bat` for portable use. |
| PENDING | Real Data | Need 2-3 participant medical samples. |

---

## Roadmap & Future Plans

### Phase 1: Core Prototype (Next)
- [ ] Rust-Python JSON-RPC bridge.
- [ ] Svelte UI Scaffolding (Clean Swiss Style).
- [ ] Sidecar lifecycle management.

### Phase 2-4: Future
- [ ] Diarization Sync.
- [ ] LLM Clinical Notes.
- [ ] Product Alpha.

---

## Watchdog Health

| Component | Status | Source of Truth |
| :--- | :--- | :--- |
| **GitHub CI** | OK | [.github/workflows/ci.yml](./.github/workflows/ci.yml) |
| **MegaLinter** | OK | [.mega-linter.yml](./.mega-linter.yml) |
| **Danger JS** | OK | [Dangerfile.js](./Dangerfile.js) |
| **Governance** | OK | [GOVERNANCE.md](./GOVERNANCE.md) |
| **Documentation** | OK | Fixed paths: tests/portable_bench to sandbox/portable_bench |
| **Spec-Kit** | OK | Added Nine Articles compliance in spec.md/plan.md |
| **Main Track** | BLOCKED | Rust not installed locally; CI validates on push |
| **Sandbox Track**| DEFICIENT | Needs real audio samples from physicians |

---

## Automated Test Log
*(Most recent system health checks)*

- **2026-02-14**: Added documentation automation scripts, pre-commit hooks, CI/CD workflows.
- **2026-02-14**: Fixed GitHub CI workflows, MegaLinter config, Danger JS null bug.
- **2026-02-11**: Reorganized documentation for clarity.
- **2026-02-10**: INITIAL Audit: Identified "Python Sidecar Illusion" as critical risk.

---

## Action Items (Blockers)

> **POZNAMKA**: Po instalaci Rust se OKAMZITE vratit k testum (krok 2-3).

1. **Rust Installation**: Required for any Progress in Main Track (Track 1).
   - Typical install location: `C:\Users\adamf\.rustup` or `C:\Program Files\Rust`
   - **Po instalaci spustit**: `rustc --version` pro overeni
   - **Pote pokracovat**: kroky 2-3 (napsat a spustit testy)
2. **Phase 0 Audio**: Must implement Mic/System audio capture in sandbox.

---

*Last Updated: 2026-02-14 18:29 (UTC+1)*
