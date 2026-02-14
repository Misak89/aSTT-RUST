// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

// Export modules
pub mod rpc;
pub mod sidecar;

use std::sync::Arc;
use tokio::sync::Mutex;
use sidecar::SidecarManager;

/// Global sidecar manager state
pub struct AppState {
    pub sidecar: Arc<Mutex<SidecarManager>>,
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
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
    
    Ok(serde_json::to_value(response).map_err(|e| e.to_string())?)
}

#[tauri::command]
async fn start_recording(
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.start_recording().await?;
    Ok(serde_json::to_value(response).map_err(|e| e.to_string())?)
}

#[tauri::command]
async fn stop_recording(
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.stop_recording().await?;
    Ok(serde_json::to_value(response).map_err(|e| e.to_string())?)
}

#[tauri::command]
async fn transcribe(
    state: tauri::State<'_, AppState>,
    audio_path: String,
) -> Result<serde_json::Value, String> {
    let mut sidecar = state.sidecar.lock().await;
    let response = sidecar.transcribe(&audio_path).await?;
    Ok(serde_json::to_value(response).map_err(|e| e.to_string())?)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize state
    let state = AppState {
        sidecar: Arc::new(Mutex::new(SidecarManager::new())),
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .manage(state)
        .invoke_handler(tauri::generate_handler![
            greet,
            init_sidecar,
            start_recording,
            stop_recording,
            transcribe
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
