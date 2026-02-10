Document Name: Project Vision
Version: 0.1
Timestamp: 2026-02-09 Mon 16:33

# _aSTT Project Vision

## Purpose

Significantly increase efficiency with a **modular desktop application** (USB portable) for **real-time speech recognition** in **2–3 participant** conversations, targeting **physicians** on **Windows** and **macOS**.

The app transcribes speech in real time, identifies who said what (diarization), and allows LLM processing of the text either immediately or after review/editing, plus export to other systems.

---

## Target Audience

- **Physicians** (e.g. in the practice or during consultations)
- Users need: transcript with timestamps, speaker attribution, optional processing and editing (summaries, notes), and integration with existing platforms (EHR, other software)

---

## Architecture: Modules

### 1. ASR Module (WhisperX)

- **Source:** [WhisperX – Automatic Speech Recognition with Word-level Timestamps & Diarization](https://github.com/m-bain/whisperX)
- **Function:** speech recognition with word-level timestamps and **speaker identification** (who said what – diarization)
- Input: audio (microphone / file / online), output: transcript + speakers + timestamps

### 2. LLM Module

- Processes text from module 1 (transcript + diarization)
- **Local or various online** LLM backends
- Use cases: summaries, examination notes, suggested diagnoses, structured outputs for clinical documentation

### 3. Prompts, Dictionaries, Context Module (extensible)

- **Prompt** management for the LLM
- **Dictionaries** (domain terms, abbreviations)
- **Context** (templates, presets by examination type / specialty)
- Presets for LLM configuration
- Input layer for quality and relevance of module 2 outputs

### 4. API Management & Export Module

- **API connection management** to external platforms
- Export of transcripts and LLM outputs to other systems (EHR, storage, other tools)

### 5. Settings & User Management Module

- User accounts, profiles, preferences
- App settings (audio, models, API keys, default prompts)
- Security and privacy (local vs. cloud, data storage)
- Licensing
- Admin remote access and updates
- WhisperX tuning options

---

## Values

- **Privacy and Security**
- **Modularity** – modules can be developed and changed independently with clear interfaces
- **Physician usability** – fast transcription, minimal friction, emphasis on diarization and structured output
- **LLM flexibility** – choice of local vs. online model according to privacy and performance needs
- **Connectivity** – export and API for integration into existing workflow and platforms
- Development follows high-quality **VibeCoding**

---

## Horizon

1. **Functional demo** to validate Module 1 and 2 (core: ASR + diarization, basic online multi-LLM support). Optional time-limited trial.
2. **Long-term desktop product:** Incremental development of all modules, including advanced prompts, dictionaries, and API. Sandbox.

---

*This document is the basis for the project constitution (CONSTITUTION.md) and further specifications.*

Previous Versions:
- 0.0 — 2026-02-09 Mon 16:33 — Initial import (pre-versioned)
