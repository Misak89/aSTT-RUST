# DEMO A002 Runbook (2026-02-28)

## What UI is implemented

- Route: `/demo-a002`
- Purpose: project control dashboard (no STT)
- Stack: SvelteKit + TypeScript + Tauri/Rust
- User actions:
  - search/filter work items
  - capacity input + load indicator
  - cycle item status (`new -> active -> blocked -> done -> new`)
  - runtime check button that calls Rust command `demo_health` via Tauri `invoke`

## Files

- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-ui\routes\demo-a002\+page.svelte`
- `C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\src-tauri\src\lib.rs` (`demo_health`)
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
