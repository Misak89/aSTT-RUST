# Project Documentation Index

Vítejte v hlavní navigaci projektu **aSTT-RUST**. Tento dokument slouží jako rozcestník pro orientaci v dokumentaci a verifikaci systému.

## 📍 Kde co najdu?

| **Kde jsou 2 projekty? (Tracks)** | [ARCHITECTURE.md](./ARCHITECTURE.md#project-segmentation) | Definice Main vs. Sandbox tracků. |
| **Co je cílem?** | [VISION.md](./VISION.md) | High-level vize a cílová skupina. |
| **Kde jsou specifikace?** | [.specify/spec.md](./.specify/spec.md) | Funkční a technické požadavky (SDD). |
| **Jaká je struktura?** | [ARCHITECTURE.md](./ARCHITECTURE.md#directory-structure) | Mapa adresářů pro lidi i stroje. |

## ⚙️ Automatizace a Verifikace

### Jak kontrolovat průběžnou aktualizaci?
- [QA_REPORT.md](./QA_REPORT.md): Aktuální stav systému a výsledky testů.

### Kde najdu logy?
- Souhrnné logy jsou přímo v [QA_REPORT.md](./QA_REPORT.md).
- Detailní výstupy testovaných modulů jsou v adresáři **[logs/](./logs/)**.

### Jak spustit aktualizaci manuálně?
Pravým tlačítkem na soubor `Document/update_docs.ps1` -> **Run with PowerShell**. Skript automaticky projde systém, zkontroluje zdraví prostředí (Rust, Python) a zapíše výsledek do reportu.

---
*Poslední revize indexu: 2026-02-10 Tue 15:15*
