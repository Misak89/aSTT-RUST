# TestDocu_a003 Demo (Electron, No STT)

## Goal

- Keep the same UI and behavior as `TestDocu_a002`.
- Run the desktop app in `Electron + Node.js` instead of `Tauri + Rust`.
- Keep the same routes, buttons, state logic, and sidecar JSON-RPC contract.

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
