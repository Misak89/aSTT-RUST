# Electron Parita a USB Postup (aSTT)

Tento dokument je odvozen pouze z runtime souboru:
- `src-ui/app.html`
- `src-ui/routes/+layout.ts`
- `src-ui/routes/+page.svelte`
- `src-ui/routes/demo-a002/+page.svelte`
- `src-tauri/src/main.rs`
- `src-tauri/src/lib.rs`
- `src-tauri/src/rpc.rs`
- `src-tauri/src/sidecar.rs`
- `src-python/sidecar.py`

## 0) Prioritni model (Privacy -> Security -> Quality)

1. Privacy je nad funkcemi:
   - STT jadro je "offline-only" i na online PC.
   - Audio data z STT nejdou do online LLM vrstvy; online vrstva pracuje jen s textem.
   - Vstupy (`MIC`, `offline file`, `online URL`, `YouTube`, `VideoCall`) jsou modularni adaptery a jdou centralne vypinat.
2. Security je nad pohodlim:
   - Jedina brana je backend policy broker s allowlist commandu.
   - STT proces ma blokovany outbound network a minimalni prava.
   - Rizikove prepinace (recording, online zdroje, screen capture) jsou jen v nastaveni chranenem heslem.
   - Vyssi bezpecnostni profil ("Strict") musi jit zapnout v admin nastaveni bez zmeny kodu UI.
3. Quality je overitelna:
   - Zachovani 1:1 command kontraktu.
   - Diagnostika musi obsahovat zdroj, stav, cas a auditni stopu.
   - Chovani je fail-closed: pokud chybi policy nebo avizace, recording/online capture se nespusti.
   - UX zustava privetive: bezpecnostni "treni" je rizene profilem, ne nahodne.

## A) Finalni paritni specifikace (Electron misto Tauri)

### 1. Funkcni scope
- App je SPA (`ssr = false`), ma route `/` a `/demo-a002`.
- Route `/`:
  - `ASR Window`: init/config sidecaru, vyber zdroje (`MIC`/soubor/URL), recording start/stop, transcribe, transcript, raw RPC.
  - `Service Window`: online HW metriky, code analytics, measurement logic, raw service report.
- Route `/demo-a002`:
  - 4 taby: `operations`, `knowledge`, `system`, `diagnostics`.
  - Local state persistence pod klicem `astt_demo_a002_state_v3`.
  - Diagnostics/log operace volane pres backend.

### 2. IPC kontrakt, ktery musi zustat 1:1
Electron implementace musi zachovat stejna command jmena, vstupy a vystupy.
Core kompatibilni commandy:
- `greet(name)`
- `demo_health()`
- `demo_diagnostics()`
- `demo_service_report()`
- `demo_live_metrics()`
- `demo_append_log(level, message)`
- `demo_read_logs(limit)`
- `init_sidecar(config)`
- `start_recording()`
- `stop_recording()`
- `transcribe(audio_path)`
- `get_sidecar_config()`
- `set_sidecar_config(config)`

Povinne rozsireni pro konfiguraci bezpecnosti + outbound API:
- `get_security_profile()`
- `set_security_profile(profile, admin_token?)`
- `get_security_settings()`
- `set_security_settings(settings, admin_token)`
- `get_output_api_config()`
- `set_output_api_config(config, admin_token?)`
- `test_output_api(payload_preview?)`
- `send_processed_output(payload)`

Frontend muze zustat temer beze zmeny, pouze:
- misto `invoke()` pouzit `window.electronAPI.invoke(command, args)`.
- misto Tauri file dialog API pouzit `window.electronAPI.openMediaFile()`.

### 3. Sidecar kontrakt (beze zmeny)
- Protokol: JSON-RPC 2.0 pres stdio.
- Request: `{"jsonrpc":"2.0","method":"...","params":{...},"id":N}`
- Response success: `{"jsonrpc":"2.0","result":{...},"id":N}`
- Response error: `{"jsonrpc":"2.0","error":{"code":...,"message":"..."},"id":N}`
- Metody: `init`, `start_recording`, `stop_recording`, `transcribe`, `get_config`, `set_config`.
- Python sidecar behavior (defaults, fallback, validation, remote media URL handling, recording flow) zustava stejny.

