// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

// Export modules
pub mod rpc;
pub mod sidecar;

use sidecar::SidecarManager;
use chrono::Local;
use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use std::time::{SystemTime, UNIX_EPOCH};
use sysinfo::{Pid, System};
use tauri::menu::{Menu, MenuBuilder, MenuEvent, SubmenuBuilder};
use tauri::{Emitter, Runtime};
use tokio::sync::Mutex;
use walkdir::WalkDir;

#[cfg(all(not(debug_assertions), not(feature = "custom-protocol")))]
compile_error!("Release build requires Tauri feature 'custom-protocol'.");

/// Global sidecar manager state
pub struct AppState {
    sidecar: Arc<Mutex<SidecarManager>>,
    llm: Arc<Mutex<LlmState>>,
}

#[derive(Clone, Debug, Default)]
struct LlmProviderConfig {
    endpoint: String,
    model: String,
    api_key: Option<String>,
    headers: BTreeMap<String, String>,
}

#[derive(Clone, Debug)]
struct LlmState {
    selected_offline_model: String,
    selected_online_model: String,
    online_provider: Option<LlmProviderConfig>,
    offline_provider: Option<LlmProviderConfig>,
}

impl Default for LlmState {
    fn default() -> Self {
        Self {
            selected_offline_model: "qwen3-8b-q4".to_string(),
            selected_online_model: "gpt-4o-mini".to_string(),
            online_provider: None,
            offline_provider: None,
        }
    }
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
    std::env::temp_dir()
        .join("astt_demo_a002")
        .join("service.log")
}

fn transcript_export_root() -> PathBuf {
    if let Some(root) = find_repo_root() {
        return root
            .join("sandbox")
            .join("TestDocu_a004")
            .join("session_exports")
            .join("transcripts");
    }

    std::env::temp_dir()
        .join("astt_demo_a004")
        .join("transcripts")
}

fn sanitize_export_label(input: &str) -> String {
    let mut slug = String::new();
    let mut last_underscore = false;

    for ch in input.chars() {
        let mapped = if ch.is_ascii_alphanumeric() {
            ch.to_ascii_lowercase()
        } else {
            '_'
        };

        if mapped == '_' {
            if !slug.is_empty() && !last_underscore {
                slug.push('_');
            }
            last_underscore = true;
        } else {
            slug.push(mapped);
            last_underscore = false;
        }
    }

    while slug.ends_with('_') {
        slug.pop();
    }

    if slug.is_empty() {
        return "transcript".to_string();
    }

    if slug.len() > 64 {
        slug.truncate(64);
        while slug.ends_with('_') {
            slug.pop();
        }
    }

    if slug.is_empty() {
        "transcript".to_string()
    } else {
        slug
    }
}

fn sanitize_youtube_id(input: &str) -> Option<String> {
    let id: String = input
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || *ch == '-' || *ch == '_')
        .collect();
    if id.len() < 6 {
        None
    } else {
        Some(id)
    }
}

fn query_param_value(raw: &str, key: &str) -> Option<String> {
    let query = raw.split('?').nth(1)?.split('#').next().unwrap_or("");
    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        let k = parts.next().unwrap_or("").trim();
        if k != key {
            continue;
        }
        let value = parts.next().unwrap_or("").trim();
        if !value.is_empty() {
            return Some(value.to_string());
        }
    }
    None
}

fn extract_youtube_id(raw: &str) -> Option<String> {
    let lower = raw.to_ascii_lowercase();

    if lower.contains("youtu.be/") {
        let candidate = raw
            .split("youtu.be/")
            .nth(1)
            .and_then(|v| v.split(['?', '&', '#', '/']).next())
            .unwrap_or("");
        return sanitize_youtube_id(candidate);
    }

    if lower.contains("youtube.com") {
        if let Some(v) = query_param_value(raw, "v") {
            if let Some(id) = sanitize_youtube_id(&v) {
                return Some(id);
            }
        }

        for marker in ["/shorts/", "/embed/", "/live/"] {
            if let Some(rest) = raw.split(marker).nth(1) {
                let candidate = rest.split(['?', '&', '#', '/']).next().unwrap_or("");
                if let Some(id) = sanitize_youtube_id(candidate) {
                    return Some(id);
                }
            }
        }
    }

    None
}

fn url_last_path_segment(raw: &str) -> Option<String> {
    let without_hash = raw.split('#').next().unwrap_or(raw);
    let without_query = without_hash.split('?').next().unwrap_or(without_hash);
    without_query
        .rsplit('/')
        .find(|segment| !segment.trim().is_empty())
        .map(|v| v.to_string())
}

fn url_host(raw: &str) -> Option<String> {
    let after_scheme = raw.split("://").nth(1)?;
    let host_port = after_scheme.split('/').next().unwrap_or("").trim();
    let host = host_port.split(':').next().unwrap_or("").trim();
    if host.is_empty() {
        None
    } else {
        Some(host.to_string())
    }
}

fn derive_transcript_label(source_label: Option<&str>, preferred_label: Option<&str>) -> String {
    if let Some(custom) = preferred_label.map(str::trim).filter(|v| !v.is_empty()) {
        return sanitize_export_label(custom);
    }

    let Some(raw) = source_label.map(str::trim).filter(|v| !v.is_empty()) else {
        return "transcript".to_string();
    };

    let candidate = if raw.starts_with("http://") || raw.starts_with("https://") {
        if let Some(youtube_id) = extract_youtube_id(raw) {
            return sanitize_export_label(&format!("youtube_{youtube_id}"));
        }
        if let Some(last) = url_last_path_segment(raw) {
            last
        } else if let Some(host) = url_host(raw) {
            host
        } else {
            raw.to_string()
        }
    } else {
        Path::new(raw)
            .file_stem()
            .and_then(|v| v.to_str())
            .unwrap_or(raw)
            .to_string()
    };

    sanitize_export_label(&candidate)
}

fn format_export_timestamp(seconds: f64) -> String {
    let safe = if seconds.is_finite() {
        seconds.max(0.0)
    } else {
        0.0
    };
    let total_ms = (safe * 1000.0).round() as u64;
    let hours = total_ms / 3_600_000;
    let minutes = (total_ms % 3_600_000) / 60_000;
    let secs = (total_ms % 60_000) / 1000;
    let millis = total_ms % 1000;
    format!("{hours:02}:{minutes:02}:{secs:02}.{millis:03}")
}

fn normalize_segment_text(value: &str) -> String {
    value
        .replace("\r\n", " ")
        .replace('\r', " ")
        .replace('\n', " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn now_unix_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

fn now_file_stamp_local() -> String {
    Local::now().format("%Y%m%d_%H%M%S_%3f").to_string()
}

fn command_available(command: &str, args: &[&str]) -> bool {
    std::process::Command::new(command)
        .args(args)
        .output()
        .map(|out| out.status.success())
        .unwrap_or(false)
}

fn resolve_python_runtime_command() -> String {
    if let Ok(raw) = std::env::var("ASTT_PYTHON_BIN") {
        let trimmed = raw.trim();
        if !trimmed.is_empty() {
            let candidate = PathBuf::from(trimmed);
            if candidate.is_file() {
                return candidate.to_string_lossy().to_string();
            }
        }
    }

    if let Ok(cwd) = std::env::current_dir() {
        let candidates = [
            cwd.join(".venv-a004").join("Scripts").join("python.exe"),
            cwd.join(".venv-a004").join("bin").join("python"),
            cwd.join("..")
                .join(".venv-a004")
                .join("Scripts")
                .join("python.exe"),
            cwd.join("..").join(".venv-a004").join("bin").join("python"),
            cwd.join(".venv").join("Scripts").join("python.exe"),
            cwd.join(".venv").join("bin").join("python"),
            cwd.join("..").join(".venv").join("Scripts").join("python.exe"),
            cwd.join("..").join(".venv").join("bin").join("python"),
        ];
        if let Some(found) = candidates.into_iter().find(|p| p.is_file()) {
            return found.to_string_lossy().to_string();
        }
    }

    "python".to_string()
}

fn python_import_available(python_command: &str, module_name: &str) -> bool {
    std::process::Command::new(python_command)
        .args(["-c", &format!("import {module_name}")])
        .output()
        .map(|out| out.status.success())
        .unwrap_or(false)
}

fn normalize_mode(mode: &str) -> &'static str {
    match mode.trim().to_ascii_lowercase().as_str() {
        "online" => "online",
        _ => "offline",
    }
}

fn normalize_chat_endpoint(raw_endpoint: &str) -> String {
    let base = raw_endpoint.trim().trim_end_matches('/');
    if base.ends_with("/v1/chat/completions") {
        base.to_string()
    } else {
        format!("{base}/v1/chat/completions")
    }
}

fn default_offline_llm_endpoint() -> String {
    std::env::var("ASTT_OFFLINE_LLM_ENDPOINT")
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| "http://127.0.0.1:11434".to_string())
}

