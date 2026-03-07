// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

// Export modules
pub mod rpc;
pub mod sidecar;

use sidecar::SidecarManager;
use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use std::time::{SystemTime, UNIX_EPOCH};
use sysinfo::{Pid, System};
use tokio::sync::Mutex;
use walkdir::WalkDir;

#[cfg(all(not(debug_assertions), not(feature = "custom-protocol")))]
compile_error!("Release build requires Tauri feature 'custom-protocol'.");

/// Global sidecar manager state
pub struct AppState {
    pub sidecar: Arc<Mutex<SidecarManager>>,
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn demo_health() -> serde_json::Value {
    serde_json::json!({
        "ok": true,
        "service": "demo-a002",
        "stt_enabled": false,
        "runtime": "tauri-rust"
    })
}

fn demo_log_path() -> PathBuf {
    std::env::temp_dir().join("astt_demo_a002").join("service.log")
}

fn now_unix_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

fn should_skip_dir(path: &Path) -> bool {
    let Some(name_os) = path.file_name() else {
        return false;
    };
    let name = name_os.to_string_lossy().to_ascii_lowercase();
    matches!(
        name.as_str(),
        ".git"
            | "node_modules"
            | "target"
            | ".svelte-kit"
            | "build"
            | "dist"
            | "site"
            | "sandbox"
            | ".venv"
            | "venv"
            | "venv-system"
            | "python-embed"
            | "__pycache__"
            | ".idea"
            | ".vscode"
            | "logs"
    ) || name.starts_with("backup_docs_")
        || name.starts_with("_usb")
}

fn language_for_path(path: &Path) -> Option<&'static str> {
    let ext = path
        .extension()
        .and_then(|s| s.to_str())
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default();
    match ext.as_str() {
        "rs" => Some("Rust"),
        "py" => Some("Python"),
        "svelte" => Some("Svelte"),
        "ts" => Some("TypeScript"),
        "js" => Some("JavaScript"),
        "json" => Some("JSON"),
        "yml" | "yaml" => Some("YAML"),
        "md" => Some("Markdown"),
        "ps1" => Some("PowerShell"),
        "cmd" | "bat" => Some("Batch"),
        "toml" => Some("TOML"),
        "css" => Some("CSS"),
        "html" => Some("HTML"),
        "sh" => Some("Shell"),
        _ => None,
    }
}

fn count_lines(path: &Path) -> u64 {
    let Ok(bytes) = fs::read(path) else {
        return 0;
    };
    if bytes.is_empty() {
        return 0;
    }
    // Avoid counting binary blobs and very large generated files as source lines.
    if bytes.len() > 2 * 1024 * 1024 {
        return 0;
    }
    if bytes.iter().take(8192).any(|&b| b == 0) {
        return 0;
    }
    bytes.iter().filter(|&&b| b == b'\n').count() as u64 + 1
}

fn is_repo_root(path: &Path) -> bool {
    path.join("package.json").is_file() && path.join("src-tauri").is_dir()
}

fn find_repo_root_from(start: &Path, max_depth: usize) -> Option<PathBuf> {
    let mut dir = start.to_path_buf();
    for _ in 0..=max_depth {
        if is_repo_root(&dir) {
            return Some(dir);
        }
        if !dir.pop() {
            break;
        }
    }
    None
}

fn find_repo_root() -> Option<PathBuf> {
    if let Ok(env_root) = std::env::var("ASTT_REPO_ROOT") {
        let p = PathBuf::from(env_root);
        if is_repo_root(&p) {
            return Some(p);
        }
    }

    if let Ok(cwd) = std::env::current_dir() {
        if let Some(root) = find_repo_root_from(&cwd, 16) {
            return Some(root);
        }
    }

    if let Ok(exe) = std::env::current_exe() {
        if let Some(exe_dir) = exe.parent() {
            if let Some(root) = find_repo_root_from(exe_dir, 20) {
                return Some(root);
            }
        }
    }

    None
}

