<script lang="ts">
  import { onMount } from "svelte";
  import { invokeCommand as invoke, openMediaFileDialog as openDialog } from "$lib/runtime-bridge";

  type RpcEnvelope = {
    result?: Record<string, unknown>;
    error?: {
      code?: number;
      message?: string;
    };
  };

  type ModelRow = {
    id: string;
    label: string;
    memory_hint_gb?: string;
  };

  let activeWindow = $state<"asr" | "text">("asr");
  let isBusy = $state(false);
  let busyLabel = $state("");
  let status = $state("Ready");
  let errorText = $state("");

  let model = $state("base");
  let language = $state("cs");
  let device = $state("cpu");
  let computeType = $state("int8");
  let diarization = $state(false);
  let hfToken = $state("");

  let audioPath = $state("jfk.wav");
  let mediaUrl = $state("");
  let recordingState = $state("idle");
  let recordingSessionId = $state("");

  let transcriptRaw = $state("");
  let transcriptLanguage = $state("");
  let transcriptEngine = $state("");

  let stageAProfile = $state("default");
  let stageAText = $state("");
  let stageAMetrics = $state("");

  let stageBMode = $state<"offline" | "online">("offline");
  let stageBProfile = $state("default");
  let stageBTemplate = $state("clinical-note");
  let stageBInput = $state("");
  let stageBOutput = $state("");

  let availableOfflineModels = $state<ModelRow[]>([]);
  let availableOnlineModels = $state<ModelRow[]>([]);
  let selectedOfflineModel = $state("qwen3-8b-q4");
  let selectedOnlineModel = $state("gpt-4o-mini");

  let providerEndpoint = $state("");
  let providerModel = $state("gpt-4o-mini");
  let providerApiKey = $state("");
  let offlineProviderEndpoint = $state("http://127.0.0.1:11434");
  let offlineProviderModel = $state("qwen3-8b-q4");
  let llmHealthText = $state("Not checked.");

  let preflight = $state<Record<string, unknown> | null>(null);
  let preflightDetailsJson = $state("");
  let preflightError = $state("");

  function formatUnknownError(error: unknown): string {
    if (error instanceof Error) return error.message;
    if (typeof error === "string") return error;
    try {
      return JSON.stringify(error);
    } catch {
      return "Unknown error";
    }
  }

  function buildConfig() {
    const config: Record<string, unknown> = {
      model,
      language,
      device,
      compute_type: computeType,
      diarization
    };
    if (hfToken.trim()) {
      config.hf_token = hfToken.trim();
    }
    return config;
  }

  async function chooseLocalMediaFile() {
    try {
      const selected = await openDialog({
        multiple: false,
        directory: false,
        filters: [
          {
            name: "Media",
            extensions: [
              "wav",
              "mp3",
              "m4a",
              "flac",
              "aac",
              "ogg",
              "mp4",
              "mov",
              "mkv",
              "webm",
              "avi"
            ]
          }
        ]
      });
      if (typeof selected === "string" && selected.trim()) {
        audioPath = selected.trim();
      }
    } catch (error) {
      errorText = formatUnknownError(error);
    }
  }

  function useMediaUrlAsSource() {
    const url = mediaUrl.trim();
    if (!url) return;
    audioPath = url;
  }

  async function callCommand<T = RpcEnvelope>(
    label: string,
    command: string,
    args: Record<string, unknown> = {}
  ): Promise<T | null> {
    isBusy = true;
    busyLabel = label;
    errorText = "";
    status = `${label}...`;
    try {
      const response = await invoke<T>(command, args);
      status = `${label}: OK`;
      return response;
    } catch (error) {
      errorText = formatUnknownError(error);
      status = `${label}: failed`;
      return null;
    } finally {
      isBusy = false;
      busyLabel = "";
    }
  }

  async function initSidecar() {
    await callCommand("Init sidecar", "init_sidecar", { config: buildConfig() });
  }

  async function startRecording() {
    const response = await callCommand<RpcEnvelope>("Start recording", "start_recording");
    const result = response?.result;
    if (!result) return;
    if (typeof result.status === "string") recordingState = result.status;
    if (typeof result.session_id === "string") recordingSessionId = result.session_id;
    if (typeof result.audio_path === "string" && result.audio_path.trim()) {
      audioPath = result.audio_path;
    }
  }

  async function stopRecording() {
    const response = await callCommand<RpcEnvelope>("Stop recording", "stop_recording");
    const result = response?.result;
    if (!result) return;
    if (typeof result.status === "string") recordingState = result.status;
    if (typeof result.session_id === "string") recordingSessionId = result.session_id;
    if (typeof result.audio_path === "string" && result.audio_path.trim()) {
      audioPath = result.audio_path;
    }
  }

  async function transcribeAudio() {
    transcriptRaw = "";
    stageAText = "";
    stageBOutput = "";
    const source = audioPath.trim();
    const response = await callCommand<RpcEnvelope>("Transcribe", "transcribe", {
      audio_path: source,
      audioPath: source
    });
    const result = response?.result;
    if (!result) return;
    if (typeof result.text === "string") transcriptRaw = result.text;
    if (typeof result.language === "string") transcriptLanguage = result.language;
    if (typeof result.engine === "string") transcriptEngine = result.engine;
    if (transcriptRaw.trim()) {
      await processStageA();
    }
  }

  async function processStageA() {
    const response = await callCommand<Record<string, unknown>>(
      "Stage A",
      "text_stage_a_process",
      {
        transcript: transcriptRaw,
        profile: stageAProfile
      }
    );
    if (!response) return;
    const text = response.text;
    if (typeof text === "string") {
      stageAText = text;
      stageBInput = text;
    }
    stageAMetrics = JSON.stringify(response.metrics ?? {}, null, 2);
  }

  async function loadModels() {
    const response = await callCommand<Record<string, unknown>>("Load models", "llm_get_models");
    if (!response) return;
    const offlineRows = Array.isArray(response.offline_models)
      ? (response.offline_models as Array<Record<string, unknown>>)
      : [];
    const onlineRows = Array.isArray(response.online_models)
      ? (response.online_models as Array<Record<string, unknown>>)
      : [];
    availableOfflineModels = offlineRows
      .map((row) => ({
        id: typeof row.id === "string" ? row.id : "",
        label: typeof row.label === "string" ? row.label : "",
        memory_hint_gb: typeof row.memory_hint_gb === "string" ? row.memory_hint_gb : undefined
      }))
      .filter((row) => row.id && row.label);
    availableOnlineModels = onlineRows
      .map((row) => ({
        id: typeof row.id === "string" ? row.id : "",
        label: typeof row.label === "string" ? row.label : ""
      }))
      .filter((row) => row.id && row.label);
    const selected = response.selected as Record<string, unknown> | undefined;
    if (selected && typeof selected.offline_model === "string") {
      selectedOfflineModel = selected.offline_model;
      offlineProviderModel = selected.offline_model;
    }
    if (selected && typeof selected.online_model === "string") {
      selectedOnlineModel = selected.online_model;
      providerModel = selected.online_model;
    }
    const offlineRuntime = response.offline_runtime as Record<string, unknown> | undefined;
    if (offlineRuntime && typeof offlineRuntime.default_endpoint === "string") {
      offlineProviderEndpoint = offlineRuntime.default_endpoint;
    }
  }

  async function setModel(mode: "offline" | "online", modelId: string) {
    if (!modelId.trim()) return;
    await callCommand("Set model", "llm_set_model", {
      mode,
      model_id: modelId
    });
  }

  async function registerOnlineProvider() {
    await callCommand("Register provider", "llm_register_provider", {
      provider_config: {
        mode: "online",
        endpoint: providerEndpoint.trim(),
        model: providerModel.trim(),
        api_key: providerApiKey.trim()
      }
    });
  }

  async function registerOfflineProvider() {
    await callCommand("Register provider", "llm_register_provider", {
      provider_config: {
        mode: "offline",
        endpoint: offlineProviderEndpoint.trim(),
        model: offlineProviderModel.trim()
      }
    });
  }

  async function checkLlmHealth() {
    const response = await callCommand<Record<string, unknown>>("LLM health", "llm_health", {
      mode: stageBMode
    });
    if (!response) return;
    llmHealthText = JSON.stringify(response, null, 2);
  }

  async function processStageB() {
    const response = await callCommand<Record<string, unknown>>(
      "Stage B",
      "llm_process_text_stage_b",
      {
        input: stageBInput,
        mode: stageBMode,
        profile: stageBProfile,
        template: stageBTemplate
      }
    );
    if (!response) return;
    if (typeof response.text === "string") {
      stageBOutput = response.text;
    }
  }

  async function runPreflight(details = false) {
    preflightError = "";
    const command = details ? "preflight_details" : "preflight_check";
    try {
      const response = await invoke<Record<string, unknown>>(command);
      preflight = response;
      preflightDetailsJson = JSON.stringify(response, null, 2);
    } catch (error) {
      preflightError = formatUnknownError(error);
    }
  }

  onMount(() => {
    void loadModels();
    void runPreflight();
  });
