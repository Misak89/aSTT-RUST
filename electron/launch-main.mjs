import path from "node:path";
import process from "node:process";
import { spawn } from "node:child_process";

import electronPath from "electron";

const mainEntry = path.join(process.cwd(), "electron", "main.cjs");
const env = { ...process.env };
delete env.ELECTRON_RUN_AS_NODE;

const child = spawn(electronPath, [mainEntry], {
  stdio: "inherit",
  env,
});

child.on("error", (error) => {
  console.error(String(error));
  process.exit(1);
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