fn code_scope_roots(root: &Path) -> Vec<PathBuf> {
    let mut targets = Vec::new();
    for candidate in [
        root.join("sandbox").join("TestDocu_a002"),
        root.join("src-tauri").join("src").join("lib.rs"),
        root.join("src-tauri").join("src").join("rpc.rs"),
        root.join("src-tauri").join("src").join("sidecar.rs"),
        root.join("src-tauri").join("Cargo.toml"),
        root.join("src-tauri").join("tauri.conf.json"),
        root.join("src-tauri").join("capabilities").join("default.json"),
        root.join("src-ui").join("routes").join("+page.svelte"),
        root.join("src-ui").join("routes").join("demo-a002").join("+page.svelte"),
        root.join("src-python").join("sidecar.py"),
    ] {
        if candidate.exists() {
            targets.push(candidate);
        }
    }
    if targets.is_empty() {
        let sandbox_root = root.join("sandbox");
        if sandbox_root.exists() {
            targets.push(sandbox_root);
        }
    }
    targets
}

fn relative_to_root_display(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .map(|p| p.display().to_string())
        .unwrap_or_else(|_| path.display().to_string())
}

fn file_type_for_path(path: &Path) -> String {
    path.extension()
        .and_then(|s| s.to_str())
        .map(|s| s.to_ascii_lowercase())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "no-ext".to_string())
}

struct CodeScanState {
    stats: BTreeMap<String, (u64, u64)>,
    file_type_counts: BTreeMap<String, u64>,
    directories_seen: BTreeSet<String>,
    processed_files: BTreeSet<String>,
    demo_files_raw: Vec<(u128, serde_json::Value)>,
    file_count_scanned: u64,
    max_files: u64,
    scan_limit_hit: bool,
    tauri_lines: u64,
    tauri_files: u64,
    rust_lines: u64,
    rust_files: u64,
}

fn process_code_file(path: &Path, root: &Path, src_tauri_root: &Path, state: &mut CodeScanState) {
    if !path.is_file() || state.scan_limit_hit {
        return;
    }

    let path_abs = path.display().to_string();
    if !state.processed_files.insert(path_abs.clone()) {
        return;
    }

    state.file_count_scanned += 1;
    if state.file_count_scanned > state.max_files {
        state.scan_limit_hit = true;
        return;
    }

    let file_type = file_type_for_path(path);
    let file_type_slot = state.file_type_counts.entry(file_type.clone()).or_insert(0);
    *file_type_slot += 1;

    let lines = count_lines(path);
    let language = language_for_path(path).unwrap_or("Other");
    if lines > 0 {
        if language != "Other" {
            let slot = state.stats.entry(language.to_string()).or_insert((0, 0));
            slot.0 += lines;
            slot.1 += 1;
        }
        if language == "Rust" {
            state.rust_lines += lines;
            state.rust_files += 1;
        }
        if path.starts_with(src_tauri_root) {
            state.tauri_lines += lines;
            state.tauri_files += 1;
        }
    }

    let modified_unix_ms = fs::metadata(path)
        .ok()
        .and_then(|m| m.modified().ok())
        .and_then(|m| m.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let size_bytes = fs::metadata(path).map(|m| m.len()).unwrap_or(0);

    state.demo_files_raw.push((
        modified_unix_ms,
        serde_json::json!({
            "path_abs": path_abs,
            "path_rel": relative_to_root_display(root, path),
            "modified_unix_ms": modified_unix_ms,
            "size_bytes": size_bytes,
            "language": language,
            "lines": lines,
            "file_type": file_type
        }),
    ));
}

fn analyze_code_scope(root: &Path) -> (Vec<serde_json::Value>, serde_json::Value) {
    let source_roots = code_scope_roots(root);
    let mut state = CodeScanState {
        stats: BTreeMap::new(),
        file_type_counts: BTreeMap::new(),
        directories_seen: BTreeSet::new(),
        processed_files: BTreeSet::new(),
        demo_files_raw: Vec::new(),
        file_count_scanned: 0,
        max_files: 30_000,
        scan_limit_hit: false,
        tauri_lines: 0,
        tauri_files: 0,
        rust_lines: 0,
        rust_files: 0,
    };
    let src_tauri_root = root.join("src-tauri");

    for scan_root in &source_roots {
        if scan_root.is_file() {
            process_code_file(scan_root, root, &src_tauri_root, &mut state);
        } else {
            let iter = WalkDir::new(&scan_root)
                .into_iter()
                .filter_entry(|entry| !entry.file_type().is_dir() || !should_skip_dir(entry.path()));

            for entry in iter.filter_map(Result::ok) {
                let path = entry.path();
                if entry.file_type().is_dir() {
                    state
                        .directories_seen
                        .insert(relative_to_root_display(root, path));
                    continue;
                }
                if !entry.file_type().is_file() {
                    continue;
                }
                process_code_file(path, root, &src_tauri_root, &mut state);
                if state.scan_limit_hit {
                    break;
                }
            }
        }

        if state.scan_limit_hit {
            break;
        }
    }

    let mut rows: Vec<(String, (u64, u64))> = state.stats.into_iter().collect();
    rows.sort_by(|a, b| b.1 .0.cmp(&a.1 .0));
    let code_line_rows: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|(language, (lines, files))| {
            serde_json::json!({
                "language": language,
                "lines": lines,
                "files": files
            })
        })
        .collect();

    let mut type_rows: Vec<(String, u64)> = state.file_type_counts.into_iter().collect();
    type_rows.sort_by(|a, b| b.1.cmp(&a.1));
    let files_by_type: Vec<serde_json::Value> = type_rows
        .into_iter()
        .map(|(kind, files)| {
            serde_json::json!({
                "type": kind,
                "files": files
            })
        })
        .collect();

    state.demo_files_raw.sort_by(|a, b| b.0.cmp(&a.0));
    let demo_files: Vec<serde_json::Value> =
        state.demo_files_raw.into_iter().map(|(_, v)| v).collect();

    let summary = serde_json::json!({
        "source_roots_abs": source_roots
            .iter()
            .map(|p| p.display().to_string())
            .collect::<Vec<String>>(),
        "source_roots_rel": source_roots
            .iter()
            .map(|p| relative_to_root_display(root, p))
            .collect::<Vec<String>>(),
        "subdirectories": state.directories_seen.len(),
        "scanned_files": state.file_count_scanned.min(state.max_files),
        "scan_limit_hit": state.scan_limit_hit,
        "max_files": state.max_files,
        "file_types_total": files_by_type.len(),
        "files_by_type": files_by_type,
        "framework_counts": [
            { "name": "Tauri scope", "lines": state.tauri_lines, "files": state.tauri_files },
            { "name": "Rust", "lines": state.rust_lines, "files": state.rust_files }
        ],
        "demo_files_count": demo_files.len(),
        "demo_files": demo_files
    });

    (code_line_rows, summary)
}

