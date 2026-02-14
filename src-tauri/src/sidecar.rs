//! Sidecar Manager Module
//! 
//! Manages the Python sidecar process lifecycle for WhisperX transcription.
//! 
//! Features:
//! - Spawn sidecar process on app startup
//! - JSON-RPC communication via stdin/stdout
//! - Graceful shutdown on app exit

use std::sync::Arc;
use tauri::AppHandle;
use tauri_plugin_shell::ShellExt;
use tauri_plugin_shell::process::CommandEvent;
use tokio::sync::Mutex;
use serde_json::Value;

use crate::rpc::{RpcRequest, RpcResponse, RpcMethod};

/// Sidecar state wrapper
pub struct SidecarManager {
    /// The spawned child process (if any)
    child: Option<tauri_plugin_shell::process::CommandChild>,
    /// Receiver for stdout events
    receiver: Option<tokio::sync::mpsc::Receiver<CommandEvent>>,
    /// Pending request IDs and their responses
    pending_responses: Arc<Mutex<Vec<(u32, tokio::sync::oneshot::Sender<RpcResponse>)>>>,
}

impl SidecarManager {
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

        // Create sidecar command
        let sidecar_command = app
            .shell()
            .sidecar("sidecar")
            .map_err(|e| format!("Failed to create sidecar command: {}", e))?;

        // Spawn the process
        let (mut rx, child) = sidecar_command
            .spawn()
            .map_err(|e| format!("Failed to spawn sidecar: {}", e))?;

        self.child = Some(child);
        self.receiver = Some(rx);

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
                            if let Some(idx) = pending_lock.iter().position(|(id, _)| *id == response.id) {
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

        // Register pending response
        self.pending_responses.lock().await.push((request_id, tx));

        // Serialize and send request
        let request_json = serde_json::to_string(&request)
            .map_err(|e| format!("Failed to serialize request: {}", e))?;

        child.write(format!("{}\n", request_json).as_bytes())
            .map_err(|e| format!("Failed to write to sidecar stdin: {}", e))?;

        // Wait for response with timeout
        tokio::time::timeout(
            std::time::Duration::from_secs(30),
            rx
        )
        .await
        .map_err(|_| "Request timeout".to_string())?
        .map_err(|_| "Response channel closed".to_string())
    }

    /// Initialize the sidecar with configuration
    pub async fn init(&mut self, config: Value) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::Init, config);
        self.send_request(request).await
    }

    /// Start recording
    pub async fn start_recording(&mut self) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::StartRecording, Value::Null);
        self.send_request(request).await
    }

    /// Stop recording
    pub async fn stop_recording(&mut self) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(RpcMethod::StopRecording, Value::Null);
        self.send_request(request).await
    }

    /// Transcribe audio file
    pub async fn transcribe(&mut self, audio_path: &str) -> Result<RpcResponse, String> {
        let request = RpcRequest::new(
            RpcMethod::Transcribe,
            serde_json::json!({ "audio_path": audio_path })
        );
        self.send_request(request).await
    }

    /// Shutdown the sidecar gracefully
    pub fn shutdown(&mut self) -> Result<(), String> {
        if let Some(child) = self.child.take() {
            child.kill().map_err(|e| format!("Failed to kill sidecar: {}", e))?;
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