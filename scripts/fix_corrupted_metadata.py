#!/usr/bin/env python3
"""
fix_corrupted_metadata.py
Oprava poskozenych metadat (PowerShell interpolace bug)
Verze: 1.0
Vytvoreno: 2026-02-17
"""

import os
import re
import sys
from pathlib import Path

def fix_corrupted_metadata(file_path, dry_run=False):
    """Opravi poskozena metadata v souboru."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Kontrola, zda ma poskozena metadata
        # Pattern: $11.1 nebo $11.2 atd. (vzniklo chybnou interpolaci $1$newVersion)
        if '$1' not in content:
            return None, 'no_corruption'
        
        # Opravit poskozenou verzi: $11.1 -> **Verze:** 1.1
        # Pattern: $1 nasledovane cisly a teckou
        content = re.sub(r'\$1(\d+\.\d+)', r'**Verze:** \1', content)
        
        # Opravit poskozeny timestamp: $12026-02-17 -> **Posledni zmena:** 2026-02-17
        # Pattern: $1 nasledovane datem
        content = re.sub(
            r'\$1(\d{4}-\d{2}-\d{2})(?: \d{2}:\d{2})?(?: \(UTC\+\d\))?(?: \(UTC\+\d\))?',
            r'**Posledni zmena:** \1 (UTC+1)',
            content
        )
        
        if dry_run:
            return file_path, 'would_fix'
        
        # Ulozit
        with open(file_path, 'w', encoding='utf-8', newline='') as f:
            f.write(content)
        
        return file_path, 'fixed'
    
    except Exception as e:
        return file_path, f'error: {e}'

def main():
    dry_run = '--dry-run' in sys.argv or '-n' in sys.argv
    detailed = '--detailed' in sys.argv or '-v' in sys.argv
    
    print()
    print("=" * 40)
    print("  Corrupted Metadata Fixer v1.0 (Python)")
    if dry_run:
        print("  Mode: DRY RUN")
    print("=" * 40)
    print()
    
    # Najit vsechny .md soubory
    root = Path('.')
    md_files = []
    for pattern in ['*.md', '**/*.md']:
        for p in root.glob(pattern):
            # Vyloucit externi adresare
            if any(x in str(p) for x in ['node_modules', 'venv', 'python-embed', 'spec-kit']):
                continue
            md_files.append(p)
    
    fixed = 0
    skipped = 0
    errors = []
    
    for file_path in md_files:
        result, status = fix_corrupted_metadata(file_path, dry_run)
        
        if status == 'no_corruption':
            if detailed:
                print(f"SKIP: {file_path} (no corruption)")
            skipped += 1
        elif status == 'would_fix':
            print(f"[DRY RUN] Would fix: {file_path}")
            fixed += 1
        elif status == 'fixed':
            print(f"FIXED: {file_path}")
            fixed += 1
        elif status.startswith('error'):
            print(f"ERROR: {file_path} - {status}")
            errors.append((file_path, status))
    
    print()
    print("=" * 40)
    print("  Summary")
    print("=" * 40)
    print(f"  Fixed:   {fixed}")
    print(f"  Skipped: {skipped}")
    print(f"  Errors:  {len(errors)}")
    print("=" * 40)
    
    if dry_run:
        print()
        print("Run without --dry-run to apply fixes")
    
    if errors:
        print()
        print("Errors:")
        for file_path, error in errors:
            print(f"  - {file_path}: {error}")
    
    print()
    if fixed > 0:
        print(f"--- [CORRUPTED METADATA {'WOULD BE ' if dry_run else ''}FIXED] {fixed} files ---")
    else:
        print("--- [NO CORRUPTION FOUND] ---")

if __name__ == '__main__':
    main()