fn process_groups(system: &System) -> Vec<serde_json::Value> {
    let self_pid = Pid::from_u32(std::process::id());
    let mut rust_host_cpu = 0.0f32;
    let mut rust_host_mem = 0u64;
    let mut rust_host_count = 0usize;
    let mut sidecar_cpu = 0.0f32;
    let mut sidecar_mem = 0u64;
    let mut sidecar_count = 0usize;
    let mut tauri_runtime_cpu = 0.0f32;
    let mut tauri_runtime_mem = 0u64;
    let mut tauri_runtime_count = 0usize;

    for (pid, process) in system.processes() {
        let cmd_text = process
            .cmd()
            .iter()
            .map(|s| s.to_string_lossy().to_ascii_lowercase())
            .collect::<Vec<String>>()
            .join(" ");
        let name_text = process.name().to_string_lossy().to_ascii_lowercase();
        let cpu = process.cpu_usage();
        let memory = process.memory();
        let parent_matches = process.parent().map(|p| p == self_pid).unwrap_or(false);

        if *pid == self_pid {
            rust_host_cpu += cpu;
            rust_host_mem += memory;
            rust_host_count += 1;
            continue;
        }

        if parent_matches && (cmd_text.contains("sidecar") || name_text.contains("sidecar")) {
            sidecar_cpu += cpu;
            sidecar_mem += memory;
            sidecar_count += 1;
            continue;
        }

        if parent_matches
            && (name_text.contains("webview")
                || name_text.contains("msedgewebview2")
                || name_text.contains("webkit")
                || cmd_text.contains("webview"))
        {
            tauri_runtime_cpu += cpu;
            tauri_runtime_mem += memory;
            tauri_runtime_count += 1;
        }
    }

    vec![
        serde_json::json!({
            "component": "Rust host process",
            "approx_code_scope": "src-tauri/src/*.rs",
            "cpu_percent": rust_host_cpu,
            "memory_mb": (rust_host_mem as f64) / (1024.0 * 1024.0),
            "processes": rust_host_count,
            "measurement_note": "Exact PID of this app process."
        }),
        serde_json::json!({
            "component": "Tauri/WebView runtime",
            "approx_code_scope": "Tauri runtime + WebView2/WebKit child processes",
            "cpu_percent": tauri_runtime_cpu,
            "memory_mb": (tauri_runtime_mem as f64) / (1024.0 * 1024.0),
            "processes": tauri_runtime_count,
            "measurement_note": "Child processes (WebView runtime), separated from Rust host."
        }),
        serde_json::json!({
            "component": "Python sidecar",
            "approx_code_scope": "src-python/*.py",
            "cpu_percent": sidecar_cpu,
            "memory_mb": (sidecar_mem as f64) / (1024.0 * 1024.0),
            "processes": sidecar_count,
            "measurement_note": "Child sidecar process detected by command/process name."
        }),
    ]
}

