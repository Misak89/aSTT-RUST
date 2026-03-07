import os
import sys
import time
import logging
import numpy as np
import whisperx
import sounddevice as sd
import scipy.io.wavfile as wav
from scipy.signal import resample
from datetime import datetime

# Config
MODEL = "small"
DEVICE = "cpu"
COMPUTE_TYPE = "int8"
LOG_FILE = "benchmark.log"

# Nastavení logování
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)

def log(msg):
    logging.info(msg)

def list_input_devices():
    log("--- SKENOVÁNÍ ZAŘÍZENÍ ---")
    devices = sd.query_devices()
    valid_ids = []
    
    print(f"\n{'ID':<4} | {'Název zařízení':<40} | {'Kanály'}")
    print("-" * 60)
    
    for i, dev in enumerate(devices):
        if dev['max_input_channels'] > 0:
            clean_name = dev['name'][:40]
            print(f"{i:<4} | {clean_name:<40} | {dev['max_input_channels']}")
            log(f"Device found: ID={i}, Name='{dev['name']}', Channels={dev['max_input_channels']}, API={dev['hostapi']}")
            valid_ids.append(i)
            
    print("-" * 60)
    return valid_ids

def record_stable(filename, device_id):
    try:
        dev_info = sd.query_devices(device_id)
        fs = int(dev_info['default_samplerate'])
        channels = dev_info['max_input_channels']
        
        log(f"START RECORDING: DeviceID={device_id}, Name='{dev_info['name']}', FS={fs}, CH={channels}")
    except Exception as e:
        log(f"ERROR: Init failed for ID {device_id}: {e}")
        return False

    print("\n" + "="*50)
    print(f" NAHRÁVÁNÍ Z: {dev_info['name']} (ID: {device_id}) ")
    print("="*50)
    print("Mluvte nyní... (Stiskni CTRL+C pro ukončení)")
    
    recorded_chunks = []
    max_vol_session = 0.0
    
    def callback(indata, frames, time, status):
        if status:
            log(f"Stream Status Warning: {status}")
            
        recorded_chunks.append(indata.copy())
        
        # Volume Meter Logic
        vol = np.linalg.norm(indata) * 10
        nonlocal max_vol_session
        if vol > max_vol_session: max_vol_session = vol
        
        meter = int(min(vol, 50))
        print(f"\rLevel: [{'#' * meter}{'-' * (50-meter)}] {meter}%", end="", flush=True)

    try:
        # float32 pro WDM-KS kompatibilitu
        with sd.InputStream(samplerate=fs, device=device_id, channels=channels, dtype='float32', callback=callback):
            while True:
                sd.sleep(100)
    except KeyboardInterrupt:
        log(f"STOP RECORDING: User interrupted. Max Volume Peak: {max_vol_session:.4f}")
        print(f"\n\n[STOP] Záznam ukončen. Peak Level: {max_vol_session:.2f}")
    except Exception as e:
        log(f"CRITICAL ERROR during recording: {e}")
        print(f"\n[CHYBA] {e}")
        return False

    if recorded_chunks:
        data = np.concatenate(recorded_chunks, axis=0)
        
        # Mono conversion
        if len(data.shape) > 1 and data.shape[1] > 1:
            data = np.mean(data, axis=1)
            
        # Resample to 16kHz
        if fs != 16000:
            num_samples = int(len(data) * 16000 / fs)
            data = resample(data, num_samples)
            
        wav.write(filename, 16000, data.astype(np.float32))
        log(f"FILE SAVED: {filename} (Size: {len(data)} samples)")
        return True
    return False

def process(audio_path):
    log("--- START WHISPERX TRANSCRIPTION ---")
    print("\n" + "-" * 50)
    print(f" START AI PŘEPISU (WhisperX) ")
    print("-" * 50)
    
    start_time = time.time()
    
    try:
        model = whisperx.load_model(MODEL, DEVICE, compute_type=COMPUTE_TYPE)
        audio = whisperx.load_audio(audio_path)
        result = model.transcribe(audio, batch_size=16)
        
        model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=DEVICE)
        result = whisperx.align(result["segments"], model_a, metadata, audio, DEVICE, return_char_alignments=False)
        
        duration = time.time() - start_time
        log(f"TRANSCRIPTION COMPLETE: Took {duration:.2f}s, Language={result['language']}")

        print("\n" + "="*60 + "\n VÝSLEDEK \n" + "="*60)
        out_file = os.path.abspath(audio_path + ".txt")
        
        with open(out_file, "w", encoding="utf-8") as f:
            for s in result["segments"]:
                line = f"[{s['start']:>6.1f}s] {s['text'].strip()}"
                print(line)
                f.write(line + "\n")
                
        print(f"\nSoubor uložen v: {out_file}")
        log(f"RESULT SAVED: {out_file}")
        
    except Exception as e:
        log(f"TRANSCRIPTION FAILED: {e}")
        print(f"Chyba přepisu: {e}")

if __name__ == "__main__":
    audio_file = "benchmark_input.wav"
    log("=== NEW SESSION STARTED ===")
    
    if len(sys.argv) > 1 and sys.argv[1] == "--record":
        valid_ids = list_input_devices()
        
        selected_id = 14 # Default based on diagnostics
        if "--id" in sys.argv:
            idx = sys.argv.index("--id")
            selected_id = int(sys.argv[idx+1])
        else:
            try:
                inp = input("\nZadejte ID zařízení (Doporučeno 14): ").strip()
                if inp: selected_id = int(inp)
            except:
                print(f"Neplatná volba, používám výchozí ID {selected_id}")

        if record_stable(audio_file, selected_id):
            process(audio_file)
    else:
        if os.path.exists(audio_file):
            process(audio_file)
        else:
            print("Chyba: Žádný soubor. Spusťte přes run_demo.bat a zvolte 2.")
