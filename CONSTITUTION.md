Project Constitution
Version: 0.1
Timestamp: 2026-02-09 Mon 11:53

# _aSTT Project Constitution

The constitution defines the principles and rules for _aSTT development. All specifications, plans, and implementations should align with these principles.

---

## 1. User Focus (Physicians)

- First and most important is security, privacy, and reliability, followed by user comfort! This always come first!
- The user interface and workflows must be designed for **clinical use**: quick start-up, minimal disruptive steps, clear and concise outputs with configuration options.
- **Diarization** (who said what) is a **basic requirement**—without it, the product is (probably) incomplete for the target group.
- Terminology and documentation may also assume a medical context; security and data protection are absolutely essential.

---

## 2. Modular Architecture

- The system is split into **5 modules** 
(1. ASR/WhisperX, 2. LLM, 3. prompts/dictionaries/context, 4. API/export, 5. settings/user/license).
- Modules communicate via **clearly defined interfaces** (APIs, data formats). 
Inter-module dependencies are minimized.
- Changing or swapping one module (e.g. different ASR provider) should not break the others.

---

## 3. Quality and Testing

- **Automated tests and checks** of everything must be subject to criticism. 
- Changes, e.g., in interfaces between modules are **fundamental changes** – they require well-thought-out interventions, documentation updates, and updates to dependent modules.
- Critical paths must be **testable** with logging into the program itself (especially where it is reasonable from the point of view of security, privacy, but also for development and service).

---

## 4. Security and Privacy

- **Health data** (transcripts, context) must never be accessible to any attack, including screen monitoring, and must not be sent to undefined external services without the user's explicit repeated consent and clear information about the risks.
- The choice between **local and various online LLMs** is always up to the user; the default setting should be conservative (e.g., local or "cloud-free").
- API keys and login credentials must not be stored in plain text in the configuration; use secure storage (e.g., system key chain/credential store).
- Applications must be fundamentally resistant to attacks, reverse engineering, etc.

---

## 5. Documentation and Specifications

- VISION.md and CONSTITUTION.md are reference documents; significant changes require an explicit decision.
- Each module has an **interface description** (inputs, outputs, dependencies) and a **quick guide** for use or integration.
- Changes in behavior are reflected in the documentation before or at the time of release.

---

## 6. Technical Choices

- **Desktop:** Windows and macOS as primary platforms; technology stack (e.g., Electron, Tauri, native) selected based on performance, binary file size, and maintainability.
- **ASR:** WhisperX is the reference module for transcription and diarization; module 1 interface allows alternatives to be considered later without disrupting the rest of the system.
- **LLM:** Support for both local models (Ollama, llama.cpp, etc.) and online LLM built-in providers or via API (compatible with OpenAI, etc.) – configurable in the settings module. With the option of simple user changes in module 2. (LLM).

---

## 7. Export and Integration

- The API/export module must support **reusable connections** to external platforms (configurable endpoints, authentication).
- Export formats (JSON, CSV, possibly SRT, EHR integration) are specified and versioned; backward compatibility is prioritized where it is effective and necessary.

---

*The constitution is based on [VISION.md](VISION.md). Changes to the constitution should be intentional and documented.*

**Canonical source:** `.specify/memory/constitution.md` (Spec-Kit). Keep this file in sync or treat it as a copy for convenience.
