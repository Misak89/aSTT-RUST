//! JSON-RPC Contract Module
//! 
//! This module implements the JSON-RPC 2.0 specification for communication
//! between the Rust backend and Python sidecar (WhisperX).
//!
//! Contract: JSON-RPC over Stdio
//! - Request: {"jsonrpc": "2.0", "method": "...", "params": {...}, "id": 1}
//! - Response: {"jsonrpc": "2.0", "result": {...}, "id": 1}
//! - Error: {"jsonrpc": "2.0", "error": {"code": -32600, "message": "..."}, "id": 1}
//!
//! Robustness: Non-JSON stdout from Python is treated as internal log

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// JSON-RPC version constant
pub const JSONRPC_VERSION: &str = "2.0";

/// Supported RPC methods
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum RpcMethod {
    Init,
    StartRecording,
    StopRecording,
    Transcribe,
    GetConfig,
    SetConfig,
}

impl std::fmt::Display for RpcMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RpcMethod::Init => write!(f, "init"),
            RpcMethod::StartRecording => write!(f, "start_recording"),
            RpcMethod::StopRecording => write!(f, "stop_recording"),
            RpcMethod::Transcribe => write!(f, "transcribe"),
            RpcMethod::GetConfig => write!(f, "get_config"),
            RpcMethod::SetConfig => write!(f, "set_config"),
        }
    }
}

/// JSON-RPC Request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RpcRequest {
    #[serde(rename = "jsonrpc")]
    pub version: String,
    pub method: RpcMethod,
    pub params: Value,
    pub id: u32,
}

impl RpcRequest {
    /// Create a new RPC request with auto-incrementing ID
    pub fn new(method: RpcMethod, params: Value) -> Self {
        use std::sync::atomic::{AtomicU32, Ordering};
        static ID: AtomicU32 = AtomicU32::new(1);
        
        Self {
            version: JSONRPC_VERSION.to_string(),
            method,
            params,
            id: ID.fetch_add(1, Ordering::SeqCst),
        }
    }
}

/// JSON-RPC Error
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RpcError {
    pub code: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

impl RpcError {
    /// Create a standard JSON-RPC error
    pub fn new(code: i32, message: &str) -> Self {
        Self {
            code,
            message: message.to_string(),
            data: None,
        }
    }
    
    /// Invalid Request (-32600)
    pub fn invalid_request(msg: &str) -> Self {
        Self::new(-32600, msg)
    }
    
    /// Method not found (-32601)
    pub fn method_not_found(method: &str) -> Self {
        Self::new(-32601, &format!("Method not found: {}", method))
    }
    
    /// Internal error (-32603)
    pub fn internal_error(msg: &str) -> Self {
        Self::new(-32603, msg)
    }
}

/// JSON-RPC Response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RpcResponse {
    #[serde(rename = "jsonrpc")]
    pub version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<RpcError>,
    pub id: u32,
}

impl RpcResponse {
    /// Create a success response
    pub fn success(result: Value, id: u32) -> Self {
        Self {
            version: JSONRPC_VERSION.to_string(),
            result: Some(result),
            error: None,
            id,
        }
    }
    
    /// Create an error response
    pub fn error(error: RpcError, id: u32) -> Self {
        Self {
            version: JSONRPC_VERSION.to_string(),
            result: None,
            error: Some(error),
            id,
        }
    }
}

/// Parse a response from Python sidecar, filtering non-JSON output
/// 
/// Python might output logs to stdout that are not JSON.
/// These should be ignored by the RPC parser (robustness requirement).
pub fn parse_response(output: &str) -> Option<RpcResponse> {
    // Try to parse as JSON-RPC response
    serde_json::from_str::<RpcResponse>(output).ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_request_serialization() {
        let request = RpcRequest::new(
            RpcMethod::Init, 
            serde_json::json!({"model": "base", "device": "cpu"})
        );
        
        let json = serde_json::to_string(&request).expect("Failed to serialize");
        
        // Verify JSON-RPC 2.0 format
        assert!(json.contains(r#""jsonrpc":"2.0""#));
        assert!(json.contains(r#""method":"init""#));
    }
    
    #[test]
    fn test_response_deserialization() {
        let json = r#"{"jsonrpc":"2.0","result":{"status":"ready"},"id":1}"#;
        
        let response: RpcResponse = serde_json::from_str(json).expect("Failed to deserialize");
        
        assert!(response.result.is_some());
        assert!(response.error.is_none());
        assert_eq!(response.id, 1);
    }
    
    #[test]
    fn test_error_response() {
        let json = r#"{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"},"id":1}"#;
        
        let response: RpcResponse = serde_json::from_str(json).expect("Failed to deserialize");
        
        assert!(response.result.is_none());
        assert!(response.error.is_some());
        assert_eq!(response.error.unwrap().code, -32600);
    }
    
    #[test]
    fn test_non_json_filtering() {
        let non_json = "DEBUG: Loading whisper model...";
        let result = parse_response(non_json);
        
        // Should return None for non-JSON input (filtering)
        assert!(result.is_none());
    }
    
    #[test]
    fn test_diarization_response() {
        let json = r#"{
            "jsonrpc": "2.0",
            "result": {
                "segments": [
                    {"start": 0.0, "end": 2.5, "text": "Hello doctor.", "speaker": "SPEAKER_00"},
                    {"start": 2.5, "end": 5.0, "text": "Hello patient.", "speaker": "SPEAKER_01"}
                ]
            },
            "id": 1
        }"#;
        
        let response: RpcResponse = serde_json::from_str(json).expect("Failed to deserialize");
        
        let result = response.result.unwrap();
        let segments = result.get("segments").unwrap().as_array().unwrap();
        
        assert_eq!(segments.len(), 2);
    }
}
