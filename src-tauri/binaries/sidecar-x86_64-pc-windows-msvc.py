"""Dev-side wrapper script for the real Python sidecar."""

from dummy_sidecar import _load_real_sidecar


if __name__ == "__main__":
    _load_real_sidecar().main()
