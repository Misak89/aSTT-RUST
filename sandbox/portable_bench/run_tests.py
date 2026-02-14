"""
run_tests.py - Kompletní test suite pro portable STT benchmark
Testuje VŠE před použitím: knihovny, audio I/O, HW detekci, download, STT
"""
import sys
import os
import time
from datetime import datetime

# Test results tracking
test_results = []

def print_header(title):
    """Vypisuje header sekce"""
    print("\n" + "="*70)
    print(f" {title}")
    print("="*70)

def test_result(name, success, details=""):
    """Zaznamená výsledek testu"""
    status = "✅ PASS" if success else "❌ FAIL"
    result = {"name": name, "success": success, "details": details}
    test_results.append(result)
    print(f"{status} | {name}")
    if details:
        print(f"       {details}")
    return success

def test_imports():
    """Test 1: Importy všech potřebných knihoven"""
    print_header("TEST 1: IMPORT KNIHOVEN")
    
    all_passed = True
    
    # Core Python libs
    try:
        import platform
        import subprocess
        import ctypes
        test_result("platform, subprocess, ctypes", True)
    except Exception as e:
        test_result("platform, subprocess, ctypes", False, str(e))
        all_passed = False
    
    # Numpy & Scipy
    try:
        import numpy as np
        version = np.__version__
        test_result(f"numpy", True, f"verze {version}")
    except Exception as e:
        test_result("numpy", False, str(e))
        all_passed = False
    
    try:
        import scipy
        import scipy.io.wavfile
        from scipy.signal import resample
        test_result("scipy", True, f"verze {scipy.__version__}")
    except Exception as e:
        test_result("scipy", False, str(e))
        all_passed = False
    
    # Audio I/O knihovny
    try:
        import sounddevice as sd
        test_result("sounddevice", True, f"verze {sd.__version__}")
    except Exception as e:
        test_result("sounddevice", False, str(e))
        all_passed = False
    
    # HTTP knihovna pro download
    try:
        import requests
        test_result("requests", True, f"verze {requests.__version__}")
    except Exception as e:
        test_result("requests", False, str(e))
        all_passed = False
    
    # Audio playback (optional)
    try:
        import playsound
        test_result("playsound", True, "dostupné")
    except Exception as e:
        test_result("playsound", False, f"OPTIONAL: {e}")
    
    # Windows audio monitoring
    try:
        from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
        from comtypes import CLSCTX_ALL
        test_result("pycaw + comtypes", True)
    except Exception as e:
        test_result("pycaw + comtypes", False, f"OPTIONAL: {e}")
    
    # WASAPI loopback
    try:
        import pyaudiowpatch
        test_result("pyaudiowpatch", True)
    except Exception as e:
        test_result("pyaudiowpatch", False, f"OPTIONAL: {e}")
    
    # WhisperX (hlavní knihovna)
    try:
        import whisperx
        test_result("whisperx", True, "STT engine ready")
    except Exception as e:
        test_result("whisperx", False, f"CRITICAL: {e}")
        all_passed = False
    
    return all_passed

