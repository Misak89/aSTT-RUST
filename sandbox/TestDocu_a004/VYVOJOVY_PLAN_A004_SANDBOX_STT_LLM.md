# VYVOJOVY_PLAN_A004_SANDBOX_STT_LLM

Datum: 2026-03-04
Cil: funkcni sandbox verze pro testy STT + LLM, navazana na zkusenosti z A002/A003.
Primarni runtime: Tauri (Rust) + SvelteKit + Python sidecar.

## 0) Implementacni stav (2026-03-04)

- [x] Krok 1: A004 skeleton je implementovan v runtime kodu:
  - nova route `src-ui/routes/demo-a004/+page.svelte`
  - nove Tauri commandy (`preflight`, `Stage A`, `Stage B`, LLM provider/model management)
  - odkaz na `/demo-a004` z hlavni route
- [x] Krok 2: sidecar STT backend je realny (`whisperx` + fallback `faster-whisper`)
- [x] Krok 3: A004 bootstrap skripty (`setup_demo_a004.ps1`, `run_tauri_a004.ps1`, `RUN_A004_TAURI.cmd`)
- [ ] Krok 4+: navazujici real-world testovani MIC/soubor/URL a ladeni provideru/modelu

## 1) Scope (MVP+)

Musi fungovat:
- online prepis z `MIC`
- online prepis z lokalniho `audio souboru`
- online prepis z `video/audio URL` (prolinkovane video)
- prvni technicke zpracovani textu uz v `ASR Window` po prepisu
- druhe okno pro praci s textem (`Text Window`):
  - navazne (castecne lekarske) zpracovani textu
  - online LLM rezim
  - offline LLM rezim (jednodussi model)

## 2) Co se znovu pouzije z A002/A003

- UI struktura a stavovy management ze `src-ui/routes/+page.svelte` a `src-ui/routes/demo-a002/+page.svelte`
- command-oriented IPC pristup (stabilni command kontrakt)
- Service/Diagnostics pattern (health, logs, live metrics)
- startup a runtime guardrails (privacy/security-first, fail-closed)
- USB/portable workflow scripts a runbook styl dokumentace

## 3) Cilova architektura A004 (Tauri-first)

- Window 1: `ASR Window`
  - zdroje: MIC / soubor / URL
  - STT control: init, start, stop, transcribe, live status
  - `Stage A - Technical cleanup`:
    - normalizace odstavcu a interpunkce
    - odstraneni repetici/filler tokenu
    - zakladni jazykova korekce + timestamp alignment
- Window 2: `Text Window`
  - vstup: vystup ze Stage A
  - `Stage B - Medical/context transform`:
    - strukturovani textu podle zvolene sablony
    - sumarizace a klinicky orientovana formulace
  - rezimy: Online LLM / Offline LLM
  - vystup: upraveny text, shrnuti, strukturovany vystup
- Backend (Rust):
  - command dispatcher + policy broker
  - startup preflight (HW + kolize + permissions + firewall hints)
  - telemetry only local/audit
- Sidecar vrstva:
  - Python STT sidecar (WhisperX/faster-whisper flow)
  - optional local LLM engine adapter (llama.cpp/Ollama endpoint)

## 4) Navrh command kontraktu (A004)

STT commandy:
- `init_sidecar(config)`
- `start_recording()`
- `stop_recording()`
- `transcribe(audio_path_or_url)`
- `get_sidecar_config()`
- `set_sidecar_config(config)`
- `text_stage_a_process(transcript, profile)`

Text/LLM commandy:
- `llm_process_text_stage_b(input, mode, profile, template)`
- `llm_get_models()`
- `llm_set_model(model_id)`
- `llm_health(mode)`
- `llm_register_provider(provider_config)`  # online konektory 3. stran

Preflight/diagnostika:
- `preflight_check()`
- `preflight_details()`
- `demo_live_metrics()`
- `demo_service_report()`

## 5) Integracni kroky (po jednom kroku)

