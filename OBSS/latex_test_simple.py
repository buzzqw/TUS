#!/usr/bin/env python3

print("=== TEST SCRIPT LATEX ===")
print("Inizio test...")

try:
    print("1. Test import base...")
    import sys
    import os
    import time
    print("✅ Import base OK")

    print("2. Test pathlib...")
    from pathlib import Path
    print("✅ Pathlib OK")

    print("3. Test directory corrente...")
    current_dir = Path.cwd()
    print(f"📁 Directory corrente: {current_dir}")

    print("4. Test directory base...")
    base_dir = Path.home() / "TUS" / "OBSS"
    print(f"📁 Directory base: {base_dir}")
    print(f"📁 Esiste: {base_dir.exists()}")

    if base_dir.exists():
        print("5. Test file LaTeX...")
        files = ["OBSSv2.tex", "OBSSv2-eng.tex"]
        for filename in files:
            file_path = base_dir / filename
            print(f"📄 {filename}: {'✅' if file_path.exists() else '❌'}")

    print("6. Test comandi sistema...")
    import shutil
    commands = ['latexmk', 'xelatex', 'biber', 'python3']
    for cmd in commands:
        available = shutil.which(cmd) is not None
        print(f"🔧 {cmd}: {'✅' if available else '❌'}")

    print("7. Test import avanzati...")
    try:
        import logging
        print("✅ Logging OK")
    except Exception as e:
        print(f"❌ Logging: {e}")

    try:
        import subprocess
        print("✅ Subprocess OK")
    except Exception as e:
        print(f"❌ Subprocess: {e}")

    try:
        from concurrent.futures import ThreadPoolExecutor
        print("✅ ThreadPoolExecutor OK")
    except Exception as e:
        print(f"❌ ThreadPoolExecutor: {e}")

    try:
        import json
        print("✅ JSON OK")
    except Exception as e:
        print(f"❌ JSON: {e}")

    print("8. Test dipendenze opzionali...")
    try:
        from rich.console import Console
        print("✅ Rich disponibile")
    except ImportError:
        print("⚠️ Rich non disponibile")

    try:
        import git
        print("✅ GitPython disponibile")
    except ImportError:
        print("⚠️ GitPython non disponibile")

    try:
        import psutil
        print("✅ Psutil disponibile")
    except ImportError:
        print("⚠️ Psutil non disponibile")

    print("9. Test classe semplice...")
    class TestConfig:
        def __init__(self):
            self.test = "OK"
    
    config = TestConfig()
    print(f"✅ Test classe: {config.test}")

    print("10. Test argparse...")
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args()
    print(f"✅ Argparse: {args}")

    print("\n🎉 TUTTI I TEST COMPLETATI CON SUCCESSO!")
    print("Il problema non è con gli import base.")

except Exception as e:
    print(f"\n💥 ERRORE DURANTE I TEST: {e}")
    import traceback
    traceback.print_exc()

print("\n=== FINE TEST ===")
