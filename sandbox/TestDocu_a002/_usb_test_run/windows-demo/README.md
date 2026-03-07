# TestDocu_a002 Demo (No STT)

## Goal

- Demo UI in agreed stack: `SvelteKit + TypeScript + Tauri/Rust`.
- No STT path, no microphone, no WhisperX dependency.
- Quick portable handoff path for Windows/macOS.

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
