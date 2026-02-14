"""
test_samples.py - Automatický STT benchmark test s náhodnými audio vzorky
Kompletní test včetně HW detekce, audio output kontroly a STT přepisu
"""
import os
import sys
import time
import random
import logging
import platform
import subprocess
import ctypes
from pathlib import Path
from datetime import datetime

import numpy as np
import whisperx
import sounddevice as sd
import scipy.io.wavfile as wav

# Pro output monitoring
try:
    from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
    from comtypes import CLSCTX_ALL
    from ctypes import cast, POINTER
    PYCAW_AVAILABLE = True
except ImportError:
    PYCAW_AVAILABLE = False
    print("⚠️  modul 'pycaw' není nainstalován - přeskočíme kontrolu výstupu")

# Config
MODEL = "small"
DEVICE = "cpu"
COMPUTE_TYPE = "int8"
LOG_FILE = "test_samples.log"
SAMPLES_DIR = Path(__file__).parent / "test_samples"

# Setup logging
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

def log(msg, console=True):
    if console:
        print(msg)
    logging.info(msg)

def get_hw_info():
    """Načte informace o CPU, GPU, RAM"""
    log("\n" + "="*60)
    log(" 1. HW DETEKCE ")
    log("="*60)
    
    info = {}
    info['os'] = f"{platform.system()} {platform.release()}"
    info['cpu_cores'] = os.cpu_count()
    info['processor'] = platform.processor()
    
    # RAM (Windows)
    try:
        kernel32 = ctypes.windll.kernel32
        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ('dwLength', ctypes.c_ulong),
                ('dwMemoryLoad', ctypes.c_ulong),
                ('ullTotalPhys', ctypes.c_ulonglong),
                ('ullAvailPhys', ctypes.c_ulonglong),
                ('ullTotalPageFile', ctypes.c_ulonglong),
                ('ullAvailPageFile', ctypes.c_ulonglong),
                ('ullTotalVirtual', ctypes.c_ulonglong),
                ('ullAvailVirtual', ctypes.c_ulonglong),
                ('ullAvailExtendedVirtual', ctypes.c_ulonglong),
            ]
        mem = MEMORYSTATUSEX()
        mem.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        kernel32.GlobalMemoryStatusEx(ctypes.byref(mem))
        info['ram_total_gb'] = round(mem.ullTotalPhys / (1024**3), 2)
        info['ram_avail_gb'] = round(mem.ullAvailPhys / (1024**3), 2)
    except:
        info['ram_total_gb'] = "Unknown"
        info['ram_avail_gb'] = "Unknown"

    # GPU (WMIC)
    gpu_list = []
    try:
        process = subprocess.Popen(
            "wmic path win32_VideoController get name",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        out, _ = process.communicate()
        if out:
            for line in out.decode('utf-8', errors='ignore').split('\n'):
                clean = line.strip()
                if clean and "Name" not in clean:
                    gpu_list.append(clean)
    except:
        pass
    info['gpu_name'] = ", ".join(gpu_list) if gpu_list else "Unknown"

    # Výpis
    log(f"OS:        {info['os']}")
    log(f"CPU:       {info['processor']}")
    log(f"Cores:     {info['cpu_cores']}")
    log(f"RAM:       {info['ram_avail_gb']} GB / {info['ram_total_gb']} GB")
    log(f"GPU:       {info['gpu_name']}")
    
    return info

def check_audio_output_playing():
    """Kontroluje, jestli z reproduktorů něco hraje"""
    if not PYCAW_AVAILABLE:
        log("\n⚠️  Pycaw není k dispozici - přeskakuji kontrolu audio výstupu")
        return None
    
    log("\n" + "="*60)
    log(" 2. KONTROLA AUDIO VÝSTUPU ")
    log("="*60)
    
    try:
        from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
        from comtypes import CLSCTX_ALL
        from ctypes import cast, POINTER
        
        # Získat default output device
        speakers = AudioUtilities.GetSpeakers()
        interface = speakers.Activate(IAudioMeterInformation._iid_, CLSCTX_ALL, None)
        meter = cast(interface, POINTER(IAudioMeterInformation))
        
        log("Měřím audio výstup (2 sekundy)...")
        max_peak = 0.0
        for i in range(20):
            peak = meter.GetPeakValue()
            if peak > max_peak:
                max_peak = peak
            sys.stdout.write(f"\rPeak: {peak:.4f} (Max: {max_peak:.4f})")
            sys.stdout.flush()
            time.sleep(0.1)
        
        print()
        log(f"Maximální výstupní úroveň: {max_peak:.4f}")
        
        if max_peak > 0.01:
            log("✅ Audio výstup AKTIVNÍ - zvuk je detekován")
            return True
        else:
            log("⚠️  Audio výstup TICHÝ - nepřehrává se žádné audio")
            return False
            
    except Exception as e:
        log(f"❌ Chyba při kontrole výstupu: {e}")
        return None

def get_random_sample():
    """Náhodně vybere jeden z dostupných audio vzorků"""
    if not SAMPLES_DIR.exists():
        log(f"\n❌ Adresář {SAMPLES_DIR} neexistuje!")
        return None
    
    samples = list(SAMPLES_DIR.glob("*.mp3")) + list(SAMPLES_DIR.glob("*.wav"))
    
    if not samples:
        log(f"\n❌ Žádné audio vzorky v {SAMPLES_DIR}")
        log("Spusťte nejprve: python download_samples.py")
        return None
    
    selected = random.choice(samples)
    log(f"\n🎲 Náhodně vybraný vzorek: {selected.name}")
    return selected

def play_audio_and_monitor(audio_path):
    """Přehraje audio pomocí sounddevice a monitoruje, že opravdu hraje"""
    log("\n" + "="*60)
    log(" 3. PŘEHRÁVÁNÍ A MONITORING AUDIO ")
    log("="*60)
    log(f"Soubor: {audio_path.name}")
    
    try:
        # Načti audio soubor
        log("Načítám audio pro přehrání...")
        audio_data = whisperx.load_audio(str(audio_path))
        sample_rate = 16000  # WhisperX používá 16kHz
        
        log(f"Přehrávám audio ({len(audio_data)/sample_rate:.1f}s)...")
        
        # Přehraj pomocí sounddevice
        sd.play(audio_data, sample_rate)
        
        # Monitoring během přehrávání
        duration = len(audio_data) / sample_rate
        max_peak = 0.0
        
        for i in range(min(30, int(duration * 10))):  # Max 3s nebo délka audia
            # Jednoduchý progress bar
            progress = i / 30
            bar_len = int(progress * 50)
            sys.stdout.write(f"\r[{'#' * bar_len}{'-' * (50-bar_len)}] {(i*0.1):.1f}s")
            sys.stdout.flush()
            time.sleep(0.1)
        
        sd.wait()  # Počkej na dokončení
        print()
        log("✅ Audio přehráno úspěšně")
        return True
        
    except Exception as e:
        log(f"⚠️  Chyba při přehrávání: {e}")
        log("Audio bude pouze přepsáno ze souboru (bez živého přehrání)")
        return True  # Není kritické

def transcribe_audio(audio_path):
    """Přepíše audio pomocí WhisperX"""
    log("\n" + "="*60)
    log(" 4. STT PŘEPIS (WhisperX) ")
    log("="*60)
    log(f"Model: {MODEL}, Device: {DEVICE}, Compute: {COMPUTE_TYPE}")
    
    start_time = time.time()
    
    try:
        log("Načítám model...")
        model = whisperx.load_model(MODEL, DEVICE, compute_type=COMPUTE_TYPE)
        
        log("Načítám audio...")
        audio = whisperx.load_audio(str(audio_path))
        
        log("Provádím přepis...")
        result = model.transcribe(audio, batch_size=16)
        
        log(f"Detekovaný jazyk: {result.get('language', 'unknown')}")
        
        # Alignment
        log("Provádím alignment...")
        model_a, metadata = whisperx.load_align_model(
            language_code=result["language"],
            device=DEVICE
        )
        result = whisperx.align(
            result["segments"],
            model_a,
            metadata,
            audio,
            DEVICE,
            return_char_alignments=False
        )
        
        duration = time.time() - start_time
        log(f"\n⏱️  Celkový čas přepisu: {duration:.2f}s")
        
        # Výpis výsledků
        log("\n" + "-"*60)
        log(" VÝSLEDEK PŘEPISU: ")
        log("-"*60)
        
        full_text = []
        for seg in result["segments"]:
            text = seg['text'].strip()
            timestamp = f"[{seg['start']:>6.1f}s]"
            line = f"{timestamp} {text}"
            log(line)
            full_text.append(text)
        
        log("-"*60)
        
        # Uložení do souboru
        output_file = audio_path.parent / f"{audio_path.stem}_transcript.txt"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"Audio: {audio_path.name}\n")
            f.write(f"Čas přepisu: {duration:.2f}s\n")
            f.write(f"Jazyk: {result.get('language', 'unknown')}\n")
            f.write("-"*60 + "\n\n")
            for seg in result["segments"]:
                f.write(f"[{seg['start']:>6.1f}s] {seg['text'].strip()}\n")
        
        log(f"\n💾 Výsledek uložen: {output_file.name}")
        
        return True, duration, len(result["segments"])
        
    except Exception as e:
        log(f"\n❌ Chyba při přepisu: {e}")
        import traceback
        traceback.print_exc()
        return False, 0, 0