fn collect_live_metrics() -> serde_json::Value {
    let mut system = System::new_all();
    system.refresh_all();
    let sampling_window_ms = 450u64;
    std::thread::sleep(Duration::from_millis(sampling_window_ms));
    system.refresh_all();

    serde_json::json!({
        "generated_at_unix_ms": now_unix_ms(),
        "sampling_window_ms": sampling_window_ms,
        "host": {
            "os": std::env::consts::OS,
            "arch": std::env::consts::ARCH,
            "cpu_cores": system.cpus().len(),
            "total_memory_mb": (system.total_memory() as f64) / (1024.0 * 1024.0),
            "used_memory_mb": (system.used_memory() as f64) / (1024.0 * 1024.0),
        },
        "component_load": process_groups(&system)
    })
}

#[tauri::command]
fn demo_diagnostics() -> serde_json::Value {
    let timestamp_ms = now_unix_ms();

    let cwd = std::env::current_dir()
        .ok()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|| "unknown".to_string());

    serde_json::json!({
        "ok": true,
        "service": "demo-a002",
        "runtime": "tauri-rust",
        "pid": std::process::id(),
        "os": std::env::consts::OS,
        "arch": std::env::consts::ARCH,
        "timestamp_unix_ms": timestamp_ms,
        "cwd": cwd,
        "temp_dir": std::env::temp_dir().display().to_string(),
        "log_file": demo_log_path().display().to_string()
    })
}

