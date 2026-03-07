# Antigravity Tools & MCP Servers

Tento dokument slouží jako přehled nástrojů a technologií, které Antigravity aktivně využívá pro práci na projektu `aSTT-RUST`.

## Core Nástroje (Built-in)

Tyto nástroje jsou nativní součástí Antigravity a umožňují přímou interakci se systémem a kódem:

| Nástroj | Popis |
| :--- | :--- |
| **File System** | Čtení (`view_file`), vyhledávání (`grep_search`, `find_by_name`) a zápis (`write_to_file`) v projektu. |
| **Terminal** | Spouštění příkazů (`run_command`), práce s PowerShell/Bash a sledování výstupů. |
| **Browser** | Autonomní prohlížeč pro testování webů, čtení dokumentace a interakci s UI. |
| **Search & Web** | Vyhledávání informací na internetu a analýza obsahu webových stránek. |
| **Media** | Generování obrázků a grafických prvků pomocí AI. |

## MCP (Model Context Protocol)

Antigravity využívá standard **MCP** k rozšíření svých schopností. MCP umožňuje připojení k externím serverům, které fungují jako "pluginy".

### Jak MCP funguje:
- **Server:** Externí proces, který poskytuje specifické funkce (např. přístup k Google Drive, Slacku nebo lokální DB).
- **Client (Antigravity):** Připojí se k serveru a získá nové nástroje (`tools`) a zdroje (`resources`).

### Výhody integrace:
- **Rozšiřitelnost:** Každý programátor může vytvořit vlastní MCP server pro své specifické potřeby.
- **Kontext:** Antigravity může v reálném čase přistupovat k datům mimo samotný codebase.

---
*Poslední aktualizace: 2026-02-20*
