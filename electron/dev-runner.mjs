import { spawn } from "node:child_process";
import process from "node:process";

const DEV_URL = "http://127.0.0.1:1420";

function npmCmd() {
  return process.platform === "win32" ? "npm.cmd" : "npm";
}

function spawnNpm(args, env = process.env) {
  const mergedEnv = { ...env };
  const command = `${npmCmd()} ${args.join(" ")}`;

  return spawn(command, {
    stdio: "inherit",
    env: mergedEnv,
    shell: true,
  });
}

async function waitForDevServer(url, timeoutMs = 60_000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok || response.status < 500) return;
    } catch {
      // Wait and retry.
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Dev server did not start within ${timeoutMs} ms (${url})`);
}

const vite = spawnNpm(["run", "dev"]);

let electron = null;

function shutdown(code = 0) {
  if (electron && !electron.killed) electron.kill();
  if (vite && !vite.killed) vite.kill();
  process.exit(code);
}

process.on("SIGINT", () => shutdown(0));
process.on("SIGTERM", () => shutdown(0));

try {
  await waitForDevServer(DEV_URL, 60_000);
  electron = spawnNpm(["run", "electron:start"], {
    ...process.env,
    ELECTRON_START_URL: DEV_URL,
  });

  electron.on("exit", (code) => {
    shutdown(code ?? 0);
  });
} catch (error) {
  console.error(String(error));
  shutdown(1);
}