</script>

<main class="page">
  <section class="hero">
    <p class="eyebrow">Sandbox A004</p>
    <h1>STT + LLM Test Console</h1>
    <p class="sub">
      Stage A runs technical text cleanup immediately after transcription in ASR Window. Stage B runs
      medical/context processing in Text Window (offline or online).
    </p>
    <div class="status-row">
      <span class="chip" class:is-busy={isBusy}>
        {#if isBusy}
          Running: {busyLabel}
        {:else}
          {status}
        {/if}
      </span>
      <span class="chip neutral">Recording: {recordingState}</span>
      {#if recordingSessionId}
        <span class="chip neutral">Session: {recordingSessionId}</span>
      {/if}
    </div>
    {#if errorText}
      <p class="error">{errorText}</p>
    {/if}
  </section>

  <nav class="window-tabs" aria-label="Main windows">
    <button class:active={activeWindow === "asr"} onclick={() => (activeWindow = "asr")}>
      ASR Window
    </button>
    <button class:active={activeWindow === "text"} onclick={() => (activeWindow = "text")}>
      Text Window
    </button>
  </nav>

  {#if activeWindow === "asr"}
    <section class="panel">
      <h2>Startup Preflight</h2>
      <div class="row">
        <button onclick={() => runPreflight(false)}>Run preflight</button>
        <button onclick={() => runPreflight(true)}>Run detailed</button>
      </div>
      {#if preflight}
        <p class="meta">
          Overall: <strong>{String(preflight.overall_level ?? "INFO")}</strong> -
          {String(preflight.recommendation ?? "")}
        </p>
      {/if}
      {#if preflightError}
        <p class="error">{preflightError}</p>
      {/if}
      <textarea rows="8" readonly value={preflightDetailsJson}></textarea>
    </section>

    <section class="grid two">
      <article class="panel">
        <h2>Source + STT Controls</h2>
        <label>
          <span>Audio path / URL</span>
          <input bind:value={audioPath} />
        </label>
        <div class="row">
          <button onclick={chooseLocalMediaFile}>Choose file</button>
          <button onclick={() => (audioPath = "jfk.wav")}>Sample</button>
        </div>
        <label>
          <span>Media URL</span>
          <input bind:value={mediaUrl} placeholder="https://..." />
        </label>
        <button onclick={useMediaUrlAsSource}>Use URL as source</button>

        <div class="grid two">
          <label><span>Model</span><input bind:value={model} /></label>
          <label><span>Language</span><input bind:value={language} /></label>
          <label><span>Device</span><input bind:value={device} /></label>
          <label><span>Compute type</span><input bind:value={computeType} /></label>
        </div>
        <label><span>HF token (optional)</span><input bind:value={hfToken} type="password" /></label>
        <label class="checkbox"><input type="checkbox" bind:checked={diarization} /> Diarization</label>

        <div class="row">
          <button onclick={initSidecar}>Init sidecar</button>
          <button onclick={startRecording}>Start recording</button>
          <button onclick={stopRecording}>Stop recording</button>
          <button onclick={transcribeAudio}>Transcribe</button>
        </div>
        <p class="meta">
          Transcript language: {transcriptLanguage || "-"} | Engine: {transcriptEngine || "-"}
        </p>
        <textarea rows="10" bind:value={transcriptRaw}></textarea>
      </article>

      <article class="panel">
        <h2>Stage A - Technical Cleanup</h2>
        <label>
          <span>Profile</span>
          <input bind:value={stageAProfile} />
        </label>
        <div class="row">
          <button onclick={processStageA}>Process Stage A</button>
          <button onclick={() => (stageBInput = stageAText)}>Push to Stage B input</button>
        </div>
        <textarea rows="10" bind:value={stageAText}></textarea>
        <p class="meta">Metrics</p>
        <textarea rows="5" readonly value={stageAMetrics}></textarea>
      </article>
    </section>
  {:else}
    <section class="grid two">
      <article class="panel">
        <h2>Stage B - LLM Mode + Config</h2>
        <label>
          <span>Mode</span>
          <select
            bind:value={stageBMode}
            onchange={(event) => {
              const next = (event.currentTarget as HTMLSelectElement).value as "offline" | "online";
              stageBMode = next;
              void checkLlmHealth();
            }}
          >
            <option value="offline">offline</option>
            <option value="online">online</option>
          </select>
        </label>

        <label>
          <span>Offline model</span>
          <select
            bind:value={selectedOfflineModel}
            onchange={(event) => {
              const value = (event.currentTarget as HTMLSelectElement).value;
              selectedOfflineModel = value;
              offlineProviderModel = value;
              void setModel("offline", value);
            }}
          >
            {#each availableOfflineModels as row}
              <option value={row.id}>{row.label} ({row.memory_hint_gb ?? "-"} GB)</option>
            {/each}
          </select>
        </label>

        <label>
          <span>Online model</span>
          <select
            bind:value={selectedOnlineModel}
            onchange={(event) => {
              const value = (event.currentTarget as HTMLSelectElement).value;
              selectedOnlineModel = value;
              providerModel = value;
              void setModel("online", value);
            }}
          >
            {#each availableOnlineModels as row}
              <option value={row.id}>{row.label}</option>
            {/each}
          </select>
        </label>

        <h3>Online provider</h3>
        <label><span>Endpoint</span><input bind:value={providerEndpoint} /></label>
        <label><span>Model</span><input bind:value={providerModel} /></label>
        <label><span>API key</span><input bind:value={providerApiKey} type="password" /></label>
        <div class="row">
          <button onclick={registerOnlineProvider}>Register online provider</button>
        </div>

        <h3>Offline local provider (optional)</h3>
        <p class="meta">
          Use local OpenAI-compatible endpoint (for example Ollama on <code>127.0.0.1:11434</code>).
          If unavailable, app falls back to built-in rule mode.
        </p>
        <label><span>Local endpoint</span><input bind:value={offlineProviderEndpoint} /></label>
        <label><span>Local model</span><input bind:value={offlineProviderModel} /></label>
        <div class="row">
          <button onclick={registerOfflineProvider}>Register offline provider</button>
          <button onclick={checkLlmHealth}>Check LLM health</button>
        </div>
        <textarea rows="8" readonly value={llmHealthText}></textarea>
      </article>

      <article class="panel">
        <h2>Stage B - Text Processing</h2>
        <label><span>Profile</span><input bind:value={stageBProfile} /></label>
        <label><span>Template</span><input bind:value={stageBTemplate} /></label>
        <label for="stage-b-input"><span>Input</span></label>
        <textarea id="stage-b-input" rows="10" bind:value={stageBInput}></textarea>
        <div class="row">
          <button onclick={processStageB}>Process Stage B</button>
          <button
            onclick={() => {
              stageBOutput = "";
              errorText = "";
            }}
          >
            Clear output
          </button>
        </div>
        <label for="stage-b-output"><span>Output</span></label>
        <textarea id="stage-b-output" rows="12" bind:value={stageBOutput}></textarea>
      </article>
    </section>
  {/if}
</main>

<style>
  .page {
    padding: 1.25rem;
    max-width: 1200px;
    margin: 0 auto;
    display: grid;
    gap: 1rem;
  }
  .hero {
    background: linear-gradient(90deg, #eaf7ef 0%, #eef5fb 100%);
    border: 1px solid #cdd9e7;
    border-radius: 12px;
    padding: 1rem 1.1rem;
  }
  .eyebrow {
    margin: 0;
    text-transform: uppercase;
    color: #456;
    letter-spacing: 0.08em;
    font-size: 0.76rem;
  }
  h1 {
    margin: 0.25rem 0 0.45rem;
  }
  .sub {
    margin: 0;
    color: #34495e;
  }
  .status-row {
    margin-top: 0.65rem;
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }
  .chip {
    border: 1px solid #7ca27c;
    padding: 0.2rem 0.55rem;
    border-radius: 999px;
    background: #f0fff0;
    font-size: 0.85rem;
  }
  .chip.is-busy {
    border-color: #1f5f1f;
    background: #def7de;
  }
  .chip.neutral {
    border-color: #bfc7ce;
    background: #f6f8fa;
  }
  .error {
    color: #b00020;
    margin: 0.4rem 0 0;
  }
  .window-tabs {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.5rem;
  }
  .window-tabs button.active {
    background: #214a3d;
    color: #fff;
  }
  .panel {
    border: 1px solid #d6dce5;
    border-radius: 12px;
    padding: 0.95rem;
    background: #fff;
    display: grid;
    gap: 0.6rem;
  }
  .grid.two {
    display: grid;
    gap: 0.85rem;
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
  }
  label {
    display: grid;
    gap: 0.25rem;
    font-size: 0.9rem;
  }
  .checkbox {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  input,
  select,
  textarea,
  button {
    font: inherit;
  }
  input,
  select,
  textarea {
    border: 1px solid #bcc7d6;
    border-radius: 8px;
    padding: 0.45rem 0.55rem;
    background: #fff;
  }
  textarea {
    width: 100%;
    resize: vertical;
  }
  button {
    border: 1px solid #2d5c4f;
    background: #2d5c4f;
    color: #fff;
    border-radius: 9px;
    padding: 0.45rem 0.72rem;
    cursor: pointer;
  }
  button:hover {
    filter: brightness(1.06);
  }
  .meta {
    margin: 0;
    color: #4f5b67;
    font-size: 0.88rem;
  }
  @media (max-width: 980px) {
    .grid.two {
      grid-template-columns: 1fr;
    }
  }
</style>
