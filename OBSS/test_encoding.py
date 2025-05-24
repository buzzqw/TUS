#!/usr/bin/env python3

import os
from pathlib import Path

def test_file_encoding(file_path):
    """Test dell'encoding di un file"""
    print(f"🔍 Test encoding per: {file_path}")
    
    # Leggi i primi byte raw
    try:
        with open(file_path, 'rb') as f:
            raw_data = f.read(1024)  # Primi 1KB
        
        print(f"📊 Dimensione file: {os.path.getsize(file_path)} bytes")
        print(f"🔢 Primi 20 byte (hex): {raw_data[:20].hex()}")
        
        # Test vari encoding
        encodings = ['utf-8', 'latin1', 'cp1252', 'iso-8859-1', 'utf-16', 'utf-32']
        
        for encoding in encodings:
            try:
                decoded = raw_data.decode(encoding)
                print(f"✅ {encoding}: OK - '{decoded[:50]}...'")
                
                # Prova a leggere tutto il file con questo encoding
                try:
                    with open(file_path, 'r', encoding=encoding) as f:
                        content = f.read()
                    print(f"✅ {encoding}: File completo OK ({len(content)} caratteri)")
                    return encoding
                except UnicodeDecodeError as e:
                    print(f"⚠️ {encoding}: Fallisce al carattere {e.start}: {e.reason}")
                
            except UnicodeDecodeError as e:
                print(f"❌ {encoding}: {e.reason}")
    
    except Exception as e:
        print(f"💥 Errore lettura file: {e}")
    
    return None

def test_problematic_position(file_path, position):
    """Test del carattere problematico alla posizione specifica"""
    print(f"\n🎯 Test posizione {position}:")
    
    try:
        with open(file_path, 'rb') as f:
            f.seek(max(0, position - 10))
            data = f.read(20)
        
        print(f"📍 Byte intorno alla posizione {position}:")
        for i, byte in enumerate(data):
            pos = position - 10 + i
            marker = " <-- PROBLEMA" if pos == position else ""
            print(f"   {pos:5d}: 0x{byte:02x} ({byte:3d}) {chr(byte) if 32 <= byte <= 126 else '?'}{marker}")
            
    except Exception as e:
        print(f"💥 Errore: {e}")

# Test sui file
files_to_test = ["OBSSv2.tex", "OBSSv2-eng.tex"]

for filename in files_to_test:
    file_path = Path(filename)
    if file_path.exists():
        print("\n" + "="*60)
        encoding = test_file_encoding(file_path)
        if encoding:
            print(f"🎉 Encoding raccomandato per {filename}: {encoding}")
        else:
            print(f"⚠️ Nessun encoding funziona per {filename}")
            
        # Test posizione problematica specifica
        if filename == "OBSSv2.tex":
            test_problematic_position(file_path, 4765)  # Dalla prima volta
            test_problematic_position(file_path, 2237)  # Dalla seconda volta
    else:
        print(f"❌ File {filename} non trovato")

print("\n🏁 Test completato!")
