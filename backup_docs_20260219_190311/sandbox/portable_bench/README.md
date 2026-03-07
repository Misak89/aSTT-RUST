# Portable WhisperX Benchmark (CPU Mode)

**Cesta:** sandbox\portable_bench\README.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-16 12:23 (UTC+1)
**Posledni zmena:** 2026-02-17 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-16 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
**Kompletní portable STT benchmark včetně:**

- 🖥️ Hardware detekce (CPU, GPU, RAM)
- 🔊 Kontrola audio výstupu (Windows 10/11 WASAPI)
- 📥 Auto-download free audio vzorků (~30s každý)  
- 🎲 Náhodné testování STT na reálných datech
- 📝 Detailní logování a reporting

## 🚀 Rychlý Start

### 1. Instalace

```powershell
# Stažení a instalace Python, FFmpeg, WhisperX a dependencies
powershell -ExecutionPolicy Bypass -File setup.ps1
```

### 2. Stažení testovacích audio vzorků

```batch
run_benchmark.bat
# Zvolte: 1) Stáhnout audio vzorky
```

Vzorky jsou staženy z public domain zdrojů:

- **Vzorek 1**: T.G. Masaryk - historický záznam (CS)
- **Vzorek 2**: Karel Hynek Mácha - Máj (CS)
- **Vzorek 3**: LibriVox - Gettysburg Address (EN)

### 3. Spuštění benchmark testu

```batch
run_benchmark.bat
# Zvolte: 2) Spustit benchmark test
```

## 📋 Funkce Benchmarku

### Test provádí:

1. **HW Detekce**
   - Detekce CPU (počet jader, model)
   - Detekce RAM (celková/volná)
   - Detekce GPU (model)

2. **Audio Výstup Kontrola**
   - Monitoruje Windows audio výstup pomocí WASAPI
   - Ověřuje, že z reproduktorů opravdu něco hraje
   - Měří peak hodnoty v reálném čase

3. **Náhodný Výběr Vzorku**
   - Náhodně vybere jeden ze 3 stažených vzorků
   - Zajišťuje rozmanitost testování

4. **Přehrávání s Monitoringem**
   - Přehraje audio vzorek
   - Souběžně monitoruje audio výstup
   - Ověřuje, že audio opravdu hraje

5. **STT Přepis**
   - WhisperX přepis (model: small, CPU mode)
   - Auto-alignment
   - Časování jednotlivých segmentů
   - Uložení do .txt souboru

## 🛠️ Advanced Použití

### Ruční spuštění testů

```powershell
# V složce portable_bench:

# 1. Stáhnout vzorky
.\python-embed\python.exe download_samples.py

# 2. Benchmark test
.\python-embed\python.exe test_samples.py

# 3. Diagnostický test (loopback recording)
.\python-embed\python.exe verify_bench.py

# 4. Live nahrávání z mikrofonu
.\python-embed\python.exe demo.py --record
```

## 📊 Výstupy

- `test_samples.log` - Detailní log benchmark testu
- `test_samples/*_transcript.txt` - Přepisy jednotlivých vzorků
- `verify_bench.log` - Diagnostický log

## 🔧 Technické Detaily

### Požadavky

- Windows 10/11 (64-bit)
- ~3GB volného místa (Python + PyTorch CPU + WhisperX + FFmpeg)
- Internetové připojení (pro download vzorků a dependencies)

### Dependencies

Automaticky instalováno přes `setup.ps1`:

- Python 3.10 (embedded)
- PyTorch (CPU verze)
- WhisperX
- FFmpeg
- sounddevice, scipy
- requests, playsound
- pycaw, comtypes, pyaudiowpatch

### Struktura složky

```
portable_bench/
├── setup.ps1                    # Instalační script
├── run_benchmark.bat            # Hlavní menu
├── download_samples.py          # Download audio vzorků
├── test_samples.py              # Hlavní benchmark test
├── verify_bench.py              # Diagnostika loopback
├── demo.py                      # Live nahrávání
├── python-embed/                # Portable Python
├── ffmpeg/                      # FFmpeg binaries
├── test_samples/                # Audio vzorky
│   ├── sample_1_librivox_cs.mp3
│   ├── sample_2_audiobook_cs.mp3
│   └── sample_3_librivox_en.mp3
└── wheels/                      # Cached Python packages
```

## 🎯 Účel

Tento benchmark slouží k:

1. **Ověření funkčnosti STT** na různých systémech
2. **Měření výkonu** na CPU-only konfiguraci
3. **Testování reálných audio vzorků** (různé jazyky, kvality)
4. **Diagnostice audio subsystému** Windows (WASAPI loopback)

## 📝 Licence

- Portable benchmark: MIT
- Audio vzorky: Public Domain (LibriVox, audiobooks zdarma)
- WhisperX: MIT
- PyTorch: BSD-style

## 🆘 Řešení Problémů

### Audio vzorky se nestahují

- Zkontrolujte připojení k internetu
- Některé URL mohou být nedostupné - script použije fallback
- Můžete stáhnout vlastní MP3/WAV vzorky do `test_samples/`

### "Playsound není nainstalován"

```powershell
.\python-embed\python.exe -m pip install playsound
```

### "Pycaw není nainstalován"

```powershell
.\python-embed\python.exe -m pip install pycaw comtypes
```

### Loopback nefunguje

1. Otevřete Ovládací panely → Zvuk → Nahrávání
2. Pravým tlačítkem → Zobrazit vypnutá zařízení
3. Povolte "Stereo Mix" nebo podobné loopback zařízení
4. Spusťte znovu `verify_bench.py`