def test_hw_detection():
    """Test 2: Hardware detekce"""
    print_header("TEST 2: HARDWARE DETEKCE")
    
    import platform
    import os
    import ctypes
    import subprocess
    
    all_passed = True
    
    # OS Detection
    try:
        os_info = f"{platform.system()} {platform.release()}"
        test_result("OS detekce", True, os_info)
    except Exception as e:
        test_result("OS detekce", False, str(e))
        all_passed = False
    
    # CPU
    try:
        cores = os.cpu_count()
        processor = platform.processor()
        test_result("CPU detekce", True, f"{cores} jader, {processor[:50]}")
    except Exception as e:
        test_result("CPU detekce", False, str(e))
        all_passed = False
    
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
        total_gb = round(mem.ullTotalPhys / (1024**3), 2)
        avail_gb = round(mem.ullAvailPhys / (1024**3), 2)
        test_result("RAM detekce", True, f"{avail_gb} GB / {total_gb} GB")
    except Exception as e:
        test_result("RAM detekce", False, str(e))
        all_passed = False
    
    # GPU (WMIC)
    try:
        process = subprocess.Popen(
            "wmic path win32_VideoController get name",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        out, _ = process.communicate(timeout=5)
        gpu_list = []
        if out:
            for line in out.decode('utf-8', errors='ignore').split('\n'):
                clean = line.strip()
                if clean and "Name" not in clean:
                    gpu_list.append(clean)
        gpu_name = ", ".join(gpu_list) if gpu_list else "Unknown"
        test_result("GPU detekce", True, gpu_name[:60])
    except Exception as e:
        test_result("GPU detekce", False, str(e))
    
    return all_passed

def test_audio_devices():
    """Test 3: Audio zařízení (vstup i výstup)"""
    print_header("TEST 3: AUDIO ZAŘÍZENÍ")
    
    import sounddevice as sd
    
    all_passed = True
    
    # Input devices
    try:
        devices = sd.query_devices()
        input_devs = [d for d in devices if d['max_input_channels'] > 0]
        test_result("Audio INPUT zařízení", len(input_devs) > 0, 
                   f"Nalezeno {len(input_devs)} vstupních zařízení")
        
        if len(input_devs) > 0:
            print("       Příklady:")
            for i, dev in enumerate(input_devs[:3]):
                print(f"         - {dev['name'][:50]} ({dev['max_input_channels']} ch)")
    except Exception as e:
        test_result("Audio INPUT zařízení", False, str(e))
        all_passed = False
    
    # Output devices
    try:
        output_devs = [d for d in devices if d['max_output_channels'] > 0]
        test_result("Audio OUTPUT zařízení", len(output_devs) > 0,
                   f"Nalezeno {len(output_devs)} výstupních zařízení")
        
        if len(output_devs) > 0:
            print("       Příklady:")
            for i, dev in enumerate(output_devs[:3]):
                print(f"         - {dev['name'][:50]} ({dev['max_output_channels']} ch)")
    except Exception as e:
        test_result("Audio OUTPUT zařízení", False, str(e))
        all_passed = False
    
    return all_passed

def test_audio_output_monitoring():
    """Test 4: Monitoring audio výstupu"""
    print_header("TEST 4: AUDIO OUTPUT MONITORING")
    
    try:
        from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
        from comtypes import CLSCTX_ALL
        from ctypes import cast, POINTER
        
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioMeterInformation._iid_, CLSCTX_ALL, None)
        meter = cast(interface, POINTER(IAudioMeterInformation))
        
        print("       Měřím audio výstup (2 sekundy)...")
        max_peak = 0.0
        for i in range(20):
            peak = meter.GetPeakValue()
            if peak > max_peak:
                max_peak = peak
            time.sleep(0.1)
        
        details = f"Max peak: {max_peak:.4f}"
        if max_peak > 0.01:
            details += " - AUDIO AKTIVNÍ!"
        else:
            details += " - ticho (OK pokud nepřehráváte)"
        
        test_result("Windows Audio Meter", True, details)
        return True
        
    except Exception as e:
        test_result("Windows Audio Meter", False, str(e))
        return False

