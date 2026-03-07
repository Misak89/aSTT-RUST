# TestDocu_a003 Demo (Electron, No STT)

## Priority order

1. Privacy first
2. Security second
3. Quality third

This demo documentation treats privacy/security constraints as mandatory architecture inputs, not optional runtime flags.

## Goal

- Keep the same UI and behavior as `TestDocu_a002`.
- Run the desktop app in `Electron + Node.js` instead of `Tauri + Rust`.
- Keep the same routes, buttons, state logic, and sidecar JSON-RPC contract.

## Electron development status (without testing) - 2026-03-05

- Electron runtime layers are implemented: `electron/main.cjs`, `electron/preload.cjs`, `electron/commands.cjs`, `electron/sidecar-manager.cjs`.
- Shared UI bridge parity exists via `src-ui/lib/runtime-bridge.ts` (invoke/dialog/menu actions for both Tauri and Electron).
- Native menu actions are wired (`View` / `Help`) and mapped to renderer actions.
- Core command surface is implemented in Electron (`demo_*`, `init_sidecar`, `start_recording`, `stop_recording`, `transcribe`, `get_sidecar_config`, `set_sidecar_config`).
- Transcript TXT export command is implemented (`save_transcript_txt`) with one clear format:
  - full transcript section,
  - numbered segment lines with timestamps.
- Portable/offline packaging flow exists in `sandbox/TestDocu_a003` and `_launch_now/windows-demo`.
- This is a development snapshot only; runtime behavior was not fully re-validated in this status note.
- Active priority is Tauri-first development; Electron is currently frozen at this snapshot level.

## Privacy/security baseline

- STT runtime is designed as offline-only worker.
- Recording and online source activation must be explicitly controlled and auditable.
- Sensitive controls (`recording`, `online sources`, `screen capture`) belong to password-protected admin settings.
- If mandatory user notification cannot be shown, recording must be blocked (fail-closed).

## Security levels and friendly configurability

- Security profile is selectable in settings:
  - `Standard` (default, user-friendly) for normal local work.
  - `Hardened` (stricter confirmations, online inputs off by default).
  - `Strict` (high-friction mode, intended for privacy-critical operation).
- Security-critical controls are split by role:
  - `User settings`: language/theme/layout, non-sensitive UX behavior.
  - `Admin settings` (password-protected): recording policy, online source policy, screen capture policy, outbound policy.
- Strict profile requirements:
  - visible recording/source indicator at all times,
  - explicit user confirmation before any capture session,
  - auto-stop + re-confirmation after policy TTL,
  - fail-closed when policy/indicator/audit write cannot be guaranteed.

## Processed output API (to external app)

- App can push processed text output to another program via outbound API connector.
- Supported delivery targets:
  - secure HTTP endpoint (`POST` JSON),
  - localhost callback for local integration.
- Mandatory safety guardrails:
  - endpoint allowlist,
  - TLS required for non-localhost endpoints,
  - optional payload redaction profile before send,
  - retry queue with bounded attempts and audit trail.
- Contract parity rule:
  - the same output API commands and payload schema must exist in both Tauri (`TestDocu_a002`) and Electron (`TestDocu_a003`) variants.

## What is now testable in UI

- Route `/`:
  - `ASR Window`: sidecar init/config, local file/URL source, recording start/stop, transcribe, transcript output.
  - `Service Window`: service report, online HW polling, code-scope analytics tables.
- Route `/demo-a002`:
  - `Operations`, `Knowledge`, `System`, `Diagnostics` tabs.
  - same state persistence key: `astt_demo_a002_state_v3`.
  - same command names for health/diagnostics/logs.

## Runtime files (Electron implementation)

- `electron/main.cjs`
- `electron/preload.cjs`
- `electron/commands.cjs`
- `electron/sidecar-manager.cjs`
- `src-ui/lib/runtime-bridge.ts`
- `src-ui/routes/+page.svelte`
- `src-ui/routes/demo-a002/+page.svelte`

## Renderer loading mode

- Electron main serves static `build/` over local loopback (`http://127.0.0.1:<port>`), not `file://`.
- This removes blank-screen issues caused by absolute `/_app/...` asset paths in static SPA output.

## Privacy/network behavior

- Electron main process disables Chromium background networking features.
- Known telemetry hosts (`google-analytics`, `doubleclick`, Google update/safebrowsing endpoints) are blocked in `webRequest` rules.
- App sends network requests only when user explicitly triggers them (for example URL transcription or API test in `/demo-a002`).

## Local run (desktop dev)

```powershell
npm run electron:dev
```

## Full path run (Windows, this machine)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST'; npm run electron:dev"
```

## Build test

```powershell
npm run check
npm run build
```

## Build test with full path (Windows, this machine)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\test_demo_a003.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
```

## Portable handoff (USB)

- Build portable Windows folder (no installer, offline-safe):

```powershell
npm run electron:pack
```

- Output:
  - `dist-electron\win-unpacked\`
  - entry exe: `dist-electron\win-unpacked\aSTT-demo-electron.exe`

### Fast USB prep on this machine (Windows)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\prepare_usb_windows_demo.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST" -UsbPath "E:\aSTT-DEMO-A003" -BuildFirst
```

Double-click safe:

- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\RUN_prepare_usb_windows_demo.cmd`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\RUN_prepare_usb_windows_demo_ASK_USB.cmd`

Run from prepared USB folder via `RUN_FROM_USB.cmd` (it clears `ELECTRON_RUN_AS_NODE` before launch).
