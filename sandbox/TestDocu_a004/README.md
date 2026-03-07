# TestDocu_a004 Sandbox (Tauri STT + LLM)

## Goal

`A004` is a practical sandbox test app:

- STT from `MIC`, local audio/video file, and linked media URL.
- Stage A text processing in first window (`ASR Window`) immediately after transcript.
- Stage B text processing in second window (`Text Window`) with:
  - online LLM mode (provider endpoint),
  - offline mode (local endpoint if available, otherwise rule fallback).
- STT backend strategy:
  - primary: `whisperx`,
  - fallback: `faster-whisper` (real transcription without WhisperX-only extras).

## Route

- Open: `/demo-a004`
- Source: `src-ui/routes/demo-a004/+page.svelte`

## Runtime commands (new in A004)

- `preflight_check`, `preflight_details`
- `text_stage_a_process`
- `llm_get_models`, `llm_set_model`
- `llm_register_provider`, `llm_health`
- `llm_process_text_stage_b`

## Prerequisites for full functionality

- Python runtime available in PATH.
- For MIC capture via sidecar: Python package `sounddevice`.
- For real STT: at least one backend module:
  - `whisperx` or
  - `faster-whisper`.
- For linked video URL extraction (YouTube-like pages): `yt-dlp` CLI in PATH
  or Python module `yt_dlp` in active runtime.
- For broad media decode compatibility: `ffmpeg` in PATH.
- For local offline LLM endpoint mode (optional): OpenAI-compatible local server
  (for example Ollama gateway on `http://127.0.0.1:11434`).

## Quick start

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a004\setup_demo_a004.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a004\run_tauri_a004.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
```

Open `/demo-a004`.

## Verification script

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a004\test_demo_a004.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
```

The script validates:

- Python sidecar syntax,
- Rust tests,
- frontend check/build,
- runtime prerequisites for full A004:
  - `yt-dlp`,
  - `ffmpeg`,
  - `sounddevice`,
  - `whisperx` or `faster_whisper`.
