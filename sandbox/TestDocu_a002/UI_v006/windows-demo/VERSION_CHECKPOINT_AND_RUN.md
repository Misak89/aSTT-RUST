# A002 UI_v006 - Checkpoint + Run Guide

This file describes the fixed checkpoint of the current stable Tauri version and the simplest safe run options.

## 1) Fixed checkpoint on GitHub

- Repository: `https://github.com/Misak89/aSTT-RUST`
- Branch: `test/verify-danger`
- Stable branch pointer: `stable/a002-ui_v006`
- Stable tag: `a002-ui_v006-stable-20260307_1703_cet`
- Commit: `d86cbb0`
- App version in code: `0.1.0`
- UI label: `UI_v006` (A002)

Use this exact tag/branch to return to the same code state later.

## 2) Quick run of this exact A002 version (local EXE)

From this folder:

- `RUN_FROM_USB.cmd` (existing launcher)
- `RUN_A002_ONLY_SAFE.cmd` (new safe launcher with duplicate-run check)

Main EXE:

- `aSTT-demo.exe`

## 3) Safe run of both versions (A002 + A003)

From this folder:

- `RUN_A002_A003_SAFE.cmd`

What it does:

1. Starts A002 (`aSTT-demo.exe`) if not already running.
2. Starts A003 Electron EXE from:
   `..\..\..\TestDocu_a003\_launch_now\windows-demo\app\aSTT-demo-electron.exe`
   if present and not already running.
3. Prints clear status if one app is missing.

## 4) Return to the same source checkpoint (Git)

```powershell
git fetch --all --tags
git switch stable/a002-ui_v006
```

Or detached from tag:

```powershell
git fetch --all --tags
git switch --detach a002-ui_v006-stable-20260307_1703_cet
```

Then run dev:

```powershell
npm run tauri:dev
```

## 5) Safety notes

- Before switching Git branches, close running app windows.
- If a process is locked, close:
  - `aSTT-demo.exe`
  - `aSTT-demo-electron.exe`
- Running both apps is possible, but it increases CPU/RAM load.
