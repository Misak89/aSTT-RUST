# Změna architektury: Tauri -> Electron (pro identickou app)

Tento dokument obsahuje **pouze změny architektury** oproti variantě s Tauri.
Vše ostatní (UI flow, route struktura, ASR/no-STT funkcionalita) zůstává stejné.

## 0. Priority (Privacy -> Security -> Quality)
- Privacy-first:
  - STT cast je navrzena jako offline-only modul i na stroji pripojenem k internetu.
  - Audio se zpracovava lokalne; online LLM vrstva muze dostat jen text po policy filtru.
- Security-first:
  - Commandy jdou pres policy broker (allowlist), ne napric vrstvami.
  - STT proces ma blokovany outbound network.
  - Citlive prepinace (recording, online source, screen capture) jsou admin-only (heslo) a auditovane.
  - Vyssi bezpecnostni uroven (`Strict`) je volitelna v nastaveni, ale meni jen policy, ne UI strukturu.
- Quality-first:
  - Kontrakt commandu zustava 1:1.
  - Pri poruse policy/avizace plati fail-closed (recording se nespusti).
  - Konfigurace je privetiva: bezpecnostni treni je rizene profilem (`Standard`/`Hardened`/`Strict`).

## 1. Typ aplikace
- `Tauri (Rust host + WebView)` se nahrazuje za `Electron (Node.js Main + Chromium Renderer)`.
- SSR zůstává vypnuté; frontend je dál SvelteKit SPA build.

## 2. Frontend vrstva (Svelte)
- Beze změny: stejné route (`/`, `/demo-a002`) a stejné UI panely.
- Jediná změna je transport volání z UI do backendu (viz IPC).

## 3. IPC vrstva (UI -> backend)
- `@tauri-apps/api/core -> invoke()` se nahrazuje za `window.electronAPI.*` přes `contextBridge` v preload skriptu.
- `ipcRenderer.invoke(...)` v rendereru <-> `ipcMain.handle(...)` v main procesu.
- Zachová se stejný command contract (`init_sidecar`, `start_recording`, `demo_service_report`, ...), jen s jiným IPC mechanismem.
- K puvodnim commandum se doplnuje shodny modul pro obe app varianty:
  - security profile/settings commandy (`get/set_security_profile`, `get/set_security_settings`),
  - output API commandy (`get/set_output_api_config`, `test_output_api`, `send_processed_output`).

## 4. Backend vrstva
- Rust command handlery (`#[tauri::command]`) se nahrazují Node/Electron handlery v Main procesu.
- `AppState + Arc<Mutex<...>>` se nahrazuje singleton service objekty v Node procesu (řízení souběhu přes async frontu/lock pattern).
- HW metriky a code analytics běží v Node vrstvě (OS/process APIs + filesystem scan), ne v Rustu.
- Nastaveni je rozdelene na:
  - `User settings` (UX preference),
  - `Admin settings` (recording policy, online source policy, screen capture policy, outbound API policy).
- Outbound API export posila pouze zpracovany text/metadata, nikdy surove audio.

## 5. Sidecar vrstva (backend <-> Python)
- Místo `tauri_plugin_shell` se používá `child_process.spawn`.
- Strategie zůstává stejná:
  - dev: spouštět `python src-python/sidecar.py`
  - build: spouštět bundlovaný sidecar executable
- Protokol zůstává stejný: JSON-RPC 2.0 přes stdio.
- STT sidecar je logicky oddeleny "offline-only" worker:
  - bez povoleneho outbound network,
  - s minimalnimi runtime pravy.

## 6. Persistenční vrstva
- `localStorage` v rendereru beze změny.
- Service log se zapisuje z Main procesu do temp adresáře (`app.getPath('temp')/astt_demo_a002/service.log`), nikoli přes Rust.
- Security audit log zachycuje aktivaci recordingu a online audio zdroju (cas, zdroj, session).

## 7. Build/deploy architektura
- `tauri.conf.json`, capabilities a Tauri plugins se nahrazují Electron konfigurací:
  - Electron main/preload/renderer build pipeline (např. Vite + electron-vite / Forge / Builder)
  - balení aplikace přes Electron Builder/Forge
  - sidecar binary bundling přes `extraResources`/equivalent
- Bezpečnostní hranice je dána preload API (allowlist), ne Tauri capability JSON.
- Povinne uzivatelske avizace:
  - aktivni recording musi mit viditelny indikator,
  - aktivni online source musi byt zretelne oznamen.
- Povinna bezpecnost outbound API:
  - default OFF,
  - endpoint allowlist,
  - TLS vyzadovane mimo `localhost`,
  - audit kazdeho odeslani/chyby.
