"""
Self-Test Demo pro Portable STT Benchmark
Stáhne 3 české audio vzorky z LibriVox (public domain), 
náhodně vybere jeden, přehraje ho a přepíše pomocí WhisperX.
"""
import os
import random
import whisperx
import sounddevice as sd
import scipy.io.wavfile as wav
import urllib.request
import numpy as np

MODEL = "small"
DEVICE = "cpu"
COMPUTE_TYPE = "int8"

# LibriVox - České pohádky (Public Domain)
SAMPLE_URLS = {
    "pohadka1_zlaty_klic.mp3": "https://www.archive.org/download/key_gold_librivox/keyofgold_01_nemcova_128kb.mp3",
    "pohadka2_tri_pratelky.mp3": "https://www.archive.org/download/key_gold_librivox/keyofgold_02_nemcova_128kb.mp3",
    "pohadka3_dlouhy_nos.mp3": "https://www.archive.org/download/key_gold_librivox/keyofgold_03_nemcova_128kb.mp3"
}

def download_samples():
    """Stáhne audio vzorky, pokud ještě nejsou"""
    samples_dir = "test_samples"
    os.makedirs(samples_dir, exist_ok=True)
    
    downloaded = []
    for filename, url in SAMPLE_URLS.items():
        filepath = os.path.join(samples_dir, filename)
        
        if not os.path.exists(filepath):
            print(f"Stahuji: {filename}...")
            try:
                urllib.request.urlretrieve(url, filepath)
                print(f"  ✅ {filename}")
            except Exception as e:
                print(f"  ❌ Chyba při stahování {filename}: {e}")
                continue
        else:
            print(f"  ℹ️ {filename} již existuje.")
        
        downloaded.append(filepath)
    
    return downloaded

def convert_to_wav(mp3_file):
    """Konvertuje MP3 na WAV (16kHz mono) pomocí ffmpeg"""
    wav_file = mp3_file.replace('.mp3', '.wav')
    
    if os.path.exists(wav_file):
        return wav_file
    
    # Najdeme ffmpeg v portable složce
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ffmpeg_path = None
    for root, dirs, files in os.walk(os.path.join(script_dir, "ffmpeg")):
        if "ffmpeg.exe" in files:
            ffmpeg_path = os.path.join(root, "ffmpeg.exe")
            break
    
    if not ffmpeg_path:
        print("⚠️ FFmpeg nenalezen. Nelze konvertovat MP3.")
        return None
    
    print(f"Konvertuji {os.path.basename(mp3_file)} na WAV...")
    cmd = f'"{ffmpeg_path}" -i "{mp3_file}" -ar 16000 -ac 1 -y "{wav_file}"'
    os.system(cmd + " >nul 2>&1")  # Tichý režim
    
    if os.path.exists(wav_file):
        print(f"  ✅ Konverze hotova: {os.path.basename(wav_file)}")
        return wav_file
    else:
        print(f"  ❌ Konverze selhala")
        return None

def play_audio(filepath):
    """Přehraje audio soubor"""
    print(f"\n🔊 PŘEHRÁVÁM: {os.path.basename(filepath)}")
    
    try:
        fs, data = wav.read(filepath)
        sd.play(data, fs)
        sd.wait()
        print("✅ Přehrávání dokončeno.\n")
    except Exception as e:
        print(f"❌ Chyba přehrávání: {e}")

def run_stt(audio_file):
    """Spustí STT přepis"""
    print("="*60)
    print(" STT PŘEPIS (WhisperX) ")
    print("="*60)
    
    try:
        print("Načítám model...")
        model = whisperx.load_model(MODEL, DEVICE, compute_type=COMPUTE_TYPE)
        
        print("Provádím přepis...")
        audio = whisperx.load_audio(audio_file)
        result = model.transcribe(audio, batch_size=8)
        
        print(f"\nDetekovaný jazyk: {result.get('language', 'Neznámý')}")
        print("\nPŘEPIS:")
        print("-"*60)
        
        full_text = ""
        for seg in result["segments"]:
            timestamp = f"[{seg['start']:.1f}s]"
            text = seg['text'].strip()
            full_text += text + " "
            print(f"{timestamp} {text}")
        
        print("-"*60)
        print(f"\n✅ Přepis dokončen ({len(result['segments'])} segmentů)")
        
        # Uložení
        output_file = audio_file + ".txt"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(full_text.strip())
        print(f"💾 Uloženo do: {os.path.abspath(output_file)}")
        
        return True
        
    except Exception as e:
        print(f"\n❌ CHYBA STT: {e}")
        return False

def main():
    print("="*60)
    print(" PORTABLE STT - SELF TEST ")
    print("="*60)
    print("\nStahuji české audio vzorky z LibriVox (public domain)...")
    
    samples = download_samples()
    
    if not samples:
        print("\n❌ Žádné vzorky ke stažení.")
        return
    
    print(f"\n✅ K dispozici: {len(samples)} vzorků")
    
    # Náhodný výběr
    selected_mp3 = random.choice(samples)
    print(f"\n🎲 NÁHODNÝ VÝBĚR: {os.path.basename(selected_mp3)}")
    
    # Konverze na WAV
    selected_wav = convert_to_wav(selected_mp3)
    if not selected_wav:
        print("❌ Nepodařilo se připravit audio.")
        return
    
    # Přehrání
    play_audio(selected_wav)
    
    # STT Test
    success = run_stt(selected_wav)
    
    if success:
        print("\n" + "="*60)
        print(" ✅ SELF-TEST ÚSPĚŠNÝ ")
        print("="*60)
        print("Portable STT benchmark je plně funkční!")
    else:
        print("\n❌ Test selhal.")

if __name__ == "__main__":
    main()