fn collapse_spaces_per_line(text: &str) -> String {
    text.lines()
        .map(|line| line.split_whitespace().collect::<Vec<_>>().join(" "))
        .collect::<Vec<_>>()
        .join("\n")
}

fn dedupe_filler_tokens(text: &str) -> String {
    let mut output: Vec<&str> = Vec::new();
    let filler = ["ehm", "hmm", "um", "uh", "aaa", "eee"];
    let mut prev = String::new();
    for token in text.split_whitespace() {
        let lower = token.to_ascii_lowercase();
        if filler.contains(&lower.as_str()) && prev == lower {
            continue;
        }
        output.push(token);
        prev = lower;
    }
    output.join(" ")
}

fn ensure_sentence_terminal(text: &str) -> String {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    if trimmed.ends_with('.') || trimmed.ends_with('!') || trimmed.ends_with('?') {
        trimmed.to_string()
    } else {
        format!("{trimmed}.")
    }
}

fn stage_a_cleanup(transcript: &str, _profile: &str) -> String {
    let normalized = transcript.replace("\r\n", "\n").replace('\r', "\n");
    let condensed = collapse_spaces_per_line(&normalized);
    let no_fillers = dedupe_filler_tokens(&condensed);
    ensure_sentence_terminal(&no_fillers)
}

fn split_sentences(input: &str) -> Vec<String> {
    let mut out = Vec::new();
    for block in input
        .replace('\n', " ")
        .split_terminator(['.', '!', '?'])
        .map(str::trim)
        .filter(|v| !v.is_empty())
    {
        out.push(block.to_string());
    }
    out
}

fn stage_b_offline_transform(input: &str, profile: &str, template: &str, model_id: &str) -> String {
    let cleaned = stage_a_cleanup(input, "default");
    let mut sentences = split_sentences(&cleaned);
    if sentences.is_empty() && !cleaned.is_empty() {
        sentences.push(cleaned.clone());
    }
    let summary: Vec<String> = sentences.into_iter().take(5).collect();
    let profile_label = if profile.trim().is_empty() {
        "default"
    } else {
        profile.trim()
    };
    let template_label = if template.trim().is_empty() {
        "clinical-note"
    } else {
        template.trim()
    };

    let bullet_lines = if summary.is_empty() {
        "- No content.".to_string()
    } else {
        summary
            .iter()
            .map(|line| format!("- {}", ensure_sentence_terminal(line)))
            .collect::<Vec<_>>()
            .join("\n")
    };

    format!(
        "Mode: offline\nModel: {model_id}\nProfile: {profile_label}\nTemplate: {template_label}\n\nTechnical cleaned input:\n{cleaned}\n\nStructured draft:\n{bullet_lines}"
    )
}

fn preflight_level_rank(level: &str) -> i32 {
    match level {
        "BLOCKER" => 3,
        "WARNING" => 2,
        _ => 1,
    }
}

fn process_name_lc(process: &sysinfo::Process) -> String {
    process.name().to_string_lossy().to_ascii_lowercase()
}

