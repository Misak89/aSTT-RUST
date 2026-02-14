# Functional Specification: aSTT Core

## Overview
This specification defines the core functionality for the first iteration of the aSTT-RUST project: a real-time speech-to-text application with speaker diarization, running locally on desktop.

## User Stories

### 1. Physician Starts a Session
- **As a** physician
- **I want to** start the application and begin recording immediately
- **So that** I don't waste time configuring settings during a consultation.

### 2. Real-Time Transcription
- **As a** physician
- **I want to** see text appear on screen as I speak
- **So that** I can verify accuracy in real-time.

### 3. Speaker Identification (Diarization)
- **As a** physician
- **I want the application to** distinguish between me (Doctor) and the Patient
- **So that** the transcript clearly attributes speech to the correct person.

### 4. Export Transcript
- **As a** physician
- **I want to** copy the transcript to my clipboard or save as a file
- **So that** I can paste it into my EHR system.

## Functional Requirements

### 4. Sidecar Interface (IPC)
The Rust backend communicates with the Python sidecar via **JSON-RPC over Stdio**.
- **Payload**: Strict JSON structure (Pydantic <-> Serde).
- **Robustness**: Any non-JSON stdout from Python is treated as an internal log and ignored by the RPC parser to prevent crashes.

### FR-01: Initialization
- The app must launch within 5 seconds.
- The Python sidecar (WhisperX) must initialize in the background.
- UI must show "Ready" state once the backend is prepared.

### FR-02: Recording Control
- "Start Recording" button (prominent).
- "Stop Recording" button.
- Visual indicator of active recording (e.g., pulsing red dot).

### FR-03: Transcription Display
- Text must be appended to the main view.
- **Retroactive Diarization**: Speaker labels (e.g., "Speaker 0", "Speaker 1") will update retroactively (2-5s delay) once segment processing is complete.
- Timestamp for each segment start.

### FR-04: Configuration
- Option to select microphone input device.
- Option to toggle "Always on Top" for window.

### FR-05: Design System (Clean Swiss Style)
- **Aesthetic**: Clean Swiss Style (High Contrast Accessibility).
    - **Typography**: Sans-serif, bold hierarchy (e.g., Inter or Roboto).
    - **Palette**: Monochromatic with single accent color for active states (e.g., Medical Blue or Emergency Red for Recording).
    - **Layout**: Grid-based, generous whitespace to reduce cognitive load.
- **Behavior**: Distraction-free for clinical environments; no unnecessary animations.
- **Accessibility**: Support for high-contrast modes and screen readers.

## Non-Functional Requirements
- **Privacy**: No audio data leaves the local machine (Local-First).
- **Performance**: Latency between speech and text should be minimized (target < 3s for initial text).
- **Control & Observability**: Documentation must be machine-readable and synchronized by autonomous scripts.

## 7. Documentation & Control Requirements
- **FR_7.1**: The system must maintain a `project.json` in the root for machine discovery.
- **FR_7.2**: All documentation changes (health, logs) must be reflected in `QA_REPORT.md` via `scripts/update_docs.ps1`.
- **FR_7.3**: Research and sandbox activities must be isolated in `sandbox/`.
