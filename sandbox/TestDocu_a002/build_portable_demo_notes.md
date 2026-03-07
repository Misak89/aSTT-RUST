# Portable Demo Notes

## Quick path
1. Build the app:
   - `npm run tauri build`
2. Copy output to USB:
   - Windows output from `src-tauri/target/release/bundle/`
   - macOS output from macOS build host (`.app` / `.dmg`)

## Why this path
- It keeps agreed project stack (`Tauri + SvelteKit + TypeScript + Rust`).
- Demo runtime has no STT dependency.
- End users can run prebuilt binary without local dev tool installation.

## Security/profile notes (parity target)
- Tauri A002 is the primary baseline for performance-sensitive deployments.
- Security profiles must remain configurable (`Standard`, `Hardened`, `Strict`).
- Sensitive switches stay admin-protected (recording, online sources, screen capture, outbound API policy).
- Outbound API to external systems sends processed text/metadata only, with allowlist + TLS + audit logging.
