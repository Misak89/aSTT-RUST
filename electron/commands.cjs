const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const { SidecarManager } = require("./sidecar-manager.cjs");

const MB = 1024 * 1024;

function nowUnixMs() {
  return Date.now();
}

function demoLogPath() {
  return path.join(os.tmpdir(), "astt_demo_a002", "service.log");
}

function transcriptExportRoot() {
  const root = findRepoRoot();
  if (root) {
    return path.join(root, "sandbox", "TestDocu_a004", "session_exports", "transcripts");
  }
  return path.join(os.tmpdir(), "astt_demo_a004", "transcripts");
}

function sanitizeExportLabel(value) {
  const input = ensureString(value).trim();
  if (!input) return "transcript";

  const normalized = input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_+/g, "_");

  if (!normalized) return "transcript";
  return normalized.slice(0, 64).replace(/_+$/g, "") || "transcript";
}

function deriveTranscriptLabel(sourceLabel) {
  const raw = ensureString(sourceLabel).trim();
  if (!raw) return "transcript";

  if (/^https?:\/\//i.test(raw)) {
    const lastSegment = raw.split("/").pop() || raw;
    return sanitizeExportLabel(lastSegment);
  }

  const base = path.basename(raw, path.extname(raw));
  return sanitizeExportLabel(base || raw);
}