fn build_preflight_report() -> serde_json::Value {
    let mut system = System::new_all();
    system.refresh_all();

    let total_memory_mb = (system.total_memory() as f64) / (1024.0 * 1024.0);
    let used_memory_mb = (system.used_memory() as f64) / (1024.0 * 1024.0);
    let cpu_cores = system.cpus().len();
    let temp_dir = std::env::temp_dir();

    let memory_level = if total_memory_mb < 4096.0 {
        "BLOCKER"
    } else if total_memory_mb < 8192.0 {
        "WARNING"
    } else {
        "INFO"
    };
    let memory_message = if memory_level == "BLOCKER" {
        format!(
            "Total RAM {:.1} MB is below minimum 4096 MB for stable sandbox run.",
            total_memory_mb
        )
    } else if memory_level == "WARNING" {
        format!(
            "Total RAM {:.1} MB is below recommended 8192 MB; offline LLM options will be limited.",
            total_memory_mb
        )
    } else {
        format!(
            "Total RAM {:.1} MB is within recommended range.",
            total_memory_mb
        )
    };

    let temp_probe_dir = temp_dir.join("astt_preflight_probe");
    let temp_probe_file = temp_probe_dir.join("probe.txt");
    let temp_ok = fs::create_dir_all(&temp_probe_dir).is_ok()
        && fs::write(&temp_probe_file, b"ok").is_ok()
        && fs::remove_file(&temp_probe_file).is_ok();
    let temp_level = if temp_ok { "INFO" } else { "BLOCKER" };
    let temp_message = if temp_ok {
        format!("Temp directory is writable: {}", temp_dir.display())
    } else {
        format!(
            "Temp directory is not writable; recording/transcript cache may fail: {}",
            temp_dir.display()
        )
    };

    let python_command = resolve_python_runtime_command();
    let python_ok = command_available(python_command.as_str(), &["--version"]);
    let python_level = if python_ok { "INFO" } else { "WARNING" };
    let python_message = if python_ok {
        format!(
            "Python runtime detected for sidecar flow ({}).",
            python_command
        )
    } else {
        format!(
            "Python runtime not detected ({}); packaged sidecar binary fallback is required.",
            python_command
        )
    };

    let sounddevice_ok = if python_ok {
        python_import_available(python_command.as_str(), "sounddevice")
    } else {
        false
    };
    let sounddevice_level = if sounddevice_ok { "INFO" } else { "WARNING" };
    let sounddevice_message = if sounddevice_ok {
        "Python sounddevice package detected (MIC recording backend available).".to_string()
    } else {
        "Python sounddevice package not detected; MIC recording may fail until installed."
            .to_string()
    };

    let whisperx_ok = if python_ok {
        python_import_available(python_command.as_str(), "whisperx")
    } else {
        false
    };
    let whisperx_level = if whisperx_ok { "INFO" } else { "WARNING" };
    let whisperx_message = if whisperx_ok {
        "Python whisperx package detected (primary STT backend available).".to_string()
    } else {
        "Python whisperx package not detected; fallback STT backend is required.".to_string()
    };

    let faster_whisper_ok = if python_ok {
        python_import_available(python_command.as_str(), "faster_whisper")
    } else {
        false
    };
    let faster_whisper_level = if faster_whisper_ok { "INFO" } else { "WARNING" };
    let faster_whisper_message = if faster_whisper_ok {
        "Python faster-whisper package detected (fallback STT backend available).".to_string()
    } else {
        "Python faster-whisper package not detected.".to_string()
    };

    let stt_backend_ok = whisperx_ok || faster_whisper_ok;
    let stt_backend_level = if stt_backend_ok { "INFO" } else { "WARNING" };
    let stt_backend_message = if stt_backend_ok {
        "At least one STT backend module is available.".to_string()
    } else {
        "No STT backend module detected; init/transcribe will fail until whisperx or faster-whisper is installed."
            .to_string()
    };

    let ytdlp_cli_ok = command_available("yt-dlp", &["--version"]);
    let ytdlp_module_ok = if python_ok {
        python_import_available(python_command.as_str(), "yt_dlp")
    } else {
        false
    };
    let ytdlp_ok = ytdlp_cli_ok || ytdlp_module_ok;
    let ytdlp_level = if ytdlp_ok { "INFO" } else { "WARNING" };
    let ytdlp_message = if ytdlp_ok {
        if ytdlp_cli_ok {
            "yt-dlp CLI detected; linked video URL extraction is available.".to_string()
        } else {
            "yt_dlp Python module detected; linked video URL extraction is available.".to_string()
        }
    } else {
        "yt-dlp not detected (CLI/module); some linked video URLs (e.g. YouTube pages) may not transcribe."
            .to_string()
    };

    let ffmpeg_ok = command_available("ffmpeg", &["-version"]);
    let ffmpeg_level = if ffmpeg_ok { "INFO" } else { "WARNING" };
    let ffmpeg_message = if ffmpeg_ok {
        "ffmpeg detected for media decoding.".to_string()
    } else {
        "ffmpeg not detected in PATH; some audio/video formats may fail.".to_string()
    };

    let conflict_markers = ["zoom", "teams", "obs", "discord", "webex"];
    let security_markers = [
        "defender",
        "avast",
        "avg",
        "kaspersky",
        "norton",
        "mcafee",
        "eset",
    ];

    let mut conflict_processes = BTreeSet::new();
    let mut security_processes = BTreeSet::new();
    for process in system.processes().values() {
        let name = process_name_lc(process);
        if conflict_markers.iter().any(|marker| name.contains(marker)) {
            conflict_processes.insert(process.name().to_string_lossy().to_string());
        }
        if security_markers.iter().any(|marker| name.contains(marker)) {
            security_processes.insert(process.name().to_string_lossy().to_string());
        }
    }

    let conflict_level = if conflict_processes.is_empty() {
        "INFO"
    } else {
        "WARNING"
    };
    let conflict_message = if conflict_processes.is_empty() {
        "No known conferencing capture collisions detected.".to_string()
    } else {
        format!(
            "Potential capture collision processes detected: {}",
            conflict_processes
                .iter()
                .cloned()
                .collect::<Vec<_>>()
                .join(", ")
        )
    };

    let security_level = if security_processes.is_empty() {
        "INFO"
    } else {
        "INFO"
    };
    let security_message = if security_processes.is_empty() {
        "No known security tools detected in process list.".to_string()
    } else {
        format!(
            "Security tools detected (informational): {}",
            security_processes
                .iter()
                .cloned()
                .collect::<Vec<_>>()
                .join(", ")
        )
    };

    let checks = vec![
        serde_json::json!({
            "id": "memory",
            "level": memory_level,
            "message": memory_message,
            "observed": {
                "total_memory_mb": total_memory_mb,
                "used_memory_mb": used_memory_mb,
                "cpu_cores": cpu_cores
            }
        }),
        serde_json::json!({
            "id": "temp_dir",
            "level": temp_level,
            "message": temp_message,
            "observed": {
                "path": temp_dir.display().to_string(),
                "writable": temp_ok
            }
        }),
        serde_json::json!({
            "id": "python_runtime",
            "level": python_level,
            "message": python_message,
            "observed": {
                "python_command": python_command,
                "available": python_ok
            }
        }),
        serde_json::json!({
            "id": "python_sounddevice",
            "level": sounddevice_level,
            "message": sounddevice_message,
            "observed": {
                "python_detected": python_ok,
                "module_available": sounddevice_ok
            }
        }),
        serde_json::json!({
            "id": "python_whisperx",
            "level": whisperx_level,
            "message": whisperx_message,
            "observed": {
                "python_detected": python_ok,
                "module_available": whisperx_ok
            }
        }),
        serde_json::json!({
            "id": "python_faster_whisper",
            "level": faster_whisper_level,
            "message": faster_whisper_message,
            "observed": {
                "python_detected": python_ok,
                "module_available": faster_whisper_ok
            }
        }),
        serde_json::json!({
            "id": "stt_backend",
            "level": stt_backend_level,
            "message": stt_backend_message,
            "observed": {
                "whisperx_available": whisperx_ok,
                "faster_whisper_available": faster_whisper_ok
            }
        }),
        serde_json::json!({
            "id": "url_extractor",
            "level": ytdlp_level,
            "message": ytdlp_message,
            "observed": {
                "yt_dlp_available": ytdlp_ok,
                "yt_dlp_cli_available": ytdlp_cli_ok,
                "yt_dlp_module_available": ytdlp_module_ok
            }
        }),
        serde_json::json!({
            "id": "ffmpeg_runtime",
            "level": ffmpeg_level,
            "message": ffmpeg_message,
            "observed": {
                "ffmpeg_available": ffmpeg_ok
            }
        }),
        serde_json::json!({
            "id": "capture_collisions",
            "level": conflict_level,
            "message": conflict_message,
            "observed": {
                "processes": conflict_processes.iter().cloned().collect::<Vec<_>>()
            }
        }),
        serde_json::json!({
            "id": "security_software",
            "level": security_level,
            "message": security_message,
            "observed": {
                "processes": security_processes.iter().cloned().collect::<Vec<_>>()
            }
        }),
    ];

    let overall = checks
        .iter()
        .filter_map(|check| check.get("level").and_then(|v| v.as_str()))
        .max_by_key(|level| preflight_level_rank(level))
        .unwrap_or("INFO");

    let recommendation = match overall {
        "BLOCKER" => "Fix blockers first; risky runtime paths stay disabled.",
        "WARNING" => "Continue with caution; check warnings before long recording sessions.",
        _ => "Preflight passed for sandbox testing.",
    };

    serde_json::json!({
        "ok": overall != "BLOCKER",
        "overall_level": overall,
        "recommendation": recommendation,
        "generated_at_unix_ms": now_unix_ms(),
        "checks": checks
    })
}

