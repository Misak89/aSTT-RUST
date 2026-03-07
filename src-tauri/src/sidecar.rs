//! Sidecar Manager Module
//!
//! Manages the Python sidecar process lifecycle for WhisperX transcription.
//!
//! Features:
//! - Spawn sidecar process on app startup
//! - JSON-RPC communication via stdin/stdout
//! - Graceful shutdown on app exit

use serde_json::Value;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::AppHandle;
use tauri_plugin_shell::process::CommandEvent;
use tauri_plugin_shell::ShellExt;
use tokio::sync::Mutex;

use crate::rpc::{RpcMethod, RpcRequest, RpcResponse};

type PendingResponseSender = tokio::sync::oneshot::Sender<RpcResponse>;
type PendingResponses = Arc<Mutex<Vec<(u32, PendingResponseSender)>>>;
static ABORT_REQUESTED: AtomicBool = AtomicBool::new(false);

pub fn request_abort_current_request() {
    ABORT_REQUESTED.store(true, Ordering::SeqCst);
}

fn take_abort_current_request() -> bool {
    ABORT_REQUESTED.swap(false, Ordering::SeqCst)
}

/// Sidecar state wrapper
pub struct SidecarManager {
    /// The spawned child process (if any)
    child: Option<tauri_plugin_shell::process::CommandChild>,
    /// Receiver for stdout events
    receiver: Option<tokio::sync::mpsc::Receiver<CommandEvent>>,
    /// Pending request IDs and their responses
    pending_responses: PendingResponses,
}

impl SidecarManager {
    fn resolve_dev_sidecar_script() -> Option<PathBuf> {
        let cwd = std::env::current_dir().ok()?;
        let candidates = [
            cwd.join("src-python").join("sidecar.py"),
            cwd.join("..").join("src-python").join("sidecar.py"),
        ];
        candidates.into_iter().find(|p| p.is_file())
    }

