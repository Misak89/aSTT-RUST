import fs from "node:fs";
import path from "node:path";
import process from "node:process";

function assertExists(targetPath, label) {
  if (!fs.existsSync(targetPath)) {
    throw new Error(`Missing ${label}: ${targetPath}`);
  }
}

function copyDir(source, destination) {
  fs.cpSync(source, destination, { recursive: true, force: true });
}

const root = process.cwd();
const rootPackagePath = path.join(root, "package.json");
const rootPackage = JSON.parse(fs.readFileSync(rootPackagePath, "utf8"));

const buildDir = path.join(root, "build");
const electronDistDir = path.join(root, "node_modules", "electron", "dist");
const sidecarSource = path.join(
  root,
  "src-tauri",
  "binaries",
  "sidecar-x86_64-pc-windows-msvc.exe"
);

const outputRoot = path.join(root, "dist-electron");
const outputDir = path.join(outputRoot, "win-unpacked");
const resourcesDir = path.join(outputDir, "resources");
const appDir = path.join(resourcesDir, "app");
const appBuildDir = path.join(appDir, "build");
const appElectronDir = path.join(appDir, "electron");

assertExists(buildDir, "frontend build");
assertExists(electronDistDir, "Electron dist runtime");
assertExists(sidecarSource, "bundled sidecar binary");

fs.rmSync(outputDir, { recursive: true, force: true });
fs.mkdirSync(outputDir, { recursive: true });
copyDir(electronDistDir, outputDir);

const defaultExe = path.join(outputDir, "electron.exe");
const targetExe = path.join(outputDir, "aSTT-demo-electron.exe");
if (fs.existsSync(defaultExe)) {
  if (fs.existsSync(targetExe)) {
    fs.rmSync(targetExe, { force: true });
  }
  fs.renameSync(defaultExe, targetExe);
}

fs.mkdirSync(appDir, { recursive: true });
copyDir(buildDir, appBuildDir);
copyDir(path.join(root, "electron"), appElectronDir);

const runtimePackage = {
  name: "astt-demo-electron",
  productName: "aSTT-demo-electron",
  version: String(rootPackage.version ?? "0.1.0"),
  private: true,
  main: "electron/main.cjs",
};
fs.writeFileSync(
  path.join(appDir, "package.json"),
  `${JSON.stringify(runtimePackage, null, 2)}\n`,
  "utf8"
);

fs.copyFileSync(sidecarSource, path.join(resourcesDir, "sidecar.exe"));

console.log("Electron offline package ready:");
console.log(outputDir);