def test_ffmpeg():
    """Test 5: FFmpeg dostupnost"""
    print_header("TEST 5: FFMPEG")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ffmpeg_dir = os.path.join(script_dir, "ffmpeg")
    
    if not os.path.exists(ffmpeg_dir):
        test_result("FFmpeg složka", False, "Složka neexistuje")
        return False
    
    # Najdi ffmpeg.exe
    ffmpeg_path = None
    for root, dirs, files in os.walk(ffmpeg_dir):
        if "ffmpeg.exe" in files:
            ffmpeg_path = os.path.join(root, "ffmpeg.exe")
            break
    
    if ffmpeg_path:
        test_result("FFmpeg executable", True, ffmpeg_path)
        
        # Test funkčnosti
        try:
            import subprocess
            result = subprocess.run(
                [ffmpeg_path, "-version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            version_line = result.stdout.split('\n')[0] if result.stdout else "unknown"
            test_result("FFmpeg funkční", result.returncode == 0, version_line[:60])
            return result.returncode == 0
        except Exception as e:
            test_result("FFmpeg funkční", False, str(e))
            return False
    else:
        test_result("FFmpeg executable", False, "Nenalezeno v ffmpeg/")
        return False

def test_download_capability():
    """Test 6: Schopnost stahovat soubory"""
    print_header("TEST 6: HTTP DOWNLOAD")
    
    try:
        import requests
        
        # Test na malém souboru
        test_url = "https://httpbin.org/bytes/1024"
        print("       Testuji download na httpbin.org...")
        
        response = requests.get(test_url, timeout=10)
        success = response.status_code == 200 and len(response.content) == 1024
        
        if success:
            test_result("HTTP download", True, f"Staženo {len(response.content)} bytů")
        else:
            test_result("HTTP download", False, f"Status: {response.status_code}")
        
        return success
        
    except Exception as e:
        test_result("HTTP download", False, str(e))
        return False

def test_whisperx_basic():
    """Test 7: WhisperX základní funkce"""
    print_header("TEST 7: WHISPERX ZÁKLADNÍ TEST")
    
    try:
        import whisperx
        import numpy as np
        
        # Test načtení modelu (bez skutečného downloadu)
        test_result("WhisperX import", True)
        
        # Vytvořme falešné audio pro test
        print("       Vytvářím testovací audio...")
        sample_rate = 16000
        duration = 1  # 1 sekunda
        t = np.linspace(0, duration, sample_rate * duration)
        # Tichý sinusový signál
        audio_test = np.sin(2 * np.pi * 440 * t) * 0.1
        
        # Uložíme jako dočasný soubor
        import scipy.io.wavfile as wav
        test_audio_path = "test_audio_whisper.wav"
        wav.write(test_audio_path, sample_rate, audio_test.astype(np.float32))
        
        # Test načtení audio
        audio_loaded = whisperx.load_audio(test_audio_path)
        test_result("WhisperX load_audio", True, f"Načteno {len(audio_loaded)} vzorků")
        
        # Cleanup
        if os.path.exists(test_audio_path):
            os.remove(test_audio_path)
        
        return True
        
    except Exception as e:
        test_result("WhisperX základní test", False, str(e))
        return False

def print_summary():
    """Výsledné shrnutí"""
    print_header("SHRNUTÍ TESTŮ")
    
    total = len(test_results)
    passed = sum(1 for r in test_results if r['success'])
    failed = total - passed
    
    print(f"\nCelkem testů: {total}")
    print(f"✅ Úspěšných: {passed}")
    print(f"❌ Neúspěšných: {failed}")
    print(f"📊 Úspěšnost: {(passed/total*100):.1f}%")
    
    if failed > 0:
        print("\n⚠️  SELHANÉ TESTY:")
        for r in test_results:
            if not r['success']:
                print(f"   ❌ {r['name']}")
                if r['details']:
                    print(f"      └─ {r['details']}")
    
    print("\n" + "="*70)
    
    if failed == 0:
        print(" 🎉 VŠECHNY TESTY PROŠLY - SYSTÉM JE PŘIPRAVEN!")
    else:
        print(f" ⚠️  {failed} testů selhalo - zkontrolujte instalaci")
    print("="*70)
    
    # Uložení do logu
    log_file = "test_results.log"
    with open(log_file, 'w', encoding='utf-8') as f:
        f.write(f"TEST RUN: {datetime.now()}\n")
        f.write("="*70 + "\n\n")
        for r in test_results:
            status = "PASS" if r['success'] else "FAIL"
            f.write(f"[{status}] {r['name']}\n")
            if r['details']:
                f.write(f"  Details: {r['details']}\n")
            f.write("\n")
        f.write(f"\nSummary: {passed}/{total} passed ({(passed/total*100):.1f}%)\n")
    
    print(f"\n💾 Detailní log uložen: {log_file}")
    
    return failed == 0

def main():
    print("="*70)
    print(" PORTABLE STT BENCHMARK - COMPLETE TEST SUITE")
    print(f" {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70)
    print("\nTento test ověří VŠECHNY komponenty před použitím:")
    print("  - Import knihoven")
    print("  - HW detekce (CPU, GPU, RAM)")
    print("  - Audio zařízení (vstup + výstup)")
    print("  - Audio output monitoring")
    print("  - FFmpeg")
    print("  - HTTP download")
    print("  - WhisperX")
    
    input("\nStiskněte ENTER pro spuštění testů...")
    
    # Spustíme všechny testy
    test_imports()
    test_hw_detection()
    test_audio_devices()
    test_audio_output_monitoring()
    test_ffmpeg()
    test_download_capability()
    test_whisperx_basic()
    
    # Shrnutí
    all_ok = print_summary()
    
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
