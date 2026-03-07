# Implementation Plan - aSTT-RUST Setup

**Cesta:** .specify\plan.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-14 11:43 (UTC+1)
**Posledni zmena:** 2026-02-17 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-14 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
## Goal Description
Initialize the **aSTT-RUST** project, a modular desktop application for real-time speech recognition and diarization tailored for physicians.
The application will use **Tauri** (Rust) for the desktop backend, a **Python 3.10 sidecar** for running the ASR module (WhisperX), and **Svelte (TypeScript)** for the high-performance UI. Node.js will be used solely for build tooling.

## User Review Required
> [!IMPORTANT]
> **Frontend Framework**: I am proposing **Svelte** + TypeScript for the UI because it is lighter and faster than React, which aligns with the "high performance" and "minimal resource/binary size" goals in the Constitution. Please confirm if you strictly prefer React.

> [!IMPORTANT]
> **Spec-Kit Compliance (The Nine Articles)**:
> 1. **Library-First (Art. I)**: The ASR (Python) and Core (Rust) logic MUST be developed as standalone libraries before integration into the Tauri shell.
> 2. **Test-First (Art. III)**: This project follows strict TDD. No implementation code will be written until unit/contract tests are approved and failing.
> 3. **CLI-First (Art. II)**: The Python sidecar must be a functional CLI tool independently of the GUI.

## Proposed Changes

### Project Root
#### [NEW] [.venv](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/.venv/)
- Local virtual environment for system-independent development and testing.

#### [NEW] [sandbox/portable_bench](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/sandbox/portable_bench/)
- **setup.ps1**: PowerShell script to download standalone Python, extract it, and install `whisperx` + `torch` (CPU optimized to save size).
- **run_demo.bat**: One-click script to run diarization on a sample file using `--device cpu`.
- **README.md**: Instructions for the user.

#### [NEW] [package.json](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/package.json)
- Setup for the monorepo-like structure (UI + Tauri).
- Dev scripts (`tauri dev`, `tauri build`).

#### [NEW] [Tauri Configuration](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/src-tauri/tauri.conf.json)
- Basic Tauri config with sidecar permissions allowed.

### Frontend (UI)
#### [NEW] [src-ui](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/src-ui/)
- Initialize a Vite + Svelte + TypeScript project.
- Basic layout shell.

### Backend (Rust)
#### [NEW] [src-tauri](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/src-tauri/)
- **main.rs**: Entry point.
- **lib.rs**: Module declarations.
- **Modules Structure**:
    - `asr`: Interface to Python sidecar.
    - `llm`: Interface for LLM (future).
    - `config`: Settings management.

### Sidecar (Python)
#### [NEW] [src-python](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/src-python/)
- **main.py**: Entry point for the sidecar.
- **requirements.txt**: Dependencies (whisperx, torch, etc.).
- **script**: Initial "hello world" or basic echo to verify Rust<->Python communication.

## Verification Plan

### Automated Tests (The "Red" Phase)
- **Article III Gate**: Before any feature code is written:
    - [ ] **Contract Tests**: Define expected JSON-RPC inputs/outputs in `src-tauri/tests/contracts.rs`.
    - [ ] **Python Unit Tests**: Write tests for the inference library in `src-python/tests/`.
    - [ ] **Verification**: Run `cargo test` and `pytest` to ensure they fail before implementation begins.

### Article IX: Integration-First Verification
- **Hardware Bench**: Use `sandbox/portable_bench/` to verify performance on CPU-only machines before committing to stable code.

### Manual Verification
1. **Sidecar Communication**:
    - Run `npm run tauri dev`.
    - **DX Requirement**: The Tauri dev lifecycle must manage the sidecar (no manual Python startup).
    - Trigger a command from UI -> Rust -> Python Sidecar (JSON-RPC).
    - Verify Python responds via structured JSON.
2. **Build**:
    - Run `npm run tauri build` to ensure the bundling logic works (might fail initially without strict sidecar binary setup, but we will test the *dev* flow first).
