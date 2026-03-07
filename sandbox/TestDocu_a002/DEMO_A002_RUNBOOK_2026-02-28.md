# DEMO A002 Runbook (2026-02-28)

## What UI is implemented

- Route: `/demo-a002`
- Purpose: project control dashboard (no STT), split into 4 tabs
- Stack: SvelteKit + TypeScript + Tauri/Rust
- User actions by tab:
  - `Operations`: search/filter work items, capacity/load, status cycle, runtime check (`demo_health`)
  - `Knowledge`: dictionary add/toggle, prompt add/edit/select
  - `System`: account profile fields, settings persistence, API probe (status/latency/response preview)
  - `Diagnostics`: runtime diagnostics (`demo_diagnostics`), service log append/read (`demo_append_log`, `demo_read_logs`), simulated error entry

## Security and configuration baseline (A002)

- Tauri A002 je primární vývojová varianta (HW-úspornější baseline).
- Profil zabezpečení musí být konfigurovatelný:
  - `Standard` (default),
  - `Hardened`,
  - `Strict` (admin-only).
- Rozdělení nastavení:
  - `User settings`: běžné UX volby.
  - `Admin settings`: recording/online source/screen capture/outbound API policy.
- Outbound API export (pro externí program) je součást parity:
  - posílá jen zpracovaný text/metadata,
  - endpoint allowlist + TLS mimo `localhost`,
  - audit log každého odeslání/chyby.

## Files

- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-ui\routes\demo-a002\+page.svelte`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-tauri\src\lib.rs` (`demo_health`, `demo_diagnostics`, `demo_append_log`, `demo_read_logs`)
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\README.md`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\test_demo_a002.ps1`

## Run (Windows, full path)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST'; npm run dev"
```

Open:

- `http://localhost:1420/demo-a002`

## Verify (Windows, full path)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\sandbox\TestDocu_a002\test_demo_a002.ps1" -RootPath "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
```

## Portable packaging

- Windows build on Windows host:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST'; npm run tauri build"
```

- Output:
  - `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-tauri\target\release\bundle\`
- macOS build must be produced on macOS host (same repo, same commands).
