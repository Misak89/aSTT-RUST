# TestDocu_a002 Demo (No STT)

## Priority order

1. Privacy first
2. Security second
3. Quality third

Even in this no-STT demo, privacy/security quality gates are treated as primary constraints for future STT-capable builds.

## Security profile and API parity target

- `A002 (Tauri)` is the primary runtime baseline for lower CPU/RAM overhead.
- Tauri variant (`a002`) and Electron variant (`a003`) must expose the same security profile model:
  - `Standard` (default),
  - `Hardened`,
  - `Strict` (admin-only).
- Sensitive policy toggles remain admin-protected (password/PIN + audit log).
- Processed output export to external software is part of parity scope:
  - outbound API uses allowlisted endpoints,
  - payload is processed text/metadata only (no raw audio),
  - every send/fail event is auditable.

## Goal

- Demo UI in agreed stack: `SvelteKit + TypeScript + Tauri/Rust`.
- No STT path, no microphone, no WhisperX dependency.
- Quick portable handoff path for Windows/macOS.

## What is now testable in UI (`/demo-a002`)

- `Operations` tab:
  - work-item filter/search
  - status cycling
  - capacity/load recalculation
  - Rust runtime health check (`demo_health`)
- `Knowledge` tab:
  - custom dictionary add/toggle
  - prompt library add/edit/select
- `System` tab:
  - local account profile edit/save
  - settings persistence (theme/language/autosave)
  - API endpoint probe (status, latency, response preview)
- `Diagnostics` tab:
  - Rust diagnostics probe (`demo_diagnostics`)
  - service log append/read (`demo_append_log`, `demo_read_logs`)
  - simulated error logging for troubleshooting flow tests

## Where is the demo UI

- Route: `/demo-a002`
- Source: `src-ui/routes/demo-a002/+page.svelte`
- Rust command used by demo route: `demo_health` in `src-tauri/src/lib.rs`

## Local run (dev)

```powershell
npm run dev
```

Open:

- `http://localhost:1420/demo-a002`

## Full path run (Windows, this machine)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST'; npm run dev"
```

Open:

- `http://localhost:1420/demo-a002`

## Build test

```powershell
npm run check
npm run build
```

## Build test with full path (Windows, this machine)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\test_demo_a002.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
```

## Portable handoff (USB)

- Build OS-specific desktop bundle from this repo:

```powershell
npm run tauri build
```

- Copy built artifact to USB:
  - Windows: `src-tauri/target/release/bundle/**`
  - macOS: build on macOS host, then copy `.app` / `.dmg`.

### Fast USB prep on this machine (Windows)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\prepare_usb_windows_demo.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST" -UsbPath "E:\aSTT-DEMO-A002" -BuildFirst
```

Double-click safe (recommended):

- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\RUN_prepare_usb_windows_demo.cmd`
- Or with USB path prompt:
  - `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\RUN_prepare_usb_windows_demo_ASK_USB.cmd`

Notes:

- Truly "no install" cross-platform means shipping prebuilt binaries per OS.
- One build cannot produce both Windows and macOS desktop binaries on one host.
