# aSTT-RUST

**Automatic Speech-to-Text for Physicians**

Tento repozitář obsahuje modulární desktopovou aplikaci pro real-time přepis řeči,
postavenou na technologiích Rust (Tauri), SvelteKit a Python (WhisperX).

---

## 📖 Dokumentace (SSOT)

Tento projekt využívá přístup **Documentation as Code**. Veškerá řídicí
dokumentace je udržována jako Single Source of Truth v adresáři `/docs/core/`.

- **[Hlavní rozcestník Documentation Index](docs/core/index.md)** ← ZAČNĚTE ZDE
- **[Vize projektu](docs/core/VISION.md)**
- **[Ústava projektu](docs/core/CONSTITUTION.md)**
- **[Architektura systému](docs/core/ARCHITECTURE.md)**

---

## 🧭 Výchozí runtime směr

- Primární vývojový směr je `Tauri + Rust` (nižší runtime režie na CPU/RAM).
- `Electron` varianta je udržována jako funkčně paritní alternativa, ne jako primární baseline.

## 🔐 Privacy/Security/Quality (výchozí pravidla)

1. Privacy first
2. Security second
3. Quality third

- Bezpečnostní profily aplikace: `Standard` (default), `Hardened`, `Strict` (admin-only).
- Nastavení se dělí na:
  - `User settings` (UX preference),
  - `Admin settings` (recording policy, online zdroje, screen capture, outbound API).
- STT část je navržená jako offline-only worker i na online PC.
- Odeslání výstupu do externího programu běží přes outbound API pouze pro zpracovaný text/metadata (nikdy surové audio), s allowlistem endpointů, TLS mimo `localhost` a auditní stopou.

## 🩺 Startup Preflight (runtime, povinné)

- Při startu aplikace musí proběhnout runtime diagnostika před aktivací STT/online capture.
- Výsledek preflightu má 3 třídy:
  - `BLOCKER`: riziková funkce se nespustí (fail-closed).
  - `WARNING`: funkce je povolena s viditelným upozorněním.
  - `INFO`: jen informativní stav bez omezení.
- Diagnostika minimálně kontroluje:
  - HW minimum (CPU/RAM/disk),
  - audio zařízení a oprávnění mikrofonu,
  - kolize známého software/procesů,
  - firewall/antivir blokace sidecaru nebo IPC.
- Výstup je role-based:
  - uživatel: stručné doporučení,
  - admin: detailní technický report + návrh nápravy.
- Cíl portability:
  - Windows: portable složka bez instalace,
  - macOS: přenosná `.app` varianta (s realistickými omezeními podpisu/notarizace dle prostředí).

---

## 🚀 Rychlý Start

### Pro vývojáře

1. Nainstalujte závislosti: `npm install`.
2. Nastavte Python prostředí: `python -m venv .venv`.
3. Zkontrolujte lintery: `pre-commit run --all-files`.
4. Spusťte vývojový server: `npm run tauri dev`.

### Pro AI agenty

Každý agent **musí** nejdříve přečíst `CONSTITUTION.md` a dodržovat metodiku
**Superpowers** (Brainstorm -> Plan -> Implement -> Verify) s povinným
negativním testováním (RED Phase).

---

## 🛠️ Technologie

- **Server-side:** Rust (Tauri)
- **Frontend:** SvelteKit + TypeScript
- **AI/ML:** Python 3.10 (WhisperX / Faster-Whisper)
- **Linting:** Vale, markdownlint-cli2
- **Docs:** MkDocs (Material theme)