fn offline_model_catalog() -> Vec<serde_json::Value> {
    vec![
        serde_json::json!({
            "id": "qwen3-8b-q4",
            "label": "Qwen3 8B Q4_K_M",
            "mode": "offline",
            "memory_hint_gb": "6-8"
        }),
        serde_json::json!({
            "id": "gemma3-12b-q4",
            "label": "Gemma 3 12B Q4",
            "mode": "offline",
            "memory_hint_gb": "9-12"
        }),
        serde_json::json!({
            "id": "qwen3-14b-q4",
            "label": "Qwen3 14B Q4_K_M",
            "mode": "offline",
            "memory_hint_gb": "10-14"
        }),
        serde_json::json!({
            "id": "phi4-mini-q4",
            "label": "Phi-4-mini-instruct Q4",
            "mode": "offline",
            "memory_hint_gb": "4-6"
        }),
    ]
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
        root.join("src-tauri")
            .join("capabilities")
            .join("default.json"),
        root.join("src-ui").join("routes").join("+page.svelte"),
        root.join("src-ui")
            .join("routes")
            .join("demo-a002")
            .join("+page.svelte"),
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

fn path_has_component(path: &Path, name: &str) -> bool {
    path.components().any(|component| {
        component
            .as_os_str()
            .to_string_lossy()
            .eq_ignore_ascii_case(name)
    })
}

fn normalize_existing_dir(path_value: &str) -> Option<PathBuf> {
    let trimmed = path_value.trim();
    if trimmed.is_empty() {
        return None;
    }

    let candidate = PathBuf::from(trimmed);
    let resolved = if candidate.is_absolute() {
        candidate
    } else {
        std::env::current_dir().ok()?.join(candidate)
    };

    if !resolved.exists() || !resolved.is_dir() {
        return None;
    }

    resolved.canonicalize().ok().or(Some(resolved))
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
    framework_counts: BTreeMap<String, (u64, u64)>,
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

fn register_framework_hit(state: &mut CodeScanState, framework: &str, lines: u64) {
    let slot = state
        .framework_counts
        .entry(framework.to_string())
        .or_insert((0, 0));
    slot.0 += lines;
    slot.1 += 1;
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

    let mut framework_hits: BTreeSet<&'static str> = BTreeSet::new();
    let file_name = path
        .file_name()
        .and_then(|s| s.to_str())
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default();

    if path.starts_with(src_tauri_root) || file_name == "tauri.conf.json" {
        framework_hits.insert("Tauri");
    }
    if path_has_component(path, "src-ui")
        || path
            .extension()
            .and_then(|s| s.to_str())
            .map(|s| s.eq_ignore_ascii_case("svelte"))
            .unwrap_or(false)
    {
        framework_hits.insert("SvelteKit");
    }
    if path_has_component(path, "electron") {
        framework_hits.insert("Electron");
    }
    if language == "Rust" {
        framework_hits.insert("Rust");
    }
    if language == "Python" {
        framework_hits.insert("Python");
    }
    if language == "JavaScript" || language == "TypeScript" {
        framework_hits.insert("Node.js ecosystem");
    }
    if file_name == "sidecar.py" {
        framework_hits.insert("Python sidecar");
    }

    for framework in framework_hits {
        register_framework_hit(state, framework, lines);
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

fn analyze_code_scope_with_roots(
    root: &Path,
    source_roots: Vec<PathBuf>,
) -> (Vec<serde_json::Value>, serde_json::Value) {
    let mut state = CodeScanState {
        stats: BTreeMap::new(),
        file_type_counts: BTreeMap::new(),
        framework_counts: BTreeMap::new(),
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
            let iter = WalkDir::new(&scan_root).into_iter().filter_entry(|entry| {
                !entry.file_type().is_dir() || !should_skip_dir(entry.path())
            });

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

    let mut framework_rows: Vec<(String, (u64, u64))> =
        state.framework_counts.into_iter().collect();
    framework_rows.sort_by(|a, b| b.1 .0.cmp(&a.1 .0));
    let framework_counts: Vec<serde_json::Value> = framework_rows
        .iter()
        .map(|(name, (lines, files))| {
            serde_json::json!({
                "name": name,
                "lines": lines,
                "files": files
            })
        })
        .collect();

    state.demo_files_raw.sort_by(|a, b| b.0.cmp(&a.0));
    let demo_files: Vec<serde_json::Value> =
        state.demo_files_raw.into_iter().map(|(_, v)| v).collect();

    let languages_detected: Vec<String> = code_line_rows
        .iter()
        .filter_map(|row| {
            row.get("language")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string())
        })
        .collect();
    let frameworks_detected: Vec<String> = framework_rows
        .iter()
        .filter(|(_, (_, files))| *files > 0)
        .map(|(name, _)| name.clone())
        .collect();

    let mut technology_stack = Vec::<String>::new();
    for framework in &frameworks_detected {
        if !technology_stack.contains(framework) {
            technology_stack.push(framework.clone());
        }
    }
    for language in &languages_detected {
        if !technology_stack.contains(language) {
            technology_stack.push(language.clone());
        }
    }

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
        "framework_counts": framework_counts,
        "languages_detected": languages_detected,
        "frameworks_detected": frameworks_detected,
        "technology_stack": technology_stack,
        "demo_files_count": demo_files.len(),
        "demo_files": demo_files
    });

    (code_line_rows, summary)
}

fn analyze_code_scope(root: &Path) -> (Vec<serde_json::Value>, serde_json::Value) {
    analyze_code_scope_with_roots(root, code_scope_roots(root))
}

fn process_is_descendant_of(system: &System, pid: Pid, ancestor: Pid, max_depth: usize) -> bool {
    let mut current = Some(pid);
    for _ in 0..max_depth {
        let Some(current_pid) = current else {
            return false;
        };
        if current_pid == ancestor {
            return true;
        }
        let Some(process) = system.process(current_pid) else {
            return false;
        };
        let Some(parent_pid) = process.parent() else {
            return false;
        };
        if parent_pid == ancestor {
            return true;
        }
        current = Some(parent_pid);
    }
    false
}

fn process_groups(system: &System) -> Vec<serde_json::Value> {
    let self_pid = Pid::from_u32(std::process::id());
    let mut rust_host_cpu = 0.0f32;
    let mut rust_host_mem = 0u64;
    let mut rust_host_count = 0usize;
    let mut rust_host_pids: Vec<u32> = Vec::new();
    let mut sidecar_cpu = 0.0f32;
    let mut sidecar_mem = 0u64;
    let mut sidecar_count = 0usize;
    let mut sidecar_pids: Vec<u32> = Vec::new();
    let mut tauri_runtime_cpu = 0.0f32;
    let mut tauri_runtime_mem = 0u64;
    let mut tauri_runtime_count = 0usize;
    let mut tauri_runtime_pids: Vec<u32> = Vec::new();
    let mut unmatched_child_pids: Vec<u32> = Vec::new();

    for (pid, process) in system.processes() {
        let pid_u32 = pid.as_u32();
        let cmd_text = process
            .cmd()
            .iter()
            .map(|s| s.to_string_lossy().to_ascii_lowercase())
            .collect::<Vec<String>>()
            .join(" ");
        let name_text = process.name().to_string_lossy().to_ascii_lowercase();
        let cpu = process.cpu_usage();
        let memory = process.memory();

        if *pid == self_pid {
            rust_host_cpu += cpu;
            rust_host_mem += memory;
            rust_host_count += 1;
            rust_host_pids.push(pid_u32);
            continue;
        }

        let descendant_matches = process_is_descendant_of(system, *pid, self_pid, 8);
        if !descendant_matches {
            continue;
        }

        let is_sidecar = cmd_text.contains("sidecar")
            || name_text.contains("sidecar")
            || cmd_text.contains("whisperx");
        if is_sidecar {
            sidecar_cpu += cpu;
            sidecar_mem += memory;
            sidecar_count += 1;
            sidecar_pids.push(pid_u32);
            continue;
        }

        let is_runtime = name_text.contains("webview")
            || name_text.contains("msedgewebview2")
            || name_text.contains("msedge")
            || name_text.contains("webkit")
            || cmd_text.contains("webview")
            || cmd_text.contains("webview2")
            || cmd_text.contains("msedgewebview2");
        if is_runtime {
            tauri_runtime_cpu += cpu;
            tauri_runtime_mem += memory;
            tauri_runtime_count += 1;
            tauri_runtime_pids.push(pid_u32);
            continue;
        }

        unmatched_child_pids.push(pid_u32);
    }

    let host_status = if rust_host_count > 0 { "ok" } else { "error" };
    let host_detail = if rust_host_count > 0 {
        format!("Host PID {} detected directly.", self_pid.as_u32())
    } else {
        "Host PID was not detected (unexpected sample).".to_string()
    };

    let runtime_status = if tauri_runtime_count > 0 {
        "ok"
    } else {
        "warning"
    };
    let runtime_detail = if tauri_runtime_count > 0 {
        format!(
            "Matched {} runtime child processes in current sample.",
            tauri_runtime_count
        )
    } else if !unmatched_child_pids.is_empty() {
        format!(
            "No runtime marker match; {} child processes remained unmatched.",
            unmatched_child_pids.len()
        )
    } else {
        "No runtime child process detected in current sample.".to_string()
    };

    let sidecar_status = if sidecar_count > 0 { "ok" } else { "info" };
    let sidecar_detail = if sidecar_count > 0 {
        format!(
            "Matched {} sidecar process(es) in current sample.",
            sidecar_count
        )
    } else {
        "Sidecar process is currently not running (expected while idle).".to_string()
    };

    vec![
        serde_json::json!({
            "component": "Rust host process",
            "approx_code_scope": "src-tauri/src/*.rs",
            "cpu_percent": rust_host_cpu,
            "memory_mb": (rust_host_mem as f64) / (1024.0 * 1024.0),
            "processes": rust_host_count,
            "measurement_note": "Exact PID of this app process.",
            "detection_mode": "exact-self-pid",
            "diagnostic_status": host_status,
            "diagnostic_detail": host_detail,
            "pid_list": rust_host_pids
        }),
        serde_json::json!({
            "component": "Tauri/WebView runtime",
            "approx_code_scope": "Tauri runtime + WebView2/WebKit child processes",
            "cpu_percent": tauri_runtime_cpu,
            "memory_mb": (tauri_runtime_mem as f64) / (1024.0 * 1024.0),
            "processes": tauri_runtime_count,
            "measurement_note": "Child processes (WebView runtime), separated from Rust host.",
            "detection_mode": "descendant + runtime-name markers",
            "diagnostic_status": runtime_status,
            "diagnostic_detail": runtime_detail,
            "pid_list": tauri_runtime_pids,
            "unmatched_child_pids": unmatched_child_pids,
            "unmatched_child_count": unmatched_child_pids.len()
        }),
        serde_json::json!({
            "component": "Python sidecar",
            "approx_code_scope": "src-python/*.py",
            "cpu_percent": sidecar_cpu,
            "memory_mb": (sidecar_mem as f64) / (1024.0 * 1024.0),
            "processes": sidecar_count,
            "measurement_note": "Child sidecar process detected by command/process name.",
            "detection_mode": "descendant + sidecar-name markers",
            "diagnostic_status": sidecar_status,
            "diagnostic_detail": sidecar_detail,
            "pid_list": sidecar_pids
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
fn demo_service_report(scope_root: Option<String>) -> serde_json::Value {
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
    let manual_scope_root = scope_root.as_deref().and_then(normalize_existing_dir);
    let default_scope_root = repo_root.clone().or_else(|| std::env::current_dir().ok());

    let (selected_scope_root, scope_policy, code_lines, code_scope_summary) =
        if let Some(scope) = manual_scope_root {
            let (rows, summary) = analyze_code_scope_with_roots(&scope, vec![scope.clone()]);
            (scope, "manual-root", rows, summary)
        } else if let Some(scope) = default_scope_root {
            let (rows, summary) = analyze_code_scope(&scope);
            (scope, "latest-demo-fileset", rows, summary)
        } else {
            (
                PathBuf::from(""),
                "latest-demo-fileset",
                Vec::new(),
                serde_json::json!({
                    "source_roots_abs": [],
                    "source_roots_rel": [],
                    "subdirectories": 0,
                    "scanned_files": 0,
                    "scan_limit_hit": false,
                    "max_files": 30000,
                    "file_types_total": 0,
                    "files_by_type": [],
                    "framework_counts": [],
                    "languages_detected": [],
                    "frameworks_detected": [],
                    "technology_stack": []
                }),
            )
        };
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
    let code_scope_languages_detected = code_scope_summary
        .get("languages_detected")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_frameworks_detected = code_scope_summary
        .get("frameworks_detected")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let code_scope_technology_stack = code_scope_summary
        .get("technology_stack")
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
    let selected_scope_root_string = selected_scope_root.display().to_string();
    let code_scope_summary_text = format!(
        "Scanned scope '{}': languages={}, frameworks={}, files={}, subdirectories={}.",
        selected_scope_root_string,
        code_scope_languages_detected
            .as_array()
            .map(|v| v.len())
            .unwrap_or(0),
        code_scope_frameworks_detected
            .as_array()
            .map(|v| v.len())
            .unwrap_or(0),
        code_scope_scanned_files.as_u64().unwrap_or(0),
        code_scope_subdirs.as_u64().unwrap_or(0)
    );

    serde_json::json!({
        "ok": true,
        "generated_at_unix_ms": generated_at_unix_ms,
        "sampling_window_ms": sampling_window_ms,
        "host": host,
        "measurement_logic": [
            "HW load is online: sysinfo snapshots are sampled repeatedly (every UI poll interval).",
            "Rust host load is measured separately from Tauri/WebView child processes where possible.",
            "Code-line stats are taken from selected source scope (manual folder or default latest-demo file set).",
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
                "source": "WalkDir over selected source scope",
                "mode": "on-demand",
                "interval_ms": 0,
                "note": "Counts recognized text source extensions in selected directory scope."
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
        "technology_stack": code_scope_technology_stack,
        "code_scope_summary_text": code_scope_summary_text,
        "code_lines_by_language": code_lines,
        "framework_counts": code_scope_framework_counts,
        "demo_files": code_scope_demo_files,
        "code_lines_scope": {
            "current_working_dir": current_working_dir,
            "repo_root": repo_root_string,
            "selected_root_abs": selected_scope_root_string,
            "selected_root_mode": scope_policy,
            "source_roots": code_scope_roots_rel,
            "source_roots_abs": code_scope_roots_abs,
            "count_mode": "on-demand",
            "scope_policy": scope_policy,
            "counted_at_unix_ms": now_unix_ms(),
            "subdirectories": code_scope_subdirs,
            "scanned_files": code_scope_scanned_files,
            "demo_files_count": code_scope_demo_files_count,
            "scan_limit_hit": code_scope_scan_limit_hit,
            "max_files": code_scope_max_files,
            "file_types_total": code_scope_file_types_total,
            "files_by_type": code_scope_files_by_type,
            "languages_detected": code_scope_languages_detected,
            "frameworks_detected": code_scope_frameworks_detected,
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

    let content =
        fs::read_to_string(&log_path).map_err(|e| format!("Failed to read log file: {e}"))?;
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
fn abort_current_request() -> serde_json::Value {
    sidecar::request_abort_current_request();
    serde_json::json!({
        "ok": true,
        "status": "abort_requested"
    })
}

#[tauri::command]
fn save_transcript_txt(
    text: String,
    source_label: Option<String>,
    language: Option<String>,
    engine: Option<String>,
    segments: Option<serde_json::Value>,
    file_label: Option<String>,
    settings: Option<serde_json::Value>,
    raw_response: Option<serde_json::Value>,
) -> Result<serde_json::Value, String> {
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    let trimmed = normalized.trim();
    if trimmed.is_empty() {
        return Err("Transcript text is empty".to_string());
    }

    let export_dir = transcript_export_root();
    fs::create_dir_all(&export_dir).map_err(|e| format!("Failed to create export dir: {e}"))?;

    let export_unix_ms = now_unix_ms();
    let label = derive_transcript_label(source_label.as_deref(), file_label.as_deref());
    let export_stamp = now_file_stamp_local();
    let export_path = export_dir.join(format!("{label}_{export_stamp}.txt"));

    let mut payload = String::new();
    payload.push_str("# aSTT Transcript Export\n");
    payload.push_str(&format!("export_unix_ms={export_unix_ms}\n"));
    if let Some(source) = source_label
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
    {
        payload.push_str(&format!("source={source}\n"));
    }
    if let Some(lang) = language.as_deref().map(str::trim).filter(|v| !v.is_empty()) {
        payload.push_str(&format!("language={lang}\n"));
    }
    if let Some(stt_engine) = engine.as_deref().map(str::trim).filter(|v| !v.is_empty()) {
        payload.push_str(&format!("engine={stt_engine}\n"));
    }
    payload.push_str("format_version=3\n");
    payload.push_str("section_1=full_transcript\n");
    payload.push_str("section_2=numbered_segments_with_time\n");
    payload.push_str("section_3=settings_snapshot_json\n");
    payload.push_str("section_4=raw_rpc_response_json\n");
    payload.push_str(
        "segment_line_format=NNN | HH:MM:SS.mmm -> HH:MM:SS.mmm | speaker=<value-or-> | text=<segment_text>\n",
    );

    payload.push_str("\n[full_transcript]\n");
    payload.push_str(trimmed);
    payload.push('\n');

    payload.push_str("\n[numbered_segments_with_time]\n");
    let mut written_segments = 0usize;
    if let Some(rows) = segments.as_ref().and_then(|v| v.as_array()) {
        for row in rows {
            let Some(obj) = row.as_object() else {
                continue;
            };
            let start = obj.get("start").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let end = obj.get("end").and_then(|v| v.as_f64()).unwrap_or(start);
            let speaker = obj
                .get("speaker")
                .and_then(|v| v.as_str())
                .map(str::trim)
                .filter(|v| !v.is_empty())
                .unwrap_or("-");
            let text_value = obj
                .get("text")
                .and_then(|v| v.as_str())
                .map(normalize_segment_text)
                .unwrap_or_default();
            if text_value.is_empty() {
                continue;
            }

            let start_ts = format_export_timestamp(start);
            let end_ts = format_export_timestamp(end);
            let line_no = written_segments + 1;
            payload.push_str(&format!(
                "{:03} | {} -> {} | speaker={} | text={}\n",
                line_no,
                start_ts,
                end_ts,
                speaker,
                text_value
            ));
            written_segments += 1;
        }
    }
    if written_segments == 0 {
        payload.push_str("000 | 00:00:00.000 -> 00:00:00.000 | speaker=- | text=<no_segments_available>\n");
    }

    payload.push_str("\n[settings_snapshot_json]\n");
    if let Some(snapshot) = settings {
        match serde_json::to_string_pretty(&snapshot) {
            Ok(json) => {
                payload.push_str(&json);
                payload.push('\n');
            }
            Err(_) => {
                payload.push_str("{\"error\":\"failed to serialize settings snapshot\"}\n");
            }
        }
    } else {
        payload.push_str("{\"info\":\"settings snapshot not provided\"}\n");
    }

    payload.push_str("\n[raw_rpc_response_json]\n");
    if let Some(raw) = raw_response {
        match serde_json::to_string_pretty(&raw) {
            Ok(json) => {
                payload.push_str(&json);
                payload.push('\n');
            }
            Err(_) => {
                payload.push_str("{\"error\":\"failed to serialize raw rpc response\"}\n");
            }
        }
    } else {
        payload.push_str("{\"info\":\"raw rpc response not provided\"}\n");
    }

    fs::write(&export_path, payload.as_bytes())
        .map_err(|e| format!("Failed to write transcript TXT: {e}"))?;

    Ok(serde_json::json!({
        "ok": true,
        "label": label,
        "export_stamp_local": export_stamp,
        "path": export_path.display().to_string(),
        "export_dir": export_dir.display().to_string(),
        "bytes": payload.len(),
        "chars": trimmed.chars().count(),
        "segments_exported": written_segments
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

fn response_indicates_not_initialized(response: &rpc::RpcResponse) -> bool {
    let Some(result) = response.result.as_ref() else {
        return false;
    };
    let Some(status) = result.get("status").and_then(|v| v.as_str()) else {
        return false;
    };
    if !status.eq_ignore_ascii_case("error") {
        return false;
    }
    let Some(message) = result.get("message").and_then(|v| v.as_str()) else {
        return false;
    };
    message.to_ascii_lowercase().contains("not initialized")
}

async fn auto_init_sidecar_if_needed(sidecar: &mut SidecarManager) -> Result<(), String> {
    let init_response = sidecar.init(serde_json::json!({ "config": {} })).await?;
    if let Some(result) = init_response.result.as_ref() {
        if let Some(status) = result.get("status").and_then(|v| v.as_str()) {
            if status.eq_ignore_ascii_case("error") {
                let message = result
                    .get("message")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Auto init failed");
                return Err(format!("Auto-init failed: {message}"));
            }
        }
    }
    Ok(())
}

#[tauri::command]
async fn start_recording(
    state: tauri::State<'_, AppState>,
    app: tauri::AppHandle,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    sidecar.spawn(&app).await?;
    let response = sidecar.start_recording().await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn stop_recording(
    state: tauri::State<'_, AppState>,
    app: tauri::AppHandle,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    sidecar.spawn(&app).await?;
    let response = sidecar.stop_recording().await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn transcribe(
    state: tauri::State<'_, AppState>,
    app: tauri::AppHandle,
    audio_path: String,
    clip_seconds: Option<u32>,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    sidecar.spawn(&app).await?;
    let mut response = sidecar.transcribe(&audio_path, clip_seconds).await?;
    if response_indicates_not_initialized(&response) {
        auto_init_sidecar_if_needed(&mut sidecar).await?;
        response = sidecar.transcribe(&audio_path, clip_seconds).await?;
    }
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn get_sidecar_config(
    state: tauri::State<'_, AppState>,
    app: tauri::AppHandle,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    sidecar.spawn(&app).await?;
    let response = sidecar.get_config().await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
async fn set_sidecar_config(
    state: tauri::State<'_, AppState>,
    app: tauri::AppHandle,
    config: serde_json::Value,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    sidecar.spawn(&app).await?;
    let response = sidecar.set_config(config).await?;
    serde_json::to_value(response).map_err(|e| e.to_string())
}

#[tauri::command]
fn preflight_check() -> serde_json::Value {
    build_preflight_report()
}

#[tauri::command]
fn preflight_details() -> serde_json::Value {
    let mut report = build_preflight_report();
    if let Some(obj) = report.as_object_mut() {
        obj.insert(
            "host".to_string(),
            serde_json::json!({
                "os": std::env::consts::OS,
                "arch": std::env::consts::ARCH,
                "pid": std::process::id(),
                "cwd": std::env::current_dir().ok().map(|p| p.display().to_string()),
                "temp_dir": std::env::temp_dir().display().to_string()
            }),
        );
    }
    report
}

#[tauri::command]
fn text_stage_a_process(transcript: String, profile: Option<String>) -> serde_json::Value {
    let normalized_profile = profile
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .unwrap_or("default");
    let cleaned = stage_a_cleanup(&transcript, normalized_profile);
    let before_chars = transcript.chars().count();
    let after_chars = cleaned.chars().count();
    let before_words = transcript.split_whitespace().count();
    let after_words = cleaned.split_whitespace().count();

    serde_json::json!({
        "ok": true,
        "status": "ok",
        "profile": normalized_profile,
        "text": cleaned,
        "metrics": {
            "before_chars": before_chars,
            "after_chars": after_chars,
            "before_words": before_words,
            "after_words": after_words
        }
    })
}

#[tauri::command]
async fn llm_get_models(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let llm = state.llm.lock().await;
    let online_default = llm.selected_online_model.clone();
    let offline_default = llm.selected_offline_model.clone();
    let online_provider = llm.online_provider.clone();
    let offline_provider = llm.offline_provider.clone();
    drop(llm);

    Ok(serde_json::json!({
        "ok": true,
        "offline_models": offline_model_catalog(),
        "online_models": [
            {"id": "gpt-4o-mini", "label": "OpenAI GPT-4o mini", "mode": "online"},
            {"id": "gpt-4.1-mini", "label": "OpenAI GPT-4.1 mini", "mode": "online"},
            {"id": "grok-3-mini", "label": "xAI Grok 3 mini compatible", "mode": "online"},
            {"id": "claude-sonnet-compatible", "label": "Claude-compatible gateway", "mode": "online"}
        ],
        "selected": {
            "offline_model": offline_default,
            "online_model": online_default
        },
        "provider_configured": {
            "online": online_provider.is_some(),
            "offline": offline_provider.is_some()
        },
        "offline_runtime": {
            "default_endpoint": default_offline_llm_endpoint(),
            "auto_local_fallback": true
        }
    }))
}

#[tauri::command]
async fn llm_set_model(
    state: tauri::State<'_, AppState>,
    mode: String,
    model_id: String,
) -> Result<serde_json::Value, String> {
    let model = model_id.trim();
    if model.is_empty() {
        return Err("model_id cannot be empty".to_string());
    }

    let normalized_mode = normalize_mode(&mode);
    let mut llm = state.llm.lock().await;
    if normalized_mode == "online" {
        llm.selected_online_model = model.to_string();
    } else {
        llm.selected_offline_model = model.to_string();
    }

    Ok(serde_json::json!({
        "ok": true,
        "mode": normalized_mode,
        "model_id": model
    }))
}

#[tauri::command]
async fn llm_register_provider(
    state: tauri::State<'_, AppState>,
    provider_config: serde_json::Value,
) -> Result<serde_json::Value, String> {
    let mode = provider_config
        .get("mode")
        .and_then(|v| v.as_str())
        .map(normalize_mode)
        .unwrap_or("online");
    let endpoint = provider_config
        .get("endpoint")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .unwrap_or("");
    if endpoint.is_empty() {
        return Err("provider_config.endpoint is required".to_string());
    }
    if !(endpoint.starts_with("https://") || endpoint.starts_with("http://")) {
        return Err("provider_config.endpoint must start with http:// or https://".to_string());
    }

    let mut llm = state.llm.lock().await;
    let incoming_model = provider_config
        .get("model")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .unwrap_or("");
    let resolved_model = if mode == "online" {
        if !incoming_model.is_empty() {
            llm.selected_online_model = incoming_model.to_string();
        }
        if incoming_model.is_empty() {
            llm.selected_online_model.clone()
        } else {
            incoming_model.to_string()
        }
    } else {
        if !incoming_model.is_empty() {
            llm.selected_offline_model = incoming_model.to_string();
        }
        if incoming_model.is_empty() {
            llm.selected_offline_model.clone()
        } else {
            incoming_model.to_string()
        }
    };

    let api_key = provider_config
        .get("api_key")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(|v| v.to_string());

    let mut headers = BTreeMap::new();
    if let Some(obj) = provider_config.get("headers").and_then(|v| v.as_object()) {
        for (key, value) in obj {
            if let Some(value_str) = value.as_str() {
                headers.insert(key.clone(), value_str.to_string());
            }
        }
    }

    let config = LlmProviderConfig {
        endpoint: endpoint.to_string(),
        model: resolved_model.clone(),
        api_key,
        headers,
    };
    if mode == "online" {
        llm.online_provider = Some(config);
    } else {
        llm.offline_provider = Some(config);
    }

    Ok(serde_json::json!({
        "ok": true,
        "status": "registered",
        "mode": mode,
        "endpoint": endpoint,
        "model": resolved_model
    }))
}

#[tauri::command]
async fn llm_health(
    state: tauri::State<'_, AppState>,
    mode: String,
) -> Result<serde_json::Value, String> {
    let normalized_mode = normalize_mode(&mode);
    let llm = state.llm.lock().await;
    let online_provider = llm.online_provider.clone();
    let offline_provider = llm.offline_provider.clone();
    let offline_model = llm.selected_offline_model.clone();
    let online_model = llm.selected_online_model.clone();
    drop(llm);

    if normalized_mode == "online" {
        let ready = online_provider.is_some();
        return Ok(serde_json::json!({
            "ok": ready,
            "mode": "online",
            "status": if ready { "ready" } else { "not-configured" },
            "model": online_model,
            "provider_configured": ready
        }));
    }

    let local_provider = offline_provider.unwrap_or_else(|| LlmProviderConfig {
        endpoint: default_offline_llm_endpoint(),
        model: offline_model.clone(),
        api_key: None,
        headers: BTreeMap::new(),
    });

    let probe = llm_call_openai_compatible(
        local_provider.clone(),
        if local_provider.model.trim().is_empty() {
            offline_model.clone()
        } else {
            local_provider.model.clone()
        },
        "Health check".to_string(),
        "health".to_string(),
        "health-check".to_string(),
    )
    .await;

    let (status, detail, engine): (&str, String, &str) = match probe {
        Ok(_) => (
            "ready",
            "Local offline endpoint responded.".to_string(),
            "local-openai-compatible",
        ),
        Err(err) => (
            "fallback",
            format!("Local endpoint unavailable, fallback heuristic will be used: {err}"),
            "rule-fallback",
        ),
    };

    Ok(serde_json::json!({
        "ok": true,
        "mode": "offline",
        "status": status,
        "model": offline_model,
        "engine": engine,
        "endpoint": local_provider.endpoint,
        "detail": detail
    }))
}

async fn llm_call_openai_compatible(
    provider: LlmProviderConfig,
    model_id: String,
    input: String,
    profile: String,
    template: String,
) -> Result<String, String> {
    let endpoint = normalize_chat_endpoint(&provider.endpoint);
    let system_prompt = format!(
        "You are a medical text assistant. Profile: {profile}. Template: {template}. Return concise structured output."
    );
    let payload = serde_json::json!({
        "model": model_id,
        "temperature": 0.2,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": input}
        ]
    });

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(60))
        .build()
        .map_err(|e| format!("Failed to build HTTP client: {e}"))?;

    let mut req = client.post(endpoint).json(&payload);
    if let Some(api_key) = provider.api_key.as_deref() {
        req = req.bearer_auth(api_key);
    }
    for (header_name, header_value) in provider.headers {
        req = req.header(header_name, header_value);
    }

    let response = req
        .send()
        .await
        .map_err(|e| format!("Online LLM request failed: {e}"))?;
    let status = response.status();
    let response_text = response
        .text()
        .await
        .map_err(|e| format!("Online LLM body read failed: {e}"))?;

    if !status.is_success() {
        let snippet = if response_text.len() > 300 {
            format!("{}...", &response_text[..300])
        } else {
            response_text.clone()
        };
        return Err(format!("Online LLM returned {}: {}", status, snippet));
    }

    let payload_json: serde_json::Value = serde_json::from_str(&response_text)
        .map_err(|e| format!("Online LLM response parse failed: {e}"))?;
    if let Some(content) = payload_json
        .pointer("/choices/0/message/content")
        .and_then(|v| v.as_str())
    {
        return Ok(content.to_string());
    }
    if let Some(content) = payload_json.get("output_text").and_then(|v| v.as_str()) {
        return Ok(content.to_string());
    }
    Err("Online LLM response missing text content.".to_string())
}

#[tauri::command]
async fn llm_process_text_stage_b(
    state: tauri::State<'_, AppState>,
    input: String,
    mode: String,
    profile: Option<String>,
    template: Option<String>,
) -> Result<serde_json::Value, String> {
    let source = input.trim().to_string();
    if source.is_empty() {
        return Err("input cannot be empty".to_string());
    }

    let normalized_mode = normalize_mode(&mode);
    let normalized_profile = profile.unwrap_or_else(|| "default".to_string());
    let normalized_template = template.unwrap_or_else(|| "clinical-note".to_string());

    let llm = state.llm.lock().await;
    let selected_offline = llm.selected_offline_model.clone();
    let selected_online = llm.selected_online_model.clone();
    let online_provider = llm.online_provider.clone();
    let offline_provider = llm.offline_provider.clone();
    drop(llm);

    if normalized_mode == "online" {
        let Some(provider_config) = online_provider else {
            return Err(
                "online provider is not configured; call llm_register_provider first".to_string(),
            );
        };
        let model_id = if provider_config.model.trim().is_empty() {
            selected_online
        } else {
            provider_config.model.clone()
        };
        let generated = llm_call_openai_compatible(
            provider_config,
            model_id.clone(),
            source.clone(),
            normalized_profile.clone(),
            normalized_template.clone(),
        )
        .await?;
        return Ok(serde_json::json!({
            "ok": true,
            "mode": "online",
            "model": model_id,
            "text": generated
        }));
    }

    let local_provider = offline_provider.unwrap_or_else(|| LlmProviderConfig {
        endpoint: default_offline_llm_endpoint(),
        model: selected_offline.clone(),
        api_key: None,
        headers: BTreeMap::new(),
    });
    let local_model = if local_provider.model.trim().is_empty() {
        selected_offline.clone()
    } else {
        local_provider.model.clone()
    };
    match llm_call_openai_compatible(
        local_provider.clone(),
        local_model.clone(),
        source.clone(),
        normalized_profile.clone(),
        normalized_template.clone(),
    )
    .await
    {
        Ok(generated) => {
            return Ok(serde_json::json!({
                "ok": true,
                "mode": "offline",
                "engine": "local-openai-compatible",
                "endpoint": local_provider.endpoint,
                "model": local_model,
                "text": generated
            }));
        }
        Err(local_error) => {
            let generated = stage_b_offline_transform(
                &source,
                &normalized_profile,
                &normalized_template,
                &selected_offline,
            );
            return Ok(serde_json::json!({
                "ok": true,
                "mode": "offline",
                "engine": "rule-fallback",
                "model": selected_offline,
                "fallback_reason": local_error,
                "text": generated
            }));
        }
    }
}

const MENU_ACTION_EVENT: &str = "astt://menu-action";
const MENU_ID_VIEW_ASR: &str = "menu.view.asr";
const MENU_ID_VIEW_SERVICE: &str = "menu.view.service";
const MENU_ID_HELP_GUIDE: &str = "menu.help.guide";
const MENU_ID_HELP_DIAGNOSTICS: &str = "menu.help.diagnostics";
const MENU_ID_HELP_SERVICE: &str = "menu.help.service";
const MENU_ID_HELP_ABOUT: &str = "menu.help.about";

fn build_native_menu<R: Runtime>(app: &tauri::AppHandle<R>) -> tauri::Result<Menu<R>> {
    let file_menu = SubmenuBuilder::new(app, "File")
        .quit_with_text("Exit")
        .build()?;

    let edit_menu = SubmenuBuilder::new(app, "Edit")
        .cut()
        .copy()
        .paste()
        .select_all()
        .build()?;

    let view_menu = SubmenuBuilder::new(app, "View")
        .text(MENU_ID_VIEW_ASR, "ASR Window")
        .text(MENU_ID_VIEW_SERVICE, "Service Window")
        .build()?;

    let window_menu = SubmenuBuilder::new(app, "Window")
        .minimize()
        .maximize()
        .close_window()
        .build()?;

    let help_menu = SubmenuBuilder::new(app, "Help")
        .text(MENU_ID_HELP_GUIDE, "Návod")
        .text(MENU_ID_HELP_DIAGNOSTICS, "Diagnostika")
        .text(MENU_ID_HELP_SERVICE, "Servisní menu")
        .separator()
        .text(MENU_ID_HELP_ABOUT, "About aSTT")
        .build()?;

    MenuBuilder::new(app)
        .item(&file_menu)
        .item(&edit_menu)
        .item(&view_menu)
        .item(&window_menu)
        .item(&help_menu)
        .build()
}

fn emit_menu_action<R: Runtime>(app: &tauri::AppHandle<R>, action: &str) {
    if let Err(error) = app.emit(MENU_ACTION_EVENT, action.to_string()) {
        eprintln!("menu action emit failed ({action}): {error}");
    }
}

fn handle_native_menu_event<R: Runtime>(app: &tauri::AppHandle<R>, event: MenuEvent) {
    match event.id().as_ref() {
        MENU_ID_VIEW_ASR => emit_menu_action(app, "show_asr"),
        MENU_ID_VIEW_SERVICE | MENU_ID_HELP_SERVICE => emit_menu_action(app, "show_service"),
        MENU_ID_HELP_GUIDE => emit_menu_action(app, "open_guide"),
        MENU_ID_HELP_DIAGNOSTICS => emit_menu_action(app, "open_diagnostics"),
        MENU_ID_HELP_ABOUT => emit_menu_action(app, "open_about"),
        _ => {}
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize state
    let state = AppState {
        sidecar: Arc::new(Mutex::new(SidecarManager::new())),
        llm: Arc::new(Mutex::new(LlmState::default())),
    };

    tauri::Builder::default()
        .menu(build_native_menu)
        .on_menu_event(handle_native_menu_event)
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
            abort_current_request,
            save_transcript_txt,
            init_sidecar,
            start_recording,
            stop_recording,
            transcribe,
            get_sidecar_config,
            set_sidecar_config,
            preflight_check,
            preflight_details,
            text_stage_a_process,
            llm_get_models,
            llm_set_model,
            llm_register_provider,
            llm_health,
            llm_process_text_stage_b
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_service_report_contains_required_sections() {
        let report = demo_service_report(None);

        assert_eq!(report.get("ok").and_then(|v| v.as_bool()), Some(true));
        assert!(report.get("host").is_some());
        assert!(report
            .get("measurement_logic")
            .and_then(|v| v.as_array())
            .map(|v| !v.is_empty())
            .unwrap_or(false));
        assert!(report.get("hw_requirements_estimate").is_some());
        assert!(report
            .get("code_lines_by_language")
            .and_then(|v| v.as_array())
            .is_some());
        assert!(report
            .get("component_load")
            .and_then(|v| v.as_array())
            .is_some());
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
        assert!(report
            .get("component_load")
            .and_then(|v| v.as_array())
            .map(|v| !v.is_empty())
            .unwrap_or(false));
    }

    #[test]
    fn code_lines_are_scoped_and_typed() {
        let Some(root) = find_repo_root() else {
            return;
        };
        let (rows, summary) = analyze_code_scope(&root);
        assert!(!rows.is_empty());
        assert!(rows.iter().all(|row| {
            row.get("language")
                .and_then(|v| v.as_str())
                .map(|lang| !lang.eq_ignore_ascii_case("other"))
                .unwrap_or(false)
        }));
        assert!(summary
            .get("files_by_type")
            .and_then(|v| v.as_array())
            .is_some());
    }

    #[test]
    fn stage_a_cleanup_normalizes_spacing_and_terminal() {
        let input = "Ahoj   toto je   test\r\n\r\num um";
        let output = stage_a_cleanup(input, "default");
        assert!(output.contains("Ahoj toto je test"));
        assert!(output.ends_with('.'));
    }

    #[test]
    fn offline_stage_b_contains_mode_and_model() {
        let output = stage_b_offline_transform(
            "Pacient bez bolesti",
            "default",
            "clinical-note",
            "qwen3-8b-q4",
        );
        assert!(output.contains("Mode: offline"));
        assert!(output.contains("Model: qwen3-8b-q4"));
    }
}
