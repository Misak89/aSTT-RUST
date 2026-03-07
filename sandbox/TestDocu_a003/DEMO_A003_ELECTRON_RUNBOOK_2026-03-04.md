# DEMO A003 Runbook (2026-03-04)

## What UI is implemented

- Route: `/`
  - `ASR Window` and `Service Window` with same behavior as Tauri version.
- Route: `/demo-a002`
  - 4 tabs: `operations`, `knowledge`, `system`, `diagnostics`.
- Stack in this variant:
  - `Electron (Main + Preload + Renderer)`
  - `SvelteKit + TypeScript`
  - `Python sidecar` via JSON-RPC 2.0 over stdio.
- Renderer load mode:
  - static SPA build is served from local `127.0.0.1` loopback by Electron main.
  - avoids `file://` blank page with absolute `/_app/...` paths.
- Privacy guardrails:
  - Chromium background networking switches are disabled in `electron/main.cjs`.
  - Telemetry/update endpoints (Google Analytics / update / safebrowsing group) are blocked by request filter.

## Command parity target (same names)

- `greet`
- `demo_health`
- `demo_diagnostics`
- `demo_service_report`
- `demo_live_metrics`
- `demo_append_log`
- `demo_read_logs`
- `init_sidecar`
- `start_recording`
- `stop_recording`
- `transcribe`
- `get_sidecar_config`
- `set_sidecar_config`

## Files

- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\electron\main.cjs`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\electron\preload.cjs`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\electron\commands.cjs`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\electron\sidecar-manager.cjs`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-ui\lib\runtime-bridge.ts`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-ui\routes\+page.svelte`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-ui\routes\demo-a002\+page.svelte`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\prepare_usb_windows_demo.ps1`

## Run (Windows, full path)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST'; npm run electron:dev"
```

## Verify (Windows, full path)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\test_demo_a003.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
```

## Portable packaging (Windows)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST'; npm run electron:pack"
```

- Output folder:
  - `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\dist-electron\win-unpacked\`
  - entry exe: `aSTT-demo-electron.exe`

## USB prep (Windows)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a003\prepare_usb_windows_demo.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST" -UsbPath "E:\aSTT-DEMO-A003" -BuildFirst
```

- Result path:
  - `...\windows-demo\app\aSTT-demo-electron.exe`
- Included:
  - `README.md`
  - `RUNBOOK.md`
  - `BUILD_INFO.txt`
  - `RUN_FROM_USB.cmd`

Use `RUN_FROM_USB.cmd` to start the packaged app (launcher clears `ELECTRON_RUN_AS_NODE`).
