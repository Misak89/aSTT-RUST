# QA & Quality Dashboard (Autonomous)

**Project**: aSTT-RUST | **Current Phase**: 0 (Portable Bench) | **Status**: ⚠️ DEFICIENT

---

## 📊 Project Status Dashboard

### 📍 Current Priority: Phase 0 (Portable Bench)
**Goal**: Standalone HW benchmark for physicians (CPU-only).

| Status | Task | Description |
| :--- | :--- | :--- |
| ✅ **DONE** | Basic Inference | WhisperX running in simple venv. |
| 🟡 **READY** | Mic/Audio | Implemented in `demo.py` via `sounddevice`. |
| 🟡 **READY** | Portable Env | Updated `setup.ps1` and `run_demo.bat` for portable use. |
| 🔴 **PENDING** | Real Data | Need 2-3 participant medical samples. |

---

## 🗺️ Roadmap & Future Plans

### Phase 1: Core Prototype (Next)
- [ ] Rust-Python JSON-RPC bridge.
- [ ] Svelte UI Scaffolding (Clean Swiss Style).
- [ ] Sidecar lifecycle management.

### Phase 2-4: Future
- [ ] Diarization Sync.
- [ ] LLM Clinical Notes.
- [ ] Product Alpha.

---

## 🛡️ Watchdog Health

| Component | Status | Source of Truth |
| :--- | :--- | :--- |
| **Governance** | ✅ OK | [GOVERNANCE.md](./GOVERNANCE.md) |
| **Review Tool** | ✅ OK | [.agent/workflows/review.md](./.agent/workflows/review.md) |
| **Main Track** | ❌ MISSING | Blocked by Rust Install |
| **Sandbox Track**| ⚠️ DEFICIENT | Needs Mic/Portable fix |

---

## 📑 Automated Test Log
*(Most recent system health checks)*

- **2026-02-11**: Reorganized documentation for "Ralph Wiggum" clarity.
- **2026-02-10**: INITIAL Audit: Identified "Python Sidecar Illusion" as critical risk.

---

## ⚠️ Action Items (Blockers)
1. **Rust Installation**: Required for any Progress in Main Track (Track 1).
2. **Phase 0 Audio**: Must implement Mic/System audio capture in sandbox.