#[tauri::command]
fn demo_service_report() -> serde_json::Value {
    let live_metrics = collect_live_metrics();
    let host = live_metrics
        .get("host")
        .cloned()
        .unwrap_or_else(|| serde_json::json!({}));
    let component_load = live_metrics
        .get("component_load")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let generated_at_unix_ms = live_metrics
        .get("generated_at_unix_ms")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(now_unix_ms()));
    let sampling_window_ms = live_metrics
        .get("sampling_window_ms")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(450));

    let repo_root = find_repo_root();
    let (code_lines, code_scope_summary) = repo_root
        .as_ref()
        .map(|root| analyze_code_scope(root))
        .unwrap_or_else(|| {
            (
                Vec::new(),
                serde_json::json!({
                    "source_roots_abs": [],
                    "source_roots_rel": [],
                    "subdirectories": 0,
                    "scanned_files": 0,
                    "scan_limit_hit": false,
                    "max_files": 30000,
                    "file_types_total": 0,
                    "files_by_type": []
                }),
            )
        });
    let code_scope_roots_rel = code_scope_summary
        .get("source_roots_rel")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_roots_abs = code_scope_summary
        .get("source_roots_abs")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_subdirs = code_scope_summary
        .get("subdirectories")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(0));
    let code_scope_scanned_files = code_scope_summary
        .get("scanned_files")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(0));
    let code_scope_scan_limit_hit = code_scope_summary
        .get("scan_limit_hit")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(false));
    let code_scope_max_files = code_scope_summary
        .get("max_files")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(30000));
    let code_scope_file_types_total = code_scope_summary
        .get("file_types_total")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(0));
    let code_scope_files_by_type = code_scope_summary
        .get("files_by_type")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_framework_counts = code_scope_summary
        .get("framework_counts")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_demo_files = code_scope_summary
        .get("demo_files")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_demo_files_count = code_scope_summary
        .get("demo_files_count")
        .cloned()
        .unwrap_or_else(|| serde_json::json!(0));
    let current_working_dir = std::env::current_dir()
        .ok()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|| "unknown".to_string());
    let repo_root_string = repo_root
        .as_ref()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|| "not found".to_string());

    serde_json::json!({
        "ok": true,
        "generated_at_unix_ms": generated_at_unix_ms,
        "sampling_window_ms": sampling_window_ms,
        "host": host,
        "measurement_logic": [
            "HW load is online: sysinfo snapshots are sampled repeatedly (every UI poll interval).",
            "Rust host load is measured separately from Tauri/WebView child processes where possible.",
            "Code-line stats are taken from a curated latest-demo file set (sandbox/TestDocu_a002 + active runtime source files).",
            "Per-file HW attribution is approximate by component group, not exact per line."
        ],
        "measurement_logic_table": [
            {
                "metric": "CPU and RAM",
                "source": "sysinfo process snapshots",
                "mode": "online",
                "interval_ms": sampling_window_ms,
                "note": "Two snapshots with short delay to stabilize CPU percentage."
            },
            {
                "metric": "Rust host vs Tauri runtime split",
                "source": "PID + child process grouping",
                "mode": "online",
                "interval_ms": sampling_window_ms,
                "note": "Rust host PID is exact; WebView runtime is grouped from child processes."
            },
            {
                "metric": "Code lines by language",
                "source": "WalkDir over latest demo file set",
                "mode": "on-demand",
                "interval_ms": 0,
                "note": "Counts only recognized text source extensions inside the curated demo file set."
            }
        ],
        "hw_requirements_estimate": {
            "no_stt_demo": {
                "minimum": { "cpu_threads": 2, "ram_gb": 4 },
                "recommended": { "cpu_threads": 4, "ram_gb": 8 }
            },
            "stt_with_whisperx_cpu": {
                "minimum": { "cpu_threads": 4, "ram_gb": 16 },
                "recommended": { "cpu_threads": 8, "ram_gb": 24 }
            }
        },
        "technology_stack": [
            "Tauri (framework)",
            "Rust",
            "Svelte",
            "Python"
        ],
        "code_lines_by_language": code_lines,
        "framework_counts": code_scope_framework_counts,
        "demo_files": code_scope_demo_files,
        "code_lines_scope": {
            "current_working_dir": current_working_dir,
            "repo_root": repo_root_string,
            "source_roots": code_scope_roots_rel,
            "source_roots_abs": code_scope_roots_abs,
            "count_mode": "on-demand",
            "scope_policy": "latest-demo-fileset",
            "counted_at_unix_ms": now_unix_ms(),
            "subdirectories": code_scope_subdirs,
            "scanned_files": code_scope_scanned_files,
            "demo_files_count": code_scope_demo_files_count,
            "scan_limit_hit": code_scope_scan_limit_hit,
            "max_files": code_scope_max_files,
            "file_types_total": code_scope_file_types_total,
            "files_by_type": code_scope_files_by_type,
            "exclude_dirs": [
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
                "backup_docs_*"
            ]
        },
        "component_load": component_load,
        "repo_root": repo_root_string
    })
}

#[tauri::command]
fn demo_live_metrics() -> serde_json::Value {
    let live_metrics = collect_live_metrics();
    serde_json::json!({
        "ok": true,
        "generated_at_unix_ms": live_metrics.get("generated_at_unix_ms").cloned().unwrap_or_else(|| serde_json::json!(now_unix_ms())),
        "sampling_window_ms": live_metrics.get("sampling_window_ms").cloned().unwrap_or_else(|| serde_json::json!(450)),
        "host": live_metrics.get("host").cloned().unwrap_or_else(|| serde_json::json!({})),
        "component_load": live_metrics.get("component_load").cloned().unwrap_or_else(|| serde_json::json!([]))
    })
}

#[tauri::command]
fn demo_append_log(level: String, message: String) -> Result<serde_json::Value, String> {
    let normalized_level = level.trim().to_ascii_uppercase();
    if normalized_level.is_empty() || normalized_level.len() > 12 {
        return Err("Invalid level".to_string());
    }
    let sanitized_message = message.replace('\n', " ").replace('\r', " ");
    if sanitized_message.trim().is_empty() || sanitized_message.len() > 2000 {
        return Err("Invalid message".to_string());
    }

    let log_path = demo_log_path();
    if let Some(dir) = log_path.parent() {
        fs::create_dir_all(dir).map_err(|e| format!("Failed to create log dir: {e}"))?;
    }

    let timestamp_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let line = format!("{timestamp_ms}|{normalized_level}|{sanitized_message}\n");

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .map_err(|e| format!("Failed to open log file: {e}"))?;
    file.write_all(line.as_bytes())
        .map_err(|e| format!("Failed to write log file: {e}"))?;

    Ok(serde_json::json!({
        "ok": true,
        "log_file": log_path.display().to_string(),
        "appended": line.trim_end()
    }))
}

