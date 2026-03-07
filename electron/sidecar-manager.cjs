const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");
const { spawn } = require("node:child_process");

function resolveDevSidecarScript() {
  const cwd = process.cwd();
  const candidates = [
    path.join(cwd, "src-python", "sidecar.py"),
    path.join(cwd, "..", "src-python", "sidecar.py"),
  ];
  return candidates.find((p) => fs.existsSync(p) && fs.statSync(p).isFile()) ?? null;
}

function resolveBundledSidecar(app) {
  const envPath = process.env.ASTT_SIDECAR_BIN;
  if (envPath && fs.existsSync(envPath)) return envPath;

  const cwd = process.cwd();
  const exeBase = app?.isPackaged ? path.dirname(app.getPath("exe")) : cwd;
  const resources = app?.isPackaged ? process.resourcesPath : cwd;

  const candidates = [
    path.join(exeBase, "sidecar.exe"),
    path.join(exeBase, "sidecar"),
    path.join(resources, "sidecar.exe"),
    path.join(resources, "sidecar"),
    path.join(cwd, "src-tauri", "binaries", "sidecar-x86_64-pc-windows-msvc.exe"),
    path.join(cwd, "src-tauri", "binaries", "sidecar-x86_64-pc-windows-msvc.py"),
  ];

  return candidates.find((p) => fs.existsSync(p) && fs.statSync(p).isFile()) ?? null;
}

function spawnChecked(command, args, options) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    let settled = false;

    const onError = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };

    child.once("error", onError);
    child.once("spawn", () => {
      if (settled) return;
      settled = true;
      child.off("error", onError);
      resolve(child);
    });
  });
}

class SidecarManager {
  constructor({ app }) {
    this.app = app;
    this.child = null;
    this.nextId = 1;
    this.pending = new Map();
    this.closing = false;
  }

  hasRunningProcess() {
    return !!this.child && !this.child.killed && this.child.exitCode == null;
  }

  getPid() {
    return this.hasRunningProcess() ? this.child.pid ?? null : null;
  }

  async spawn() {
    if (this.hasRunningProcess()) return;

    this.closing = false;
    let child = null;
    const devScript = resolveDevSidecarScript();

    if (devScript) {
      try {
        child = await spawnChecked("python", [devScript], {
          cwd: path.dirname(devScript),
          stdio: ["pipe", "pipe", "pipe"],
        });
      } catch (pythonError) {
        console.warn(
          `[SIDECAR] Python dev sidecar spawn failed (${String(
            pythonError
          )}), falling back to bundled sidecar`
        );
      }
    }

    if (!child) {
      const bundled = resolveBundledSidecar(this.app);
      if (!bundled) {
        throw new Error("Failed to resolve sidecar binary/script");
      }

      if (bundled.toLowerCase().endsWith(".py")) {
        child = await spawnChecked("python", [bundled], {
          cwd: path.dirname(bundled),
          stdio: ["pipe", "pipe", "pipe"],
        });
      } else {
        child = await spawnChecked(bundled, [], {
          cwd: path.dirname(bundled),
          stdio: ["pipe", "pipe", "pipe"],
        });
      }
    }

    this.child = child;
    this.attachListeners(child);
  }

  attachListeners(child) {
    const rl = readline.createInterface({
      input: child.stdout,
      crlfDelay: Infinity,
    });

    rl.on("line", (line) => {
      let parsed = null;
      try {
        parsed = JSON.parse(line);
      } catch {
        return;
      }

      if (!parsed || typeof parsed !== "object") return;
      const id = parsed.id;
      if (typeof id !== "number") return;
      const pending = this.pending.get(id);
      if (!pending) return;

      clearTimeout(pending.timeout);
      this.pending.delete(id);
      pending.resolve(parsed);
    });

    child.stderr.on("data", (chunk) => {
      const line = String(chunk ?? "").trim();
      if (!line) return;
      console.warn(`[SIDECAR STDERR] ${line}`);
    });

    child.on("exit", (code, signal) => {
      rl.close();
      const isExpected = this.closing;
      this.child = null;
      const reason = isExpected
        ? "Sidecar stopped"
        : `Sidecar terminated (code=${String(code)}, signal=${String(signal)})`;
      this.flushPending(new Error(reason));
      this.closing = false;
    });
  }

  flushPending(error) {
    for (const [, pending] of this.pending) {
      clearTimeout(pending.timeout);
      pending.reject(error);
    }
    this.pending.clear();
  }

  async sendRequest(method, params) {
    if (!this.hasRunningProcess()) {
      throw new Error("Sidecar not spawned");
    }
    const child = this.child;
    if (!child || !child.stdin) {
      throw new Error("Sidecar stdin unavailable");
    }

    const id = this.nextId++;
    const request = {
      jsonrpc: "2.0",
      method,
      params: params ?? null,
      id,
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error("Request timeout"));
      }, 30_000);

      this.pending.set(id, { resolve, reject, timeout });
      child.stdin.write(`${JSON.stringify(request)}\n`, (writeError) => {
        if (!writeError) return;
        clearTimeout(timeout);
        this.pending.delete(id);
        reject(new Error(`Failed to write to sidecar stdin: ${writeError.message}`));
      });
    });
  }

  init(config) {
    return this.sendRequest("init", config ?? {});
  }

  startRecording() {
    return this.sendRequest("start_recording", null);
  }

  stopRecording() {
    return this.sendRequest("stop_recording", null);
  }

  transcribe(audioPath) {
    return this.sendRequest("transcribe", { audio_path: audioPath });
  }

  getConfig() {
    return this.sendRequest("get_config", null);
  }

  setConfig(config) {
    return this.sendRequest("set_config", config ?? {});
  }

  shutdown() {
    this.closing = true;
    if (!this.child) return;
    try {
      this.child.kill();
    } catch (error) {
      console.warn(`[SIDECAR] Failed to kill sidecar: ${String(error)}`);
    }
  }
}

module.exports = {
  SidecarManager,
};
