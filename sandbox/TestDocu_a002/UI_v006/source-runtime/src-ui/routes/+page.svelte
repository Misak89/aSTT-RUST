<script lang="ts">
  import { invokeCommand as invoke, openMediaFileDialog as openDialog } from "$lib/runtime-bridge";
  import { onMount } from "svelte";

  type RpcEnvelope = {
    jsonrpc?: string;
    id?: number;
    result?: Record<string, unknown>;
    error?: {
      code?: number;
      message?: string;
      data?: unknown;
    };
  };

  type Segment = {
    start?: number;
    end?: number;
    text?: string;
    speaker?: string;
  };

  let isBusy = $state(false);
  let busyLabel = $state("");
  let status = $state("Ready");
  let errorText = $state("");
  let rawResponse = $state("");

  let model = $state("base");
  let language = $state("cs");
  let device = $state("cpu");
  let computeType = $state("int8");
  let diarization = $state(false);
  let hfToken = $state("");

  let audioPath = $state("jfk.wav");
  let mediaUrl = $state("");
  let transcriptText = $state("");
  let transcriptLanguage = $state("");
  let transcriptEngine = $state("");
  let segments = $state<Segment[]>([]);
  let transcriptTextareaEl = $state<HTMLTextAreaElement | null>(null);
  let rawRpcTextareaEl = $state<HTMLTextAreaElement | null>(null);

  let recordingState = $state("idle");
  let recordingSessionId = $state("");
  let activeWindow = $state<"asr" | "service">("asr");

  let serviceReport = $state<any>(null);
  let serviceReportJson = $state("Not checked yet.");
  let serviceReportError = $state("");
  let serviceLoadedAt = $state("");
  let serviceLiveEnabled = $state(true);
  let serviceLiveIntervalMs = $state(3000);
  let serviceLiveStatus = $state<"checking" | "online" | "offline">("checking");
  let serviceLiveBusy = false;

  function setSampleAudioPath() {
    audioPath = "jfk.wav";
  }

  function autoResizeTextarea(el: HTMLTextAreaElement | null) {
    if (!el) return;
    el.style.height = "auto";
    const nextHeight = Math.max(el.scrollHeight, 140);
    el.style.height = `${nextHeight}px`;
  }

  $effect(() => {
    transcriptText;
    rawResponse;
    queueMicrotask(() => {
      autoResizeTextarea(transcriptTextareaEl);
      autoResizeTextarea(rawRpcTextareaEl);
    });
  });

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
        audioPath = selected;
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

  async function callCommand(
    label: string,
    command: string,
    args: Record<string, unknown> = {}
  ): Promise<RpcEnvelope | null> {
    isBusy = true;
    busyLabel = label;
    errorText = "";
    status = `${label}...`;
    try {
      const response = await invoke<RpcEnvelope>(command, args);
      rawResponse = JSON.stringify(response, null, 2);

      if (response?.error) {
        const code = response.error.code ?? "RPC";
        const message = response.error.message ?? "Unknown RPC error";
        errorText = `[${code}] ${message}`;
        status = `${label}: RPC error`;
      } else {
        status = `${label}: OK`;
      }
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
    const response = await callCommand("Init sidecar", "init_sidecar", {
      config: buildConfig()
    });
    const result = response?.result;
    if (result && typeof result.status === "string") {
      status = `Init: ${result.status}`;
    }
  }

  async function setConfig() {
    const response = await callCommand("Set config", "set_sidecar_config", {
      config: buildConfig()
    });
    const result = response?.result;
    if (result && typeof result.status === "string") {
      status = `Set config: ${result.status}`;
    }
  }

  async function getConfig() {
    await callCommand("Get config", "get_sidecar_config");
  }

  async function startRecording() {
    const response = await callCommand("Start recording", "start_recording");
    const result = response?.result;
    if (!result) return;

    if (typeof result.status === "string") {
      recordingState = result.status;
      status = `Recording: ${result.status}`;
    }
    if (typeof result.session_id === "string") {
      recordingSessionId = result.session_id;
    }
    if (typeof result.audio_path === "string" && result.audio_path.length > 0) {
      audioPath = result.audio_path;
    }
  }

  async function stopRecording() {
    const response = await callCommand("Stop recording", "stop_recording");
    const result = response?.result;
    if (!result) return;

    if (typeof result.status === "string") {
      recordingState = result.status;
      status = `Recording: ${result.status}`;
    }
    if (typeof result.session_id === "string") {
      recordingSessionId = result.session_id;
    }
    if (typeof result.audio_path === "string" && result.audio_path.length > 0) {
      audioPath = result.audio_path;
    }
  }

  async function transcribeAudio() {
    transcriptText = "";
    transcriptLanguage = "";
    transcriptEngine = "";
    segments = [];

    const args = {
      audioPath: audioPath.trim(),
      audio_path: audioPath.trim()
    };
    const response = await callCommand("Transcribe", "transcribe", args);
    const result = response?.result;
    if (!result) return;

    if (typeof result.status === "string") {
      status = `Transcribe: ${result.status}`;
    }
    if (typeof result.text === "string") {
      transcriptText = result.text;
    }
    if (typeof result.language === "string") {
      transcriptLanguage = result.language;
    }
    if (typeof result.engine === "string") {
      transcriptEngine = result.engine;
    }
    if (Array.isArray(result.segments)) {
      segments = result.segments as Segment[];
    }
  }

  function formatNumber(value: unknown, decimals = 1): string {
    if (typeof value !== "number" || Number.isNaN(value)) return "-";
    return value.toFixed(decimals);
  }

  function formatUnixMs(value: unknown): string {
    if (typeof value !== "number" || !Number.isFinite(value)) return "-";
    return new Date(value).toLocaleString();
  }

  function toFileUrl(path: string): string {
    const normalized = path.replace(/\\/g, "/");
    if (/^[A-Za-z]:\//.test(normalized)) {
      return encodeURI(`file:///${normalized}`);
    }
    if (normalized.startsWith("/")) {
      return encodeURI(`file://${normalized}`);
    }
    return encodeURI(`file:///${normalized}`);
  }

  function privacyPath(path: unknown): string {
    if (typeof path !== "string" || !path.trim()) return "-";
    const normalized = path.replace(/\\/g, "/");
    const marker = "/Dokumenty/";
    const idx = normalized.indexOf(marker);
    if (idx >= 0) {
      return normalized.slice(idx + 1).replace(/\//g, "\\");
    }
    return path;
  }

  async function refreshServiceReport() {
    serviceReportError = "";
    try {
      const response = await invoke<Record<string, unknown>>("demo_service_report");
      serviceReport = response;
      serviceReportJson = JSON.stringify(response, null, 2);
      serviceLoadedAt = new Date().toLocaleString();
      serviceLiveStatus = "online";
    } catch (error) {
      serviceLiveStatus = "offline";
      serviceReportError = formatUnknownError(error);
      serviceReportJson = `service report failed: ${formatUnknownError(error)}`;
    }
  }

  async function refreshLiveMetrics() {
    if (serviceLiveBusy) return;
    serviceLiveBusy = true;
    serviceLiveStatus = "checking";
    try {
      const response = await invoke<Record<string, unknown>>("demo_live_metrics");
      const previous =
        serviceReport && typeof serviceReport === "object"
          ? (serviceReport as Record<string, unknown>)
          : {};
      serviceReport = {
        ...previous,
        ...response,
        host:
          response && typeof response === "object" && "host" in response
            ? response.host
            : previous.host,
        component_load:
          response && typeof response === "object" && "component_load" in response
            ? response.component_load
            : previous.component_load
      };
      serviceReportJson = JSON.stringify(serviceReport, null, 2);
      serviceLoadedAt = new Date().toLocaleString();
      serviceReportError = "";
      serviceLiveStatus = "online";
    } catch (error) {
      serviceLiveStatus = "offline";
      serviceReportError = formatUnknownError(error);
    } finally {
      serviceLiveBusy = false;
    }
  }

  const measurementLogicRows = $derived.by(() => {
    const baseRows = Array.isArray(serviceReport?.measurement_logic_table)
      ? (serviceReport.measurement_logic_table as Array<Record<string, unknown>>)
      : Array.isArray(serviceReport?.measurement_logic)
        ? (serviceReport.measurement_logic as string[]).map((note) => ({
            metric: "General",
            source: "service report",
            mode: "info",
            interval_ms: "-",
            note
          }))
        : [];

    return [
      ...baseRows,
      {
        metric: "UI polling",
        source: "Svelte timer",
        mode: serviceLiveEnabled ? "online" : "paused",
        interval_ms: serviceLiveEnabled ? Math.max(1000, Number(serviceLiveIntervalMs) || 3000) : 0,
        note: "Calls demo_live_metrics periodically."
      }
    ];
  });
  const codeLinesByLanguage = $derived(
    Array.isArray(serviceReport?.code_lines_by_language)
      ? (serviceReport.code_lines_by_language as Array<Record<string, unknown>>)
      : []
  );
  const codeLinesScope = $derived(
    serviceReport && typeof serviceReport === "object" && serviceReport.code_lines_scope
      ? (serviceReport.code_lines_scope as Record<string, unknown>)
      : null
  );
  const codeLinesSourceRoots = $derived(
    Array.isArray(codeLinesScope?.source_roots)
      ? (codeLinesScope.source_roots as string[])
      : []
  );
  const codeLinesSourceRootsAbs = $derived(
    Array.isArray(codeLinesScope?.source_roots_abs)
      ? (codeLinesScope.source_roots_abs as string[])
      : []
  );
  const codeFilesByType = $derived(
    Array.isArray(codeLinesScope?.files_by_type)
      ? (codeLinesScope.files_by_type as Array<Record<string, unknown>>)
      : []
  );
  const technologyStack = $derived(
    Array.isArray(serviceReport?.technology_stack)
      ? (serviceReport.technology_stack as string[])
      : []
  );
  const frameworkCounts = $derived(
    Array.isArray(serviceReport?.framework_counts)
      ? (serviceReport.framework_counts as Array<Record<string, unknown>>)
      : []
  );
  const demoFiles = $derived(
    Array.isArray(serviceReport?.demo_files)
      ? (serviceReport.demo_files as Array<Record<string, unknown>>)
      : []
  );
  const componentLoad = $derived(
    Array.isArray(serviceReport?.component_load)
      ? (serviceReport.component_load as Array<Record<string, unknown>>)
      : []
  );

  onMount(() => {
    void refreshServiceReport();
  });

  $effect(() => {
    const shouldPoll = serviceLiveEnabled;
    const intervalMs = Math.max(1000, Number(serviceLiveIntervalMs) || 3000);
    if (!shouldPoll) return;
    void refreshLiveMetrics();
    const timer = setInterval(() => {
      void refreshLiveMetrics();
    }, intervalMs);
    return () => clearInterval(timer);
  });

  $effect(() => {
    if (activeWindow !== "service") return;
    void refreshServiceReport();
  });
</script>

<main class="page">
  <section class="hero">
    <p class="eyebrow">aSTT-RUST</p>
    <h1>ASR Control Panel</h1>
    <p class="sub">
      Desktop runtime -> Python sidecar (WhisperX) JSON-RPC workflow for init, recording and file
      transcription.
    </p>
    <p class="sub">
      Demo without STT:
      <a class="demo-link" href="/demo-a002">open /demo-a002</a>
    </p>
    <div class="status-row">
      <span class:is-busy={isBusy} class="chip">
        {#if isBusy}
          Running: {busyLabel}
        {:else}
          {status}
        {/if}
      </span>
      {#if recordingSessionId}
        <span class="chip neutral">Session: {recordingSessionId}</span>
      {/if}
      <span class="chip neutral">Recording: {recordingState}</span>
    </div>
    {#if errorText}
      <p class="error">{errorText}</p>
    {/if}
  </section>

  <nav class="window-tabs" aria-label="Main windows">
    <button class:active={activeWindow === "asr"} onclick={() => (activeWindow = "asr")}>
      ASR Window
    </button>
    <button
      class:active={activeWindow === "service"}
      onclick={() => (activeWindow = "service")}
    >
      Service Window
    </button>
  </nav>

  {#if activeWindow === "asr"}
  <section class="grid">
    <div class="panel">
      <h2>Sidecar Init / Config</h2>
      <div class="form-grid">
        <label>
          <span>Model</span>
          <input bind:value={model} placeholder="base" />
        </label>
        <label>
          <span>Language</span>
          <input bind:value={language} placeholder="cs" />
        </label>
        <label>
          <span>Device</span>
          <select bind:value={device}>
            <option value="cpu">cpu</option>
            <option value="cuda">cuda</option>
          </select>
        </label>
        <label>
          <span>Compute Type</span>
          <input bind:value={computeType} placeholder="int8" />
        </label>
      </div>
      <label class="full">
        <span>HF Token (optional for diarization)</span>
        <input bind:value={hfToken} type="password" placeholder="hf_..." />
      </label>
      <label class="toggle">
        <input bind:checked={diarization} type="checkbox" />
        <span>Enable diarization</span>
      </label>
      <div class="buttons">
        <button onclick={initSidecar} disabled={isBusy}>Init sidecar</button>
        <button onclick={setConfig} disabled={isBusy}>Set config</button>
        <button class="ghost" onclick={getConfig} disabled={isBusy}>Get config</button>
      </div>
    </div>

    <div class="panel">
      <h2>Audio Source</h2>
      <label class="full">
        <span>Audio/Video source path (local file path or http(s) link)</span>
        <input bind:value={audioPath} placeholder="C:\\path\\to\\audio.wav OR https://example.com/media.mp4" />
      </label>
      <label class="full">
        <span>Audio/Video link (direct URL)</span>
        <input bind:value={mediaUrl} placeholder="https://example.com/audio-or-video-file" />
      </label>
      <div class="buttons">
        <button class="ghost" onclick={chooseLocalMediaFile} disabled={isBusy}>
          Choose local media file
        </button>
        <button class="ghost" onclick={useMediaUrlAsSource} disabled={isBusy || !mediaUrl.trim()}>
          Use URL as source
        </button>
        <button class="ghost" onclick={setSampleAudioPath} disabled={isBusy}>Use sample jfk.wav</button>
        <button onclick={transcribeAudio} disabled={isBusy || !audioPath.trim()}>
          Transcribe file
        </button>
      </div>

      <hr />

      <h3>Microphone (sidecar-driven)</h3>
      <p class="hint">
        Requires Python `sounddevice` + PortAudio. `stop_recording` returns `audio_path`, which can be
        transcribed next.
      </p>
      <div class="buttons">
        <button onclick={startRecording} disabled={isBusy || recordingState === "recording"}>
          Start recording
        </button>
        <button class="warn" onclick={stopRecording} disabled={isBusy || recordingState !== "recording"}>
          Stop recording
        </button>
      </div>
    </div>

    <div class="panel output">
      <h2>Transcript Output</h2>
      <div class="meta">
        <span>Language: {transcriptLanguage || "-"}</span>
        <span>Engine: {transcriptEngine || "-"}</span>
        <span>Segments: {segments.length}</span>
      </div>
      <textarea
        bind:this={transcriptTextareaEl}
        readonly
        value={transcriptText}
        placeholder="Transcript text will appear here..."
      ></textarea>
      <div class="segment-list">
        {#if segments.length === 0}
          <p class="hint">No segments yet.</p>
        {:else}
          {#each segments as segment, index}
            <div class="segment">
              <div class="segment-head">
                <strong>#{index + 1}</strong>
                <span>{segment.speaker || "-"}</span>
                <span>{segment.start ?? 0}s -> {segment.end ?? 0}s</span>
              </div>
              <p>{segment.text || ""}</p>
            </div>
          {/each}
        {/if}
      </div>
    </div>

    <div class="panel output">
      <h2>Raw RPC Response</h2>
      <textarea
        bind:this={rawRpcTextareaEl}
        class="raw-rpc"
        readonly
        value={rawResponse || "No response yet."}
      ></textarea>
    </div>
  </section>
  {:else}
    <section class="panel service-panel">
      <div class="service-head">
        <h2>Service Window: HW + Code Analytics</h2>
        <div class="service-actions">
          <button onclick={refreshServiceReport}>Refresh Service Report</button>
          <label class="toggle-inline">
            <input type="checkbox" bind:checked={serviceLiveEnabled} />
            <span>Online HW</span>
          </label>
          <label class="inline-select">
            <span>Interval</span>
            <select bind:value={serviceLiveIntervalMs}>
              <option value={3000}>3 s</option>
              <option value={5000}>5 s</option>
              <option value={10000}>10 s</option>
            </select>
          </label>
          <span>Live: {serviceLiveStatus}</span>
          <span>Last update: {serviceLoadedAt || "-"}</span>
        </div>
      </div>

      {#if serviceReportError}
        <p class="error">{serviceReportError}</p>
      {/if}

      <div class="service-grid">
        <article class="service-card">
          <h3>Host + Requirements</h3>
          <p class="hint">
            OS: {serviceReport?.host?.os ?? "-"} / {serviceReport?.host?.arch ?? "-"}
            | Cores: {serviceReport?.host?.cpu_cores ?? "-"}
          </p>
          <p class="hint">
            Memory total: {formatNumber(serviceReport?.host?.total_memory_mb)} MB
            | used: {formatNumber(serviceReport?.host?.used_memory_mb)} MB
          </p>
          <p class="hint">
            No-STT min/recommended RAM:
            {serviceReport?.hw_requirements_estimate?.no_stt_demo?.minimum?.ram_gb ?? "-"} /
            {serviceReport?.hw_requirements_estimate?.no_stt_demo?.recommended?.ram_gb ?? "-"} GB
          </p>
          <p class="hint">
            STT CPU min/recommended RAM:
            {serviceReport?.hw_requirements_estimate?.stt_with_whisperx_cpu?.minimum?.ram_gb ?? "-"} /
            {serviceReport?.hw_requirements_estimate?.stt_with_whisperx_cpu?.recommended?.ram_gb ?? "-"} GB
          </p>
        </article>

        <article class="service-card">
          <h3>Measurement Logic</h3>
          {#if measurementLogicRows.length === 0}
            <p class="hint">No logic available.</p>
          {:else}
            <table>
              <thead>
                <tr>
                  <th>Metric</th>
                  <th>Source</th>
                  <th>Mode</th>
                  <th>Interval ms</th>
                  <th>Note</th>
                </tr>
              </thead>
              <tbody>
                {#each measurementLogicRows as row}
                  <tr>
                    <td>{row.metric ?? "-"}</td>
                    <td>{row.source ?? "-"}</td>
                    <td>{row.mode ?? "-"}</td>
                    <td>{row.interval_ms ?? "-"}</td>
                    <td>{row.note ?? "-"}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {/if}
        </article>
      </div>

      <div class="service-grid">
        <article class="service-card">
          <h3>Code Lines by Language</h3>
          <p class="hint">
            Current dir: {privacyPath(codeLinesScope?.current_working_dir)}
          </p>
          <p class="hint">
            Repo root: {privacyPath(codeLinesScope?.repo_root)}
          </p>
          <p class="hint">
            Count mode: {codeLinesScope?.count_mode ?? "-"}
            | Counted at: {formatUnixMs(codeLinesScope?.counted_at_unix_ms)}
          </p>
          <p class="hint">
            Scope policy: {codeLinesScope?.scope_policy ?? "-"}
          </p>
          <p class="hint">
            Tech stack:
            {#if technologyStack.length === 0}
              -
            {:else}
              {technologyStack.join(" | ")}
            {/if}
          </p>
          <p class="hint">
            Subdirs: {codeLinesScope?.subdirectories ?? "-"}
            | Scanned files: {codeLinesScope?.scanned_files ?? "-"}
            | Demo files: {codeLinesScope?.demo_files_count ?? "-"}
            | File types: {codeLinesScope?.file_types_total ?? "-"}
          </p>
          <p class="hint">
            Source roots:
            {#if codeLinesSourceRootsAbs.length === 0}
              -
            {:else}
              {codeLinesSourceRoots.join(" | ")}
            {/if}
          </p>
          <div class="path-links">
            {#if codeLinesSourceRootsAbs.length > 0}
              {#each codeLinesSourceRootsAbs as path}
                <a class="path-link" href={toFileUrl(path)} target="_blank" rel="noreferrer">
                  {privacyPath(path)}
                </a>
              {/each}
            {/if}
          </div>
          <table>
            <thead>
              <tr>
                <th>Language</th>
                <th>Lines</th>
                <th>Files</th>
              </tr>
            </thead>
            <tbody>
              {#if codeLinesByLanguage.length === 0}
                <tr>
                  <td colspan="3" class="hint">No data.</td>
                </tr>
              {:else}
                {#each codeLinesByLanguage as row}
                  <tr>
                    <td>{row.language ?? "-"}</td>
                    <td>{row.lines ?? "-"}</td>
                    <td>{row.files ?? "-"}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
          <h4>Files by Type</h4>
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Files</th>
              </tr>
            </thead>
            <tbody>
              {#if codeFilesByType.length === 0}
                <tr>
                  <td colspan="2" class="hint">No data.</td>
                </tr>
              {:else}
                {#each codeFilesByType as row}
                  <tr>
                    <td>{row.type ?? "-"}</td>
                    <td>{row.files ?? "-"}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
          <h4>Framework Counters</h4>
          <table>
            <thead>
              <tr>
                <th>Scope</th>
                <th>Lines</th>
                <th>Files</th>
              </tr>
            </thead>
            <tbody>
              {#if frameworkCounts.length === 0}
                <tr>
                  <td colspan="3" class="hint">No data.</td>
                </tr>
              {:else}
                {#each frameworkCounts as row}
                  <tr>
                    <td>{row.name ?? "-"}</td>
                    <td>{row.lines ?? "-"}</td>
                    <td>{row.files ?? "-"}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
          <h4>Latest Demo Files (Name + Saved Time)</h4>
          <table>
            <thead>
              <tr>
                <th>File</th>
                <th>Saved</th>
                <th>Lang</th>
                <th>Lines</th>
                <th>Type</th>
              </tr>
            </thead>
            <tbody>
              {#if demoFiles.length === 0}
                <tr>
                  <td colspan="5" class="hint">No data.</td>
                </tr>
              {:else}
                {#each demoFiles as row}
                  <tr>
                    <td>
                      <a
                        class="path-link"
                        href={toFileUrl(String(row.path_abs ?? ""))}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {privacyPath(row.path_abs)}
                      </a>
                    </td>
                    <td>{formatUnixMs(row.modified_unix_ms)}</td>
                    <td>{row.language ?? "-"}</td>
                    <td>{row.lines ?? "-"}</td>
                    <td>{row.file_type ?? "-"}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
        </article>

        <article class="service-card">
          <h3>Approx HW Load by Code Component</h3>
          <table>
            <thead>
              <tr>
                <th>Component</th>
                <th>Code Scope</th>
                <th>CPU %</th>
                <th>Memory MB</th>
                <th>Proc</th>
              </tr>
            </thead>
            <tbody>
              {#if componentLoad.length === 0}
                <tr>
                  <td colspan="5" class="hint">No data.</td>
                </tr>
              {:else}
                {#each componentLoad as row}
                  <tr>
                    <td>{row.component ?? "-"}</td>
                    <td>{row.approx_code_scope ?? "-"}</td>
                    <td>{formatNumber(row.cpu_percent, 2)}</td>
                    <td>{formatNumber(row.memory_mb, 1)}</td>
                    <td>{row.processes ?? "-"}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
        </article>
      </div>

      <h3>Raw Service Report</h3>
      <textarea class="raw-rpc" readonly value={serviceReportJson}></textarea>
    </section>
  {/if}
</main>

<style>
  :global(body) {
    margin: 0;
    background:
      radial-gradient(circle at 10% 10%, #c6f1e7 0%, transparent 40%),
      radial-gradient(circle at 90% 10%, #fde6c8 0%, transparent 35%),
      linear-gradient(180deg, #f4efe4 0%, #efe8d7 100%);
    color: #1f1b16;
    font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
  }

  .page {
    max-width: 1200px;
    margin: 0 auto;
    padding: 1.25rem;
  }

  .hero {
    background: rgba(255, 255, 255, 0.72);
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 1rem;
    padding: 1rem 1rem 0.8rem;
    box-shadow: 0 10px 24px rgba(40, 34, 25, 0.08);
  }

  .eyebrow {
    margin: 0;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #6a5946;
  }

  h1 {
    margin: 0.15rem 0 0;
    font-size: 1.8rem;
    line-height: 1.1;
  }

  h2 {
    margin: 0 0 0.7rem;
    font-size: 1.05rem;
  }

  h3 {
    margin: 0.8rem 0 0.35rem;
    font-size: 0.95rem;
  }

  h4 {
    margin: 0.75rem 0 0.35rem;
    font-size: 0.9rem;
  }

  .sub {
    margin: 0.4rem 0 0;
    color: #55493d;
  }

  .demo-link {
    color: #1f5b49;
    font-weight: 700;
    text-decoration: underline;
  }

  .window-tabs {
    margin-top: 0.9rem;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.6rem;
  }

  .window-tabs button {
    background: rgba(255, 255, 255, 0.82);
    color: #23463d;
    border-color: rgba(31, 27, 22, 0.16);
  }

  .window-tabs button.active {
    background: #23463d;
    color: #ffffff;
    border-color: #23463d;
  }

  .status-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
    margin-top: 0.7rem;
  }

  .chip {
    border-radius: 999px;
    padding: 0.35rem 0.65rem;
    font-size: 0.85rem;
    background: #eef7ef;
    border: 1px solid #b9d5bb;
  }

  .chip.is-busy {
    background: #fff2d6;
    border-color: #e9c67b;
  }

  .chip.neutral {
    background: rgba(255, 255, 255, 0.8);
    border-color: rgba(31, 27, 22, 0.12);
  }

  .error {
    margin: 0.65rem 0 0;
    color: #8f1f1f;
    background: #ffe1df;
    border: 1px solid #efb4ae;
    padding: 0.6rem 0.75rem;
    border-radius: 0.75rem;
  }

  .grid {
    margin-top: 1rem;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
    align-items: start;
  }

  .panel {
    background: rgba(255, 255, 255, 0.8);
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 1rem;
    padding: 0.9rem;
    box-shadow: 0 6px 18px rgba(40, 34, 25, 0.06);
  }

  .panel.output {
    grid-column: span 2;
  }

  .service-panel {
    margin-top: 1rem;
  }

  .service-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .service-actions {
    display: flex;
    gap: 0.6rem;
    align-items: center;
    flex-wrap: wrap;
    font-size: 0.85rem;
    color: #5e5144;
  }

  .toggle-inline {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    margin: 0;
  }

  .inline-select {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    margin: 0;
  }

  .inline-select select {
    min-width: 6.2rem;
  }

  .service-grid {
    margin-top: 0.8rem;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.8rem;
  }

  .service-card {
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 0.8rem;
    background: rgba(255, 255, 255, 0.65);
    padding: 0.7rem;
  }

  .path-links {
    display: grid;
    gap: 0.2rem;
    margin: 0.35rem 0 0.55rem;
  }

  .path-link {
    color: #1f5b49;
    text-decoration: underline;
    word-break: break-all;
    font-size: 0.82rem;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.6rem;
  }

  label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    font-size: 0.85rem;
    color: #4e4236;
  }

  label.full {
    margin-top: 0.6rem;
  }

  label.toggle {
    margin-top: 0.7rem;
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
  }

  input,
  select,
  button,
  textarea {
    font: inherit;
  }

  input,
  select,
  textarea {
    border: 1px solid rgba(31, 27, 22, 0.16);
    border-radius: 0.65rem;
    background: rgba(255, 255, 255, 0.95);
    padding: 0.55rem 0.7rem;
    color: #221d17;
  }

  textarea {
    width: 100%;
    min-height: 7rem;
    resize: vertical;
  }

  .buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.7rem;
  }

  button {
    border: 1px solid #23463d;
    background: #23463d;
    color: #fff;
    border-radius: 0.7rem;
    padding: 0.55rem 0.85rem;
    cursor: pointer;
    transition: transform 120ms ease, opacity 120ms ease, background-color 120ms ease;
  }

  button:hover:not(:disabled) {
    transform: translateY(-1px);
  }

  button:disabled {
    cursor: not-allowed;
    opacity: 0.55;
  }

  button.ghost {
    background: transparent;
    color: #23463d;
  }

  button.warn {
    background: #8a3828;
    border-color: #8a3828;
  }

  .hint {
    margin: 0;
    color: #6a5946;
    font-size: 0.85rem;
  }

  hr {
    border: none;
    border-top: 1px solid rgba(31, 27, 22, 0.1);
    margin: 0.95rem 0;
  }

  .meta {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    font-size: 0.85rem;
    color: #5e5144;
    margin-bottom: 0.5rem;
  }

  .segment-list {
    margin-top: 0.75rem;
    display: grid;
    gap: 0.5rem;
  }

  .segment {
    border: 1px solid rgba(31, 27, 22, 0.08);
    background: rgba(255, 255, 255, 0.7);
    border-radius: 0.7rem;
    padding: 0.55rem 0.65rem;
  }

  .segment-head {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
    font-size: 0.8rem;
    color: #5a4d40;
    margin-bottom: 0.2rem;
  }

  .segment p {
    margin: 0;
  }

  .raw-rpc {
    margin: 0;
    white-space: pre;
    word-break: break-word;
    background: #171717;
    color: #f1f1f1;
    border-radius: 0.75rem;
    padding: 0.7rem;
    min-height: 10rem;
    overflow: hidden;
    font-size: 0.8rem;
    font-family: Consolas, "Courier New", monospace;
  }

  @media (max-width: 900px) {
    .grid {
      grid-template-columns: 1fr;
    }

    .window-tabs {
      grid-template-columns: 1fr;
    }

    .service-grid {
      grid-template-columns: 1fr;
    }

    .panel.output {
      grid-column: span 1;
    }

    .form-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
