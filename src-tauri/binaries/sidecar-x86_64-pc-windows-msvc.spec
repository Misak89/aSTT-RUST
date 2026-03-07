# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

spec_dir = Path(globals().get("SPECPATH", ".")).resolve()
repo_root = spec_dir.parent.parent
sidecar_script = repo_root / "src-python" / "sidecar.py"

a = Analysis(
    [str(sidecar_script)],
    pathex=[str(sidecar_script.parent)],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='sidecar-x86_64-pc-windows-msvc',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
