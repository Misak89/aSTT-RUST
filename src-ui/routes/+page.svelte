<script lang="ts">
  import {
    invokeCommand as invoke,
    listenRuntimeMenuActions,
    openMediaFileDialog as openDialog
  } from "$lib/runtime-bridge";
  import { goto } from "$app/navigation";
  import { onMount, tick } from "svelte";

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

  type ComponentLoadRow = {
    component: string;
    approx_code_scope: string;
    cpu_percent: number | null;
    memory_mb: number | null;
    processes: number;
    measurement_note?: string;
    diagnostic_status?: string;
    diagnostic_detail?: string;
    detection_mode?: string;
    pid_list: number[];
  };

  type ComponentLoadSample = {
    ts: number;
    component: string;
    cpu_percent: number | null;
    memory_mb: number | null;
    processes: number;
    diagnostic_status: string;
  };

  type ComponentAggregate = {
    component: string;
    sample_count: number;
    avg_cpu: number | null;
    peak_cpu: number | null;
    avg_memory: number | null;
    peak_memory: number | null;
    avg_processes: number;
    warning_samples: number;
  };

  type ComponentHistorySeries = {
    component: string;
    sample_count: number;
    from_ts: number;
    to_ts: number;
    latest_cpu: number | null;
    latest_memory: number | null;
    latest_processes: number;
    cpu_has_data: boolean;
    ram_has_data: boolean;
    cpu_max: number;
    ram_max: number;
    cpu_polyline: string;
    ram_polyline: string;
  };

  type SourcePreview = {
    kind: "youtube" | "video" | "audio" | null;
    src: string;
    hint: string;
  };

  const MODEL_OPTIONS = ["tiny", "base", "small", "medium", "large-v3"];
  const LANGUAGE_OPTIONS = [
    { value: "auto", label: "auto" },
    { value: "cs", label: "cs" },
    { value: "en", label: "en" },
    { value: "sk", label: "sk" },
    { value: "de", label: "de" },
    { value: "pl", label: "pl" }
  ];
  const COMPUTE_TYPE_OPTIONS = ["int8", "int8_float16", "float16", "float32"];

  let isBusy = $state(false);
  let busyLabel = $state("");
  let status = $state("Ready");
  let errorText = $state("");
  let rawResponse = $state("");

  let model = $state("large-v3");
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
  let transcriptTotalElapsedMs = $state<number | null>(null);
  let transcriptFirstWordLatencyMs = $state<number | null>(null);
  let transcriptFirstWordToDisplayMs = $state<number | null>(null);
  let transcriptLatencyBudgetOk = $state<boolean | null>(null);
  let transcriptFirstSegmentStartS = $state<number | null>(null);
  let lastTranscribeClipSeconds = $state<number | null>(null);
  let lastTranscribeSourceKind = $state<"url" | "file" | null>(null);
  let transcriptLastSavedPath = $state("");
  let transcriptLastExportDir = $state("");
  let segments = $state<Segment[]>([]);
  let transcriptTextareaEl = $state<HTMLTextAreaElement | null>(null);
  let rawRpcTextareaEl = $state<HTMLTextAreaElement | null>(null);
  let previewVideoEl = $state<HTMLVideoElement | null>(null);
  let previewAudioEl = $state<HTMLAudioElement | null>(null);

  let timedClipSeconds = $state(180);
  let lowLatencyVideoMode = $state(false);
  let lowLatencyVideoSeconds = $state(5);
  let fastUrlPreviewEnabled = $state(true);
  let fastUrlPreviewSeconds = $state(8);
  let timedRunArmed = $state(false);
  let timedCountdownActive = $state(false);
  let timedSecondsRemaining = $state(0);
  let timedRunStartedAtMs = $state<number | null>(null);
  let timedRunTargetSeconds = $state(0);
  let timedFinalizeBusy = $state(false);
  let autoSaveTimedRun = $state(true);
  let previewAutoplayNonce = $state(0);
  let previewVolumePercent = $state(80);
  let previewMuted = $state(false);
  let previewIsPlaying = $state(false);
  let timedCountdownTimer: ReturnType<typeof setInterval> | null = null;

  let recordingState = $state("idle");
  let recordingSessionId = $state("");
  let autoTranscribeMic = $state(true);
  let autoMicQuickSeconds = $state(3);
  let activeWindow = $state<"asr" | "service">("asr");

  let serviceReport = $state<any>(null);
  let serviceReportJson = $state("Not checked yet.");
  let serviceReportError = $state("");
  let serviceLoadedAt = $state("");
  let serviceLiveEnabled = $state(true);
  let serviceLiveIntervalMs = $state(3000);
  let serviceLiveStatus = $state<"checking" | "online" | "offline">("checking");
  let serviceLiveBusy = false;
  let serviceScopePath = $state("");
  let componentSamplesRecent = $state<ComponentLoadSample[]>([]);
  let componentSamplesAll = $state<ComponentLoadSample[]>([]);
  let runtimeMonitorLines = $state<string[]>([]);

  const HW_HISTORY_WINDOW_MS = 35 * 60 * 1000;
  const MAX_HW_SAMPLES_ALL = 60_000;
  const MAX_RUNTIME_MONITOR_LINES = 220;

  function addRuntimeMonitor(message: string) {
    const ts = new Date().toLocaleTimeString();
    runtimeMonitorLines = [...runtimeMonitorLines, `${ts} | ${message}`].slice(
      -MAX_RUNTIME_MONITOR_LINES
    );
  }

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

  $effect(() => {
    previewVideoEl;
    previewAudioEl;
    previewVolumePercent;
    previewMuted;
    applyPreviewAudioSettings();
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

  function normalizeTimedSeconds(): number {
    const parsed = Number(timedClipSeconds);
    if (!Number.isFinite(parsed)) return 180;
    return Math.min(3600, Math.max(5, Math.trunc(parsed)));
  }

  function normalizeLowLatencySeconds(): number {
    const parsed = Number(lowLatencyVideoSeconds);
    if (!Number.isFinite(parsed)) return 5;
    return Math.min(300, Math.max(3, Math.trunc(parsed)));
  }

  function normalizeFastUrlPreviewSeconds(): number {
    const parsed = Number(fastUrlPreviewSeconds);
    if (!Number.isFinite(parsed)) return 8;
    return Math.min(20, Math.max(3, Math.trunc(parsed)));
  }

  function formatCountdown(seconds: number): string {
    const safe = Math.max(0, Math.trunc(seconds));
    const mm = Math.floor(safe / 60)
      .toString()
      .padStart(2, "0");
    const ss = (safe % 60).toString().padStart(2, "0");
    return `${mm}:${ss}`;
  }

  function clampPreviewVolumePercent(value: number): number {
    if (!Number.isFinite(value)) return 80;
    return Math.min(100, Math.max(0, Math.trunc(value)));
  }

  function applyPreviewAudioSettings() {
    const normalizedPercent = clampPreviewVolumePercent(Number(previewVolumePercent));
    if (normalizedPercent !== previewVolumePercent) {
      previewVolumePercent = normalizedPercent;
    }
    const normalizedVolume = normalizedPercent / 100;
    if (previewVideoEl) {
      previewVideoEl.volume = normalizedVolume;
      previewVideoEl.muted = previewMuted;
    }
    if (previewAudioEl) {
      previewAudioEl.volume = normalizedVolume;
      previewAudioEl.muted = previewMuted;
    }
  }

  function refreshPreviewPlaybackState() {
    const videoPlaying = previewVideoEl ? !previewVideoEl.paused && !previewVideoEl.ended : false;
    const audioPlaying = previewAudioEl ? !previewAudioEl.paused && !previewAudioEl.ended : false;
    previewIsPlaying = videoPlaying || audioPlaying;
  }

  function handlePreviewPlay() {
    previewIsPlaying = true;
  }

  function handlePreviewPause() {
    refreshPreviewPlaybackState();
  }

  function togglePreviewMuted() {
    previewMuted = !previewMuted;
    if (!previewMuted && previewVolumePercent <= 0) {
      previewVolumePercent = 10;
    }
    applyPreviewAudioSettings();
  }

  function stopTimedCountdown() {
    if (timedCountdownTimer) {
      clearInterval(timedCountdownTimer);
      timedCountdownTimer = null;
    }
    timedCountdownActive = false;
  }

  function pausePreviewPlayback() {
    if (previewVideoEl) {
      previewVideoEl.pause();
      previewVideoEl.currentTime = 0;
    }
    if (previewAudioEl) {
      previewAudioEl.pause();
      previewAudioEl.currentTime = 0;
    }
    previewIsPlaying = false;
  }

  function armTimedSourceRun() {
    timedClipSeconds = normalizeTimedSeconds();
    timedRunArmed = true;
    timedRunTargetSeconds = 0;
    timedRunStartedAtMs = null;
    timedFinalizeBusy = false;
    status = `Timed run armed: ${timedClipSeconds}s. Use final Start click.`;
  }

  async function startPreviewPlaybackNow() {
    previewMuted = false;
    if (previewVolumePercent <= 0) {
      previewVolumePercent = 35;
    }
    applyPreviewAudioSettings();

    if (sourcePreview.kind === "youtube") {
      // Force iframe src refresh with autoplay=1 exactly on final user click.
      previewAutoplayNonce += 1;
      previewIsPlaying = true;
      return;
    }

    try {
      if (sourcePreview.kind === "video" && previewVideoEl) {
        previewVideoEl.currentTime = 0;
        await previewVideoEl.play();
        refreshPreviewPlaybackState();
        return;
      }
      if (sourcePreview.kind === "audio" && previewAudioEl) {
        previewAudioEl.currentTime = 0;
        await previewAudioEl.play();
        refreshPreviewPlaybackState();
      }
    } catch (error) {
      previewIsPlaying = false;
      errorText = `Preview playback failed: ${formatUnknownError(error)}`;
    }
  }

  async function transcribeFromSourceButton() {
    try {
      await startPreviewPlaybackNow();
    } catch {
      // Preview autoplay is best-effort.
    }
    await transcribeAudio();
  }

  function currentTimedCapturedSeconds(): number {
    const target = timedRunTargetSeconds > 0 ? timedRunTargetSeconds : normalizeTimedSeconds();
    if (timedRunStartedAtMs === null) {
      return Math.max(1, target);
    }
    const elapsed = Math.ceil((Date.now() - timedRunStartedAtMs) / 1000);
    return Math.max(1, Math.min(target, elapsed));
  }

  async function finalizeTimedSourceRun(reason: "manual-stop" | "timer-expired") {
    if (timedFinalizeBusy) return;
    if (!timedCountdownActive && timedRunStartedAtMs === null) return;

    timedFinalizeBusy = true;
    const capturedSeconds = currentTimedCapturedSeconds();

    stopTimedCaptureWithoutTranscribe();

    addRuntimeMonitor(`Timed run ${reason}: captured=${capturedSeconds}s -> transcribe`);
    status = `Timed run stopped, transcribing ${capturedSeconds}s...`;

    try {
      await transcribeAudio(capturedSeconds, `Transcription in progress (${capturedSeconds}s captured)...`);
      if (autoSaveTimedRun) {
        await saveTranscriptTxt();
      }
    } finally {
      timedFinalizeBusy = false;
    }
  }

  function startTimedCountdown(totalSeconds: number) {
    stopTimedCountdown();
    timedSecondsRemaining = totalSeconds;
    timedCountdownActive = true;
    timedCountdownTimer = setInterval(() => {
      timedSecondsRemaining = Math.max(0, timedSecondsRemaining - 1);
      if (timedSecondsRemaining <= 0) {
        void finalizeTimedSourceRun("timer-expired");
      }
    }, 1000);
  }

  function stopTimedCaptureWithoutTranscribe(): number {
    const capturedSeconds = currentTimedCapturedSeconds();
    stopTimedCountdown();
    pausePreviewPlayback();
    timedRunArmed = false;
    timedRunStartedAtMs = null;
    timedRunTargetSeconds = 0;
    timedSecondsRemaining = 0;
    return capturedSeconds;
  }

  function stopTimedSourceRunOnly() {
    if (!timedCountdownActive && !timedRunArmed) return;
    const capturedSeconds = stopTimedCaptureWithoutTranscribe();
    status = `Timed capture stopped at ${capturedSeconds}s.`;
    addRuntimeMonitor(`Timed run stopped manually at ${capturedSeconds}s (no transcribe).`);
  }

  async function finishTimedSourceRunNow() {
    if (!timedCountdownActive && !timedRunArmed) return;
    await finalizeTimedSourceRun("manual-stop");
  }

  function cancelTimedSourceRun() {
    stopTimedSourceRunOnly();
  }

  function isHttpUrl(value: string): boolean {
    return /^https?:\/\//i.test(value.trim());
  }

  function extractYouTubeVideoId(value: string): string | null {
    const raw = value.trim();
    if (!raw) return null;
    try {
      const parsed = new URL(raw);
      const host = parsed.hostname.toLowerCase();
      if (host.includes("youtu.be")) {
        const id = parsed.pathname.replace(/^\/+/, "").split("/")[0];
        return id || null;
      }
      if (host.includes("youtube.com")) {
        const fromWatch = parsed.searchParams.get("v");
        if (fromWatch) return fromWatch;
        const pieces = parsed.pathname.split("/").filter(Boolean);
        const embedIdx = pieces.findIndex((p) => p === "embed");
        if (embedIdx >= 0 && pieces[embedIdx + 1]) return pieces[embedIdx + 1];
        const shortsIdx = pieces.findIndex((p) => p === "shorts");
        if (shortsIdx >= 0 && pieces[shortsIdx + 1]) return pieces[shortsIdx + 1];
      }
      return null;
    } catch {
      return null;
    }
  }

  function inferMediaKind(value: string): "audio" | "video" | null {
    const lowered = value.toLowerCase();
    if (/\.(wav|mp3|m4a|flac|aac|ogg)(\?|#|$)/.test(lowered)) return "audio";
    if (/\.(mp4|mov|mkv|webm|avi)(\?|#|$)/.test(lowered)) return "video";
    return null;
  }

  function sanitizeExportLabel(value: string): string {
    const sanitized = value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .replace(/_+/g, "_");
    if (!sanitized) return "transcript";
    return sanitized.slice(0, 80).replace(/_+$/g, "") || "transcript";
  }

  function buildTranscriptFileLabel(): string {
    const source = audioPath.trim();
    const typedUrl = mediaUrl.trim();
    const youtubeId = extractYouTubeVideoId(source) || extractYouTubeVideoId(typedUrl);
    if (youtubeId) {
      return sanitizeExportLabel(`youtube_${youtubeId}`);
    }

    if (isHttpUrl(source)) {
      try {
        const parsed = new URL(source);
        const pathParts = parsed.pathname
          .split("/")
          .map((part) => part.trim())
          .filter(Boolean);
        const fromPath = pathParts.length > 0 ? pathParts[pathParts.length - 1] : parsed.hostname;
        return sanitizeExportLabel(fromPath || parsed.hostname || "remote_source");
      } catch {
        return sanitizeExportLabel(source);
      }
    }

    const filename = source.split(/[\\/]/).pop() ?? source;
    const stem = filename.replace(/\.[^.]+$/, "");
    return sanitizeExportLabel(stem || "local_source");
  }

  function parseRawResponseForExport(): unknown {
    const raw = rawResponse.trim();
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return { raw_text: raw };
    }
  }

  function buildTranscriptSettingsSnapshot(): Record<string, unknown> {
    const source = audioPath.trim();
    const normalizedLowLatencySeconds = normalizeLowLatencySeconds();
    const normalizedFastUrlPreviewSeconds = normalizeFastUrlPreviewSeconds();
    const normalizedTimedSeconds = normalizeTimedSeconds();

    return {
      export_created_at_iso: new Date().toISOString(),
      source: {
        audio_path: source,
        media_url: mediaUrl.trim(),
        source_kind: lastTranscribeSourceKind,
        is_http: isHttpUrl(source),
        youtube_id: extractYouTubeVideoId(source) || extractYouTubeVideoId(mediaUrl.trim()),
        inferred_media_kind: inferMediaKind(source)
      },
      stt_config: {
        model,
        language,
        device,
        compute_type: computeType,
        diarization,
        hf_token_set: Boolean(hfToken.trim())
      },
      run_options: {
        low_latency_video_mode: lowLatencyVideoMode,
        low_latency_video_seconds: normalizedLowLatencySeconds,
        fast_url_preview_enabled: fastUrlPreviewEnabled,
        fast_url_preview_seconds: normalizedFastUrlPreviewSeconds,
        timed_clip_seconds_target: normalizedTimedSeconds,
        timed_auto_save_txt: autoSaveTimedRun,
        auto_transcribe_mic: autoTranscribeMic,
        auto_mic_quick_seconds: autoMicQuickSeconds,
        last_transcribe_clip_seconds: lastTranscribeClipSeconds
      },
      transcript_metrics: {
        transcript_language: transcriptLanguage || null,
        transcript_engine: transcriptEngine || null,
        segments_count: segments.length,
        first_word_latency_ms: transcriptFirstWordLatencyMs,
        first_word_to_ui_ms: transcriptFirstWordToDisplayMs,
        total_elapsed_ms: transcriptTotalElapsedMs,
        first_segment_start_s: transcriptFirstSegmentStartS,
        latency_budget_ok: transcriptLatencyBudgetOk
      },
      runtime_state: {
        status,
        recording_state: recordingState
      },
      runtime_monitor_tail: runtimeMonitorLines.slice(-60)
    };
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

  function canSaveCurrentTranscript(): boolean {
    const trimmed = transcriptText.trim();
    if (!trimmed) return false;
    if (trimmed.startsWith("[Error]")) return false;
    if (trimmed.startsWith("[Info]")) return false;
    if (trimmed.toLowerCase().startsWith("transcription in progress")) return false;
    if (trimmed.toLowerCase().startsWith("mic quick transcript in progress")) return false;
    return true;
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

  function buildQuickMicConfig() {
    const cfg: Record<string, unknown> = {
      model: "tiny",
      language: language?.trim() || "cs",
      device,
      compute_type: device === "cuda" || device === "mps" ? "float16" : "int8",
      diarization: false
    };
    return cfg;
  }

  function buildQuickUrlPreviewConfig() {
    const cfg: Record<string, unknown> = {
      model: "tiny",
      language: language?.trim() || "cs",
      device,
      compute_type: device === "cuda" || device === "mps" ? "float16" : "int8",
      diarization: false
    };
    return cfg;
  }

  function applyLowLatencyPreset() {
    model = "tiny";
    computeType = device === "cuda" || device === "mps" ? "float16" : "int8";
    lowLatencyVideoMode = true;
    lowLatencyVideoSeconds = 5;
    status = `Low-latency preset applied: model=${model}, auto URL clip=${lowLatencyVideoSeconds}s`;
    addRuntimeMonitor(
      `Low-latency preset -> model=${model}, device=${device}, compute=${computeType}, clip=${lowLatencyVideoSeconds}s`
    );
  }

  function applyCzQualityPreset() {
    model = "large-v3";
    language = "cs";
    computeType = device === "cuda" || device === "mps" ? "float16" : "int8";
    lowLatencyVideoMode = false;
    status = `CZ quality preset applied: model=${model}, language=${language}, compute=${computeType}`;
    addRuntimeMonitor(
      `CZ quality preset -> model=${model}, language=${language}, device=${device}, compute=${computeType}`
    );
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
    const startedAtMs = Date.now();
    addRuntimeMonitor(`${label} START (${command})`);
    try {
      const response = await invoke<RpcEnvelope>(command, args);
      rawResponse = JSON.stringify(response, null, 2);
      const elapsedMs = Date.now() - startedAtMs;

      if (response?.error) {
        const code = response.error.code ?? "RPC";
        const message = response.error.message ?? "Unknown RPC error";
        errorText = `[${code}] ${message}`;
        status = `${label}: RPC error`;
        addRuntimeMonitor(`${label} ERROR in ${elapsedMs} ms -> [${code}] ${message}`);
      } else {
        status = `${label}: OK`;
        const resultStatus = response?.result?.status;
        const resultText = typeof resultStatus === "string" ? ` status=${resultStatus}` : "";
        addRuntimeMonitor(`${label} OK in ${elapsedMs} ms${resultText}`);
      }
      return response;
    } catch (error) {
      errorText = formatUnknownError(error);
      status = `${label}: failed`;
      const elapsedMs = Date.now() - startedAtMs;
      addRuntimeMonitor(`${label} FAILED in ${elapsedMs} ms -> ${errorText}`);
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

  async function abortCurrentRequestHard() {
    if (!isBusy) {
      addRuntimeMonitor("Abort clicked while idle: no active init/transcribe request.");
      status = "Abort ignored (idle).";
      return;
    }

    const hadSavableTranscript = canSaveCurrentTranscript();
    addRuntimeMonitor("Abort requested by user (hard).");
    stopTimedCountdown();
    pausePreviewPlayback();
    timedRunArmed = false;
    timedRunStartedAtMs = null;
    timedRunTargetSeconds = 0;
    timedSecondsRemaining = 0;
    timedFinalizeBusy = false;

    try {
      const response = await invoke<Record<string, unknown>>("abort_current_request");
      const raw = JSON.stringify(response, null, 2);
      rawResponse = raw;
      status = hadSavableTranscript
        ? "Abort requested. Saving current transcript..."
        : "Abort requested.";
      errorText = "";
      addRuntimeMonitor("Abort request sent.");

      if (hadSavableTranscript) {
        await saveTranscriptTxt();
      } else {
        addRuntimeMonitor("Abort: no transcript text was available to save yet.");
      }
    } catch (error) {
      const message = formatUnknownError(error);
      errorText = message;
      addRuntimeMonitor(`Abort request failed -> ${message}`);
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
    let hasOutputAudio = false;

    if (typeof result.status === "string") {
      recordingState = result.status;
      status = `Recording: ${result.status}`;
    }
    if (typeof result.session_id === "string") {
      recordingSessionId = result.session_id;
    }
    if (typeof result.audio_path === "string" && result.audio_path.length > 0) {
      audioPath = result.audio_path;
      hasOutputAudio = true;
    }

    if (autoTranscribeMic && hasOutputAudio && recordingState.toLowerCase() === "stopped") {
      const quickSeconds = Math.max(2, Math.min(10, Math.trunc(Number(autoMicQuickSeconds) || 3)));
      autoMicQuickSeconds = quickSeconds;
      addRuntimeMonitor(`Auto MIC quick init (tiny) + quick transcript (${quickSeconds}s)`);
      await callCommand("Init sidecar (MIC quick)", "init_sidecar", {
        config: buildQuickMicConfig()
      });
      await transcribeAudio(quickSeconds, `MIC quick transcript in progress (${quickSeconds}s)...`);
      addRuntimeMonitor("Auto MIC quick transcript finished (refine is manual)");
    }
  }

  async function transcribeAudio(
    clipSeconds?: number,
    startMessage = "Transcription in progress..."
  ) {
    const uiRequestStartedAtMs = Date.now();
    transcriptText = startMessage;
    transcriptLanguage = "";
    transcriptEngine = "";
    transcriptTotalElapsedMs = null;
    transcriptFirstWordLatencyMs = null;
    transcriptFirstWordToDisplayMs = null;
    transcriptLatencyBudgetOk = null;
    transcriptFirstSegmentStartS = null;
    segments = [];

    const sourceValue = audioPath.trim();
    const normalizedLowLatencySeconds = normalizeLowLatencySeconds();
    const normalizedFastPreviewSeconds = normalizeFastUrlPreviewSeconds();
    if (normalizedLowLatencySeconds !== lowLatencyVideoSeconds) {
      lowLatencyVideoSeconds = normalizedLowLatencySeconds;
    }
    if (normalizedFastPreviewSeconds !== fastUrlPreviewSeconds) {
      fastUrlPreviewSeconds = normalizedFastPreviewSeconds;
    }

    const explicitClip =
      typeof clipSeconds === "number" && Number.isFinite(clipSeconds) && clipSeconds > 0
        ? Math.trunc(clipSeconds)
        : null;
    const autoLowLatencyClip =
      explicitClip === null && lowLatencyVideoMode && isHttpUrl(sourceValue)
        ? normalizedLowLatencySeconds
        : null;
    const normalizedClip = explicitClip ?? autoLowLatencyClip;
    lastTranscribeClipSeconds = normalizedClip;
    lastTranscribeSourceKind = isHttpUrl(sourceValue) ? "url" : "file";
    addRuntimeMonitor(
      `Init config model=${model}, language=${language}, device=${device}, compute=${computeType}, diarization=${diarization}`
    );
    addRuntimeMonitor(
      `Transcribe request source=${isHttpUrl(sourceValue) ? "url" : "file"} clip=${normalizedClip ?? "full-source"}`
    );
    if (normalizedClip !== null && normalizedClip <= 5) {
      addRuntimeMonitor("Notice: clip<=5s, output will likely be only 1-2 short sentences.");
    }
    if (
      device === "cpu" &&
      (model === "medium" || model === "large-v3") &&
      (normalizedClip === null || normalizedClip >= 45)
    ) {
      addRuntimeMonitor(
        "Warning: CPU + medium/large + longer clip can delay first full result by tens of seconds to minutes."
      );
    }

    const shouldRunFastUrlPreview =
      fastUrlPreviewEnabled &&
      isHttpUrl(sourceValue) &&
      model !== "tiny" &&
      (normalizedClip === null || normalizedClip > normalizedFastPreviewSeconds);
    if (shouldRunFastUrlPreview) {
      addRuntimeMonitor(
        `Fast URL preview pass enabled -> tiny/${normalizedFastPreviewSeconds}s (full pass keeps your selected model).`
      );
      const quickInitResponse = await callCommand("Init sidecar (URL quick preview)", "init_sidecar", {
        config: buildQuickUrlPreviewConfig()
      });
      const quickInitResult = quickInitResponse?.result;
      const quickInitOk =
        Boolean(quickInitResponse) &&
        Boolean(quickInitResult) &&
        !(typeof quickInitResult?.status === "string" && quickInitResult.status === "error");

      if (quickInitOk) {
        const quickArgs: Record<string, unknown> = {
          audioPath: sourceValue,
          audio_path: sourceValue,
          clip_seconds: normalizedFastPreviewSeconds,
          clipSeconds: normalizedFastPreviewSeconds
        };
        const quickResponse = await callCommand("Transcribe (URL quick preview)", "transcribe", quickArgs);
        const quickResult = quickResponse?.result;
        if (quickResult && typeof quickResult.text === "string" && quickResult.text.trim()) {
          transcriptText = `[Quick preview tiny/${normalizedFastPreviewSeconds}s]\n${quickResult.text.trim()}\n\n[Full pass running...]`;
          if (typeof quickResult.language === "string") {
            transcriptLanguage = quickResult.language;
          }
          if (typeof quickResult.engine === "string") {
            transcriptEngine = quickResult.engine;
          }
          if (Array.isArray(quickResult.segments)) {
            segments = quickResult.segments as Segment[];
          }
          addRuntimeMonitor("Fast URL preview produced initial text.");
        } else {
          addRuntimeMonitor("Fast URL preview finished, but returned empty text.");
        }
      } else {
        addRuntimeMonitor("Fast URL preview init failed; continuing with normal pass.");
      }
    }

    const initResponse = await callCommand("Init sidecar (auto)", "init_sidecar", {
      config: buildConfig()
    });
    const initResult = initResponse?.result;
    if (!initResponse || !initResult || (typeof initResult.status === "string" && initResult.status === "error")) {
      transcriptText = `[Error] Sidecar init failed before transcribe. ${errorText || ""}`.trim();
      return;
    }

    const args: Record<string, unknown> = {
      audioPath: sourceValue,
      audio_path: sourceValue,
      ...(normalizedClip ? { clip_seconds: normalizedClip, clipSeconds: normalizedClip } : {})
    };
    const transcribeUiStartedAtMs = Date.now();
    const response = await callCommand("Transcribe", "transcribe", args);
    if (!response) {
      const fallbackError = errorText.trim() || "No response from runtime.";
      transcriptText = `[Error] ${fallbackError}`;
      return;
    }
    const result = response?.result;
    if (!result) {
      const fallbackError = errorText.trim() || "No result payload returned.";
      transcriptText = `[Error] ${fallbackError}`;
      return;
    }

    if (typeof result.status === "string") {
      status = `Transcribe: ${result.status}`;
      if (result.status === "error" && typeof result.message === "string") {
        errorText = result.message;
        transcriptText = `[Error] ${result.message}`;
      }
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
    const timing =
      result.timing && typeof result.timing === "object"
        ? (result.timing as Record<string, unknown>)
        : null;
    if (timing) {
      const totalElapsed = toFiniteNumber(timing.total_elapsed_ms);
      if (totalElapsed !== null) transcriptTotalElapsedMs = Math.max(0, Math.trunc(totalElapsed));

      const firstWordLatency = toFiniteNumber(timing.first_word_latency_ms);
      if (firstWordLatency !== null) {
        transcriptFirstWordLatencyMs = Math.max(0, Math.trunc(firstWordLatency));
      }

      const firstSegmentStart = toFiniteNumber(timing.first_segment_start_s);
      if (firstSegmentStart !== null) {
        transcriptFirstSegmentStartS = Math.max(0, firstSegmentStart);
      }

      if (typeof timing.latency_budget_ok === "boolean") {
        transcriptLatencyBudgetOk = timing.latency_budget_ok;
      }
    }
    if (Array.isArray(result.segments)) {
      segments = result.segments as Segment[];
    }

    if (!transcriptText.trim() && typeof result.message === "string" && !errorText.trim()) {
      errorText = result.message;
    }
    if (!transcriptText.trim()) {
      const infoMessage =
        (typeof result.message === "string" && result.message.trim()) ||
        "No transcript text returned by STT engine.";
      transcriptText = `[Info] ${infoMessage}`;
    }

    await tick();
    const uiDisplayElapsedMs = Math.max(0, Date.now() - transcribeUiStartedAtMs);
    const endToEndUiElapsedMs = Math.max(0, Date.now() - uiRequestStartedAtMs);
    if (transcriptFirstSegmentStartS !== null) {
      transcriptFirstWordToDisplayMs = Math.max(
        0,
        uiDisplayElapsedMs - Math.trunc(transcriptFirstSegmentStartS * 1000)
      );
    }

    if (transcriptFirstWordLatencyMs !== null) {
      const budgetLabel =
        transcriptLatencyBudgetOk === null
          ? "budget=n/a"
          : transcriptLatencyBudgetOk
            ? "budget=OK"
            : "budget=LATE";
      addRuntimeMonitor(
        `First-word latency(back)=${transcriptFirstWordLatencyMs} ms, first-word->UI=${transcriptFirstWordToDisplayMs ?? "-"} ms, total(back)=${transcriptTotalElapsedMs ?? "-"} ms, uiElapsed(transcribe)=${uiDisplayElapsedMs} ms, uiElapsed(end-to-end)=${endToEndUiElapsedMs} ms, ${budgetLabel}`
      );
    }
  }

  async function saveTranscriptTxt() {
    const trimmed = transcriptText.trim();
    if (!trimmed || trimmed.startsWith("[Error]") || trimmed.startsWith("[Info]")) {
      status = "Save TXT: no valid transcript text.";
      addRuntimeMonitor("Save TXT skipped: transcript output is empty or non-final.");
      return;
    }

    const response = await callCommand("Save transcript TXT", "save_transcript_txt", {
      text: transcriptText,
      source_label: audioPath.trim(),
      sourceLabel: audioPath.trim(),
      language: transcriptLanguage.trim(),
      engine: transcriptEngine.trim(),
      segments,
      file_label: buildTranscriptFileLabel(),
      settings: buildTranscriptSettingsSnapshot(),
      raw_response: parseRawResponseForExport()
    });
    if (!response) {
      return;
    }

    const payload =
      response?.result && typeof response.result === "object"
        ? (response.result as Record<string, unknown>)
        : (response as unknown as Record<string, unknown>);
    const savedPath = typeof payload.path === "string" ? payload.path : "";
    const exportDir = typeof payload.export_dir === "string" ? payload.export_dir : "";
    if (!savedPath) {
      addRuntimeMonitor("Save TXT finished but no export path returned.");
      return;
    }

    transcriptLastSavedPath = savedPath;
    transcriptLastExportDir = exportDir;
    status = "Transcript saved to TXT.";
    addRuntimeMonitor(`Transcript TXT saved -> ${compactExportPath(savedPath)}`);
  }

  async function startTimedSourceRun() {
    if (!timedRunArmed || isBusy || timedFinalizeBusy) return;
    const seconds = normalizeTimedSeconds();
    timedClipSeconds = seconds;
    timedRunArmed = false;
    timedRunTargetSeconds = seconds;
    timedRunStartedAtMs = Date.now();
    timedSecondsRemaining = seconds;

    // Final click starts preview + timer capture. Transcribe starts when stopped or timer expires.
    try {
      await startPreviewPlaybackNow();
    } catch {
      // Preview is best-effort; timed capture still starts.
    }
    startTimedCountdown(seconds);
    status = `Timed capture running (${seconds}s max). Click Cancel/Stop timed run anytime to transcribe immediately.`;
    addRuntimeMonitor(`Timed run started target=${seconds}s`);
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

  const sourcePreview: SourcePreview = $derived.by(() => {
    const source = audioPath.trim();
    const typedUrl = mediaUrl.trim();
    previewAutoplayNonce;
    timedCountdownActive;
    previewIsPlaying;
    const youtubeId = extractYouTubeVideoId(source) || extractYouTubeVideoId(typedUrl);
    if (youtubeId) {
      const params = new URLSearchParams({
        autoplay: timedCountdownActive || previewIsPlaying ? "1" : "0",
        rel: "0",
        modestbranding: "1",
        playsinline: "1",
        start: "0",
        trigger: String(previewAutoplayNonce)
      });
      return {
        kind: "youtube",
        src: `https://www.youtube.com/embed/${youtubeId}?${params.toString()}`,
        hint: "YouTube preview"
      };
    }

    if (!source) {
      return { kind: null, src: "", hint: "No source selected." };
    }

    let src = "";
    if (isHttpUrl(source)) {
      src = source;
    } else if (/^[A-Za-z]:[\\/]/.test(source) || source.startsWith("/") || source.startsWith("\\\\")) {
      src = toFileUrl(source);
    }

    if (!src) {
      return {
        kind: null,
        src: "",
        hint: "Preview requires URL source or absolute local file path."
      };
    }

    const inferred = inferMediaKind(source) ?? inferMediaKind(src);
    if (inferred === "audio") {
      return { kind: "audio", src, hint: "Audio preview" };
    }

    return { kind: "video", src, hint: "Video preview" };
  });

  const previewAudioRunning = $derived.by(() => {
    if (sourcePreview.kind === "youtube") {
      return timedCountdownActive || previewIsPlaying;
    }
    return previewIsPlaying;
  });

  const runtimeMonitorText = $derived.by(() => runtimeMonitorLines.join("\n"));

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

  function compactExportPath(path: unknown): string {
    if (typeof path !== "string" || !path.trim()) return "-";
    const normalized = path.replace(/\\/g, "/");
    const lower = normalized.toLowerCase();
    const markers = ["/session_exports/transcripts/", "/astt_demo_a004/transcripts/"];
    for (const marker of markers) {
      const idx = lower.lastIndexOf(marker);
      if (idx >= 0) {
        return normalized.slice(idx + 1).replace(/\//g, "\\");
      }
    }
    const parts = normalized.split("/").filter(Boolean);
    if (parts.length >= 3) {
      return parts.slice(parts.length - 3).join("\\");
    }
    return normalized.replace(/\//g, "\\");
  }

  function toFiniteNumber(value: unknown): number | null {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string") {
      const parsed = Number(value.trim());
      if (Number.isFinite(parsed)) return parsed;
    }
    return null;
  }

  function toFiniteInt(value: unknown, fallback = 0): number {
    const parsed = toFiniteNumber(value);
    if (parsed === null) return fallback;
    return Math.max(0, Math.trunc(parsed));
  }

  function normalizeDiagnosticStatus(rawStatus: unknown): string {
    if (typeof rawStatus !== "string") return "";
    const value = rawStatus.trim().toLowerCase();
    if (value === "ok" || value === "warning" || value === "info" || value === "error") {
      return value;
    }
    return "";
  }

  function inferDiagnosticStatus(component: string, processes: number): string {
    const name = component.toLowerCase();
    if (name.includes("host")) return processes > 0 ? "ok" : "error";
    if (name.includes("runtime") || name.includes("webview")) return processes > 0 ? "ok" : "warning";
    if (name.includes("sidecar")) return processes > 0 ? "ok" : "info";
    return processes > 0 ? "ok" : "warning";
  }

  function inferDiagnosticDetail(component: string, processes: number): string {
    const name = component.toLowerCase();
    if (name.includes("runtime") || name.includes("webview")) {
      return processes > 0
        ? "Runtime child processes detected."
        : "Runtime child processes were not detected in this sample.";
    }
    if (name.includes("sidecar")) {
      return processes > 0
        ? "Sidecar process is active."
        : "Sidecar is currently not running (expected while idle).";
    }
    if (name.includes("host")) {
      return processes > 0
        ? "Main host process is detected."
        : "Main host process was not detected (unexpected).";
    }
    return processes > 0 ? "Component processes detected." : "Component processes not detected.";
  }

  function normalizeComponentLoadRows(source: unknown): ComponentLoadRow[] {
    if (!Array.isArray(source)) return [];
    return source.map((raw) => {
      const row = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : {};
      const processes = toFiniteInt(row.processes, 0);
      const component =
        typeof row.component === "string" && row.component.trim()
          ? row.component.trim()
          : "Unknown component";
      const diagnosticStatus =
        normalizeDiagnosticStatus(row.diagnostic_status) || inferDiagnosticStatus(component, processes);
      const pidList = Array.isArray(row.pid_list)
        ? row.pid_list
            .map((pid) => toFiniteInt(pid, -1))
            .filter((pid) => pid > 0)
        : [];

      const cpu = toFiniteNumber(row.cpu_percent);
      const memory = toFiniteNumber(row.memory_mb);

      return {
        component,
        approx_code_scope:
          typeof row.approx_code_scope === "string" && row.approx_code_scope.trim()
            ? row.approx_code_scope.trim()
            : "-",
        cpu_percent: cpu !== null ? Math.max(0, cpu) : null,
        memory_mb: memory !== null ? Math.max(0, memory) : null,
        processes,
        measurement_note:
          typeof row.measurement_note === "string" ? row.measurement_note : undefined,
        diagnostic_status: diagnosticStatus,
        diagnostic_detail:
          typeof row.diagnostic_detail === "string" && row.diagnostic_detail.trim()
            ? row.diagnostic_detail.trim()
            : inferDiagnosticDetail(component, processes),
        detection_mode: typeof row.detection_mode === "string" ? row.detection_mode : undefined,
        pid_list: pidList
      };
    });
  }

  function appendComponentHistory(report: Record<string, unknown>) {
    const ts = toFiniteNumber(report.generated_at_unix_ms) ?? Date.now();
    const rows = normalizeComponentLoadRows(report.component_load);
    if (rows.length === 0) return;

    const samples: ComponentLoadSample[] = rows.map((row) => ({
      ts,
      component: row.component,
      cpu_percent: row.cpu_percent,
      memory_mb: row.memory_mb,
      processes: row.processes,
      diagnostic_status: row.diagnostic_status ?? inferDiagnosticStatus(row.component, row.processes)
    }));

    const recentMinTs = Date.now() - HW_HISTORY_WINDOW_MS;
    componentSamplesRecent = [...componentSamplesRecent, ...samples].filter(
      (sample) => sample.ts >= recentMinTs
    );

    const nextAll = [...componentSamplesAll, ...samples];
    componentSamplesAll =
      nextAll.length > MAX_HW_SAMPLES_ALL
        ? nextAll.slice(nextAll.length - MAX_HW_SAMPLES_ALL)
        : nextAll;
  }

  function aggregateComponentSamples(samples: ComponentLoadSample[]): ComponentAggregate[] {
    const buckets = new Map<
      string,
      {
        sampleCount: number;
        cpuCount: number;
        cpuSum: number;
        cpuPeak: number;
        memoryCount: number;
        memorySum: number;
        memoryPeak: number;
        processSum: number;
        warningSamples: number;
      }
    >();

    for (const sample of samples) {
      const key = sample.component;
      if (!buckets.has(key)) {
        buckets.set(key, {
          sampleCount: 0,
          cpuCount: 0,
          cpuSum: 0,
          cpuPeak: 0,
          memoryCount: 0,
          memorySum: 0,
          memoryPeak: 0,
          processSum: 0,
          warningSamples: 0
        });
      }
      const bucket = buckets.get(key);
      if (!bucket) continue;

      bucket.sampleCount += 1;
      bucket.processSum += sample.processes;
      if (sample.diagnostic_status === "warning" || sample.diagnostic_status === "error") {
        bucket.warningSamples += 1;
      }

      if (typeof sample.cpu_percent === "number") {
        bucket.cpuCount += 1;
        bucket.cpuSum += sample.cpu_percent;
        bucket.cpuPeak = Math.max(bucket.cpuPeak, sample.cpu_percent);
      }

      if (typeof sample.memory_mb === "number") {
        bucket.memoryCount += 1;
        bucket.memorySum += sample.memory_mb;
        bucket.memoryPeak = Math.max(bucket.memoryPeak, sample.memory_mb);
      }
    }

    return [...buckets.entries()]
      .map(([component, bucket]) => ({
        component,
        sample_count: bucket.sampleCount,
        avg_cpu: bucket.cpuCount > 0 ? bucket.cpuSum / bucket.cpuCount : null,
        peak_cpu: bucket.cpuCount > 0 ? bucket.cpuPeak : null,
        avg_memory: bucket.memoryCount > 0 ? bucket.memorySum / bucket.memoryCount : null,
        peak_memory: bucket.memoryCount > 0 ? bucket.memoryPeak : null,
        avg_processes: bucket.sampleCount > 0 ? bucket.processSum / bucket.sampleCount : 0,
        warning_samples: bucket.warningSamples
      }))
      .sort((a, b) => a.component.localeCompare(b.component));
  }

  function buildSparkline(values: number[]): { hasData: boolean; max: number; polyline: string } {
    const width = 320;
    const height = 74;
    if (values.length === 0) {
      return { hasData: false, max: 1, polyline: "" };
    }

    const max = Math.max(1, ...values);
    const count = values.length;
    const points = values.map((value, index) => {
      const x = count === 1 ? 0 : (index / (count - 1)) * (width - 1);
      const y = height - 1 - (Math.max(0, value) / max) * (height - 1);
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    });

    if (count === 1) {
      points.push(`${(width - 1).toFixed(2)},${points[0].split(",")[1]}`);
    }

    return {
      hasData: true,
      max,
      polyline: points.join(" ")
    };
  }

  function buildHistorySeries(samples: ComponentLoadSample[]): ComponentHistorySeries[] {
    const buckets = new Map<string, ComponentLoadSample[]>();
    for (const sample of samples) {
      if (!buckets.has(sample.component)) {
        buckets.set(sample.component, []);
      }
      buckets.get(sample.component)?.push(sample);
    }

    return [...buckets.entries()]
      .map(([component, values]) => {
        const sorted = [...values].sort((a, b) => a.ts - b.ts);
        const cpuHasData = sorted.some((point) => typeof point.cpu_percent === "number");
        const ramHasData = sorted.some((point) => typeof point.memory_mb === "number");

        const cpuValues = sorted.map((point) =>
          typeof point.cpu_percent === "number" ? point.cpu_percent : 0
        );
        const ramValues = sorted.map((point) =>
          typeof point.memory_mb === "number" ? point.memory_mb : 0
        );
        const cpuSparkline = buildSparkline(cpuValues);
        const ramSparkline = buildSparkline(ramValues);
        const latest = sorted[sorted.length - 1];

        return {
          component,
          sample_count: sorted.length,
          from_ts: sorted[0]?.ts ?? 0,
          to_ts: latest?.ts ?? 0,
          latest_cpu: latest?.cpu_percent ?? null,
          latest_memory: latest?.memory_mb ?? null,
          latest_processes: latest?.processes ?? 0,
          cpu_has_data: cpuHasData,
          ram_has_data: ramHasData,
          cpu_max: cpuSparkline.max,
          ram_max: ramSparkline.max,
          cpu_polyline: cpuSparkline.polyline,
          ram_polyline: ramSparkline.polyline
        };
      })
      .sort((a, b) => a.component.localeCompare(b.component));
  }

  async function refreshServiceReport() {
    serviceReportError = "";
    try {
      const args = serviceScopePath.trim() ? { scope_root: serviceScopePath.trim() } : {};
      const response = await invoke<Record<string, unknown>>("demo_service_report", args);
      appendComponentHistory(response);
      serviceReport = response;
      serviceReportJson = JSON.stringify(response, null, 2);
      serviceLoadedAt = new Date().toLocaleString();
      serviceLiveStatus = "online";

      const selectedRoot = (
        (response?.code_lines_scope as Record<string, unknown> | undefined)?.selected_root_abs
      );
      if (typeof selectedRoot === "string" && selectedRoot.trim()) {
        serviceScopePath = selectedRoot;
      }
    } catch (error) {
      serviceLiveStatus = "offline";
      serviceReportError = formatUnknownError(error);
      serviceReportJson = `service report failed: ${formatUnknownError(error)}`;
    }
  }

  async function chooseServiceScopeDirectory() {
    try {
      const selected = await openDialog({
        directory: true,
        multiple: false,
        title: "Choose source directory for code analytics"
      });
      const resolved =
        typeof selected === "string"
          ? selected
          : Array.isArray(selected) && selected.length > 0 && typeof selected[0] === "string"
            ? selected[0]
            : "";
      if (!resolved.trim()) return;
      serviceScopePath = resolved.trim();
      await refreshServiceReport();
    } catch (error) {
      serviceReportError = formatUnknownError(error);
    }
  }

  function resetServiceScopeDirectory() {
    serviceScopePath = "";
    void refreshServiceReport();
  }

  async function refreshLiveMetrics() {
    if (serviceLiveBusy) return;
    serviceLiveBusy = true;
    serviceLiveStatus = "checking";
    try {
      const response = await invoke<Record<string, unknown>>("demo_live_metrics");
      appendComponentHistory(response);
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
  const codeLanguagesDetected = $derived(
    Array.isArray(codeLinesScope?.languages_detected)
      ? (codeLinesScope.languages_detected as string[])
      : []
  );
  const codeFrameworksDetected = $derived(
    Array.isArray(codeLinesScope?.frameworks_detected)
      ? (codeLinesScope.frameworks_detected as string[])
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
  const codeScopeSummaryText = $derived(
    typeof serviceReport?.code_scope_summary_text === "string"
      ? (serviceReport.code_scope_summary_text as string)
      : ""
  );
  const demoFiles = $derived(
    Array.isArray(serviceReport?.demo_files)
      ? (serviceReport.demo_files as Array<Record<string, unknown>>)
      : []
  );
  const componentLoad = $derived(normalizeComponentLoadRows(serviceReport?.component_load));
  const componentDiagnostics = $derived.by(() =>
    componentLoad.map((row) => ({
      ...row,
      diagnostic_status:
        row.diagnostic_status || inferDiagnosticStatus(row.component, row.processes),
      diagnostic_detail:
        row.diagnostic_detail || inferDiagnosticDetail(row.component, row.processes),
      pid_text: row.pid_list.length > 0 ? row.pid_list.join(", ") : "-"
    }))
  );
  const componentHistorySeries = $derived.by(() => buildHistorySeries(componentSamplesRecent));
  const componentSummaryRecent = $derived.by(() => aggregateComponentSamples(componentSamplesRecent));
  const componentSummaryOverall = $derived.by(() => aggregateComponentSamples(componentSamplesAll));
  const historyWindowRangeLabel = $derived.by(() => {
    if (componentSamplesRecent.length === 0) return "No samples in last 35 minutes yet.";
    const sorted = [...componentSamplesRecent].sort((a, b) => a.ts - b.ts);
    const from = sorted[0];
    const to = sorted[sorted.length - 1];
    return `Last 35 minutes window: ${formatUnixMs(from?.ts)} -> ${formatUnixMs(to?.ts)} (${componentSamplesRecent.length} samples).`;
  });
  const historyOverallRangeLabel = $derived.by(() => {
    if (componentSamplesAll.length === 0) return "No overall samples yet.";
    const sorted = [...componentSamplesAll].sort((a, b) => a.ts - b.ts);
    const from = sorted[0];
    const to = sorted[sorted.length - 1];
    return `Overall session: ${formatUnixMs(from?.ts)} -> ${formatUnixMs(to?.ts)} (${componentSamplesAll.length} samples).`;
  });

  function applyWindowFromUrl() {
    const search = new URLSearchParams(window.location.search);
    const target = search.get("window");
    if (target === "asr" || target === "service") {
      activeWindow = target;
    }
  }

  function applyMenuAction(
    action: "show_asr" | "show_service" | "open_guide" | "open_diagnostics" | "open_about"
  ) {
    if (action === "show_asr") {
      activeWindow = "asr";
      return;
    }
    if (action === "show_service") {
      activeWindow = "service";
      return;
    }
    if (action === "open_diagnostics") {
      void goto("/demo-a002?tab=diagnostics");
      return;
    }
    if (action === "open_guide") {
      void goto("/guide");
      return;
    }
    void goto("/about");
  }

  onMount(() => {
    addRuntimeMonitor("UI mounted");
    addRuntimeMonitor("Sidecar log file: %TEMP%\\astt_demo_a004\\sidecar.log");
    applyWindowFromUrl();
    void refreshServiceReport();

    let disposed = false;
    let unlistenMenuActions: (() => void) | null = null;

    void (async () => {
      try {
        const unlisten = await listenRuntimeMenuActions((action) => {
          applyMenuAction(action);
        });
        if (disposed) {
          unlisten();
          return;
        }
        unlistenMenuActions = unlisten;
      } catch {
        // Ignore missing runtime menu bridge.
      }
    })();

    return () => {
      disposed = true;
      stopTimedCountdown();
      pausePreviewPlayback();
      if (unlistenMenuActions) {
        unlistenMenuActions();
      }
    };
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
    <p class="sub">
      Sandbox STT + LLM:
      <a class="demo-link" href="/demo-a004">open /demo-a004</a>
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
    <details class="runtime-monitor">
      <summary>Runtime Monitor</summary>
      <textarea class="raw-rpc monitor-box" readonly value={runtimeMonitorText}></textarea>
      <p class="hint">Sidecar log file: `%TEMP%\\astt_demo_a004\\sidecar.log`</p>
    </details>
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
          <select bind:value={model}>
            {#each MODEL_OPTIONS as option}
              <option value={option}>{option}</option>
            {/each}
          </select>
        </label>
        <label>
          <span>Language</span>
          <select bind:value={language}>
            {#each LANGUAGE_OPTIONS as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </label>
        <label>
          <span>Device</span>
          <select bind:value={device}>
            <option value="cpu">cpu (all systems)</option>
            <option value="cuda">cuda (NVIDIA GPU)</option>
            <option value="mps">mps (Apple Silicon GPU)</option>
          </select>
        </label>
        <label>
          <span>Compute Type</span>
          <select bind:value={computeType}>
            {#each COMPUTE_TYPE_OPTIONS as option}
              <option value={option}>{option}</option>
            {/each}
          </select>
        </label>
      </div>
      <p class="hint">
        `cuda` is GPU mode for NVIDIA cards; on macOS Apple Silicon use `mps`.
      </p>
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
        <button class="ghost" onclick={applyCzQualityPreset} disabled={isBusy}>
          CZ quality (large-v3)
        </button>
        <button class="ghost" onclick={applyLowLatencyPreset} disabled={isBusy}>Low-latency preset</button>
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
        <button onclick={() => void transcribeFromSourceButton()} disabled={isBusy || !audioPath.trim()}>
          Transcribe file
        </button>
        <button class="warn compact" onclick={abortCurrentRequestHard}>
          {isBusy ? "Abort current request" : "Abort (idle)"}
        </button>
      </div>
      <p class="hint">`Abort current request` is emergency stop for running init/transcribe.</p>
      <label class="toggle">
        <input bind:checked={lowLatencyVideoMode} type="checkbox" />
        <span>Enable low-latency URL mode for `Transcribe file`</span>
      </label>
      <label class="full">
        <span>Auto clip seconds for URL source</span>
        <input
          type="number"
          min="3"
          max="300"
          step="1"
          bind:value={lowLatencyVideoSeconds}
          disabled={!lowLatencyVideoMode}
          onchange={() => {
            lowLatencyVideoSeconds = normalizeLowLatencySeconds();
          }}
        />
      </label>
      <p class="hint">
        If enabled and source is `http(s)`, `Transcribe file` auto-uses `clip_seconds` (default 5 s)
        for low latency.
      </p>
      {#if lowLatencyVideoMode}
        <p class="hint">
          Current URL clip is {normalizeLowLatencySeconds()} s, so transcript may contain only a short part.
        </p>
      {/if}
      <label class="toggle">
        <input bind:checked={fastUrlPreviewEnabled} type="checkbox" />
        <span>Fast first sentence preview for URL sources</span>
      </label>
      <label class="full">
        <span>Fast preview seconds (3-20)</span>
        <input
          type="number"
          min="3"
          max="20"
          step="1"
          bind:value={fastUrlPreviewSeconds}
          disabled={!fastUrlPreviewEnabled}
          onchange={() => {
            fastUrlPreviewSeconds = normalizeFastUrlPreviewSeconds();
          }}
        />
      </label>
      <p class="hint">
        Runs a quick `tiny` pass first to show initial text sooner, then runs full pass with your selected model.
      </p>

      <h3>Timed Capture Control</h3>
      <p class="hint">
        Arm run, start capture, then stop anytime. On stop, app transcribes exactly captured duration.
      </p>
      <div class="form-grid">
        <label>
          <span>Capture duration (seconds)</span>
          <input
            type="number"
            min="5"
            max="3600"
            step="1"
            bind:value={timedClipSeconds}
            onchange={() => {
              timedClipSeconds = normalizeTimedSeconds();
            }}
          />
        </label>
        <label>
          <span>Remaining time</span>
          <input
            readonly
            value={timedCountdownActive ? formatCountdown(timedSecondsRemaining) : "00:00"}
          />
        </label>
      </div>
      <div class="buttons">
        <button class="ghost" onclick={armTimedSourceRun} disabled={isBusy || !audioPath.trim()}>
          1) Arm timed run
        </button>
        <button
          onclick={startTimedSourceRun}
          disabled={isBusy || timedFinalizeBusy || !audioPath.trim() || !timedRunArmed}
        >
          2) Start timed run (final click)
        </button>
        <button
          class="warn"
          onclick={cancelTimedSourceRun}
          disabled={timedFinalizeBusy || (!timedCountdownActive && !timedRunArmed)}
        >
          Stop timed run (no transcribe)
        </button>
        <button
          onclick={finishTimedSourceRunNow}
          disabled={timedFinalizeBusy || (!timedCountdownActive && !timedRunArmed)}
        >
          Finish now (Transcribe+Save)
        </button>
      </div>
      <label class="toggle">
        <input bind:checked={autoSaveTimedRun} type="checkbox" />
        <span>Auto-save TXT after timed stop</span>
      </label>
      <p class="hint">
        State:
        {timedFinalizeBusy
          ? "finalizing (transcribing captured part)..."
          : timedCountdownActive
          ? `running, ${formatCountdown(timedSecondsRemaining)} left`
          : timedRunArmed
            ? "armed, waiting for final Start click"
            : "idle"}
      </p>
      <p class="hint">
        `Stop timed run` ends capture immediately without blocking. `Finish now` transcribes captured part and can auto-save TXT.
      </p>

      <h3>Source Preview (Audio/Video Check)</h3>
      <p class="hint">
        Use this to manually listen/watch and compare with transcript output.
      </p>
      {#if sourcePreview.kind === "youtube"}
        <div class="preview-wrap">
          <iframe
            class="preview-frame"
            src={sourcePreview.src}
            title="YouTube source preview"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
          ></iframe>
        </div>
      {:else if sourcePreview.kind === "video"}
        <div class="preview-wrap">
          <!-- svelte-ignore a11y_media_has_caption -->
          <video
            bind:this={previewVideoEl}
            class="preview-video"
            controls
            src={sourcePreview.src}
            onplay={handlePreviewPlay}
            onpause={handlePreviewPause}
            onended={handlePreviewPause}
          ></video>
        </div>
      {:else if sourcePreview.kind === "audio"}
        <div class="preview-wrap">
          <audio
            bind:this={previewAudioEl}
            class="preview-audio"
            controls
            src={sourcePreview.src}
            onplay={handlePreviewPlay}
            onpause={handlePreviewPause}
            onended={handlePreviewPause}
          ></audio>
        </div>
      {:else}
        <p class="hint">{sourcePreview.hint}</p>
      {/if}
      {#if sourcePreview.kind}
        <div class="preview-audio-controls">
          <label class="volume-inline">
            <span>Volume</span>
            <input type="range" min="0" max="100" step="1" bind:value={previewVolumePercent} />
          </label>
          <button class="ghost compact" onclick={togglePreviewMuted}>
            {previewMuted ? "Unmute" : "Mute"}
          </button>
          <span class={`audio-indicator ${previewAudioRunning ? "on" : "off"}`}>
            {previewAudioRunning ? "Audio running" : "Audio idle"}
          </span>
        </div>
        {#if sourcePreview.kind === "youtube"}
          <p class="hint">YouTube iframe keeps its own volume controls inside the embedded player.</p>
        {/if}
      {/if}

      <hr />

      <h3>Microphone (sidecar-driven)</h3>
      <p class="hint">
        Requires Python `sounddevice` + PortAudio. `stop_recording` returns `audio_path`, which can be
        transcribed next.
      </p>
      <p class="hint">
        Auto mode runs fast `tiny` quick transcript first; for quality pass, use `Transcribe file` manually
        with your selected model (for example `large-v3`).
      </p>
      <label class="toggle">
        <input bind:checked={autoTranscribeMic} type="checkbox" />
        <span>Auto-transcribe after Stop recording</span>
      </label>
      <label class="full">
        <span>MIC quick transcript seconds (2-10)</span>
        <input
          type="number"
          min="2"
          max="10"
          step="1"
          bind:value={autoMicQuickSeconds}
          disabled={!autoTranscribeMic}
        />
      </label>
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
        <span>
          First-word latency:
          {transcriptFirstWordLatencyMs !== null ? `${transcriptFirstWordLatencyMs} ms` : "-"}
        </span>
        <span>
          First-word -> UI:
          {transcriptFirstWordToDisplayMs !== null ? `${transcriptFirstWordToDisplayMs} ms` : "-"}
        </span>
        <span>
          Total elapsed:
          {transcriptTotalElapsedMs !== null ? `${transcriptTotalElapsedMs} ms` : "-"}
        </span>
        <span>
          First segment start:
          {transcriptFirstSegmentStartS !== null ? `${transcriptFirstSegmentStartS.toFixed(2)} s` : "-"}
        </span>
        <span>
          Latency budget:
          {transcriptLatencyBudgetOk === null ? "-" : transcriptLatencyBudgetOk ? "OK" : "LATE"}
        </span>
      </div>
      <textarea
        bind:this={transcriptTextareaEl}
        readonly
        value={transcriptText}
        placeholder="Transcript text will appear here..."
      ></textarea>
      <div class="buttons transcript-actions">
        <button class="ghost" onclick={saveTranscriptTxt} disabled={isBusy || !transcriptText.trim()}>
          Save transcript as TXT
        </button>
      </div>
      {#if transcriptLastSavedPath}
        <p class="hint">
          Last saved:
          <a
            class="path-link"
            href={toFileUrl(transcriptLastSavedPath)}
            target="_blank"
            rel="noreferrer"
            title={transcriptLastSavedPath}
          >
            {compactExportPath(transcriptLastSavedPath)}
          </a>
        </p>
      {/if}
      {#if transcriptLastExportDir}
        <p class="hint">
          Export folder:
          <a
            class="path-link"
            href={toFileUrl(transcriptLastExportDir)}
            target="_blank"
            rel="noreferrer"
            title={transcriptLastExportDir}
          >
            {compactExportPath(transcriptLastExportDir)}
          </a>
        </p>
      {/if}
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
          <div class="service-scope-actions">
            <button class="ghost" onclick={chooseServiceScopeDirectory}>
              Choose source folder
            </button>
            <button
              class="ghost"
              onclick={resetServiceScopeDirectory}
              disabled={!serviceScopePath.trim()}
            >
              Use default scope
            </button>
          </div>
          <p class="hint">
            Selected scope:
            {privacyPath(serviceScopePath || codeLinesScope?.selected_root_abs)}
          </p>
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
            Languages detected:
            {#if codeLanguagesDetected.length === 0}
              -
            {:else}
              {codeLanguagesDetected.join(" | ")}
            {/if}
          </p>
          <p class="hint">
            Frameworks detected:
            {#if codeFrameworksDetected.length === 0}
              -
            {:else}
              {codeFrameworksDetected.join(" | ")}
            {/if}
          </p>
          {#if codeScopeSummaryText}
            <p class="hint scope-summary">{codeScopeSummaryText}</p>
          {/if}
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
          <p class="hint">{historyWindowRangeLabel}</p>
          <p class="hint">{historyOverallRangeLabel}</p>
          <table>
            <thead>
              <tr>
                <th>Component</th>
                <th>Code Scope</th>
                <th>CPU %</th>
                <th>Memory MB</th>
                <th>Proc</th>
                <th>Status</th>
                <th>PIDs</th>
              </tr>
            </thead>
            <tbody>
              {#if componentLoad.length === 0}
                <tr>
                  <td colspan="7" class="hint">No data.</td>
                </tr>
              {:else}
                {#each componentLoad as row}
                  <tr>
                    <td>{row.component ?? "-"}</td>
                    <td>{row.approx_code_scope ?? "-"}</td>
                    <td>{formatNumber(row.cpu_percent, 2)}</td>
                    <td>{formatNumber(row.memory_mb, 1)}</td>
                    <td>{row.processes ?? "-"}</td>
                    <td>
                      <span class={`diag-chip diag-${row.diagnostic_status ?? "info"}`}>
                        {row.diagnostic_status ?? "-"}
                      </span>
                    </td>
                    <td>{row.pid_list.length > 0 ? row.pid_list.join(", ") : "-"}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>

          <h4>Diagnostics Check (current sample)</h4>
          <table>
            <thead>
              <tr>
                <th>Component</th>
                <th>Mode</th>
                <th>Status</th>
                <th>Detail</th>
              </tr>
            </thead>
            <tbody>
              {#if componentDiagnostics.length === 0}
                <tr>
                  <td colspan="4" class="hint">No diagnostics yet.</td>
                </tr>
              {:else}
                {#each componentDiagnostics as row}
                  <tr>
                    <td>{row.component}</td>
                    <td>{row.detection_mode ?? "-"}</td>
                    <td>
                      <span class={`diag-chip diag-${row.diagnostic_status}`}>
                        {row.diagnostic_status}
                      </span>
                    </td>
                    <td>
                      {row.diagnostic_detail ?? "-"}
                      {#if row.pid_text !== "-"}
                        (PIDs: {row.pid_text})
                      {/if}
                    </td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>

          <h4>CPU/RAM Trend (last 35 minutes)</h4>
          {#if componentHistorySeries.length === 0}
            <p class="hint">No trend data yet. Keep Service window open to collect live samples.</p>
          {:else}
            <div class="history-grid">
              {#each componentHistorySeries as series}
                <article class="history-card">
                  <h5>{series.component}</h5>
                  <p class="hint">
                    Samples: {series.sample_count}
                    | Range: {formatUnixMs(series.from_ts)} -> {formatUnixMs(series.to_ts)}
                  </p>
                  <p class="hint">
                    Latest CPU: {formatNumber(series.latest_cpu, 2)} %
                    | Latest RAM: {formatNumber(series.latest_memory, 1)} MB
                    | Proc: {series.latest_processes}
                  </p>
                  <div class="sparkline-row">
                    <span class="sparkline-label">CPU % (0 -> {formatNumber(series.cpu_max, 1)})</span>
                    {#if series.cpu_has_data}
                      <svg
                        class="sparkline"
                        viewBox="0 0 320 74"
                        preserveAspectRatio="none"
                        aria-label={`CPU trend ${series.component}`}
                      >
                        <polyline points={series.cpu_polyline} class="sparkline-cpu"></polyline>
                      </svg>
                    {:else}
                      <p class="hint">CPU metric is unavailable for this component.</p>
                    {/if}
                  </div>
                  <div class="sparkline-row">
                    <span class="sparkline-label">RAM MB (0 -> {formatNumber(series.ram_max, 1)})</span>
                    {#if series.ram_has_data}
                      <svg
                        class="sparkline"
                        viewBox="0 0 320 74"
                        preserveAspectRatio="none"
                        aria-label={`RAM trend ${series.component}`}
                      >
                        <polyline points={series.ram_polyline} class="sparkline-ram"></polyline>
                      </svg>
                    {:else}
                      <p class="hint">RAM metric is unavailable for this component.</p>
                    {/if}
                  </div>
                </article>
              {/each}
            </div>
          {/if}

          <h4>Summary (last 35 minutes)</h4>
          <table>
            <thead>
              <tr>
                <th>Component</th>
                <th>Samples</th>
                <th>Avg CPU %</th>
                <th>Peak CPU %</th>
                <th>Avg RAM MB</th>
                <th>Peak RAM MB</th>
                <th>Avg Proc</th>
                <th>Warn samples</th>
              </tr>
            </thead>
            <tbody>
              {#if componentSummaryRecent.length === 0}
                <tr>
                  <td colspan="8" class="hint">No recent summary yet.</td>
                </tr>
              {:else}
                {#each componentSummaryRecent as row}
                  <tr>
                    <td>{row.component}</td>
                    <td>{row.sample_count}</td>
                    <td>{formatNumber(row.avg_cpu, 2)}</td>
                    <td>{formatNumber(row.peak_cpu, 2)}</td>
                    <td>{formatNumber(row.avg_memory, 1)}</td>
                    <td>{formatNumber(row.peak_memory, 1)}</td>
                    <td>{formatNumber(row.avg_processes, 2)}</td>
                    <td>{row.warning_samples}</td>
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>

          <h4>Summary (overall session)</h4>
          <table>
            <thead>
              <tr>
                <th>Component</th>
                <th>Samples</th>
                <th>Avg CPU %</th>
                <th>Peak CPU %</th>
                <th>Avg RAM MB</th>
                <th>Peak RAM MB</th>
                <th>Avg Proc</th>
                <th>Warn samples</th>
              </tr>
            </thead>
            <tbody>
              {#if componentSummaryOverall.length === 0}
                <tr>
                  <td colspan="8" class="hint">No overall summary yet.</td>
                </tr>
              {:else}
                {#each componentSummaryOverall as row}
                  <tr>
                    <td>{row.component}</td>
                    <td>{row.sample_count}</td>
                    <td>{formatNumber(row.avg_cpu, 2)}</td>
                    <td>{formatNumber(row.peak_cpu, 2)}</td>
                    <td>{formatNumber(row.avg_memory, 1)}</td>
                    <td>{formatNumber(row.peak_memory, 1)}</td>
                    <td>{formatNumber(row.avg_processes, 2)}</td>
                    <td>{row.warning_samples}</td>
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

  .runtime-monitor {
    margin-top: 0.65rem;
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 0.75rem;
    background: rgba(255, 255, 255, 0.72);
    padding: 0.4rem 0.55rem 0.55rem;
  }

  .runtime-monitor summary {
    cursor: pointer;
    font-weight: 600;
    color: #23463d;
    margin-bottom: 0.35rem;
  }

  .monitor-box {
    min-height: 8.2rem;
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
    overflow-x: auto;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.82rem;
    margin-top: 0.35rem;
  }

  th,
  td {
    border: 1px solid rgba(31, 27, 22, 0.12);
    padding: 0.28rem 0.38rem;
    text-align: left;
    vertical-align: top;
  }

  .diag-chip {
    display: inline-flex;
    align-items: center;
    border-radius: 999px;
    padding: 0.1rem 0.45rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: lowercase;
    border: 1px solid transparent;
  }

  .diag-ok {
    color: #1e5b3c;
    background: #e3f5e7;
    border-color: #b6e0c0;
  }

  .diag-warning {
    color: #7d4b00;
    background: #fff1cf;
    border-color: #f0d08b;
  }

  .diag-info {
    color: #195171;
    background: #e1f1fc;
    border-color: #b5d6ea;
  }

  .diag-error {
    color: #7d1e1e;
    background: #ffdede;
    border-color: #efb4ae;
  }

  .history-grid {
    display: grid;
    gap: 0.6rem;
    margin-top: 0.55rem;
  }

  .history-card {
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 0.7rem;
    background: rgba(255, 255, 255, 0.74);
    padding: 0.55rem;
  }

  .history-card h5 {
    margin: 0 0 0.35rem;
    font-size: 0.88rem;
  }

  .sparkline-row {
    margin-top: 0.45rem;
    display: grid;
    gap: 0.22rem;
  }

  .sparkline-label {
    font-size: 0.78rem;
    color: #6a5946;
  }

  .sparkline {
    width: 100%;
    height: 74px;
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 0.4rem;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(243, 236, 220, 0.8));
  }

  .sparkline-cpu {
    fill: none;
    stroke: #1f5b49;
    stroke-width: 2;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  .sparkline-ram {
    fill: none;
    stroke: #8a3828;
    stroke-width: 2;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  .service-scope-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
    margin-bottom: 0.4rem;
  }

  .scope-summary {
    margin-top: 0.3rem;
    font-weight: 600;
    color: #23463d;
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

  .transcript-actions {
    margin-top: 0.45rem;
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

  .preview-wrap {
    margin-top: 0.45rem;
    border: 1px solid rgba(31, 27, 22, 0.12);
    border-radius: 0.7rem;
    background: rgba(255, 255, 255, 0.78);
    padding: 0.45rem;
  }

  .preview-frame {
    width: 100%;
    min-height: 300px;
    border: 0;
    border-radius: 0.5rem;
    background: #0f0f0f;
  }

  .preview-video {
    width: 100%;
    max-height: 360px;
    border-radius: 0.5rem;
    background: #0f0f0f;
  }

  .preview-audio {
    width: 100%;
  }

  .preview-audio-controls {
    margin-top: 0.4rem;
    display: flex;
    align-items: center;
    gap: 0.45rem;
    flex-wrap: wrap;
  }

  label.volume-inline {
    margin: 0;
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.78rem;
    color: #5e5144;
  }

  .volume-inline input[type="range"] {
    width: 128px;
    padding: 0;
    border: none;
    background: transparent;
  }

  button.compact {
    padding: 0.34rem 0.62rem;
    border-radius: 0.6rem;
    font-size: 0.78rem;
  }

  .audio-indicator {
    border: 1px solid rgba(31, 27, 22, 0.2);
    border-radius: 999px;
    padding: 0.22rem 0.56rem;
    font-size: 0.78rem;
    color: #5a4d40;
    background: rgba(255, 255, 255, 0.78);
  }

  .audio-indicator.on {
    border-color: rgba(35, 70, 61, 0.58);
    background: rgba(35, 70, 61, 0.15);
    color: #15362d;
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