#[tauri::command]
fn demo_read_logs(limit: usize) -> Result<serde_json::Value, String> {
    let max_limit = if limit == 0 { 50 } else { limit.min(500) };
    let log_path = demo_log_path();
    if !log_path.exists() {
        return Ok(serde_json::json!({
            "ok": true,
            "log_file": log_path.display().to_string(),
            "lines": []
        }));
    }

    let content = fs::read_to_string(&log_path).map_err(|e| format!("Failed to read log file: {e}"))?;
    let mut lines: Vec<String> = content
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| line.to_string())
        .collect();

    if lines.len() > max_limit {
        let start = lines.len() - max_limit;
        lines = lines[start..].to_vec();
    }

    Ok(serde_json::json!({
        "ok": true,
        "log_file": log_path.display().to_string(),
        "lines": lines
    }))
}

#[tauri::command]
async fn init_sidecar(
    state: tauri::State<'_, AppState>,
    app: tauri::AppHandle,
    config: serde_json::Value,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;

    // Spawn if not already spawned
    sidecar.spawn(&app).await?;

    // Initialize with config
    let response = sidecar.init(config).await?;

    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn start_recording(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.start_recording().await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn stop_recording(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.stop_recording().await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn transcribe(
    state: tauri::State<'_, AppState>,
    audio_path: String,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.transcribe(&audio_path).await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn get_sidecar_config(
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.get_config().await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn set_sidecar_config(
    state: tauri::State<'_, AppState>,
    config: serde_json::Value,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.set_config(config).await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize state
    let state = AppState {
        sidecar: Arc::new(Mutex::new(SidecarManager::new())),
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .manage(state)
        .invoke_handler(tauri::generate_handler![
            greet,
            demo_health,
            demo_diagnostics,
            demo_service_report,
            demo_live_metrics,
            demo_append_log,
            demo_read_logs,
            init_sidecar,
            start_recording,
            stop_recording,
            transcribe,
            get_sidecar_config,
            set_sidecar_config
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_service_report_contains_required_sections() {
        let report = demo_service_report();

        assert_eq!(report.get("ok").and_then(|v| v.as_bool()), Some(true));
        assert!(report.get("host").is_some());
        assert!(
            report
                .get("measurement_logic")
                .and_then(|v| v.as_array())
                .map(|v| !v.is_empty())
                .unwrap_or(false)
        );
        assert!(report.get("hw_requirements_estimate").is_some());
        assert!(
            report
                .get("code_lines_by_language")
                .and_then(|v| v.as_array())
                .is_some()
        );
        assert!(
            report
                .get("component_load")
                .and_then(|v| v.as_array())
                .is_some()
        );
    }

    #[test]
    fn process_groups_returns_expected_component_count() {
        let mut system = System::new_all();
        system.refresh_all();
        let groups = process_groups(&system);
        assert_eq!(groups.len(), 3);
    }

    #[test]
    fn demo_live_metrics_contains_online_sections() {
        let report = demo_live_metrics();
        assert_eq!(report.get("ok").and_then(|v| v.as_bool()), Some(true));
        assert!(report.get("host").is_some());
        assert!(
            report
                .get("component_load")
                .and_then(|v| v.as_array())
                .map(|v| !v.is_empty())
                .unwrap_or(false)
        );
    }

    #[test]
    fn code_lines_are_scoped_and_typed() {
        let Some(root) = find_repo_root() else {
            return;
        };
        let (rows, summary) = analyze_code_scope(&root);
        assert!(!rows.is_empty());
        assert!(
            rows.iter().all(|row| {
                row.get("language")
                    .and_then(|v| v.as_str())
                    .map(|lang| !lang.eq_ignore_ascii_case("other"))
                    .unwrap_or(false)
            })
        );
        assert!(summary.get("files_by_type").and_then(|v| v.as_array()).is_some());
    }
}
