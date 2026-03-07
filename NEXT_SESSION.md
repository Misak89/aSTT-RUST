# Souhrn pro restart PC (2026-03-05 03:02:48 CET)

Ulozeno (local): 2026-03-05 03:02:48 +01:00
Ulozeno (UTC):   2026-03-05 02:02:48 Z

## Standard umisteni kontextu
- Operativni souhrn: `NEXT_SESSION.md` (tento soubor)
- Canonical control data: `docs_control/next_session.json`
- Generated kontrolni view: `docs/generated/control/NEXT_SESSION.md`

## Priorita
- Tauri-first (A004).
- Electron je ted zmrazen (snapshot only).

## Co je hotovo (A004)
1. Export transcriptu do TXT:
- `save_transcript_txt` uklada do `sandbox/TestDocu_a004/session_exports/transcripts`
- format obsahuje:
  - `[full_transcript]`
  - `[numbered_segments_with_time]`
  - `[settings_snapshot_json]`
  - `[raw_rpc_response_json]`

2. Timed capture flow:
- `Arm timed run` + `Start timed run`
- `Stop timed run (no transcribe)`
- `Finish now (Transcribe+Save)`
- `Auto-save TXT after timed stop`

3. Emergency abort:
- `Abort current request` (vedle `Transcribe file`)
- backend command: `abort_current_request`

4. Monitoring/log:
- Runtime Monitor loguje init config (`model/language/device/compute/diarization`)
- Loguje clip (`clip=...`) + upozorneni pro kratky clip
- Latence je rozdelena na `uiElapsed(transcribe)` a `uiElapsed(end-to-end)`

## Potvrzene vysvetleni posledniho incidentu
- Beh s `model=medium`, `language=en` byl spravne.
- Vystup byl kratky, protoze request bezel s `clip_seconds=5`.
- Pri abortu behem `init` jeste neexistuje transcript text -> neni co ulozit.

## Zname omezeni
- `Transcribe file` je stale non-streaming (finalni response, ne prubezne partial output).
- Prvni init novych modelu muze byt dlouhy (download/cache load).

## Zmenene soubory v posledni fazi
- `src-ui/routes/+page.svelte`
- `src-tauri/src/lib.rs`
- `src-tauri/src/sidecar.rs`
- `sandbox/TestDocu_a003/README.md` (status snapshot Electron)

## Pokracovani po restartu
1. Spustit:
- `sandbox/TestDocu_a004/RUN_A004_TAURI.cmd`

2. Pred testem overit v UI:
- model/language
- `Enable low-latency URL mode` (kdyz je ON, clip je kratky)

3. Pro delsi porovnani kvality:
- low-latency OFF, nebo zvysit clip/time

4. Pri zaseknuti:
- klik `Abort current request`

---
Souhrn je pripraven pro navazani po restartu.
