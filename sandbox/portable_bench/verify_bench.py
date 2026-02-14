import os
import sys
import time
import logging
import numpy as np
import whisperx
import platform
import subprocess
import ctypes

# Pro loopback recording
import pyaudiowpatch as pyaudio

# Pro detekci output aktivity
from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
from ctypes import cast, POINTER
from comtypes import CLSCTX_ALL

# Config
LOG_FILE = "verify_bench.log"
TEST_DURATION = 5.0
MIN_RMS_THRESHOLD = 0.001

logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(asctime)s - %(message)s')

def log(msg):
    print(msg)
    logging.info(msg)

def get_system_info():
    """HW Audit"""
    info = {}
    info['os'] = f"{platform.system()} {platform.release()}"
    info['cpu_cores'] = os.cpu_count()
    
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

    # GPU (WMIC)
    gpu_list = []
    try:
        process = subprocess.Popen("wmic path win32_VideoController get name", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        out, _ = process.communicate()
        if out:
            for line in out.decode('utf-8', errors='ignore').split('\n'):
                clean = line.strip()
                if clean and "Name" not in clean:
                    gpu_list.append(clean)
    except:
        pass
    info['gpu_name'] = ", ".join(gpu_list) if gpu_list else "Unknown"

    return info

def check_speaker_activity():
    """Kontrola, jestli z reproduktorů vůbec něco jde (pomocí pycaw)"""
    log("\n--- OUTPUT ACTIVITY CHECK (Speakers) ---")
    try:
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioMeterInformation._iid_, CLSXCTX_ALL, None)
        meter = interface.QueryInterface(IAudioMeterInformation)
        
        log("Měřím výstupní aktivitu po dobu 3 sekund...")
        max_peak = 0.0
        for _ in range(30):
            peak = meter.GetPeakValue()
            if peak > max_peak: max_peak = peak
            time.sleep(0.1)
        
        log(f"Max Output Peak: {max_peak:.4f}")
        if max_peak > 0.01:
            log("✅ ZVUK DETEKOVÁN na výstupu reproduktorů!")
            return True
        else:
            log("❌ TICHO na výstupu. Pusťte prosím audio/video.")
            return False
    except Exception as e:
        log(f"⚠️ Nelze měřit výstup: {e}")
        return None

def find_loopback_device():
    """Najde WASAPI loopback device (default output jako input)"""
    log("\n--- HLEDÁM WASAPI LOOPBACK DEVICE ---")
    p = pyaudio.PyAudio()
    wasapi_info = None
    
    # Najdi WASAPI host API
    for i in range(p.get_host_api_count()):
        api = p.get_host_api_info_by_index(i)
        if "WASAPI" in api['name']:
            wasapi_info = api
            break
    
    if not wasapi_info:
        log("❌ WASAPI nenalezeno!")
        return None
    
    # Najdi default loopback (default output se stane inputem)
    default_speakers = p.get_device_info_by_index(wasapi_info['defaultOutputDevice'])
    
    # Hledáme loopback variantu
    for i in range(p.get_device_count()):
        dev = p.get_device_info_by_index(i)
        # Loopback má isLoopback flag
        if dev.get('isLoopback', False) and dev['hostApi'] == wasapi_info['index']:
            log(f"✅ Nalezen Loopback: {dev['name']}")
            return i, dev
    
    log("❌ Loopback device nenalezen. Zkuste povolit 'Stereo Mix' ve Windows.")
    return None, None

def test_loopback_recording():
    """Zkusí nahrát z loopback"""
    dev_id, dev_info = find_loopback_device()
    if dev_id is None:
        return False
    
    log(f"\n--- TEST LOOPBACK RECORDING ({TEST_DURATION}s) ---")
    log("Pusťte audio NYNÍ! Začínám za 2 sekundy...")
    time.sleep(2)
    
    p = pyaudio.PyAudio()
    recorded_chunks = []
    
    def callback(in_data, frame_count, time_info, status):
        recorded_chunks.append(np.frombuffer(in_data, dtype=np.float32).copy())
        return (in_data, pyaudio.paContinue)
    
    try:
        stream = p.open(
            format=pyaudio.paFloat32,
            channels=dev_info['maxInputChannels'],
            rate=int(dev_info['defaultSampleRate']),
            input=True,
            input_device_index=dev_id,
            stream_callback=callback
        )
        
        stream.start_stream()
        for i in range(int(TEST_DURATION)):
            sys.stdout.write(f"\rNahrávám... {i+1}/{int(TEST_DURATION)}s")
            sys.stdout.flush()
            time.sleep(1)
        
        stream.stop_stream()
        stream.close()
        print()
        
        if recorded_chunks:
            data = np.concatenate(recorded_chunks)
            rms = np.sqrt(np.mean(data**2))
            log(f"Naměřeno RMS: {rms:.6f}")
            
            if rms > MIN_RMS_THRESHOLD:
                log(f"✅ LOOPBACK FUNGUJE!")
                # Ulož audio
                filename = "loopback_test.wav"
                from scipy.io.wavfile import write
                # Resample to 16kHz mono
                if len(data.shape) > 1:
                    data = np.mean(data, axis=1)
                write(filename, 16000, data.astype(np.float32))
                log(f"Uloženo do: {filename}")
                return True
            else:
                log("❌ Loopback otevřen, ale žádný signál.")
        
    except Exception as e:
        log(f"❌ Chyba při loopback nahrávání: {e}")
    
    return False

def main_verification():
    log("="*60)
    log(" COMPREHENSIVE AUDIO VERIFICATION TOOL ")
    log("="*60)
    
    # 1. HW Audit
    sys_info = get_system_info()
    log(f"\nOS: {sys_info['os']}")
    log(f"CPU: {sys_info['cpu_cores']} Cores")
    log(f"RAM: {sys_info['ram_avail_gb']} GB / {sys_info['ram_total_gb']} GB")
    log(f"GPU: {sys_info['gpu_name']}")
    
    # 2. Kontrola output aktivity
    output_active = check_speaker_activity()
    if output_active == False:
        log("\n⚠️ DOPORUČENÍ: Nejprve pusťte video/hudbu, pak spusťte test znovu.")
        return
    
    # 3. Test loopback
    success = test_loopback_recording()
    
    if success:
        log("\n✅ === VÝSLEDEK: LOOPBACK RECORDING FUNGUJE ===")
        log("Portable benchmark je připraven pro reálné použití.")
    else:
        log("\n⚠️ === VÝSLEDEK: LOOPBACK NENÍ K DISPOZICI ===")
        log("Systém má funkční audio output, ale nelze zachytit přes loopback.")
        log("Možnosti:")
        log("  1. Povolit 'Stereo Mix' v Ovládacích panelech -> Zvuk -> Nahrávání")
        log("  2. Použít externí mikrofon + reproduktory (akustická smyčka)")
        log("  3. Použít předdefinovaný testovací WAV soubor (bez live recording)")

if __name__ == "__main__":
    main_verification()
