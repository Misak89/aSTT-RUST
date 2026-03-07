#!/usr/bin/env python3
"""
Python Sidecar for aSTT - STT JSON-RPC Server

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
import hashlib
import queue
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.parse
import urllib.request
import wave
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from dataclasses import dataclass

# Configure logging to stderr + file with [LOG] prefix
LOG_DIR = os.path.join(tempfile.gettempdir(), "astt_demo_a004")
LOG_FILE = os.path.join(LOG_DIR, "sidecar.log")
SESSION_ID = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + f"_pid{os.getpid()}"
SESSION_LOG_FILE = os.path.join(LOG_DIR, f"sidecar_{SESSION_ID}.log")
os.makedirs(LOG_DIR, exist_ok=True)

_log_format = '[LOG] %(asctime)s - %(levelname)s - %(message)s'
_formatter = logging.Formatter(_log_format)
_root_logger = logging.getLogger()
_root_logger.setLevel(logging.INFO)
_root_logger.handlers.clear()

_stderr_handler = logging.StreamHandler(sys.stderr)
_stderr_handler.setFormatter(_formatter)
_root_logger.addHandler(_stderr_handler)

for _log_path in (LOG_FILE, SESSION_LOG_FILE):
    try:
        _file_handler = logging.FileHandler(_log_path, encoding="utf-8")
        _file_handler.setFormatter(_formatter)
        _root_logger.addHandler(_file_handler)
    except Exception:
        # Keep stderr logging even if file handlers cannot be created.
        pass


def _sha1_file(path: str) -> str:
    try:
        digest = hashlib.sha1()
        with open(path, "rb") as f:
            while True:
                chunk = f.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
        return digest.hexdigest()
    except Exception:
        return "unknown"


def _safe_word_count(text: str) -> int:
    return len([token for token in text.split() if token.strip()])

logger = logging.getLogger(__name__)
logger.info("Sidecar log file (latest): %s", LOG_FILE)
logger.info("Sidecar session log file: %s", SESSION_LOG_FILE)
logger.info(
    "Sidecar session start local=%s utc=%s",
    datetime.now().astimezone().isoformat(timespec="seconds"),
    datetime.now(timezone.utc).isoformat(timespec="seconds"),
)
try:
    sidecar_path = os.path.abspath(__file__)
    sidecar_mtime_utc = datetime.fromtimestamp(os.path.getmtime(sidecar_path), tz=timezone.utc)
    logger.info(
        "Sidecar fingerprint: file=%s sha1=%s mtime_utc=%s",
        sidecar_path,
        _sha1_file(sidecar_path),
        sidecar_mtime_utc.isoformat(timespec="seconds"),
    )
except Exception:
    pass

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
            "model": "large-v3",
            "language": "cs",
            "device": "cpu",
            "compute_type": "int8"
        }
        self.whisperx_model = None
        self.faster_whisper_model = None
        self.stt_engine = "none"


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

    @staticmethod
    def _is_video_page_url(url: str) -> bool:
        parsed = urllib.parse.urlparse(url)
        host = (parsed.netloc or "").lower()
        return any(domain in host for domain in ("youtube.com", "youtu.be"))

    def _download_with_ytdlp(self, url: str) -> Dict[str, Any]:
        temp_dir = tempfile.mkdtemp(prefix="astt_ytdlp_")
        output_template = os.path.join(temp_dir, "%(id)s.%(ext)s")
        ytdlp_executable = shutil.which("yt-dlp")
        command_candidates = []
        command_candidates.append([
            sys.executable,
            "-m",
            "yt_dlp",
            "--no-playlist",
            "--no-progress",
            "--quiet",
            "--print",
            "after_move:filepath",
            "-f",
            "bestaudio",
            "-o",
            output_template,
            url,
        ])
        if ytdlp_executable:
            command_candidates.append([
                ytdlp_executable,
                "--no-playlist",
                "--no-progress",
                "--quiet",
                "--print",
                "after_move:filepath",
                "-f",
                "bestaudio",
                "-o",
                output_template,
                url,
            ])

        logger.info("Downloading linked video/audio via yt-dlp: %s", url)
        last_error_message = "yt-dlp download did not start"
        result = None
        for cmd in command_candidates:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300,
                check=False,
            )
            if result.returncode == 0:
                break
            stderr = (result.stderr or "").strip()
            stdout = (result.stdout or "").strip()
            last_error_message = stderr or stdout or f"yt-dlp exited with code {result.returncode}"
            logger.warning("yt-dlp candidate failed: %s", last_error_message)
            result = None

        if result is None:
            raise ValueError(last_error_message)

        output_lines = [line.strip() for line in (result.stdout or "").splitlines() if line.strip()]
        candidate_path = output_lines[-1] if output_lines else ""
        if not candidate_path:
            files = []
            for name in os.listdir(temp_dir):
                path = os.path.join(temp_dir, name)
                if os.path.isfile(path):
                    files.append(path)
            if files:
                files.sort(key=lambda p: os.path.getmtime(p), reverse=True)
                candidate_path = files[0]

        if not candidate_path or not os.path.isfile(candidate_path):
            raise ValueError("yt-dlp download finished but output file was not found")

        size_bytes = os.path.getsize(candidate_path)
        max_bytes = 500 * 1024 * 1024
        if size_bytes > max_bytes:
            raise ValueError("Downloaded media exceeds 500MB limit")

        logger.info("yt-dlp downloaded media to %s (%s bytes)", candidate_path, size_bytes)
        return {"path": candidate_path, "bytes": size_bytes, "temp_dir": temp_dir}

    def _create_clipped_audio(self, source_path: str, clip_seconds: int) -> str:
        if clip_seconds <= 0:
            raise ValueError("clip_seconds must be > 0")

        ffmpeg_executable = shutil.which("ffmpeg")
        if ffmpeg_executable is None:
            raise ValueError("ffmpeg is required for clipped transcription mode")

        fd, clip_path = tempfile.mkstemp(prefix="astt_clip_", suffix=".wav")
        os.close(fd)

        cmd = [
            ffmpeg_executable,
            "-y",
            "-i",
            source_path,
            "-t",
            str(clip_seconds),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            clip_path,
        ]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=max(120, clip_seconds + 30),
            check=False,
        )
        if result.returncode != 0:
            stderr = (result.stderr or "").strip()
            stdout = (result.stdout or "").strip()
            message = stderr or stdout or f"ffmpeg exited with code {result.returncode}"
            if os.path.exists(clip_path):
                try:
                    os.remove(clip_path)
                except OSError:
                    pass
            raise ValueError(message)

        return clip_path

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
        """Initialize STT model (prefer WhisperX, fallback to faster-whisper)."""
        logger.info(f"Initializing with params: {params}")

        try:
            config_payload = self._extract_config_payload(params)
        except ValueError as e:
            return {"status": "error", "message": str(e)}

        next_config = dict(self.state.config)
        if config_payload:
            next_config.update(config_payload)

        if self.state.initialized and next_config == self.state.config:
            return {
                "status": "already_initialized",
                "config": self.state.config,
                "engine": self.state.stt_engine
            }

        if self.state.initialized and next_config != self.state.config:
            logger.info(
                "Reinitializing STT backend due to config change: %s -> %s",
                self.state.config,
                next_config,
            )
            self.state.initialized = False
            self.state.whisperx_model = None
            self.state.faster_whisper_model = None
            self.state.stt_engine = "none"
            try:
                import gc
                gc.collect()
            except Exception:
                pass

        self.state.config = next_config

        self.state.whisperx_model = None
        self.state.faster_whisper_model = None
        self.state.stt_engine = "none"

        model_name = str(self.state.config.get("model", "base"))
        device = str(self.state.config.get("device", "cpu"))
        compute_type = str(self.state.config.get("compute_type", "int8"))
        whisperx_error: Optional[str] = None
        faster_whisper_error: Optional[str] = None

        # First preference: WhisperX
        try:
            import whisperx

            logger.info(f"Loading WhisperX model: {model_name} on {device}")
            self.state.whisperx_model = whisperx.load_model(
                model_name,
                device=device,
                compute_type=compute_type
            )
            self.state.initialized = True
            self.state.stt_engine = "whisperx"
            logger.info("WhisperX model loaded successfully")
        except Exception as e:
            whisperx_error = str(e)
            logger.warning("WhisperX init failed: %s", whisperx_error)

        # Fallback: faster-whisper (real transcription without alignment/diarization)
        if not self.state.initialized:
            try:
                from faster_whisper import WhisperModel

                logger.info(f"Loading faster-whisper model: {model_name} on {device}")
                self.state.faster_whisper_model = WhisperModel(
                    model_name,
                    device=device,
                    compute_type=compute_type
                )
                self.state.initialized = True
                self.state.stt_engine = "faster-whisper"
                logger.info("faster-whisper model loaded successfully")
            except Exception as e:
                faster_whisper_error = str(e)
                logger.warning("faster-whisper init failed: %s", faster_whisper_error)

        if not self.state.initialized:
            return {
                "status": "error",
                "message": "No STT backend available. Install whisperx or faster-whisper.",
                "whisperx_error": whisperx_error,
                "faster_whisper_error": faster_whisper_error
            }

        logger.info(f"Initialized with config: {self.state.config}")
        return {
            "status": "initialized",
            "config": self.state.config,
            "engine": self.state.stt_engine
        }

    def handle_start_recording(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Start audio recording"""
        logger.info(f"Starting recording with params: {params}")

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
        """Transcribe audio file with active STT backend."""
        request_started_at = time.monotonic()
        download_elapsed_ms: Optional[int] = None
        clip_elapsed_ms: Optional[int] = None
        stt_elapsed_ms: Optional[int] = None

        audio_path = params.get("audio_path") or params.get("audioPath", "")
        audio_path = str(audio_path).strip()
        clip_seconds_raw = params.get("clip_seconds")
        if clip_seconds_raw is None:
            clip_seconds_raw = params.get("clipSeconds")
        clip_seconds = 0
        if clip_seconds_raw is not None:
            try:
                clip_seconds = int(clip_seconds_raw)
            except (TypeError, ValueError):
                return {
                    "status": "error",
                    "message": "clip_seconds must be an integer if provided",
                    "audio_path": audio_path
                }
            if clip_seconds < 0:
                return {
                    "status": "error",
                    "message": "clip_seconds must be >= 0",
                    "audio_path": audio_path
                }
        logger.info("Transcribe request options: clip_seconds=%s", clip_seconds if clip_seconds > 0 else "full-source")
        logger.info(f"Transcribing source: {audio_path}")

        if not self.state.initialized:
            return {"status": "error", "message": "Not initialized"}

        if not audio_path:
            return {"status": "error", "message": "No audio_path provided"}

        resolved_audio_path = audio_path
        temporary_audio_path: Optional[str] = None
        temporary_audio_dir: Optional[str] = None
        temporary_clip_path: Optional[str] = None

        if audio_path.lower().startswith(("http://", "https://")):
            try:
                download_started_at = time.monotonic()
                if self._is_video_page_url(audio_path):
                    downloaded = self._download_with_ytdlp(audio_path)
                else:
                    downloaded = self._download_remote_media(audio_path)
                download_elapsed_ms = int((time.monotonic() - download_started_at) * 1000)
                resolved_audio_path = downloaded["path"]
                temporary_audio_path = resolved_audio_path
                temporary_audio_dir = downloaded.get("temp_dir")
            except Exception as e:
                return {"status": "error", "message": f"Failed to download remote media: {e}", "audio_path": audio_path}
        elif not os.path.isfile(audio_path):
            return {"status": "error", "message": "Audio/video file not found", "audio_path": audio_path}

        language_pref = str(self.state.config.get("language", "cs")).strip().lower()
        if language_pref in ("", "auto"):
            language_pref = ""
        logger.info(
            "Transcribe config: model=%s language=%s device=%s compute_type=%s engine=%s",
            self.state.config.get("model", ""),
            language_pref if language_pref else "auto",
            self.state.config.get("device", "cpu"),
            self.state.config.get("compute_type", "int8"),
            self.state.stt_engine,
        )

        working_audio_path = resolved_audio_path
        if clip_seconds > 0:
            try:
                clip_started_at = time.monotonic()
                working_audio_path = self._create_clipped_audio(resolved_audio_path, clip_seconds)
                clip_elapsed_ms = int((time.monotonic() - clip_started_at) * 1000)
                temporary_clip_path = working_audio_path
            except Exception as e:
                return {
                    "status": "error",
                    "message": f"Failed to create clipped audio: {e}",
                    "audio_path": audio_path
                }

        # Try active transcription backend
        try:
            stt_started_at = time.monotonic()
            if self.state.whisperx_model is not None:
                try:
                    import whisperx

                    # Load audio/video via FFmpeg pipeline used by WhisperX.
                    audio = whisperx.load_audio(working_audio_path)

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

                    stt_elapsed_ms = int((time.monotonic() - stt_started_at) * 1000)
                    segments_result = result.get("segments", [])
                    first_segment_start_s: Optional[float] = None
                    if isinstance(segments_result, list):
                        for segment in segments_result:
                            if isinstance(segment, dict) and "start" in segment:
                                try:
                                    start = float(segment.get("start", 0.0))
                                except (TypeError, ValueError):
                                    continue
                                if start >= 0:
                                    first_segment_start_s = start
                                    break
                    total_elapsed_ms = int((time.monotonic() - request_started_at) * 1000)
                    first_word_latency_ms: Optional[int] = None
                    if first_segment_start_s is not None:
                        first_word_latency_ms = max(
                            0, total_elapsed_ms - int(first_segment_start_s * 1000)
                        )
                    latency_budget_ms = 3000
                    latency_budget_ok = (
                        first_word_latency_ms is not None
                        and first_word_latency_ms <= latency_budget_ms
                    )
                    logger.info(
                        "Transcribe timing: total=%sms download=%s clip=%s stt=%s first_segment_start_s=%s first_word_latency_ms=%s budget_ok=%s",
                        total_elapsed_ms,
                        download_elapsed_ms,
                        clip_elapsed_ms,
                        stt_elapsed_ms,
                        first_segment_start_s,
                        first_word_latency_ms,
                        latency_budget_ok,
                    )
                    transcript_text = " ".join([s["text"] for s in result.get("segments", [])])
                    transcript_char_count = len(transcript_text)
                    transcript_word_count = _safe_word_count(transcript_text)
                    segment_count = len(segments_result) if isinstance(segments_result, list) else 0
                    logger.info(
                        "Transcribe result: status=success engine=whisperx segments=%s chars=%s words=%s language=%s",
                        segment_count,
                        transcript_char_count,
                        transcript_word_count,
                        language,
                    )

                    return {
                        "status": "success",
                        "text": transcript_text,
                        "segments": result.get("segments", []),
                        "language": language,
                        "audio_path": audio_path,
                        "resolved_audio_path": resolved_audio_path,
                        "working_audio_path": working_audio_path,
                        "clip_seconds": clip_seconds if clip_seconds > 0 else None,
                        "engine": "whisperx",
                        "first_word_latency_ms": first_word_latency_ms,
                        "timing": {
                            "total_elapsed_ms": total_elapsed_ms,
                            "download_elapsed_ms": download_elapsed_ms,
                            "clip_elapsed_ms": clip_elapsed_ms,
                            "stt_elapsed_ms": stt_elapsed_ms,
                            "first_segment_start_s": first_segment_start_s,
                            "first_word_latency_ms": first_word_latency_ms,
                            "latency_budget_ms": latency_budget_ms,
                            "latency_budget_ok": latency_budget_ok,
                        },
                    }
                except Exception as e:
                    logger.error(f"Transcription failed: {e}")
                    return {"status": "error", "message": str(e), "audio_path": audio_path}

            if self.state.faster_whisper_model is not None:
                try:
                    transcribe_kwargs: Dict[str, Any] = {
                        "beam_size": 5,
                        "vad_filter": True
                    }
                    if language_pref:
                        transcribe_kwargs["language"] = language_pref

                    segments_iter, info = self.state.faster_whisper_model.transcribe(
                        working_audio_path,
                        **transcribe_kwargs
                    )

                    segments_payload = []
                    text_parts = []
                    processed_segments = 0
                    last_progress_logged_at = time.monotonic()
                    progress_interval_s = 2.0
                    for segment in segments_iter:
                        segment_text = str(getattr(segment, "text", "")).strip()
                        if not segment_text:
                            continue
                        text_parts.append(segment_text)
                        segments_payload.append({
                            "start": float(getattr(segment, "start", 0.0)),
                            "end": float(getattr(segment, "end", 0.0)),
                            "text": segment_text,
                            "speaker": "SPEAKER_01"
                        })
                        processed_segments += 1
                        now_monotonic = time.monotonic()
                        if now_monotonic - last_progress_logged_at >= progress_interval_s:
                            segment_end = float(getattr(segment, "end", 0.0))
                            stt_running_ms = int((now_monotonic - stt_started_at) * 1000)
                            logger.info(
                                "Transcribe progress: engine=faster-whisper segments=%s last_end_s=%.3f stt_elapsed_ms=%s",
                                processed_segments,
                                segment_end,
                                stt_running_ms,
                            )
                            last_progress_logged_at = now_monotonic

                    detected_language = (
                        str(getattr(info, "language", "")).strip()
                        if info is not None
                        else ""
                    )
                    if not detected_language:
                        detected_language = language_pref or str(self.state.config.get("language", "cs"))

                    stt_elapsed_ms = int((time.monotonic() - stt_started_at) * 1000)
                    first_segment_start_s: Optional[float] = None
                    if len(segments_payload) > 0:
                        first_raw = segments_payload[0].get("start")
                        try:
                            first_segment_start_s = float(first_raw)
                        except (TypeError, ValueError):
                            first_segment_start_s = None
                    total_elapsed_ms = int((time.monotonic() - request_started_at) * 1000)
                    first_word_latency_ms: Optional[int] = None
                    if first_segment_start_s is not None:
                        first_word_latency_ms = max(
                            0, total_elapsed_ms - int(first_segment_start_s * 1000)
                        )
                    latency_budget_ms = 3000
                    latency_budget_ok = (
                        first_word_latency_ms is not None
                        and first_word_latency_ms <= latency_budget_ms
                    )
                    logger.info(
                        "Transcribe timing: total=%sms download=%s clip=%s stt=%s first_segment_start_s=%s first_word_latency_ms=%s budget_ok=%s",
                        total_elapsed_ms,
                        download_elapsed_ms,
                        clip_elapsed_ms,
                        stt_elapsed_ms,
                        first_segment_start_s,
                        first_word_latency_ms,
                        latency_budget_ok,
                    )
                    transcript_text = " ".join(text_parts)
                    transcript_char_count = len(transcript_text)
                    transcript_word_count = _safe_word_count(transcript_text)
                    logger.info(
                        "Transcribe result: status=success engine=faster-whisper segments=%s chars=%s words=%s language=%s",
                        len(segments_payload),
                        transcript_char_count,
                        transcript_word_count,
                        detected_language,
                    )

                    return {
                        "status": "success",
                        "text": transcript_text,
                        "segments": segments_payload,
                        "language": detected_language,
                        "audio_path": audio_path,
                        "resolved_audio_path": resolved_audio_path,
                        "working_audio_path": working_audio_path,
                        "clip_seconds": clip_seconds if clip_seconds > 0 else None,
                        "engine": "faster-whisper",
                        "first_word_latency_ms": first_word_latency_ms,
                        "timing": {
                            "total_elapsed_ms": total_elapsed_ms,
                            "download_elapsed_ms": download_elapsed_ms,
                            "clip_elapsed_ms": clip_elapsed_ms,
                            "stt_elapsed_ms": stt_elapsed_ms,
                            "first_segment_start_s": first_segment_start_s,
                            "first_word_latency_ms": first_word_latency_ms,
                            "latency_budget_ms": latency_budget_ms,
                            "latency_budget_ok": latency_budget_ok,
                        },
                    }
                except Exception as e:
                    logger.error(f"faster-whisper transcription failed: {e}")
                    return {"status": "error", "message": str(e), "audio_path": audio_path}

            return {
                "status": "error",
                "message": "No initialized STT backend. Run init and install whisperx or faster-whisper.",
                "audio_path": audio_path
            }
        finally:
            if temporary_clip_path and os.path.exists(temporary_clip_path):
                try:
                    os.remove(temporary_clip_path)
                except OSError:
                    pass
            if temporary_audio_path and os.path.exists(temporary_audio_path):
                try:
                    os.remove(temporary_audio_path)
                except OSError:
                    pass
            if temporary_audio_dir and os.path.isdir(temporary_audio_dir):
                try:
                    shutil.rmtree(temporary_audio_dir, ignore_errors=True)
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
