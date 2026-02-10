# System Architecture: aSTT Core

## 1. Overview
aSTT is a modular desktop application designed for real-time speech transcription and diarization, primarily for physicians. It leverages a high-performance Rust backend (Tauri), a Python sidecar for ML inference (WhisperX), and a modern web frontend.

## High-Level Diagram

```mermaid
graph TD
    User[Physician] --> UI[Frontend UI (Svelte)]
    UI -- Commands --> Rust[Tauri Core (Rust)]
    Rust -- Manages --> Py[Python Sidecar]
    Py -- Inference --> Whisper[WhisperX]
    Controller[Autonomous Doc Controller] -- Updates --> Documentation
    Documentation -- Guides --> Agent[LLM/Dev Agent]
```

## Track Segmentation (Machine-Readable)
The project is architected as two parallel tracks defined in `project.json`:

1.  **Main Track (Production)**: `src-ui/`, `src-tauri/`, `src-python/`. Focused on stability and deployment.
2.  **Sandbox Track (Research)**: `sandbox/portable_bench/`. Focused on HW validation and benchmarking.

## Modules (Per Constitution)

### 1. ASR Module (Python Sidecar)
- **Responsibility**: Audio ingestion, speech-to-text, speaker diarization.
- **Technology**: Python 3.10, WhisperX, PyTorch.
- **Communication**: Standard Input/Output (stdio) or local WebSocket with the Rust core.
- **Key Interface**: `transcribe(audio_path) -> JSON`, `stream_audio(chunk) -> JSON`.

### 2. LLM Module (Rust/Python Hybrid)
- **Responsibility**: Processing transcripts for summaries, notes, and structured data.
- **Technology**: 
    - **Local**: `llama.cpp` (managed by Rust or Python sidecar).
    - **Cloud**: OpenAI-compatible REST API client (Rust).
- **Interface**: `process_text(text, prompt_template) -> text`.

### 3. Context Module (Rust)
- **Responsibility**: Managing prompts, medical dictionaries, and user context.
- **Storage**: Local JSON/SQLite database.
- **Interface**: `get_prompt(scenario_id)`, `get_dictionary(specialty)`.

### 4. API & Export Module (Rust)
- **Responsibility**: Securely sending data to external systems.
- **Features**: Retry logic, authentication management (secure storage), extensive logging.
- **Interface**: `export_to_ehr(data)`, `sync_to_cloud(data)`.

### 5. Settings & User Module (Rust/UI)
- **Responsibility**: Configuration management, user profiles, licensing.
- **Storage**: Encrypted local config file.
- **Interface**: `load_settings()`, `save_settings()`.

## Project Segmentation
The project is divided into two distinct tracks to ensure stability while allowing for aggressive hardware testing:

### 1. Main Application (Production Track)
*   **Goal**: Full-featured desktop software for physicians.
*   **Status**: Scaffolding complete; blocked on Rust installation.
*   **Location**: `src-ui/`, `src-tauri/`, `src-python/`.

### 2. STT Benchmark Prototype (Research Track)
*   **Goal**: Validate WhisperX performance on varying hardware (4-5 year old CPUs) and 2-3 participants.
*   **Status**: Functional; used for "Portable USB" testing.
*   **Location**: `tests/portable_bench/` (acts as our **Sandbox/Research** area).

## Directory Structure
```text
aSTT-RUST/
├── Document/                # Shared Documentation (Spec-Kit)
├── src-tauri/               # [TRACK 1] Rust Backend
├── src-ui/                  # [TRACK 1] Svelte Frontend
├── src-python/              # [TRACK 1] Python Sidecar (Production)
├── tests/
│   └── portable_bench/      # [TRACK 2] HW Prototype & Sandbox
├── .venv/                   # Development virtual environment
└── package.json             # Root build orchestration
```

## 2. Track Separation
- **Track 1 (Main SW)**: Production-ready code in `src-*`.
- **Track 2 (Sandbox)**: Research and prototypes in `sandbox/`.

## Development Timeline (Milestones)

| Phase | Milestone | Goal | Status |
| :--- | :--- | :--- | :--- |
| **0** | **Portable Bench** | Validate WhisperX on CPU-only office notebooks | **DONE** |
| **1** | **Prototype (Core)** | Rust-Python bridge, basic UI, "Start/Stop" transcription | *IN PROGRESS* |
| **2** | **Diarization Sync** | Integrating speaker labels into the real-time UI | *PLANNED* |
| **3** | **LLM Integration** | Summary generation (Doctor's Notes) from transcript | *PLANNED* |
| **4** | **Alpha Release** | Portable USB-ready build for physician feedback | *PLANNED* |

## Future Architecture: Mobile (Addendum)

### Strategy: Hybrid or Server-Side
Migrating the current Desktop architecture (Python Sidecar) to mobile is **not directly possible** due to OS sandboxing and resource constraints.

#### Option A: Server-Side Processing (Recommended for MVP)
- **Mobile App**: Lightweight UI (Tauri Mobile or React Native).
- **Backend**: The Desktop app's Python sidecar moves to a cloud API (FastAPI/GPU Server).
- **Flow**: App records audio -> Uploads to Server -> Server returns JSON.

#### Option B: On-Device (Advanced)
- **Engine Replacement**: Python/WhisperX must be replaced by **C++** libraries (`whisper.cpp` or `mlx` for iOS).
- **Integration**:
    - **iOS**: Swift bindings to CoreML/Metal.
    - **Android**: JNI bindings to TFLite/NCNN.
- **Tauri Mobile**: Can still be used for UI, but the "backend" logic moves from Python sidecar to Rust plugin wrapping the C++ libraries.

## Documentation Control
The documentation is managed by an **Autonomous Documentation Controller** (`scripts/update_docs.ps1`).

- **Verification**: Checks path integrity and cross-references.
- **Reporting**: Updates `QA_REPORT.md` with system health and test metrics.
- **Versioning**: Enforces semantic versioning of specs for LLM synchronization.
- **Automation**: Runs sandbox benchmarks and captures machine-readable logs.