### 4. Backend behavior, ktery musi zustat stejny
- State sidecar manageru je singleton.
- Zdroj audia je spravovan modulove (source adapters) pres policy broker:
  - `MIC` je podporovan vzdy, ale lze jej vypnout.
  - online adaptery (`URL`, `YouTube`, `VideoCall`) jsou defaultne OFF a mohou byt povoleny docasne (TTL).
- `init_sidecar` zajisti spawn + init.
- `start_recording`/`stop_recording`/`transcribe` vraci JSON-RPC envelope.
- `demo_append_log`:
  - `level`: uppercase, non-empty, max 12 znaku.
  - `message`: bez newline, non-empty, max 2000 znaku.
- `demo_read_logs(limit)`:
  - `limit = 0 -> 50`.
  - max limit 500.
- Service report obsahuje stejne top-level sekce:
  - `host`, `measurement_logic`, `measurement_logic_table`,
  - `hw_requirements_estimate`, `technology_stack`,
  - `code_lines_by_language`, `framework_counts`, `demo_files`,
  - `code_lines_scope`, `component_load`.
- Povinny compliance behavior:
  - pri aktivnim recordingu musi byt viditelna avizace.
  - start/stop recordingu musi byt auditovany.
  - pokud se nepodari zobrazit avizaci, recording se blokuje.
  - prepnuti do profilu `Strict` je auditovane.
- Konfiguracni model:
  - `User settings`: pouze UX volby (napr. jazyk, tema, layout, non-sensitive preference).
  - `Admin settings`: recording policy, online source policy, screen capture policy, outbound API policy.
  - Admin vrstva je chranena heslem/PIN a kratkym session tokenem.
- Outbound API modul:
  - odesila pouze zpracovany text/metadata, nikdy surove audio.
  - defaultne OFF, aktivace jen pres policy + audit.
  - endpointy jsou omezeny allowlistem.
  - pro endpointy mimo `localhost` je povinne TLS.

### 5. Co je jedina architekturni zmena
- Tauri runtime nahradit Electron runtime:
  - Tauri command bridge -> Electron `ipcMain.handle` + `ipcRenderer.invoke`.
  - Tauri shell spawn sidecaru -> Node `child_process.spawn`.
  - Tauri plugin dialog -> Electron dialog v preload bridge.
- UI, stavy, command contract i sidecar JSON-RPC zustavaji funkcne stejne.

### 6. Prakticka poznamka k "zcela stejne funkcnosti"
1. Nejbezpecnejsi je zachovat frontend soubory temer beze zmeny a emulovat Tauri command API v Electronu.
2. Tim ziskas stejny UX, stejne stavy, stejne response struktury i stejne chovani tlacitek bez prepisovani UI logiky.
3. Dalsi logicky krok je dopsat presny Electron IPC interface (TypeScript typy request/response pro vsechny core + security/API commandy), aby slo kodovani delat primo podle kontraktu.

## B) Postup vyvoje identicke USB verze (kodovani)

### Faze 0: Zmrazit kontrakt
1. Vytvorit "parity checklist" pro vsechny commandy, payloady a response keys.
2. Fixnout presne default hodnoty UI stavu (`model`, `language`, `audioPath`, intervaly, tab defaults).
3. Definovat pass/fail kriterium: "stejne chovani tlacitek + stejne response shape + stejne chyby".
4. Definovat privacy/security acceptance:
   - STT outbound network = blokovany.
   - recording + online source aktivace = pouze pres policy + audit.
   - admin nastaveni (heslo) chrani rizikove prepinace.
5. Definovat profilovy model:
   - `Standard`, `Hardened`, `Strict`.
   - vychozi profil je privetivy (`Standard`), strict mode je admin-only.

### Faze 1: Electron skeleton
1. Zalozit Electron app se 3 vrstvami:
   - `main` (Node backend command dispatcher),
   - `preload` (safe API export),
   - `renderer` (Svelte route kod).