1. Vytvorit A004 skeleton (UI route + Rust command scaffold + sidecar wiring).
2. Zprovoznit MIC online STT end-to-end.
3. Pridat prepis lokalniho audio souboru.
4. Pridat URL pipeline (download/extract -> transcribe).
5. Dodelat `Stage A` zpracovani hned po STT v `ASR Window`.
6. Pridat druhe `Text Window` a prepinac `Online/Offline LLM` pro `Stage B`.
7. Napojit online LLM konektor (API key pouze v admin settings).
8. Napojit offline LLM adapter (lokalni model, bez odchodu surovych audio dat).
9. Dodelat startup preflight + role-based warnings (User/Admin).
10. Dodelat runbook + test script + USB/portable baleni.

## 6) Acceptance criteria

- Vsechny 3 STT vstupy jsou funkcni v jednom UI flow.
- Stage A probiha ihned po prepisu v prvnim okne.
- Text Window umi Stage B online i offline LLM zpracovani stejneho vstupu.
- Startup preflight vraci `BLOCKER/WARNING/INFO` a viditelne instrukce.
- Pri policy poruse je chovani fail-closed.
- Tauri build je spustitelny jako portable slozka ve Windows.
- Dokumentace obsahuje realne kroky reprodukce testu.

## 7) Offline LLM shortlist (RAM 10-16-18 GB, lokalni provoz)

Poznamka: RAM spotreba zavisi na kvantizaci a kontextu. Nize jsou prakticke cile pro bezny desktop.

- `Qwen3-8B` (Q4_K_M): cca 6-8 GB RAM
- `Qwen3-14B` (Q4_K_M): cca 10-14 GB RAM
- `Gemma 3 12B` (Q4): cca 9-12 GB RAM
- `Phi-4-mini-instruct` (~3.8B, Q4, odhad): cca 4-6 GB RAM
- `Mistral Small 3.2 24B` (Q4): casto 16-22 GB (na 18 GB je to hranicni)

Doporuceni pro A004 offline MVP:
- default: `Qwen3-8B` nebo `Gemma 3 12B`
- vyssi kvalita pri 16-18 GB: `Qwen3-14B`
- fallback low-RAM: `Phi-4-mini-instruct`

## 8) Rizika

- URL/video zdroje mohou selhat na site, geo restrikci nebo formatu media.
- Online LLM muze byt latencni nebo firewall-blocked.
- Offline model kvalita vs. RAM je tradeoff; musi byt volitelny profil.
- Realny startup preflight potrebuje test na vice strojich (Windows/macOS).

## 9) Provider model (online 3rd-party LLM)

- Integrace ma byt provider-agnostic:
  - preferovat `OpenAI-compatible` API adapter jako default vrstvu.
  - kazdy provider jen jako konfigurace endpointu, modelu a auth.
- Podporit dva typy provideru:
  - `free/test` (nizsi SLA, vhodne pro sandbox),
  - `paid/production` (stabilnejsi latence a limity).
- App 3. stran se integruje nejjednoduseji pres:
  - REST API endpoint + API key,
  - jednotny JSON request/response kontrakt,
  - timeout/retry policy a audit log.

## 10) Odkazy na zdroje (modely a pamet)

- Qwen3 release + model family (official Qwen blog, 2025-04-29):
  - https://qwenlm.github.io/blog/qwen3/
- Qwen3 GGUF velikosti (official Qwen HF):
  - https://huggingface.co/Qwen/Qwen3-8B-GGUF
  - https://huggingface.co/Qwen/Qwen3-14B-GGUF
- Gemma 3 release (official Google blog, 2025-03-12):
  - https://blog.google/technology/developers/gemma-3/
- Gemma 3 practical memory table (official Google docs):
  - https://ai.google.dev/gemma/docs/core/model_card_3
- Phi-4-mini-instruct (official Microsoft HF model card):
  - https://huggingface.co/microsoft/Phi-4-mini-instruct
- Mistral Small 3.2 release timeline (official Mistral legal page):
  - https://docs.mistral.ai/getting-started/models/models_overview/