function formatExportTimestamp(seconds) {
  const safeSeconds = Number.isFinite(Number(seconds)) ? Math.max(0, Number(seconds)) : 0;
  const totalMs = Math.round(safeSeconds * 1000);
  const hours = Math.floor(totalMs / 3600000);
  const minutes = Math.floor((totalMs % 3600000) / 60000);
  const secs = Math.floor((totalMs % 60000) / 1000);
  const millis = totalMs % 1000;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(
    secs
  ).padStart(2, "0")}.${String(millis).padStart(3, "0")}`;
}

function normalizeSegmentText(value) {
  return ensureString(value)
    .replace(/\r\n/g, " ")
    .replace(/\r/g, " ")
    .replace(/\n/g, " ")
    .trim()
    .split(/\s+/)
    .filter((token) => token.length > 0)
    .join(" ");
}

function shouldSkipDirName(name) {
  const lowered = String(name || "").toLowerCase();
  const fixed = new Set([
    ".git",
    "node_modules",
    "target",
    ".svelte-kit",
    "build",
    "dist",
    "site",
    "sandbox",
    ".venv",
    "venv",
    "venv-system",
    "python-embed",
    "__pycache__",
    ".idea",
    ".vscode",
    "logs",
  ]);

  if (fixed.has(lowered)) return true;
  if (lowered.startsWith("backup_docs_")) return true;
  if (lowered.startsWith("_usb")) return true;
  return false;
}

function languageForPath(filePath) {
  const ext = path.extname(filePath).toLowerCase().replace(/^\./, "");
  switch (ext) {
    case "rs":
      return "Rust";
    case "py":
      return "Python";
    case "svelte":
      return "Svelte";
    case "ts":
      return "TypeScript";
    case "js":
    case "cjs":
    case "mjs":
      return "JavaScript";
    case "json":
      return "JSON";
    case "yml":
    case "yaml":
      return "YAML";
    case "md":
      return "Markdown";
    case "ps1":
      return "PowerShell";
    case "cmd":
    case "bat":
      return "Batch";
    case "toml":
      return "TOML";
    case "css":
      return "CSS";
    case "html":
      return "HTML";
    case "sh":
      return "Shell";
    default:
      return null;
  }
}

function countLines(filePath) {
  let bytes = null;
  try {
    bytes = fs.readFileSync(filePath);
  } catch {
    return 0;
  }

  if (!bytes || bytes.length === 0) return 0;
  if (bytes.length > 2 * MB) return 0;

  const probeLen = Math.min(8192, bytes.length);
  for (let i = 0; i < probeLen; i += 1) {
    if (bytes[i] === 0) return 0;
  }

  let lines = 1;
  for (let i = 0; i < bytes.length; i += 1) {
    if (bytes[i] === 10) lines += 1;
  }
  return lines;
}

function isRepoRoot(candidatePath) {
  return (
    fs.existsSync(path.join(candidatePath, "package.json")) &&
    fs.existsSync(path.join(candidatePath, "src-tauri"))
  );
}

function findRepoRootFrom(startPath, maxDepth) {
  let current = path.resolve(startPath);
  for (let i = 0; i <= maxDepth; i += 1) {
    if (isRepoRoot(current)) return current;
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return null;
}

function findRepoRoot() {
  const envRoot = process.env.ASTT_REPO_ROOT;
  if (envRoot && isRepoRoot(envRoot)) return path.resolve(envRoot);

  const cwdRoot = findRepoRootFrom(process.cwd(), 16);
  if (cwdRoot) return cwdRoot;

  const exeRoot = findRepoRootFrom(path.dirname(process.execPath), 20);
  return exeRoot;
}

function codeScopeRoots(root) {
  const candidates = [
    path.join(root, "sandbox", "TestDocu_a002"),
    path.join(root, "electron", "main.cjs"),
    path.join(root, "electron", "preload.cjs"),
    path.join(root, "electron", "commands.cjs"),
    path.join(root, "electron", "sidecar-manager.cjs"),
    path.join(root, "src-ui", "routes", "+page.svelte"),
    path.join(root, "src-ui", "routes", "demo-a002", "+page.svelte"),
    path.join(root, "src-python", "sidecar.py"),
  ];

  const existing = candidates.filter((candidate) => fs.existsSync(candidate));
  if (existing.length > 0) return existing;

  const fallback = path.join(root, "sandbox");
  if (fs.existsSync(fallback)) return [fallback];
  return [];
}

function pathHasComponent(filePath, name) {
  const loweredName = String(name || "").toLowerCase();
  if (!loweredName) return false;
  const pieces = path.resolve(filePath).split(/[\\/]+/);
  return pieces.some((piece) => piece.toLowerCase() === loweredName);
}

function normalizeExistingDir(pathValue) {
  if (typeof pathValue !== "string") return null;
  const trimmed = pathValue.trim();
  if (!trimmed) return null;

  const candidate = path.isAbsolute(trimmed)
    ? trimmed
    : path.resolve(process.cwd(), trimmed);
  if (!fs.existsSync(candidate)) return null;

  let stat = null;
  try {
    stat = fs.statSync(candidate);
  } catch {
    return null;
  }
  if (!stat.isDirectory()) return null;

  try {
    return fs.realpathSync(candidate);
  } catch {
    return path.resolve(candidate);
  }
}

function relativeToRootDisplay(root, targetPath) {
  try {
    return path.relative(root, targetPath) || targetPath;
  } catch {
    return targetPath;
  }
}

function fileTypeForPath(filePath) {
  const ext = path.extname(filePath).toLowerCase().replace(/^\./, "");
  return ext || "no-ext";
}

function normalizedForCompare(targetPath) {
  return path.resolve(targetPath).toLowerCase();
}

function startsWithPath(candidate, root) {
  const c = normalizedForCompare(candidate);
  const r = normalizedForCompare(root);
  return c === r || c.startsWith(`${r}${path.sep.toLowerCase()}`);
}

function analyzeCodeScopeWithRoots(root, sourceRoots) {
  const electronRoot = path.join(root, "electron");
  const srcTauriRoot = path.join(root, "src-tauri");

  const state = {
    stats: new Map(),
    fileTypeCounts: new Map(),
    frameworkCounts: new Map(),
    directoriesSeen: new Set(),
    processedFiles: new Set(),
    demoFilesRaw: [],
    fileCountScanned: 0,
    maxFiles: 30_000,
    scanLimitHit: false,
  };

  const registerFrameworkHit = (framework, lines) => {
    const previous = state.frameworkCounts.get(framework) ?? { lines: 0, files: 0 };
    previous.lines += lines;
    previous.files += 1;
    state.frameworkCounts.set(framework, previous);
  };

  const processFile = (filePath) => {
    if (state.scanLimitHit) return;
    if (!fs.existsSync(filePath)) return;

    let stat = null;
    try {
      stat = fs.statSync(filePath);
    } catch {
      return;
    }
    if (!stat.isFile()) return;

    const abs = path.resolve(filePath);
    if (state.processedFiles.has(abs)) return;
    state.processedFiles.add(abs);

    state.fileCountScanned += 1;
    if (state.fileCountScanned > state.maxFiles) {
      state.scanLimitHit = true;
      return;
    }

    const fileType = fileTypeForPath(abs);
    state.fileTypeCounts.set(fileType, (state.fileTypeCounts.get(fileType) ?? 0) + 1);

    const lines = countLines(abs);
    const language = languageForPath(abs) ?? "Other";
    if (lines > 0) {
      if (language !== "Other") {
        const previous = state.stats.get(language) ?? { lines: 0, files: 0 };
        previous.lines += lines;
        previous.files += 1;
        state.stats.set(language, previous);
      }
    }

    const frameworkHits = new Set();
    const fileName = path.basename(abs).toLowerCase();
    const extension = path.extname(abs).toLowerCase();
    if (startsWithPath(abs, srcTauriRoot) || fileName === "tauri.conf.json") {
      frameworkHits.add("Tauri");
    }
    if (pathHasComponent(abs, "src-ui") || extension === ".svelte") {
      frameworkHits.add("SvelteKit");
    }
    if (startsWithPath(abs, electronRoot) || pathHasComponent(abs, "electron")) {
      frameworkHits.add("Electron");
    }
    if (language === "Rust") {
      frameworkHits.add("Rust");
    }
    if (language === "Python") {
      frameworkHits.add("Python");
    }
    if (language === "JavaScript" || language === "TypeScript") {
      frameworkHits.add("Node.js ecosystem");
    }
    if (fileName === "sidecar.py") {
      frameworkHits.add("Python sidecar");
    }
    for (const framework of frameworkHits) {
      registerFrameworkHit(framework, lines);
    }

    const modifiedUnixMs = stat.mtimeMs ? Math.floor(stat.mtimeMs) : 0;
    state.demoFilesRaw.push({
      modified_unix_ms: modifiedUnixMs,
      path_abs: abs,
      path_rel: relativeToRootDisplay(root, abs),
      size_bytes: stat.size,
      language,
      lines,
      file_type: fileType,
    });
  };

  const walkDirectory = (startDir) => {
    const stack = [startDir];
    while (stack.length > 0 && !state.scanLimitHit) {
      const current = stack.pop();
      let entries = [];
      try {
        entries = fs.readdirSync(current, { withFileTypes: true });
      } catch {
        continue;
      }

      for (const entry of entries) {
        if (state.scanLimitHit) break;
        const target = path.join(current, entry.name);
        if (entry.isDirectory()) {
          if (shouldSkipDirName(entry.name)) continue;
          state.directoriesSeen.add(relativeToRootDisplay(root, target));
          stack.push(target);
          continue;
        }
        if (entry.isFile()) processFile(target);
      }
    }
  };

  for (const scanRoot of sourceRoots) {
    if (state.scanLimitHit) break;
    let stat = null;
    try {
      stat = fs.statSync(scanRoot);
    } catch {
      continue;
    }
    if (stat.isFile()) processFile(scanRoot);
    if (stat.isDirectory()) walkDirectory(scanRoot);
  }

  const rows = [...state.stats.entries()]
    .map(([language, payload]) => ({
      language,
      lines: payload.lines,
      files: payload.files,
    }))
    .sort((a, b) => b.lines - a.lines);

  const filesByType = [...state.fileTypeCounts.entries()]
    .map(([type, files]) => ({ type, files }))
    .sort((a, b) => b.files - a.files);
  const frameworkRows = [...state.frameworkCounts.entries()]
    .map(([name, payload]) => ({
      name,
      lines: payload.lines,
      files: payload.files,
    }))
    .sort((a, b) => b.lines - a.lines);

  const demoFiles = [...state.demoFilesRaw].sort(
    (a, b) => b.modified_unix_ms - a.modified_unix_ms
  );
  const languagesDetected = rows
    .map((row) => row.language)
    .filter((name) => typeof name === "string" && name.length > 0);
  const frameworksDetected = frameworkRows
    .filter((row) => Number(row.files) > 0)
    .map((row) => row.name);
  const technologyStack = [];
  for (const framework of frameworksDetected) {
    if (!technologyStack.includes(framework)) technologyStack.push(framework);
  }
  for (const language of languagesDetected) {
    if (!technologyStack.includes(language)) technologyStack.push(language);
  }

  return {
    codeLinesByLanguage: rows,
    summary: {
      source_roots_abs: sourceRoots.map((p) => path.resolve(p)),
      source_roots_rel: sourceRoots.map((p) => relativeToRootDisplay(root, p)),
      subdirectories: state.directoriesSeen.size,
      scanned_files: Math.min(state.fileCountScanned, state.maxFiles),
      scan_limit_hit: state.scanLimitHit,
      max_files: state.maxFiles,
      file_types_total: filesByType.length,
      files_by_type: filesByType,
      framework_counts: frameworkRows,
      languages_detected: languagesDetected,
      frameworks_detected: frameworksDetected,
      technology_stack: technologyStack,
      demo_files_count: demoFiles.length,
      demo_files: demoFiles,
    },
  };
}

function analyzeCodeScope(root) {
  return analyzeCodeScopeWithRoots(root, codeScopeRoots(root));
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isPidAlive(pid) {
  if (!pid || typeof pid !== "number") return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function readExternalProcessSample(pid) {
  if (!pid || typeof pid !== "number" || pid <= 0) return null;

  if (process.platform === "win32") {
    const script = [
      `$p = Get-Process -Id ${pid} -ErrorAction Stop`,
      '[Console]::WriteLine("$($p.CPU)|$($p.WorkingSet64)")',
    ].join("; ");
    const result = spawnSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], {
      encoding: "utf8",
      timeout: 1200,
    });
    if (result.status !== 0) return null;

    const line = String(result.stdout || "").trim();
    if (!line) return null;
    const [cpuSecondsRaw, workingSetRaw] = line.split("|");
    const cpuSeconds = Number(cpuSecondsRaw);
    const workingSetBytes = Number(workingSetRaw);
    if (!Number.isFinite(workingSetBytes)) return null;

    return {
      cpuSeconds: Number.isFinite(cpuSeconds) ? cpuSeconds : null,
      cpuPercent: null,
      workingSetBytes,
    };
  }

  if (process.platform === "linux" || process.platform === "darwin") {
    const result = spawnSync("ps", ["-p", String(pid), "-o", "%cpu=,rss="], {
      encoding: "utf8",
      timeout: 1200,
    });
    if (result.status !== 0) return null;

    const lines = String(result.stdout || "")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    if (lines.length === 0) return null;

    const [cpuRaw, rssRaw] = lines[lines.length - 1].split(/\s+/);
    const cpuPercent = Number(cpuRaw);
    const rssKb = Number(rssRaw);
    if (!Number.isFinite(rssKb)) return null;

    return {
      cpuSeconds: null,
      cpuPercent: Number.isFinite(cpuPercent) ? cpuPercent : null,
      workingSetBytes: rssKb * 1024,
    };
  }

  return null;
}

function processGroups(context, sample) {
  const mainMemMb = process.memoryUsage().rss / MB;
  const appMetrics = typeof context.getAppMetrics === "function" ? context.getAppMetrics() : [];

  let runtimeCpu = 0;
  let runtimeMemMb = 0;
  let runtimeCount = 0;
  const runtimePids = [];
  const runtimeTypeCounts = {};
  for (const metric of appMetrics) {
    if (!metric || typeof metric !== "object") continue;
    const metricPid = Number(metric.pid);
    if (!Number.isFinite(metricPid) || metricPid <= 0) continue;
    if (metricPid === process.pid) continue;

    runtimeCpu += Number(metric.cpu?.percentCPU ?? 0);
    runtimeMemMb += Number(metric.memory?.workingSetSize ?? 0) / 1024;
    runtimeCount += 1;
    runtimePids.push(metricPid);

    const type = String(metric.type ?? "unknown");
    runtimeTypeCounts[type] = (runtimeTypeCounts[type] ?? 0) + 1;
  }

  const sidecarPid = context.sidecarManager?.getPid?.() ?? null;
  const sidecarAlive = isPidAlive(sidecarPid);
  const sidecarCount = sidecarAlive ? 1 : 0;
  const sidecarCpu =
    typeof sample.sidecarCpuPercent === "number" && Number.isFinite(sample.sidecarCpuPercent)
      ? Math.max(0, sample.sidecarCpuPercent)
      : null;
  const sidecarMemory =
    typeof sample.sidecarMemoryMb === "number" && Number.isFinite(sample.sidecarMemoryMb)
      ? Math.max(0, sample.sidecarMemoryMb)
      : null;
  const sidecarHasMetrics = sidecarCpu !== null || sidecarMemory !== null;
  const runtimeStatus = runtimeCount > 0 ? "ok" : "warning";
  const runtimeDetail =
    runtimeCount > 0
      ? `Runtime metrics grouped from ${runtimeCount} Electron process(es).`
      : "No Electron runtime process metrics detected in this sample.";
  const sidecarStatus = sidecarAlive ? "ok" : "info";
  const sidecarDetail = sidecarAlive
    ? sidecarHasMetrics
      ? "Sidecar process is active and sampled."
      : "Sidecar process is active, but CPU/RAM metrics are unavailable in this sample."
    : "Sidecar process is currently not running (expected while idle).";

  return [
    {
      component: "Node host process",
      approx_code_scope: "electron/*.cjs",
      cpu_percent: sample.mainCpuPercent,
      memory_mb: mainMemMb,
      processes: 1,
      measurement_note: "Exact PID of main Electron process.",
      detection_mode: "exact-main-pid",
      diagnostic_status: "ok",
      diagnostic_detail: `Main process PID ${process.pid}.`,
      pid_list: [process.pid],
    },
    {
      component: "Electron runtime",
      approx_code_scope: "Chromium renderer + utility processes",
      cpu_percent: runtimeCpu,
      memory_mb: runtimeMemMb,
      processes: runtimeCount,
      measurement_note: "Grouped from Electron runtime process metrics.",
      detection_mode: "electron app metrics grouping",
      diagnostic_status: runtimeStatus,
      diagnostic_detail: runtimeDetail,
      pid_list: runtimePids,
      runtime_type_counts: runtimeTypeCounts,
    },
    {
      component: "Python sidecar",
      approx_code_scope: "src-python/*.py",
      cpu_percent: sidecarCpu,
      memory_mb: sidecarMemory,
      processes: sidecarCount,
      measurement_note: "Sidecar process detected by child PID; CPU/RAM sampled from OS process snapshot when available.",
      detection_mode: "child-pid presence check",
      diagnostic_status: sidecarStatus,
      diagnostic_detail: sidecarDetail,
      pid_list: sidecarAlive && typeof sidecarPid === "number" ? [sidecarPid] : [],
    },
  ];
}

async function collectLiveMetrics(context) {
  const samplingWindowMs = 450;
  const cpuStart = process.cpuUsage();
  const cpuCores = Math.max(1, os.cpus().length);
  const sidecarPid = context.sidecarManager?.getPid?.() ?? null;
  const sidecarStart = readExternalProcessSample(sidecarPid);

  await delay(samplingWindowMs);

  const cpuDelta = process.cpuUsage(cpuStart);
  const cpuMs = (cpuDelta.user + cpuDelta.system) / 1000;
  const mainCpuPercent = (cpuMs / (samplingWindowMs * cpuCores)) * 100;
  const sidecarEnd = readExternalProcessSample(sidecarPid);

  let sidecarCpuPercent = null;
  let sidecarMemoryMb = null;
  if (sidecarEnd && Number.isFinite(sidecarEnd.workingSetBytes)) {
    sidecarMemoryMb = sidecarEnd.workingSetBytes / MB;
  }

  if (sidecarEnd && Number.isFinite(sidecarEnd.cpuPercent)) {
    sidecarCpuPercent = sidecarEnd.cpuPercent;
  } else if (
    sidecarStart &&
    sidecarEnd &&
    Number.isFinite(sidecarStart.cpuSeconds) &&
    Number.isFinite(sidecarEnd.cpuSeconds)
  ) {
    const deltaCpuSeconds = Math.max(0, sidecarEnd.cpuSeconds - sidecarStart.cpuSeconds);
    sidecarCpuPercent = (deltaCpuSeconds * 1000) / (samplingWindowMs * cpuCores) * 100;
  }

  return {
    generated_at_unix_ms: nowUnixMs(),
    sampling_window_ms: samplingWindowMs,
    host: {
      os: process.platform,
      arch: process.arch,
      cpu_cores: cpuCores,
      total_memory_mb: os.totalmem() / MB,
      used_memory_mb: (os.totalmem() - os.freemem()) / MB,
    },
    component_load: processGroups(context, {
      mainCpuPercent,
      sidecarCpuPercent,
      sidecarMemoryMb,
    }),
  };
}

async function demoServiceReport(context, args = {}) {
  const live = await collectLiveMetrics(context);
  const repoRoot = findRepoRoot();
  const manualScopeRoot = normalizeExistingDir(args.scope_root);
  const defaultScopeRoot = repoRoot || process.cwd();

  let selectedScopeRoot = defaultScopeRoot || "";
  let scopePolicy = "latest-demo-fileset";
  let codeLinesByLanguage = [];
  let codeScopeSummary = null;

  if (manualScopeRoot) {
    selectedScopeRoot = manualScopeRoot;
    scopePolicy = "manual-root";
    const analyzed = analyzeCodeScopeWithRoots(manualScopeRoot, [manualScopeRoot]);
    codeLinesByLanguage = analyzed.codeLinesByLanguage;
    codeScopeSummary = analyzed.summary;
  } else if (defaultScopeRoot) {
    selectedScopeRoot = defaultScopeRoot;
    const analyzed = analyzeCodeScope(defaultScopeRoot);
    codeLinesByLanguage = analyzed.codeLinesByLanguage;
    codeScopeSummary = analyzed.summary;
  } else {
    codeScopeSummary = {
      source_roots_abs: [],
      source_roots_rel: [],
      subdirectories: 0,
      scanned_files: 0,
      scan_limit_hit: false,
      max_files: 30_000,
      file_types_total: 0,
      files_by_type: [],
      framework_counts: [],
      languages_detected: [],
      frameworks_detected: [],
      technology_stack: [],
      demo_files_count: 0,
      demo_files: [],
    };
  }

  const currentWorkingDir = process.cwd();
  const repoRootString = repoRoot ?? "not found";
  const selectedScopeRootString = selectedScopeRoot || "";
  const codeScopeSummaryText = `Scanned scope '${selectedScopeRootString}': languages=${(codeScopeSummary.languages_detected ?? []).length}, frameworks=${(codeScopeSummary.frameworks_detected ?? []).length}, files=${codeScopeSummary.scanned_files ?? 0}, subdirectories=${codeScopeSummary.subdirectories ?? 0}.`;

  return {
    ok: true,
    generated_at_unix_ms: live.generated_at_unix_ms ?? nowUnixMs(),
    sampling_window_ms: live.sampling_window_ms ?? 450,
    host: live.host ?? {},
    measurement_logic: [
      "HW load is online: process snapshots are sampled repeatedly (every UI poll interval).",
      "Node host load is measured separately from Electron runtime processes where possible.",
      "Code-line stats are taken from selected source scope (manual folder or default latest-demo file set).",
      "Per-file HW attribution is approximate by component group, not exact per line.",
    ],
    measurement_logic_table: [
      {
        metric: "CPU and RAM",
        source: "Node/Electron process snapshots",
        mode: "online",
        interval_ms: live.sampling_window_ms ?? 450,
        note: "Two snapshots with short delay to stabilize CPU percentage.",
      },
      {
        metric: "Main process vs runtime split",
        source: "PID + Electron process metrics",
        mode: "online",
        interval_ms: live.sampling_window_ms ?? 450,
        note: "Main process PID is exact; runtime metrics are grouped.",
      },
      {
        metric: "Code lines by language",
        source: "Filesystem scan over selected source scope",
        mode: "on-demand",
        interval_ms: 0,
        note: "Counts recognized text source extensions in selected directory scope.",
      },
    ],
    hw_requirements_estimate: {
      no_stt_demo: {
        minimum: { cpu_threads: 2, ram_gb: 4 },
        recommended: { cpu_threads: 4, ram_gb: 8 },
      },
      stt_with_whisperx_cpu: {
        minimum: { cpu_threads: 4, ram_gb: 16 },
        recommended: { cpu_threads: 8, ram_gb: 24 },
      },
    },
    technology_stack: codeScopeSummary.technology_stack ?? [],
    code_scope_summary_text: codeScopeSummaryText,
    code_lines_by_language: codeLinesByLanguage,
    framework_counts: codeScopeSummary.framework_counts ?? [],
    demo_files: codeScopeSummary.demo_files ?? [],
    code_lines_scope: {
      current_working_dir: currentWorkingDir,
      repo_root: repoRootString,
      selected_root_abs: selectedScopeRootString,
      selected_root_mode: scopePolicy,
      source_roots: codeScopeSummary.source_roots_rel ?? [],
      source_roots_abs: codeScopeSummary.source_roots_abs ?? [],
      count_mode: "on-demand",
      scope_policy: scopePolicy,
      counted_at_unix_ms: nowUnixMs(),
      subdirectories: codeScopeSummary.subdirectories ?? 0,
      scanned_files: codeScopeSummary.scanned_files ?? 0,
      demo_files_count: codeScopeSummary.demo_files_count ?? 0,
      scan_limit_hit: codeScopeSummary.scan_limit_hit ?? false,
      max_files: codeScopeSummary.max_files ?? 30_000,
      file_types_total: codeScopeSummary.file_types_total ?? 0,
      files_by_type: codeScopeSummary.files_by_type ?? [],
      languages_detected: codeScopeSummary.languages_detected ?? [],
      frameworks_detected: codeScopeSummary.frameworks_detected ?? [],
      exclude_dirs: [
        ".git",
        "node_modules",
        "target",
        ".svelte-kit",
        "build",
        "dist",
        "site",
        "sandbox",
        ".venv",
        "venv",
        "venv-system",
        "python-embed",
        "__pycache__",
        ".idea",
        ".vscode",
        "logs",
        "backup_docs_*",
      ],
    },
    component_load: live.component_load ?? [],
    repo_root: repoRootString,
  };
}

async function demoLiveMetrics(context) {
  const live = await collectLiveMetrics(context);
  return {
    ok: true,
    generated_at_unix_ms: live.generated_at_unix_ms ?? nowUnixMs(),
    sampling_window_ms: live.sampling_window_ms ?? 450,
    host: live.host ?? {},
    component_load: live.component_load ?? [],
  };
}

function ensureString(value) {
  return typeof value === "string" ? value : String(value ?? "");
}

function createCommandRuntime(context) {
  const sidecarManager = new SidecarManager({ app: context.app });
  const commandContext = {
    ...context,
    sidecarManager,
  };

  const handlers = {
    greet: async (args = {}) => {
      const name = ensureString(args.name ?? "User");
      return `Hello, ${name}! You've been greeted from Node!`;
    },

    demo_health: async () => ({
      ok: true,
      service: "demo-a002",
      stt_enabled: false,
      runtime: "electron-node",
    }),

    demo_diagnostics: async () => ({
      ok: true,
      service: "demo-a002",
      runtime: "electron-node",
      pid: process.pid,
      os: process.platform,
      arch: process.arch,
      timestamp_unix_ms: nowUnixMs(),
      cwd: process.cwd(),
      temp_dir: os.tmpdir(),
      log_file: demoLogPath(),
    }),

    demo_service_report: async (args = {}) => demoServiceReport(commandContext, args),

    demo_live_metrics: async () => demoLiveMetrics(commandContext),

    demo_append_log: async (args = {}) => {
      const normalizedLevel = ensureString(args.level).trim().toUpperCase();
      if (!normalizedLevel || normalizedLevel.length > 12) {
        throw new Error("Invalid level");
      }

      const sanitizedMessage = ensureString(args.message).replace(/[\r\n]+/g, " ");
      if (!sanitizedMessage.trim() || sanitizedMessage.length > 2000) {
        throw new Error("Invalid message");
      }

      const logPath = demoLogPath();
      fs.mkdirSync(path.dirname(logPath), { recursive: true });

      const line = `${nowUnixMs()}|${normalizedLevel}|${sanitizedMessage}\n`;
      fs.appendFileSync(logPath, line, "utf8");

      return {
        ok: true,
        log_file: logPath,
        appended: line.trimEnd(),
      };
    },

    demo_read_logs: async (args = {}) => {
      const parsedLimit = Number(args.limit);
      const maxLimit =
        !Number.isFinite(parsedLimit) || parsedLimit <= 0
          ? 50
          : Math.min(Math.trunc(parsedLimit), 500);

      const logPath = demoLogPath();
      if (!fs.existsSync(logPath)) {
        return {
          ok: true,
          log_file: logPath,
          lines: [],
        };
      }

      const content = fs.readFileSync(logPath, "utf8");
      let lines = content
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line.length > 0);

      if (lines.length > maxLimit) {
        lines = lines.slice(lines.length - maxLimit);
      }

      return {
        ok: true,
        log_file: logPath,
        lines,
      };
    },

    init_sidecar: async (args = {}) => {
      await sidecarManager.spawn();
      return sidecarManager.init(args.config ?? {});
    },

    start_recording: async () => sidecarManager.startRecording(),

    stop_recording: async () => sidecarManager.stopRecording(),

    transcribe: async (args = {}) => {
      const audioPath = ensureString(args.audio_path ?? args.audioPath ?? "").trim();
      return sidecarManager.transcribe(audioPath);
    },

    get_sidecar_config: async () => sidecarManager.getConfig(),

    set_sidecar_config: async (args = {}) => sidecarManager.setConfig(args.config ?? {}),

    save_transcript_txt: async (args = {}) => {
      const normalized = ensureString(args.text ?? "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
      const trimmed = normalized.trim();
      if (!trimmed) {
        throw new Error("Transcript text is empty");
      }

      const sourceLabel = ensureString(args.source_label ?? args.sourceLabel ?? "").trim();
      const language = ensureString(args.language ?? "").trim();
      const engine = ensureString(args.engine ?? "").trim();

      const exportUnixMs = nowUnixMs();
      const exportDir = transcriptExportRoot();
      fs.mkdirSync(exportDir, { recursive: true });

      const label = deriveTranscriptLabel(sourceLabel);
      const outPath = path.join(exportDir, `${label}_${exportUnixMs}.txt`);

      let payload = "# aSTT Transcript Export\n";
      payload += `export_unix_ms=${exportUnixMs}\n`;
      if (sourceLabel) payload += `source=${sourceLabel}\n`;
      if (language) payload += `language=${language}\n`;
      if (engine) payload += `engine=${engine}\n`;
      payload += "format_version=2\n";
      payload += "section_1=full_transcript\n";
      payload += "section_2=numbered_segments_with_time\n";
      payload +=
        "segment_line_format=NNN | HH:MM:SS.mmm -> HH:MM:SS.mmm | speaker=<value-or-> | text=<segment_text>\n";

      payload += "\n[full_transcript]\n";
      payload += `${trimmed}\n`;

      payload += "\n[numbered_segments_with_time]\n";
      const inputSegments = Array.isArray(args.segments) ? args.segments : [];
      let segmentsExported = 0;
      for (let idx = 0; idx < inputSegments.length; idx += 1) {
        const row = inputSegments[idx];
        if (!row || typeof row !== "object") continue;
        const startRaw = Number(row.start);
        const endRaw = Number(row.end);
        const start = Number.isFinite(startRaw) ? Math.max(0, startRaw) : 0;
        const end = Number.isFinite(endRaw) ? Math.max(start, endRaw) : start;
        const speaker = ensureString(row.speaker ?? "").trim() || "-";
        const textValue = normalizeSegmentText(row.text ?? "");
        if (!textValue) continue;

        const startTs = formatExportTimestamp(start);
        const endTs = formatExportTimestamp(end);
        const lineNo = segmentsExported + 1;
        payload += `${String(lineNo).padStart(3, "0")} | ${startTs} -> ${endTs} | speaker=${speaker} | text=${textValue}\n`;
        segmentsExported += 1;
      }

      if (segmentsExported === 0) {
        payload +=
          "000 | 00:00:00.000 -> 00:00:00.000 | speaker=- | text=<no_segments_available>\n";
      }

      fs.writeFileSync(outPath, payload, "utf8");

      return {
        ok: true,
        path: outPath,
        export_dir: exportDir,
        bytes: Buffer.byteLength(payload, "utf8"),
        chars: [...trimmed].length,
        segments_exported: segmentsExported,
      };
    },
  };

  return {
    handlers,
    shutdown() {
      sidecarManager.shutdown();
    },
  };
}

module.exports = {
  createCommandRuntime,
};
