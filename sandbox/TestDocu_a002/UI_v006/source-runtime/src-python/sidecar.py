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
import os
import queue
import tempfile
import threading
import time
import urllib.parse
import urllib.request
import wave
from typing import Any, Dict, Optional
from dataclasses import dataclass

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
        self.recording_session_id: Optional[str] = None
        self.recording_output_path: Optional[str] = None
        self.recording_started_at_monotonic: Optional[float] = None
        self.recording_thread: Optional[threading.Thread] = None
        self.recording_stop_event: Optional[threading.Event] = None
        self.recording_error: Optional[str] = None
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

    def _extract_config_payload(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Accept both direct config params and nested {'config': {...}} shape."""
        if not isinstance(params, dict):
            raise ValueError("params must be an object")

        if "config" in params:
            nested = params.get("config")
            if nested is None:
                return {}
            if not isinstance(nested, dict):
                raise ValueError("config must be an object")
            return nested

        return params

    @staticmethod
    def _infer_temp_suffix_from_url(url: str) -> str:
        parsed = urllib.parse.urlparse(url)
        _, ext = os.path.splitext(parsed.path)
        ext = (ext or "").lower()
        allowed = {
            ".wav", ".mp3", ".m4a", ".flac", ".aac", ".ogg",
            ".mp4", ".mov", ".mkv", ".webm", ".avi"
        }
        return ext if ext in allowed else ".bin"

    def _download_remote_media(self, url: str) -> Dict[str, Any]:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in ("http", "https"):
            raise ValueError("Only http(s) URLs are supported for remote media")

        suffix = self._infer_temp_suffix_from_url(url)
        fd, temp_path = tempfile.mkstemp(prefix="astt_remote_media_", suffix=suffix)
        os.close(fd)

        max_bytes = 500 * 1024 * 1024
        bytes_written = 0
        logger.info("Downloading remote media from URL: %s", url)

        try:
            request = urllib.request.Request(url, headers={"User-Agent": "aSTT-RUST/0.1"})
            with urllib.request.urlopen(request, timeout=60) as response, open(temp_path, "wb") as out_file:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    bytes_written += len(chunk)
                    if bytes_written > max_bytes:
                        raise ValueError("Remote media exceeds 500MB limit")
                    out_file.write(chunk)
        except Exception:
            if os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except OSError:
                    pass
            raise

        logger.info("Remote media downloaded to %s (%s bytes)", temp_path, bytes_written)
        return {"path": temp_path, "bytes": bytes_written}

    def _record_audio_worker(
        self,
        output_path: str,
        sample_rate: int,
        channels: int,
        stop_event: threading.Event,
    ) -> None:
        """Capture microphone audio into a WAV file using sounddevice.RawInputStream."""
        try:
            import sounddevice as sd  # type: ignore

            chunks: "queue.Queue[bytes]" = queue.Queue()

            def callback(indata, frames, time_info, status):  # noqa: ANN001
                if status:
                    logger.warning(f"Recording callback status: {status}")
                chunks.put(bytes(indata))

            with wave.open(output_path, "wb") as wav_file:
                wav_file.setnchannels(channels)
                wav_file.setsampwidth(2)  # int16
                wav_file.setframerate(sample_rate)

                with sd.RawInputStream(
                    samplerate=sample_rate,
                    channels=channels,
                    dtype="int16",
                    callback=callback,
                ):
                    logger.info(
                        "Recording started (sample_rate=%s, channels=%s) -> %s",
                        sample_rate,
                        channels,
                        output_path,
                    )
                    while not stop_event.is_set():
                        try:
                            wav_file.writeframes(chunks.get(timeout=0.1))
                        except queue.Empty:
                            continue

                    # Drain any remaining buffered chunks.
                    while True:
                        try:
                            wav_file.writeframes(chunks.get_nowait())
                        except queue.Empty:
                            break

        except Exception as e:
            self.state.recording_error = str(e)
            logger.error(f"Recording worker failed: {e}")
        finally:
            self.state.recording = False
            logger.info("Recording worker finished")

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

        if not isinstance(request.params, dict):
            return RpcResponse(
                error={
                    "code": ErrorCode.INVALID_PARAMS,
                    "message": "params must be a JSON object"
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

        try:
            config_payload = self._extract_config_payload(params)
        except ValueError as e:
            return {"status": "error", "message": str(e)}

        if self.state.initialized:
            return {"status": "already_initialized", "config": self.state.config}

        # Update config with provided params
        if config_payload:
            self.state.config.update(config_payload)

        # Load WhisperX model
        try:
            import whisperx
            model_name = self.state.config.get("model", "base")
            device = self.state.config.get("device", "cpu")
            compute_type = self.state.config.get("compute_type", "int8")
            
            logger.info(f"Loading WhisperX model: {model_name} on {device}")
            self.state.whisperx_model = whisperx.load_model(
                model_name,
                device=device,
                compute_type=compute_type
            )
            self.state.initialized = True
            logger.info(f"WhisperX model loaded successfully")
        except ImportError:
            logger.warning("WhisperX not installed, using placeholder mode")
            self.state.initialized = True
        except Exception as e:
            logger.error(f"Failed to load WhisperX: {e}")
            return {"status": "error", "message": str(e)}

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

        sample_rate = int(params.get("sample_rate", 16000))
        channels = int(params.get("channels", 1))
        if sample_rate <= 0:
            return {"status": "error", "message": "sample_rate must be > 0"}
        if channels <= 0:
            return {"status": "error", "message": "channels must be > 0"}

        output_path = params.get("output_path")
        if output_path is not None and not isinstance(output_path, str):
            return {"status": "error", "message": "output_path must be string if provided"}

        if not output_path:
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            output_path = os.path.join(tempfile.gettempdir(), f"astt_recording_{timestamp}.wav")
        else:
            output_path = os.path.abspath(output_path)

        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        try:
            import sounddevice  # noqa: F401
        except ImportError:
            return {
                "status": "error",
                "message": "Microphone recording backend not available (missing dependency: sounddevice)",
                "missing_dependency": "sounddevice",
                "hint": "Install Python package 'sounddevice' and PortAudio runtime."
            }

        stop_event = threading.Event()
        session_id = f"session_{int(time.time())}"
        self.state.recording_error = None
        self.state.recording_session_id = session_id
        self.state.recording_output_path = output_path
        self.state.recording_started_at_monotonic = time.monotonic()
        self.state.recording_stop_event = stop_event
        self.state.recording = True
        self.state.recording_thread = threading.Thread(
            target=self._record_audio_worker,
            args=(output_path, sample_rate, channels, stop_event),
            name="astt-sidecar-recorder",
            daemon=True,
        )
        self.state.recording_thread.start()

        return {
            "status": "recording",
            "session_id": session_id,
            "sample_rate": sample_rate,
            "channels": channels,
            "audio_path": output_path
        }

    def handle_stop_recording(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Stop audio recording"""
        logger.info(f"Stopping recording with params: {params}")

        if not self.state.recording and self.state.recording_thread is None:
            return {"status": "not_recording"}

        if self.state.recording_stop_event is not None:
            self.state.recording_stop_event.set()
        if self.state.recording_thread is not None:
            self.state.recording_thread.join(timeout=10.0)

        thread_alive = bool(self.state.recording_thread and self.state.recording_thread.is_alive())
        duration_ms = 0
        if self.state.recording_started_at_monotonic is not None:
            duration_ms = int((time.monotonic() - self.state.recording_started_at_monotonic) * 1000)

        audio_path = self.state.recording_output_path
        session_id = self.state.recording_session_id
        recording_error = self.state.recording_error

        self.state.recording = False
        self.state.recording_thread = None
        self.state.recording_stop_event = None
        self.state.recording_started_at_monotonic = None
        self.state.recording_session_id = None

        if thread_alive:
            return {
                "status": "error",
                "message": "Recording thread did not stop within timeout",
                "session_id": session_id,
                "audio_path": audio_path
            }

        if recording_error:
            return {
                "status": "error",
                "message": recording_error,
                "session_id": session_id,
                "audio_path": audio_path,
                "duration_ms": duration_ms
            }

        return {
            "status": "stopped",
            "session_id": session_id,
            "audio_path": audio_path,
            "duration_ms": duration_ms
        }

    def handle_transcribe(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Transcribe audio file with WhisperX"""
        audio_path = params.get("audio_path") or params.get("audioPath", "")
        audio_path = str(audio_path).strip()
        logger.info(f"Transcribing source: {audio_path}")

        if not self.state.initialized:
            return {"status": "error", "message": "Not initialized"}

        if not audio_path:
            return {"status": "error", "message": "No audio_path provided"}

        resolved_audio_path = audio_path
        temporary_audio_path: Optional[str] = None

        if audio_path.lower().startswith(("http://", "https://")):
            try:
                downloaded = self._download_remote_media(audio_path)
                resolved_audio_path = downloaded["path"]
                temporary_audio_path = resolved_audio_path
            except Exception as e:
                return {"status": "error", "message": f"Failed to download remote media: {e}", "audio_path": audio_path}
        elif not os.path.isfile(audio_path):
            return {"status": "error", "message": "Audio/video file not found", "audio_path": audio_path}

        # Try real WhisperX transcription
        try:
            if self.state.whisperx_model is not None:
                try:
                    import whisperx
                    
                    # Load audio/video via FFmpeg pipeline used by WhisperX.
                    audio = whisperx.load_audio(resolved_audio_path)
                    
                    # Transcribe
                    result = self.state.whisperx_model.transcribe(audio)
                    
                    # Align if possible
                    language = result.get("language", self.state.config.get("language", "cs"))
                    try:
                        model_a, metadata = whisperx.load_align_model(
                            language_code=language,
                            device=self.state.config.get("device", "cpu")
                        )
                        result = whisperx.align(
                            result["segments"],
                            model_a,
                            metadata,
                            audio,
                            self.state.config.get("device", "cpu")
                        )
                    except Exception as e:
                        logger.warning(f"Alignment failed: {e}")
                    
                    # Diarization if enabled
                    if self.state.config.get("diarization", False):
                        try:
                            diarize_model = whisperx.DiarizationPipeline(
                                use_auth_token=self.state.config.get("hf_token"),
                                device=self.state.config.get("device", "cpu")
                            )
                            diarize_segments = diarize_model(audio)
                            result = whisperx.assign_word_speakers(diarize_segments, result)
                        except Exception as e:
                            logger.warning(f"Diarization failed: {e}")
                    
                    return {
                        "status": "success",
                        "text": " ".join([s["text"] for s in result.get("segments", [])]),
                        "segments": result.get("segments", []),
                        "language": language,
                        "audio_path": audio_path,
                        "resolved_audio_path": resolved_audio_path,
                        "engine": "whisperx"
                    }
                except Exception as e:
                    logger.error(f"Transcription failed: {e}")
                    return {"status": "error", "message": str(e), "audio_path": audio_path}
            
            # Fallback: placeholder response
            return {
                "status": "success",
                "text": "Placeholder transcription (WhisperX not loaded)",
                "segments": [
                    {
                        "start": 0.0,
                        "end": 2.5,
                        "text": "Placeholder transcription",
                        "speaker": "SPEAKER_01"
                    }
                ],
                "language": self.state.config.get("language", "cs"),
                "audio_path": audio_path,
                "resolved_audio_path": resolved_audio_path,
                "engine": "placeholder"
            }
        finally:
            if temporary_audio_path and os.path.exists(temporary_audio_path):
                try:
                    os.remove(temporary_audio_path)
                except OSError:
                    pass

    def handle_get_config(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Get current configuration"""
        logger.info("Getting config")
        return {"config": self.state.config}

    def handle_set_config(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Update configuration"""
        logger.info(f"Setting config: {params}")

        try:
            config_payload = self._extract_config_payload(params)
        except ValueError as e:
            return {"status": "error", "message": str(e)}

        if config_payload:
            self.state.config.update(config_payload)

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
