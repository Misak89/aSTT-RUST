//! JSON-RPC Contract Tests
//! 
//! These tests verify the contract between Rust backend and Python sidecar.
//! According to Spec-Kit TDD: These tests MUST FAIL until implementation is complete.
//!
//! Contract: JSON-RPC over Stdio
//! - Request: {"jsonrpc": "2.0", "method": "...", "params": {...}, "id": 1}
//! - Response: {"jsonrpc": "2.0", "result": {...}, "id": 1}
//! - Error: {"jsonrpc": "2.0", "error": {"code": -32600, "message": "..."}, "id": 1}

use app_temp_lib::rpc::{RpcRequest, RpcResponse, RpcError, RpcMethod};

/// FR-04.1: Request serialization must produce valid JSON-RPC 2.0
#[test]
fn test_rpc_request_serialization() {
    let request = RpcRequest::new(RpcMethod::Init, serde_json::json!({
        "model": "base",
        "device": "cpu"
    }));
    
    let json = serde_json::to_string(&request).expect("Failed to serialize");
    
    // Verify JSON-RPC 2.0 format
    assert!(json.contains(r#""jsonrpc":"2.0""#));
    assert!(json.contains(r#""method":"init""#));
    // ID is auto-incremented, just verify it exists
    assert!(json.contains(r#""id":"#));
}

/// FR-04.2: Response deserialization must handle valid responses
#[test]
fn test_rpc_response_deserialization() {
    let json = r#"{"jsonrpc":"2.0","result":{"status":"ready"},"id":1}"#;
    
    let response: RpcResponse = serde_json::from_str(json).expect("Failed to deserialize");
    
    assert!(response.result.is_some());
    assert!(response.error.is_none());
    assert_eq!(response.id, 1);
}

/// FR-04.3: Error responses must be properly parsed
#[test]
fn test_rpc_error_response() {
    let json = r#"{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"},"id":1}"#;
    
    let response: RpcResponse = serde_json::from_str(json).expect("Failed to deserialize");
    
    assert!(response.result.is_none());
    assert!(response.error.is_some());
    assert_eq!(response.error.unwrap().code, -32600);
}

/// FR-04.4: Non-JSON output must be filtered (robustness requirement)
#[test]
fn test_non_json_filtering() {
    // Python might output logs to stdout that are not JSON
    // These should be ignored by the RPC parser
    
    let non_json = "DEBUG: Loading whisper model...";
    let result = app_temp_lib::rpc::parse_response(non_json);
    
    // Should return None for non-JSON input (filtering)
    assert!(result.is_none());
}

/// FR-04.5: init method should create valid request
#[test]
fn test_init_method_request() {
    let request = RpcRequest::new(
        RpcMethod::Init, 
        serde_json::json!({"model": "base", "language": "en"})
    );
    
    assert_eq!(request.method, RpcMethod::Init);
    assert_eq!(request.params.get("model").unwrap(), "base");
}

/// FR-04.6: start_recording method
#[test]
fn test_start_recording_request() {
    let request = RpcRequest::new(
        RpcMethod::StartRecording, 
        serde_json::json!({"sample_rate": 16000})
    );
    
    assert_eq!(request.method, RpcMethod::StartRecording);
}

/// FR-04.7: stop_recording method
#[test]
fn test_stop_recording_request() {
    let request = RpcRequest::new(
        RpcMethod::StopRecording, 
        serde_json::json!({})
    );
    
    assert_eq!(request.method, RpcMethod::StopRecording);
}

/// FR-04.8: transcribe method
#[test]
fn test_transcribe_request() {
    let request = RpcRequest::new(
        RpcMethod::Transcribe, 
        serde_json::json!({"audio_data": "base64_encoded"})
    );
    
    assert_eq!(request.method, RpcMethod::Transcribe);
}

/// FR-04.9: Full round-trip (serialize -> deserialize)
#[test]
fn test_full_round_trip() {
    let original = RpcRequest::new(
        RpcMethod::Init,
        serde_json::json!({"model": "large-v2"})
    );
    
    let json = serde_json::to_string(&original).expect("Serialize failed");
    let parsed: RpcRequest = serde_json::from_str(&json).expect("Deserialize failed");
    
    assert_eq!(original.method, parsed.method);
    assert_eq!(original.id, parsed.id);
}

/// FR-04.10: Response with speaker diarization
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
    assert_eq!(segments[0].get("speaker").unwrap(), "SPEAKER_00");
    assert_eq!(segments[1].get("speaker").unwrap(), "SPEAKER_01");
}