    fn resolve_python_command() -> String {
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
                cwd.join("..").join(".venv-a004").join("Scripts").join("python.exe"),
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

    /// Create a new sidecar manager
    pub fn new() -> Self {
        Self {
            child: None,
            receiver: None,
            pending_responses: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Spawn the sidecar process
    pub async fn spawn(&mut self, app: &AppHandle) -> Result<(), String> {
        if self.child.is_some() {
            return Ok(()); // Already spawned
        }

        let shell = app.shell();
        let python_command = Self::resolve_python_command();

        // Prefer local Python sidecar in dev environments (real WhisperX from local Python env).
        let spawn_result: Result<_, String> = if let Some(script_path) =
            Self::resolve_dev_sidecar_script()
        {
            let script_dir = script_path.parent().unwrap_or(Path::new("."));
            match shell
                .command(&python_command)
                .arg(&script_path)
                .current_dir(script_dir)
                .spawn()
            {
                Ok(spawned) => Ok(spawned),
                Err(python_err) => {
                    eprintln!(
                        "[SIDECAR] Python dev sidecar spawn failed ({} via '{}'), falling back to bundled sidecar",
                        python_err, python_command
                    );
                    shell
                        .sidecar("sidecar")
                        .map_err(|e| format!("Failed to create sidecar command: {}", e))?
                        .spawn()
                        .map_err(|e| format!("Failed to spawn sidecar: {}", e))
                }
            }
        } else {
            shell
                .sidecar("sidecar")
                .map_err(|e| format!("Failed to create sidecar command: {}", e))?
                .spawn()
                .map_err(|e| format!("Failed to spawn sidecar: {}", e))
        };

        let (mut rx, child) = spawn_result?;

        self.child = Some(child);
        // Note: rx is moved to async task, so we don't store it

        // Start listening for responses
        let pending = self.pending_responses.clone();
        tauri::async_runtime::spawn(async move {
            while let Some(event) = rx.recv().await {
                match event {
                    CommandEvent::Stdout(line_bytes) => {
                        let line = String::from_utf8_lossy(&line_bytes);
                        // Try to parse as JSON-RPC response
                        if let Ok(response) = serde_json::from_str::<RpcResponse>(&line) {
                            // Find and complete pending request
                            let mut pending_lock = pending.lock().await;
                            if let Some(idx) =
                                pending_lock.iter().position(|(id, _)| *id == response.id)
                            {
                                let (_, tx) = pending_lock.remove(idx);
                                let _ = tx.send(response);
                            }
                        }
                    }
                    CommandEvent::Stderr(err_bytes) => {
                        let err = String::from_utf8_lossy(&err_bytes);
                        eprintln!("[SIDECAR STDERR] {}", err);
                    }
                    CommandEvent::Error(err) => {
                        eprintln!("[SIDECAR ERROR] {}", err);
                    }
                    CommandEvent::Terminated(payload) => {
                        eprintln!("[SIDECAR] Process terminated: {:?}", payload);
                        break;
                    }
                    _ => {}
                }
            }
        });

        Ok(())
    }

    /// Send a JSON-RPC request and wait for response
    pub async fn send_request(&mut self, request: RpcRequest) -> Result<RpcResponse, String> {
        let child = self.child.as_mut().ok_or("Sidecar not spawned")?;

        // Create oneshot channel for response
        let (tx, rx) = tokio::sync::oneshot::channel();
        let request_id = request.id;
        let method = request.method.clone();

        // Register pending response
        self.pending_responses.lock().await.push((request_id, tx));

        // Serialize and send request
        let request_json = serde_json::to_string(&request)
            .map_err(|e| format!("Failed to serialize request: {}", e))?;

        child
            .write(format!("{}\n", request_json).as_bytes())
            .map_err(|e| format!("Failed to write to sidecar stdin: {}", e))?;

        // Transcription of longer media can take minutes on CPU.
        let timeout_seconds: u64 = match method {
            RpcMethod::Transcribe => 20 * 60,
            RpcMethod::Init => 10 * 60,
            _ => 30,
        };
        let timeout_duration = std::time::Duration::from_secs(timeout_seconds);
        let deadline = tokio::time::Instant::now() + timeout_duration;
        let wait_started_at = tokio::time::Instant::now();
        let mut last_wait_log_at = wait_started_at;
        let mut abort_probe = tokio::time::interval(std::time::Duration::from_millis(120));
        tokio::pin!(rx);

        loop {
            tokio::select! {
                response = &mut rx => {
                    match response {
                        Ok(parsed) => return Ok(parsed),
                        Err(_closed) => {
                            let mut pending = self.pending_responses.lock().await;
                            if let Some(idx) = pending.iter().position(|(id, _)| *id == request_id) {
                                pending.remove(idx);
                            }
                            return Err("Response channel closed".to_string());
                        }
                    }
                }
                _ = abort_probe.tick() => {
                    let now = tokio::time::Instant::now();
                    if now.duration_since(last_wait_log_at) >= std::time::Duration::from_secs(10) {
                        let elapsed_secs = now.duration_since(wait_started_at).as_secs();
                        eprintln!(
                            "[SIDECAR WAIT] method={} elapsed={}s timeout={}s",
                            method, elapsed_secs, timeout_seconds
                        );
                        last_wait_log_at = now;
                    }

                    if take_abort_current_request() {
                        {
                            let mut pending = self.pending_responses.lock().await;
                            if let Some(idx) = pending.iter().position(|(id, _)| *id == request_id) {
                                pending.remove(idx);
                            }
                        }
                        if let Some(child) = self.child.take() {
                            let _ = child.kill();
                        }
                        self.receiver = None;
                        return Err(format!("Request aborted by user (method: {})", method));
                    }

                    if tokio::time::Instant::now() >= deadline {
                        let mut pending = self.pending_responses.lock().await;
                        if let Some(idx) = pending.iter().position(|(id, _)| *id == request_id) {
                            pending.remove(idx);
                        }
                        return Err(format!(
                            "Request timeout after {} seconds (method: {})",
                            timeout_seconds, method
                        ));
                    }
                }
            }
        }
    }

    /// Initialize the sidecar with configuration
    pub async fn init(&mut self, config: Value) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::Init, config);
        self.send_request(request).await
    }

    /// Start recording
    pub async fn start_recording(&mut self) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::StartRecording, serde_json::json!({}));
        self.send_request(request).await
    }

    /// Stop recording
    pub async fn stop_recording(&mut self) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::StopRecording, serde_json::json!({}));
        self.send_request(request).await
    }

    /// Transcribe audio file
    pub async fn transcribe(
        &mut self,
        audio_path: &str,
        clip_seconds: Option<u32>,
    ) -> Result<RpcResponse, String> {
        let mut params = serde_json::json!({ "audio_path": audio_path });
        if let Some(seconds) = clip_seconds {
            if let Some(obj) = params.as_object_mut() {
                obj.insert("clip_seconds".to_string(), serde_json::json!(seconds));
            }
        }
        let request = RpcRequest::new(RpcMethod::Transcribe, params);
        self.send_request(request).await
    }

    /// Get current sidecar configuration
    pub async fn get_config(&mut self) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::GetConfig, serde_json::json!({}));
        self.send_request(request).await
    }

    /// Update sidecar configuration
    pub async fn set_config(&mut self, config: Value) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::SetConfig, config);
        self.send_request(request).await
    }

    /// Shutdown the sidecar gracefully
    pub fn shutdown(&mut self) -> Result<(), String> {
        if let Some(child) = self.child.take() {
            child
                .kill()
                .map_err(|e| format!("Failed to kill sidecar: {}", e))?;
        }
        self.receiver = None;
        Ok(())
    }
}

impl Default for SidecarManager {
    fn default() -> Self {
        Self::new()
    }
}

// Re-export for use in lib.rs
pub use tauri_plugin_shell::ShellExt as SidecarShellExt;