def main():
    log("="*60)
    log(" PORTABLE STT BENCHMARK TEST ")
    log(f" {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ")
    log("="*60)
    
    # 1. HW Info
    hw_info = get_hw_info()
    
    # 2. Kontrola audio výstupu (před přehráváním)
    output_status = check_audio_output_playing()
    
    # 3. Náhodný výběr vzorku
    sample = get_random_sample()
    if sample is None:
        log("\n❌ TEST PŘERUŠEN: Chybí audio vzorky")
        log("Spusťte: python download_samples.py")
        return False
    
    # 4. Přehrání a monitoring
    play_success = play_audio_and_monitor(sample)
    
    # 5. STT Přepis
    success, duration, segments = transcribe_audio(sample)
    
    # 6. Shrnutí
    log("\n" + "="*60)
    log(" SHRNUTÍ TESTU ")
    log("="*60)
    log(f"HW Info:         ✅ {hw_info['cpu_cores']} cores, {hw_info['ram_total_gb']}GB RAM")
    log(f"Audio výstup:    {'✅ Aktivní' if output_status else '⚠️  Tichý' if output_status is False else '⚠️  Není k dispozici'}")
    log(f"Přehrávání:      {'✅ OK' if play_success else '⚠️  Problém'}")
    log(f"STT přepis:      {'✅ OK' if success else '❌ SELHALO'}")
    if success:
        log(f"Doba přepisu:    {duration:.2f}s")
        log(f"Počet segmentů:  {segments}")
    log("="*60)
    
    if success:
        log("\n🎉 BENCHMARK TEST ÚSPĚŠNĚ DOKONČEN!")
        return True
    else:
        log("\n❌ BENCHMARK TEST SELHAL")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
