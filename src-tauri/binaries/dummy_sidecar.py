"""Compatibility wrapper for legacy PyInstaller spec entrypoint.

This file used to be a dummy sidecar. Keep filename for compatibility with older
build scripts, but delegate to the real JSON-RPC sidecar implementation.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def _load_real_sidecar():
    repo_root = Path(__file__).resolve().parents[2]
    real_sidecar = repo_root / "src-python" / "sidecar.py"
    if not real_sidecar.exists():
        raise FileNotFoundError(f"Real sidecar not found: {real_sidecar}")

    spec = importlib.util.spec_from_file_location("astt_real_sidecar", real_sidecar)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load module spec for: {real_sidecar}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    try:
        module = _load_real_sidecar()
        module.main()
    except Exception as exc:  # pragma: no cover - launcher fallback
        sys.stderr.write(f"[LOG] launcher_error: {exc}\n")
        sys.stderr.flush()
        sys.exit(1)
