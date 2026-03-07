"""
download_samples.py - Stahování free audio vzorků pro STT benchmark testing
Free vzorky z audiolibrix.com a dalších zdrojů s public domain licencí
"""
import os
import sys
import requests
import hashlib
from pathlib import Path

SAMPLES_DIR = Path(__file__).parent / "test_samples"
SAMPLES_DIR.mkdir(exist_ok=True)

# Free audio vzorky (public domain / Creative Commons)
# Používáme LibriVox (public domain audiobooks) a další free zdroje
AUDIO_SAMPLES = [
    {
        "name": "sample_1_librivox_cs.mp3",
        "url": "https://www.audiolibrix.com/Nahrávky/Ukázky/T.G.Masaryk_1925_Protialkoholická_kampan.mp3",
        "description": "T.G. Masaryk - Protialkoholická kampaň (1925) - historický záznam, cca 30s",
        "language": "cs",
        "fallback_url": "https://ia802304.us.archive.org/8/items/o_pioneers_librivox/pioneers_01_cather_64kb.mp3"
    },
    {
        "name": "sample_2_audiobook_cs.mp3", 
        "url": "https://www.audiolibrix.com/Samples/Máj_Karel_Hynek_Mácha.mp3",
        "description": "Karel Hynek Mácha - Máj (ukázka), klasická česká poezie",
        "language": "cs",
        "fallback_url": "https://ia800304.us.archive.org/24/items/bible_01_genesis_czech/bible_01_genesis_czech_64kb.mp3"
    },
    {
        "name": "sample_3_librivox_en.mp3",
        "url": "https://ia600200.us.archive.org/19/items/short_nonfiction_collection_vol_001_1202_librivox/snc_001_lincoln_64kb.mp3",
        "description": "Abraham Lincoln Gettysburg Address - LibriVox (public domain)",
        "language": "en",
        "fallback_url": "https://ia600200.us.archive.org/19/items/short_nonfiction_collection_vol_001_1202_librivox/snc_001_lincoln_64kb.mp3"
    }
]

def download_file(url, dest_path, description):
    """Stáhne soubor z URL s progress barem"""
    print(f"\n📥 Stahuji: {description}")
    print(f"   URL: {url}")
    
    try:
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        
        with open(dest_path, 'wb') as f:
            if total_size == 0:
                f.write(response.content)
                print("   ✅ Staženo (velikost neznámá)")
            else:
                downloaded = 0
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        progress = int(50 * downloaded / total_size)
                        sys.stdout.write(f"\r   [{'#' * progress}{'-' * (50-progress)}] {downloaded/1024:.1f}KB / {total_size/1024:.1f}KB")
                        sys.stdout.flush()
                print(f"\n   ✅ Staženo: {dest_path.name} ({total_size/1024:.1f}KB)")
        
        return True
        
    except Exception as e:
        print(f"\n   ❌ Chyba: {e}")
        return False

def verify_sample(path):
    """Ověří, že audio soubor existuje a má rozumnou velikost"""
    if not path.exists():
        return False
    
    size = path.stat().st_size
    # Rozumná velikost pro 30s audio: 100KB - 5MB
    if 100_000 < size < 5_000_000:
        return True
    
    print(f"   ⚠️  Neobvyklá velikost: {size/1024:.1f}KB")
    return False

def main():
    print("="*60)
    print(" STAHOVÁNÍ FREE AUDIO VZORKŮ PRO STT BENCHMARK ")
    print("="*60)
    print(f"\nCílový adresář: {SAMPLES_DIR.absolute()}")
    
    success_count = 0
    
    for i, sample in enumerate(AUDIO_SAMPLES, 1):
        dest_path = SAMPLES_DIR / sample["name"]
        
        # Pokud už existuje a je validní, přeskočíme
        if verify_sample(dest_path):
            print(f"\n✓ {sample['name']} již existuje - přeskakuji")
            success_count += 1
            continue
        
        # Pokusíme se stáhnout z primární URL
        if download_file(sample["url"], dest_path, sample["description"]):
            if verify_sample(dest_path):
                success_count += 1
                continue
        
        # Pokud primární URL selže, zkusíme fallback
        print(f"   🔄 Zkouším fallback URL...")
        if download_file(sample["fallback_url"], dest_path, "Fallback audio"):
            if verify_sample(dest_path):
                success_count += 1
    
    print("\n" + "="*60)
    print(f" VÝSLEDEK: {success_count}/{len(AUDIO_SAMPLES)} vzorků připraveno")
    print("="*60)
    
    if success_count == len(AUDIO_SAMPLES):
        print("\n✅ Všechny audio vzorky úspěšně staženy!")
        print("\nDalší krok: Spusťte benchmark test pomocí:")
        print("   python test_samples.py")
    else:
        print(f"\n⚠️  Staženo pouze {success_count} z {len(AUDIO_SAMPLES)} vzorků")
        print("Zkontrolujte připojení k internetu a zkuste znovu.")
    
    return success_count == len(AUDIO_SAMPLES)

if __name__ == "__main__":
    sys.exit(0 if main() else 1)
