#!/usr/bin/env python3
"""
Python Sidecar for aSTT - WhisperX JSON-RPC Server

This script implements the JSON-RPC 2.0 contract for communication
with the Rust Tauri backend via stdin/stdout.

Contract:
- Request: {"jsonrpc": "2.0", "method": "...", "params": {...}, "id": 1}
- Response: {"jsonrpc": "2.0", "result": {...}, "id": 1}
- Error: {"jsonrpc": "2.0", "error": {"code": -32600, "message": "..."}, "id": 1}

Robustness: All non-JSON output must be prefixed with [LOG] and sent to stderr
"""

import sys
import json
import logging
from typing import Any, Dict, Optional
from dataclasses import dataclass
from enum import Enum

# Configure logging to stderr with [LOG] prefix
logging.basicConfig(
    level=logging.INFO,
    format='[LOG] %(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stderr
)
logger = logging.getLogger(__name__)

# JSON-RPC Error Codes
class ErrorCode:
    INVALID_REQUEST = -32600
    METHOD_NOT_FOUND = -32601
    INVALID_PARAMS = -32602
    INTERNAL_ERROR = -32603
    SERVER_ERROR = -32000


@dataclass
class RpcRequest:
    jsonrpc: str
    method: str
    params: Dict[str, Any]
    id: int


@dataclass
class RpcResponse:
    jsonrpc: str = "2.0"
    result: Optional[Dict[str, Any]] = None
    error: Optional[Dict[str, Any]] = None
    id: Optional[int] = None

    def to_dict(self) -> Dict[str, Any]:
        d = {"jsonrpc": self.jsonrpc, "id": self.id}
        if self.error:
            d["error"] = self.error
        else:
            d["result"] = self.result or {}
        return d


class SidecarState:
    """Manages the state of the sidecar"""
    def __init__(self):
        self.initialized = False
        self.recording = False
        self.config = {
            "model": "base",
            "language": "cs",
            "device": "cpu",
            "compute_type": "int8"
        }
        self.whisperx_model = None


class SidecarHandler:
    """Handles JSON-RPC requests from Rust backend"""

    def __init__(self):
        self.state = SidecarState()

    def handle_request(self, request: RpcRequest) -> RpcResponse:
        """Route request to appropriate handler"""
        handlers = {
            "init": self.handle_init,
            "start_recording": self.handle_start_recording,
            "stop_recording": self.handle_stop_recording,
            "transcribe": self.handle_transcribe,
            "get_config": self.handle_get_config,
            "set_config": self.handle_set_config,
        }

        handler = handlers.get(request.method)
        if not handler:
            return RpcResponse(
                error={
                    "code": ErrorCode.METHOD_NOT_FOUND,
                    "message": f"Method not found: {request.method}"
                },
                id=request.id
            )

        try:
            result = handler(request.params)
            return RpcResponse(result=result, id=request.id)
        except Exception as e:
            logger.error(f"Error handling {request.method}: {e}")
            return RpcResponse(
                error={
                    "code": ErrorCode.INTERNAL_ERROR,
                    "message": str(e)
                },
                id=request.id
            )

    def handle_init(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Initialize WhisperX model"""
        logger.info(f"Initializing with params: {params}")

        if self.state.initialized:
            return {"status": "already_initialized", "config": self.state.config}

        # Update config with provided params
        if "config" in params:
            self.state.config.update(params["config"])

        # TODO: Actually load WhisperX model
        # For now, just mark as initialized
        self.state.initialized = True

        logger.info(f"Initialized with config: {self.state.config}")
        return {
            "status": "initialized",
            "config": self.state.config
        }

    def handle_start_recording(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Start audio recording"""
        logger.info(f"Starting recording with params: {params}")

        if not self.state.initialized:
            return {"status": "error", "message": "Not initialized"}

        if self.state.recording:
            return {"status": "already_recording"}

        # TODO: Implement actual recording
        self.state.recording = True

        return {"status": "recording", "session_id": "session_001"}

    def handle_stop_recording(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Stop audio recording"""
        logger.info(f"Stopping recording with params: {params}")

        if not self.state.recording:
            return {"status": "not_recording"}

        # TODO: Implement actual stop
        self.state.recording = False

        return {"status": "stopped", "duration_ms": 5000}

    def handle_transcribe(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Transcribe audio file"""
        audio_path = params.get("audio_path", "")
        logger.info(f"Transcribing: {audio_path}")

        if not self.state.initialized:
            return {"status": "error", "message": "Not initialized"}

        # TODO: Implement actual transcription with WhisperX
        # This is a placeholder response
        return {
            "status": "success",
            "text": "Placeholder transcription text",
            "segments": [
                {
                    "start": 0.0,
                    "end": 2.5,
                    "text": "Placeholder transcription text",
                    "speaker": "SPEAKER_01"
                }
            ],
            "language": self.state.config.get("language", "cs")
        }

    def handle_get_config(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Get current configuration"""
        logger.info("Getting config")
        return {"config": self.state.config}

    def handle_set_config(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Update configuration"""
        logger.info(f"Setting config: {params}")

        if "config" in params:
            self.state.config.update(params["config"])

        return {"status": "updated", "config": self.state.config}


def parse_request(line: str) -> Optional[RpcRequest]:
    """Parse a JSON-RPC request from a line"""
    try:
        data = json.loads(line.strip())
        return RpcRequest(
            jsonrpc=data.get("jsonrpc", "2.0"),
            method=data.get("method", ""),
            params=data.get("params", {}),
            id=data.get("id", 0)
        )
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse request: {e}")
        return None


def main():
    """Main loop - read from stdin, process, write to stdout"""
    logger.info("Python sidecar starting...")
    handler = SidecarHandler()

    # Signal ready
    logger.info("Sidecar ready, waiting for requests...")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        # Skip non-JSON lines (shouldn't happen, but be safe)
        if not line.startswith("{"):
            logger.warning(f"Skipping non-JSON line: {line[:50]}...")
            continue

        # Parse request
        request = parse_request(line)
        if not request:
            response = RpcResponse(
                error={
                    "code": ErrorCode.INVALID_REQUEST,
                    "message": "Invalid JSON-RPC request"
                }
            )
        else:
            response = handler.handle_request(request)

        # Send response
        response_json = json.dumps(response.to_dict())
        sys.stdout.write(response_json + "\n")
        sys.stdout.flush()

        logger.info(f"Sent response for request id={request.id if request else 'unknown'}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Sidecar shutting down...")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)