2. V preload expose pouze:
   - `invoke(command, args)`,
   - `openMediaFile()`.
3. Zapnout `contextIsolation: true`, `nodeIntegration: false`.

### Faze 2: Renderer parita
1. V obou Svelte routach zamenit jen transportni vrstvu:
   - `invoke(...)` -> `window.electronAPI.invoke(...)`.
   - file picker -> `window.electronAPI.openMediaFile()`.
2. Nemenit business logiku UI, jen adaptovat importy.
3. Zkontrolovat, ze vsechny stavy a derived hodnoty zustaly stejne.

### Faze 3: Main command dispatcher
1. V `main` vytvorit mapu commandu se stejnyma jmenama.
2. Implementovat no-STT commandy:
   - `demo_health`, `demo_diagnostics`, `demo_service_report`,
   - `demo_live_metrics`, `demo_append_log`, `demo_read_logs`.
3. Implementovat stejnou validaci log level/message.
4. Implementovat stejny format log radku: `timestamp|LEVEL|message`.
5. Dodelat security profile commandy a admin autentizaci.
6. Dodelat output API commandy s allowlist + TLS kontrolou.

### Faze 4: Sidecar manager v Electron
1. Implementovat singleton manager:
   - spawn jen jednou,
   - pending response mapa podle JSON-RPC `id`,
   - timeout requestu 30s.
2. Spawn strategie:
   - pokud je dostupny `src-python/sidecar.py`, zkusit `python sidecar.py`,
   - pri fail fallback na bundled sidecar executable.
3. Stdout parser:
   - parsovat jen validni JSON-RPC,
   - non-JSON radky ignorovat nebo logovat jako diagnostiku.

### Faze 5: ASR commandy parity
1. `init_sidecar(config)` -> spawn + JSON-RPC `init`.
2. `start_recording()` -> JSON-RPC `start_recording`.
3. `stop_recording()` -> JSON-RPC `stop_recording`.
4. `transcribe(audio_path)` -> JSON-RPC `transcribe` (zachovat `audio_path` key).
5. `get_sidecar_config`/`set_sidecar_config` -> JSON-RPC `get_config`/`set_config`.

### Faze 6: USB portable baleni
1. Vyrobit portable Windows build (bez instalace) jako `win-unpacked` slozku (offline-safe).
   Implementace: `npm run electron:pack` (`electron/pack-offline.mjs`) kopiruje lokalni `node_modules/electron/dist` a runtime app.
2. Pribalit sidecar binary do resources (fallback path).
3. Udrzet relativni path resolution pro beh z USB (drive letter agnostic).
4. Vytvorit USB adresar:
   - `app/aSTT-demo-electron.exe`
   - README + RUN_FROM_USB.cmd
   - `app/resources` (sidecar + nutna runtime data)
5. Overit beh na cistem stroji bez dev toolchain.

### Faze 7: Parity test plan
1. UI parity:
   - route `/` a `/demo-a002` stejne layouty, taby, defaulty.
2. Command parity:
   - vsechna core + security/API commandy vraci stejne key names a stejne error path.
3. Sidecar parity:
   - init, recording, transcribe lokalni soubor, transcribe URL.
4. Service parity:
   - live metrics polling 3/5/10s,
   - service report tabulky se plni bez zmen UI kodu.
5. USB parity:
   - run z USB, bez instalace, logy a temp files se tvori korektne.
6. Privacy/security parity:
   - pokus o STT sitovy pristup je blokovan.
   - zapnuti recordingu a online zdroju se projevi avizaci + audit zaznamem.
   - admin-only prepinace nejdou menit bez hesla.
7. Output API parity:
   - odeslani jde jen na povoleny endpoint.
   - payload neobsahuje surove audio.
   - chyba endpointu je auditovana a vidi ji uzivatel.

### Faze 8: Definition of Done
1. Uzivatel nepozna rozdil v UI toku ani ve funkcnim vystupu.
2. Vsechny UI akce maji stejny efekt a stejne response shape jako puvodni varianta.
3. USB build se spousti a funguje bez dodatecne instalace aplikace.
