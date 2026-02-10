# Implementation Plan - aSTT-RUST Setup

## Goal Description
Initialize the **aSTT-RUST** project, a modular desktop application for real-time speech recognition and diarization tailored for physicians.
The application will use **Tauri** (Rust) for the desktop backend, a **Python 3.10 sidecar** for running the ASR module (WhisperX), and **Svelte (TypeScript)** for the high-performance UI. Node.js will be used solely for build tooling.

## User Review Required
> [!IMPORTANT]
> **Frontend Framework**: I am proposing **Svelte** + TypeScript for the UI because it is lighter and faster than React, which aligns with the "high performance" and "minimal resource/binary size" goals in the Constitution. Please confirm if you strictly prefer React.

> [!IMPORTANT]
> **Priority Change**: The user prioritized a **CPU-only version** for standard office notebooks (4-5 years old) without NVIDIA GPUs.
> **Implication**: We must configure the "Portable Test Bench" to run on CPU. Performance will be lower, but it validates functionality.
> **Environment Strategy**: 
> 1. **Development**: Using a local virtual environment (`.venv`) created from system Python 3.11/3.13 for isolation and ease of development.
> 2. **Portable/QA**: Using a standalone, no-install Python build in `tests/portable_bench` for user-ready "no-install" verification.

## Proposed Changes

### Project Root
#### [NEW] [.venv](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/.venv/)
- Local virtual environment for system-independent development and testing.

#### [NEW] [tests/portable_bench](file:///c:/Users/adamf/OneDrive/Dokumenty/aSTT-RUST/tests/portable_bench/)
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

### Automated Tests
- **Rust Tests**: `cargo test` to verify module logic (once added).
- **UI Tests**: Basic render test (will add later).

### Manual Verification
1. **Sidecar Communication**:
    - Run `npm run tauri dev`.
    - Trigger a command from UI -> Rust -> Python Sidecar.
    - Verify Python responds (e.g., logs to console or returns string).
2. **Build**:
    - Run `npm run tauri build` to ensure the bundling logic works (might fail initially without strict sidecar binary setup, but we will test the *dev* flow first).
