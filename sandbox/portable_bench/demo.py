import os
import subprocess
import urllib.request
import sys

AUDIO_URL = "https://github.com/ggerganov/whisper.cpp/raw/master/samples/jfk.wav"
AUDIO_FILE = "jfk.wav"

def download_audio():
    if not os.path.exists(AUDIO_FILE):
        print(f"Downloading sample audio ({AUDIO_FILE})...")
        urllib.request.urlretrieve(AUDIO_URL, AUDIO_FILE)
        print("Download complete.")

def run_whisperx():
    print("Running WhisperX (This may take a while on CPU)...")
    # Command: whisperx jfk.wav --model tiny --device cpu --compute_type int8
    # We use 'tiny' model for quick verification on CPU.
    # We use 'int8' quantization for speed.
    cmd = [
        sys.executable, "-m", "whisperx", 
        AUDIO_FILE, 
        "--model", "tiny", 
        "--device", "cpu", 
        "--compute_type", "int8",
        "--output_dir", ".",
        "--output_format", "txt"
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print("\n--- Success! ---")
        print(f"Transcript saved to {AUDIO_FILE}.txt")
        with open(f"{AUDIO_FILE}.txt", "r", encoding="utf-8") as f:
            print(f.read())
    except subprocess.CalledProcessError as e:
        print(f"Error running WhisperX: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    download_audio()
    run_whisperx()
