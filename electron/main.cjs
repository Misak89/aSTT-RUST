const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

const electronExport = require("electron");
const runtimeSessionId =
  process.env.ASTT_ELECTRON_SESSION || `${Date.now()}_${process.pid}`;

function respawnWithoutRunAsNode(electronModule) {
  if (process.env.ASTT_ELECTRON_RESPAWNED === "1") {
    console.error("Failed to start Electron runtime (ELECTRON_RUN_AS_NODE still active).");
    process.exit(1);
    return;
  }

  const electronBinary =
    typeof electronModule === "string" && electronModule.trim().length > 0
      ? electronModule
      : process.execPath;

  const env = { ...process.env, ASTT_ELECTRON_RESPAWNED: "1" };
  env.ASTT_ELECTRON_SESSION = runtimeSessionId;
  delete env.ELECTRON_RUN_AS_NODE;

  const child = spawn(electronBinary, process.argv.slice(1), {
    env,
    stdio: "inherit",
  });

  child.on("error", (error) => {
    console.error(`Failed to respawn Electron: ${String(error)}`);
    process.exit(1);
  });

  child.on("exit", (code) => {
    process.exit(code ?? 0);
  });
}

if (!electronExport || typeof electronExport !== "object" || !electronExport.app) {
  respawnWithoutRunAsNode(electronExport);
} else {
  const { app, BrowserWindow, Menu, dialog, ipcMain, session } = electronExport;
  const { createCommandRuntime } = require("./commands.cjs");

  let runtime = null;
  let staticServer = null;
  let staticServerUrl = null;
  let mainWindow = null;
  const MENU_ACTION_CHANNEL = "astt:menu-action";

  const hasSingleInstanceLock = app.requestSingleInstanceLock();
  if (!hasSingleInstanceLock) {
    app.quit();
  }

  function ensureDirectory(dirPath) {
    fs.mkdirSync(dirPath, { recursive: true });
  }

  function cacheAndDataPaths() {
    const root = path.join(os.tmpdir(), "astt_electron_runtime", runtimeSessionId);
    return {
      root,
      userData: path.join(root, "user-data"),
      cache: path.join(root, "cache"),
    };
  }

  function configureChromiumPrivacyDefaults() {
    const paths = cacheAndDataPaths();
    ensureDirectory(paths.userData);
    ensureDirectory(paths.cache);
    app.setPath("userData", paths.userData);
    app.commandLine.appendSwitch("disk-cache-dir", paths.cache);
    app.commandLine.appendSwitch("disable-http-cache");
    app.commandLine.appendSwitch("disable-gpu-shader-disk-cache");
    app.commandLine.appendSwitch("disable-background-networking");
    app.commandLine.appendSwitch("disable-client-side-phishing-detection");
    app.commandLine.appendSwitch("disable-component-update");
    app.commandLine.appendSwitch("disable-default-apps");
    app.commandLine.appendSwitch("disable-domain-reliability");
    app.commandLine.appendSwitch("disable-sync");
    app.commandLine.appendSwitch("no-pings");
    app.commandLine.appendSwitch("disable-breakpad");
    app.commandLine.appendSwitch("disable-features", [
      "AutofillServerCommunication",
      "CertificateTransparencyComponentUpdater",
      "MediaRouter",
      "OptimizationHints",
      "Translate",
    ].join(","));
  }

  function contentTypeFor(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    switch (ext) {
      case ".html":
        return "text/html; charset=utf-8";
      case ".js":
      case ".mjs":
      case ".cjs":
        return "text/javascript; charset=utf-8";
      case ".css":
        return "text/css; charset=utf-8";
      case ".json":
        return "application/json; charset=utf-8";
      case ".svg":
        return "image/svg+xml";
      case ".png":
        return "image/png";
      case ".jpg":
      case ".jpeg":
        return "image/jpeg";
      case ".gif":
        return "image/gif";
      case ".webp":
        return "image/webp";
      case ".ico":
        return "image/x-icon";
      case ".woff":
        return "font/woff";
      case ".woff2":
        return "font/woff2";
      default:
        return "application/octet-stream";
    }
  }

  function safeJoin(root, requestedPath) {
    const normalized = path
      .normalize(String(requestedPath || ""))
      .replace(/^([.][.][\\/])+/, "");
    const candidate = path.join(root, normalized);
    const relative = path.relative(root, candidate);
    if (relative.startsWith("..") || path.isAbsolute(relative)) {
      return null;
    }
    return candidate;
  }

  async function startStaticServer() {
    if (staticServer && staticServerUrl) return staticServerUrl;

    const staticRoot = path.join(__dirname, "..", "build");
    const indexPath = path.join(staticRoot, "index.html");
    if (!fs.existsSync(indexPath)) {
      throw new Error(`Missing static build index: ${indexPath}`);
    }

    staticServer = http.createServer(async (req, res) => {
      const method = String(req.method || "GET").toUpperCase();
      if (method !== "GET" && method !== "HEAD") {
        res.writeHead(405, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Method Not Allowed");
        return;
      }

      const requestUrl = new URL(req.url || "/", "http://127.0.0.1");
      let pathname = decodeURIComponent(requestUrl.pathname || "/");
      if (!pathname || pathname === "/") pathname = "/index.html";

      const requested = safeJoin(staticRoot, pathname.replace(/^[/\\]+/, ""));
      let targetPath = requested;
      let hasFile = false;

      if (targetPath && fs.existsSync(targetPath)) {
        try {
          hasFile = fs.statSync(targetPath).isFile();
        } catch {
          hasFile = false;
        }
      }

      if (!hasFile) {
        targetPath = indexPath;
      }

      res.setHeader("Content-Type", contentTypeFor(targetPath));
      res.setHeader("Cache-Control", "no-store");

      if (method === "HEAD") {
        res.writeHead(200);
        res.end();
        return;
      }

      const stream = fs.createReadStream(targetPath);
      stream.on("error", () => {
        if (!res.headersSent) {
          res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        }
        res.end("Failed to read resource");
      });
      stream.pipe(res);
    });

    await new Promise((resolve, reject) => {
      staticServer.once("error", reject);
      staticServer.listen(0, "127.0.0.1", resolve);
    });

    const address = staticServer.address();
    if (!address || typeof address !== "object") {
      throw new Error("Failed to obtain static server address");
    }

    staticServerUrl = `http://127.0.0.1:${address.port}`;
    console.log(`[ELECTRON] Static server ready: ${staticServerUrl}`);
    return staticServerUrl;
  }

  function isBlockedTelemetryHost(hostname) {
    const host = String(hostname || "").toLowerCase();
    if (!host) return false;

    const exactMatches = new Set([
      "clients4.google.com",
      "clients2.google.com",
      "redirector.gvt1.com",
      "update.googleapis.com",
      "safebrowsing.googleapis.com",
      "www.google-analytics.com",
      "ssl.google-analytics.com",
    ]);

    if (exactMatches.has(host)) return true;
    if (host.endsWith(".google-analytics.com")) return true;
    if (host.endsWith(".googlesyndication.com")) return true;
    if (host.endsWith(".doubleclick.net")) return true;

    return false;
  }

  function installTelemetryBlockRules() {
    const filter = { urls: ["*://*/*"] };
    session.defaultSession.webRequest.onBeforeRequest(filter, (details, callback) => {
      try {
        const url = new URL(details.url);
        if (isBlockedTelemetryHost(url.hostname)) {
          callback({ cancel: true });
          return;
        }
      } catch {
        // Ignore malformed URL values and allow the request.
      }
      callback({});
    });

    session.defaultSession.setSpellCheckerEnabled(false);
    session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => {
      callback(false);
    });
  }

  function emitMenuAction(action) {
    if (!mainWindow || mainWindow.isDestroyed()) return;
    mainWindow.webContents.send(MENU_ACTION_CHANNEL, action);
  }

  function installNativeMenu() {
    const template = [
      {
        label: "File",
        submenu: [{ role: "quit", label: "Exit" }],
      },
      {
        label: "Edit",
        submenu: [
          { role: "cut" },
          { role: "copy" },
          { role: "paste" },
          { role: "selectAll" },
        ],
      },
      {
        label: "View",
        submenu: [
          { label: "ASR Window", click: () => emitMenuAction("show_asr") },
          { label: "Service Window", click: () => emitMenuAction("show_service") },
        ],
      },
      {
        label: "Window",
        submenu: [{ role: "minimize" }, { role: "maximize" }, { role: "close" }],
      },
      {
        label: "Help",
        submenu: [
          { label: "Návod", click: () => emitMenuAction("open_guide") },
          { label: "Diagnostika", click: () => emitMenuAction("open_diagnostics") },
          { label: "Servisní menu", click: () => emitMenuAction("show_service") },
          { type: "separator" },
          { label: "About aSTT", click: () => emitMenuAction("open_about") },
        ],
      },
    ];

    Menu.setApplicationMenu(Menu.buildFromTemplate(template));
  }

  async function createWindow() {
    const startUrl = process.env.ELECTRON_START_URL;
    let targetUrl = startUrl || null;
    if (!targetUrl) {
      try {
        targetUrl = await startStaticServer();
      } catch (error) {
        const reason = String(error);
        console.error(`[ELECTRON] Failed to start static renderer server: ${reason}`);
        dialog.showErrorBox(
          "aSTT Electron - Renderer startup error",
          `Renderer server could not start.\n\n${reason}`
        );
        return null;
      }
    }

    const win = new BrowserWindow({
      width: 1000,
      height: 700,
      title: "aSTT Desktop App",
      webPreferences: {
        preload: path.join(__dirname, "preload.cjs"),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
      },
    });
    mainWindow = win;
    win.on("closed", () => {
      if (mainWindow === win) {
        mainWindow = null;
      }
    });

    win.webContents.on("console-message", (_event, level, message, line, sourceId) => {
      console.log(
        `[ELECTRON][renderer-console][L${level}] ${String(message)} (${String(
          sourceId
        )}:${String(line)})`
      );
    });
    win.webContents.on("preload-error", (_event, preloadPath, error) => {
      console.error(
        `[ELECTRON] Preload error in ${String(preloadPath)}: ${String(error)}`
      );
    });
    win.webContents.on("did-finish-load", () => {
      console.log(`[ELECTRON] Renderer loaded: ${win.webContents.getURL()}`);
    });
    win.webContents.on("did-fail-load", (_event, code, desc, url) => {
      console.error(`[ELECTRON] Renderer load failed (${code}) ${desc}: ${url}`);
    });

    try {
      await win.loadURL(targetUrl);
      const snapshot = await win.webContents.executeJavaScript(
        `(() => new Promise((resolve) => {
          const started = Date.now();
          const collect = () => {
            const main = document.querySelector("main");
            const text = (main?.innerText || document.body?.innerText || "").trim();
            return {
              title: document.title,
              hasMain: Boolean(main),
              bodyChildren: document.body?.childElementCount ?? 0,
              textPreview: text.slice(0, 180),
              elapsedMs: Date.now() - started
            };
          };

          const tick = () => {
            const snap = collect();
            if (snap.hasMain || snap.elapsedMs >= 8000) {
              resolve(snap);
              return;
            }
            setTimeout(tick, 200);
          };

          tick();
        }))()`
      );
      console.log(`[ELECTRON] Renderer snapshot: ${JSON.stringify(snapshot)}`);
    } catch (error) {
      const reason = String(error);
      console.error(`[ELECTRON] Failed to load renderer URL: ${reason}`);
      const failureHtml = [
        "<!doctype html>",
        "<html><head><meta charset=\"utf-8\"><title>aSTT Electron - Load Error</title></head>",
        "<body style=\"font-family:Segoe UI,Arial,sans-serif;padding:24px;line-height:1.5\">",
        "<h2>Renderer failed to load</h2>",
        "<p>The Electron runtime started, but UI assets were not loaded.</p>",
        `<pre style=\"white-space:pre-wrap\">${reason.replace(/[<>&]/g, "")}</pre>`,
        "</body></html>",
      ].join("");
      if (!win.isDestroyed()) {
        await win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(failureHtml)}`);
      }
      dialog.showErrorBox(
        "aSTT Electron - Renderer load error",
        `Renderer URL could not be loaded.\n\n${reason}`
      );
    }

    return win;
  }

  function registerIpcHandlers() {
    ipcMain.handle("astt:invoke", async (_event, command, args = {}) => {
      if (!runtime) {
        throw new Error("Runtime not initialized");
      }

      const handler = runtime.handlers?.[command];
      if (typeof handler !== "function") {
        throw new Error(`Unknown command: ${String(command)}`);
      }

      return handler(args ?? {});
    });

    ipcMain.handle("astt:openMediaFile", async (event, options = {}) => {
      const browserWindow = BrowserWindow.fromWebContents(event.sender);
      const opts = options && typeof options === "object" ? options : {};
      const wantsDirectory = Boolean(opts.directory);
      const allowsMultiple = Boolean(opts.multiple);
      const properties = [
        wantsDirectory ? "openDirectory" : "openFile",
        ...(allowsMultiple ? ["multiSelections"] : []),
      ];

      const result = await dialog.showOpenDialog(browserWindow ?? undefined, {
        title:
          typeof opts.title === "string" && opts.title.trim().length > 0
            ? opts.title.trim()
            : wantsDirectory
              ? "Choose directory"
              : "Choose local media file",
        defaultPath:
          typeof opts.defaultPath === "string" && opts.defaultPath.trim().length > 0
            ? opts.defaultPath.trim()
            : undefined,
        properties,
        filters: wantsDirectory
          ? undefined
          : opts?.filters ?? [
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
              "avi",
            ],
          },
        ],
      });

      if (result.canceled || !result.filePaths.length) return null;
      if (allowsMultiple) return result.filePaths;
      return result.filePaths[0];
    });
  }

  function initRuntime() {
    runtime = createCommandRuntime({
      app,
      getRendererPids: () =>
        BrowserWindow.getAllWindows()
          .map((win) => win.webContents.getOSProcessId())
          .filter((pid) => typeof pid === "number" && pid > 0),
      getAppMetrics: () => app.getAppMetrics(),
    });
  }

  configureChromiumPrivacyDefaults();

  app.on("second-instance", () => {
    if (!mainWindow || mainWindow.isDestroyed()) {
      return;
    }
    if (mainWindow.isMinimized()) {
      mainWindow.restore();
    }
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    if (!hasSingleInstanceLock) {
      return;
    }

    installTelemetryBlockRules();
    installNativeMenu();
    initRuntime();
    registerIpcHandlers();
    void createWindow();

    app.on("activate", () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        void createWindow();
      }
    });
  });

  app.on("before-quit", () => {
    if (runtime) runtime.shutdown();
    if (staticServer) {
      try {
        staticServer.close();
      } catch {
        // Ignore close failures on shutdown.
      }
    }
  });

  app.on("window-all-closed", () => {
    if (process.platform !== "darwin") {
      app.quit();
    }
  });
}
