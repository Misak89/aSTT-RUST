# DEMO A004 Runbook (2026-03-04)

## Scope under test

1. STT input sources:
   - Microphone recording (`start_recording` / `stop_recording`),
   - Local media file transcription,
   - Linked URL transcription (including YouTube-like page URL via `yt-dlp` if installed).
2. Stage A in `ASR Window`:
   - technical cleanup immediately after transcript.
3. Stage B in `Text Window`:
   - online LLM processing via provider endpoint,
   - offline mode via local endpoint if available, otherwise deterministic fallback output.
4. Runtime preflight:
   - severity model `BLOCKER / WARNING / INFO` with host diagnostics.
5. STT engine selection:
   - primary `whisperx`,
   - fallback `faster-whisper`.

## Setup for full runtime

1. Run:
   - `pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a004\setup_demo_a004.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"`
2. Start app:
   - `pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a004\run_tauri_a004.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"`

## Manual test checklist

1. Open app and navigate to `/demo-a004`.
2. Run `Startup Preflight` and verify JSON output appears.
3. Initialize sidecar.
4. Test local media file transcription:
   - pick file,
   - press `Transcribe`,
   - verify `Transcript` and automatic `Stage A` output.
5. Test linked URL transcription:
   - paste URL,
   - click `Use URL as source`,
   - run `Transcribe`,
   - verify output or meaningful error.
6. In `Text Window`, test Stage B offline:
   - keep mode `offline`,
   - run `Check LLM health`,
   - run `Process Stage B`,
   - verify output is produced (local endpoint or fallback).
7. In `Text Window`, test Stage B online:
   - set mode `online`,
   - register provider endpoint/model/key,
   - run `Check LLM health`,
   - run `Process Stage B`,
   - verify response text.
8. Optional MIC test:
   - `Start recording`, speak 5-10 seconds, `Stop recording`,
   - run `Transcribe` on generated audio path.

## Troubleshooting

- If MIC recording fails: ensure Python `sounddevice` is installed in `.venv-a004`.
- If linked video URL fails: install `yt-dlp` (PATH) or ensure `yt_dlp` module exists in active Python.
- If media decode fails: install `ffmpeg` in PATH.
- If STT init fails: install `whisperx` or `faster-whisper`.
- If offline local endpoint mode fails: verify local server endpoint and model name.
- If online mode fails: verify endpoint, model, key, and firewall/proxy policies.
