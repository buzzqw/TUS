#!/usr/bin/env python3

"""
Compilatore LaTeX Unificato - Parallelo e Sequenziale
=====================================================

Un unico compilatore che supporta ENTRAMBE le modalità:
- Modalità PARALLELA (default): massima velocità, multi-core
- Modalità SEQUENZIALE: debug facile, un file alla volta

Utilizzo:
  python3 latex_compiler.py                    # Parallelo (default)
  python3 latex_compiler.py --sequential       # Sequenziale
  python3 latex_compiler.py --parallel         # Parallelo (esplicito)
"""

import os
import sys
import time
import subprocess
import shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import argparse
import logging

try:
    from rich.console import Console
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn
    from rich.table import Table
    from rich.panel import Panel
    console = Console()
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

def print_msg(emoji, message, level="INFO"):
    timestamp = datetime.now().strftime("%H:%M:%S")
    if level == "ERROR":
        print(f"[{timestamp}] ❌ {message}", file=sys.stderr)
    elif level == "WARNING":
        print(f"[{timestamp}] ⚠️ {message}")
    else:
        print(f"[{timestamp}] {emoji} {message}")

def get_github_token_from_file(token_path):
    try:
        with open(token_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip().startswith("githubtoken="):
                    return line.strip().split("=", 1)[1]
    except Exception as e:
        print_msg("❌", f"Impossibile leggere il file token: {e}")
        return None

class UnifiedConfig:
    def __init__(self):
        self.base_dir = Path.cwd()
        self.files = ["OBSSv2.tex", "OBSSv2-eng.tex"]
        self.parallel_enabled = True  # Default: parallelo
        self.max_workers = 4
        self.timeout = 300
        self.do_git_commit = False
        self.github_token = None
        self.debug_mode = False
        self.fast_mode = False

        print_msg("⚙️", f"Configurazione: {self.base_dir}")

class PerformanceTracker:
    def __init__(self):
        self.start_time = time.time()
        self.operations = []
        self.compilation_times = {}

    def track_compilation(self, filename, duration, success=True):
        self.compilation_times[filename] = duration
        self.operations.append({
            'name': f"COMPILAZIONE {filename}",
            'duration': duration,
            'success': success,
            'timestamp': datetime.now().isoformat()
        })
        status = "✅" if success else "❌"
        print_msg("📊", f"{status} {filename}: {duration:.2f}s")

    def get_total_time(self):
        return time.time() - self.start_time

    def show_report(self, mode="auto"):
        total_time = self.get_total_time()

        if RICH_AVAILABLE:
            # Determina titolo based su modalità
            if mode == "parallel":
                title = "📊 Report Performance - Modalità PARALLELA"
                mode_emoji = "🚀"
            elif mode == "sequential":
                title = "📊 Report Performance - Modalità SEQUENZIALE"
                mode_emoji = "🔄"
            else:
                title = "📊 Report Performance"
                mode_emoji = "📊"

            table = Table(title=title)
            table.add_column("File", style="cyan")
            table.add_column("Tempo", style="green")
            table.add_column("Stato", style="yellow")

            for filename, duration in self.compilation_times.items():
                op = next((o for o in self.operations if filename in o['name']), {})
                status = "✅" if op.get('success', True) else "❌"
                table.add_row(filename, f"{duration:.2f}s", status)

            if self.compilation_times:
                total_comp = sum(self.compilation_times.values())
                avg_comp = total_comp / len(self.compilation_times)
                table.add_row(
                    "[bold]TOTALE[/bold]",
                    f"[bold]{total_comp:.2f}s[/bold]",
                    f"[bold]Media: {avg_comp:.2f}s[/bold]"
                )

            console.print(table)

            # Panel con performance specifiche per modalità
            panel_content = f"{mode_emoji} Modalità: {mode.upper()}\n"
            panel_content += f"⏱️ Tempo totale: {total_time:.2f}s\n"
            panel_content += f"📄 File compilati: {len(self.compilation_times)}\n"

            if mode == "parallel":
                panel_content += f"🔥 Speedup teorico: {len(self.compilation_times)}x\n"
                efficiency = (sum(self.compilation_times.values()) / total_time) * 100
                panel_content += f"⚡ Efficienza parallela: {efficiency:.1f}%\n"

            if total_time < 30:
                panel_content += "🏆 Performance ECCELLENTE!"
                style = "green"
            elif total_time < 60:
                panel_content += "✅ Performance BUONA!"
                style = "yellow"
            else:
                panel_content += "⏱️ Performance accettabile"
                style = "red"

            panel = Panel(panel_content, title="🎯 Riassunto", border_style=style)
            console.print(panel)
        else:
            print("\n" + "="*60)
            print(f"📊 REPORT PERFORMANCE - {mode.upper()}")
            print("="*60)
            for filename, duration in self.compilation_times.items():
                print(f"📄 {filename}: {duration:.2f}s")
            if self.compilation_times:
                print(f"⏱️ Tempo totale: {total_time:.2f}s")
                print(f"📊 Tempo medio: {sum(self.compilation_times.values()) / len(self.compilation_times):.2f}s")

class UnifiedLaTeXCompiler:
    def __init__(self, config):
        self.config = config
        self.performance = PerformanceTracker()
        self.setup_dirs()

        mode = "PARALLELA" if config.parallel_enabled else "SEQUENZIALE"
        print_msg("🚀", f"Compilatore inizializzato - Modalità {mode}")

    def setup_dirs(self):
        self.temp_dir = self.config.base_dir / "temp"
        self.aux_dir = self.temp_dir / "compilation"
        self.aux_dir_noimage = self.temp_dir / "compilation-noimage"
        self.aux_dir_nocopertina = self.temp_dir / "compilation-nocopertina"

        dirs = [
            self.temp_dir,
            self.aux_dir,
            self.aux_dir / "italian",
            self.aux_dir / "english",
            self.aux_dir_noimage,
            self.aux_dir_nocopertina
        ]

        for d in dirs:
            d.mkdir(parents=True, exist_ok=True)

        print_msg("📁", f"Directory temporanee: {self.temp_dir}")

    def run(self):
        mode_name = "PARALLELA" if self.config.parallel_enabled else "SEQUENZIALE"
        print_msg("🚀", f"=== INIZIO COMPILAZIONE {mode_name} ===")

        try:
            if not self.check_dependencies():
                return 1

            response = input(f"\n🚀 Compilazione ULTRA-VELOCE ({mode_name.lower()})? [Y/n]: ").strip().lower()
            if response not in ['n', 'no']:
                self.config.do_git_commit = True
                self.config.compile_no_cover = True
                self.config.compile_no_images = True

                print_msg("⚙️", f"Modalità ULTRA-VELOCE {mode_name} attivata")
                print_msg("✨", "Includerà:")
                print_msg("✨", "  📄 Versione normale (OBSSv2.tex + OBSSv2-eng.tex)")
                print_msg("✨", "  📄 Versione senza copertina (OBSSv2-nocopertina.pdf)")
                print_msg("✨", "  🖼️  Versione senza immagini (OBSSv2-noimage.pdf)")
                print_msg("✨", "  🚀 Commit Git automatico")

                # CORREZIONE: Crea i file temporanei PRIMA del filtro
                print_msg("🔧", "Creazione file temporanei...")
                noimage_tex = self.create_noimage_version()
                if noimage_tex:
                    self.config.files.append(noimage_tex.name)
                    print_msg("✅", f"Aggiunto: {noimage_tex.name}")

                nocopertina_tex = self.create_nocopertina_version()
                if nocopertina_tex:
                    self.config.files.append(nocopertina_tex.name)
                    print_msg("✅", f"Aggiunto: {nocopertina_tex.name}")

            else:
                cover_response = input("🔄 Compilare versione senza copertina? [y/N]: ").strip().lower()
                if cover_response in ['y', 'yes', 's', 'si']:
                    self.config.compile_no_cover = True
                    print_msg("✅", "Versione senza copertina attivata")
                    nocopertina_tex = self.create_nocopertina_version()
                    if nocopertina_tex:
                        self.config.files.append(nocopertina_tex.name)

                images_response = input("🔄 Compilare versione senza immagini? [y/N]: ").strip().lower()
                if images_response in ['y', 'yes', 's', 'si']:
                    self.config.compile_no_images = True
                    print_msg("✅", "Versione senza immagini attivata")
                    noimage_tex = self.create_noimage_version()
                    if noimage_tex:
                        self.config.files.append(noimage_tex.name)

                git_response = input("🔄 Commit Git automatico? [y/N]: ").strip().lower()
                if git_response in ['y', 'yes', 's', 'si']:
                    self.config.do_git_commit = True
                    print_msg("✅", "Git automatico attivato")

            # CORREZIONE: Filtra i file DOPO averli creati
            print_msg("🔍", f"Verifica file in configurazione: {self.config.files}")
            files_to_compile = []

            for filename in self.config.files:
                file_path = self.config.base_dir / filename

                print_msg("🔍", f"Verificando {filename}")

                if not file_path.exists():
                    print_msg("⚠️", f"File {filename} non trovato")
                    continue

                if self.needs_compilation(file_path):
                    files_to_compile.append(file_path)
                    print_msg("✅", f"Aggiunto a compilazione: {filename}")
                else:
                    print_msg("⏭️", f"Skip: {filename} (già aggiornato)")

            print_msg("📋", f"Piano finale: {len(files_to_compile)} file da compilare")
            print_msg("📋", f"File da compilare: {[f.name for f in files_to_compile]}")

            if files_to_compile:
                # DECISIONE: Parallelo o Sequenziale
                will_use_parallel = self.config.parallel_enabled and len(files_to_compile) > 1

                if will_use_parallel:
                    print_msg("🚀", f"🔥 MODALITÀ PARALLELA con {min(len(files_to_compile), self.config.max_workers)} worker")
                    results = self.compile_parallel(files_to_compile)
                else:
                    if self.config.parallel_enabled:
                        print_msg("🔄", "MODALITÀ SEQUENZIALE (solo 1 file)")
                    else:
                        print_msg("🔄", "MODALITÀ SEQUENZIALE (richiesta)")
                    results = self.compile_sequential(files_to_compile)

                failed = sum(1 for success, _, _ in results.values() if not success)
                if failed > 0:
                    print_msg("⚠️", f"{failed} compilazioni fallite")
                else:
                    print_msg("🎉", "Tutte le compilazioni completate con successo!")

            self.show_pdfs()
            self.cleanup()

            # Report con modalità specifica
            mode = "parallel" if self.config.parallel_enabled else "sequential"
            self.performance.show_report(mode)

            self.git_commit()
            print_msg("🎉", f"=== COMPILAZIONE {mode_name} COMPLETATA ===")
            return 0

        except KeyboardInterrupt:
            print_msg("🛑", "Operazione interrotta")
            return 1
        except Exception as e:
            print_msg("💥", f"Errore fatale: {e}")
            if self.config.debug_mode:
                import traceback
                traceback.print_exc()
            return 1

    def show_pdfs(self):
        pdfs = list(self.config.base_dir.glob("*.pdf"))
        if not pdfs:
            print_msg("⚠️", "Nessun PDF trovato")
            return
        total_size = sum(p.stat().st_size for p in pdfs)
        total_mb = total_size / (1024 * 1024)
        print_msg("📄", f"{len(pdfs)} PDF generati ({total_mb:.1f}MB totali)")
        for pdf in pdfs:
            size_mb = pdf.stat().st_size / (1024 * 1024)
            print_msg("📄", f"  {pdf.name} ({size_mb:.1f}MB)")

    def setup_gitignore(self):
        gitignore_path = self.config.base_dir / ".gitignore"
        ignore_patterns = [
            "# Directory temporanee",
            "temp/",
            "*.aux",
            "*.log",
            "*.fls",
            "*.fdb_latexmk",
            "*.synctex.gz",
            "*.bcf",
            "*.bbl",
            "*.blg",
            "*.run.xml",
            "*.xdv",
            "*.toc",
            "*.lof",
            "*.lot",
            "*.out",
            "*.idx",
            "*.ind",
            "*.ilg",
            "",
            "# File temporanei versioni alternative",
            "*-nocopertina.tex",
            "*-noimage.tex",
            "",
            "# File di sistema",
            ".DS_Store",
            "Thumbs.db",
            "*~",
            "*.bak",
            "",
            "# Cache Python",
            "__pycache__/",
            "*.pyc",
            "*.pyo",
            ".token"
        ]
        try:
            existing_patterns = set()
            if gitignore_path.exists():
                with open(gitignore_path, 'r', encoding='utf-8', errors='replace') as f:
                    existing_patterns = set(line.strip() for line in f if line.strip() and not line.startswith('#'))
            new_patterns = []
            for pattern in ignore_patterns:
                if pattern and not pattern.startswith('#') and pattern not in existing_patterns:
                    new_patterns.append(pattern)
            if new_patterns:
                with open(gitignore_path, 'a', encoding='utf-8') as f:
                    f.write("\n# Aggiunto automaticamente dal compilatore LaTeX\n")
                    for pattern in new_patterns:
                        f.write(f"{pattern}\n")
                print_msg("📝", f"Aggiornato .gitignore con {len(new_patterns)} nuovi pattern")
                for pattern in new_patterns[:3]:
                    print_msg("📝", f"  + {pattern}")
                if len(new_patterns) > 3:
                    print_msg("📝", f"  + ... e altri {len(new_patterns) - 3}")
            else:
                print_msg("✅", ".gitignore già aggiornato")
        except Exception as e:
            print_msg("⚠️", f"Errore aggiornamento .gitignore: {e}")

    def git_commit(self):
        if not self.config.do_git_commit:
            return
        self.setup_gitignore()
        token_path = self.config.base_dir / ".token"
        token = self.config.github_token
        if not token:
            token = get_github_token_from_file(token_path)
            if not token:
                print_msg("❌", "Token GitHub non trovato in .token, impossibile eseguire push.")
                return
            self.config.github_token = token
        try:
            result = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True)
            if not result.stdout.strip():
                print_msg("📝", "Nessuna modifica da committare")
                return
            subprocess.run(['git', 'add', '-u'], check=True)
            commit_msg = input("💬 Messaggio commit (Enter per default): ").strip()
            if not commit_msg:
                mode = "parallela" if self.config.parallel_enabled else "sequenziale"
                commit_msg = f"Aggiornamento LaTeX ({mode}) - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
            subprocess.run(['git', 'commit', '-m', commit_msg], check=True)
            url_result = subprocess.run(['git', 'remote', 'get-url', 'origin'], capture_output=True, text=True)
            old_url = url_result.stdout.strip()
            if old_url.startswith("https://"):
                protocol_sep = "https://"
                rest = old_url[len(protocol_sep):]
                token_url = f"https://{token}@{rest}"
                seturl_result = subprocess.run(['git', 'remote', 'set-url', 'origin', token_url])
                if seturl_result.returncode != 0:
                    print_msg("❌", "Non riesco a impostare la remote con il token.")
                    return
                subprocess.run(['git', 'push'], check=True)
                subprocess.run(['git', 'remote', 'set-url', 'origin', old_url])
            else:
                print_msg("❌", "Remote non HTTPS: il push autenticato con token non è supportato.")
                return
            print_msg("🚀", f"Git commit e push completati.")
        except subprocess.CalledProcessError as e:
            print_msg("❌", f"Errore comando Git: {e}")
        except Exception as e:
            print_msg("❌", f"Errore Git: {e}")

    def cleanup(self):
        patterns = ["*-nocopertina.tex", "*-noimage.tex"]
        cleaned_files = []
        for pattern in patterns:
            for f in self.config.base_dir.glob(pattern):
                try:
                    f.unlink(missing_ok=True)
                    cleaned_files.append(f.name)
                except Exception as e:
                    print_msg("⚠️", f"Errore rimozione {f.name}: {e}")
        if cleaned_files:
            print_msg("🧹", f"Rimossi file temporanei: {', '.join(cleaned_files)}")
        else:
            print_msg("🧹", "Pulizia completata")

    def compile_parallel(self, files):
        """Modalità parallela - multi-threading"""
        print_msg("🚀", f"=== COMPILAZIONE PARALLELA: {len(files)} file ===")

        results = {}
        num_workers = min(len(files), self.config.max_workers)

        print_msg("🔧", f"ThreadPoolExecutor: {num_workers} worker per {len(files)} file")

        if RICH_AVAILABLE:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
                TimeElapsedColumn(),
                console=console
            ) as progress:
                task = progress.add_task("Compilazione parallela...", total=len(files))

                with ThreadPoolExecutor(max_workers=num_workers) as executor:
                    future_to_file = {executor.submit(self.compile_single_file, f): f for f in files}
                    print_msg("📤", f"Sottomessi {len(future_to_file)} job paralleli")

                    for i, future in enumerate(as_completed(future_to_file), 1):
                        file_path = future_to_file[future]
                        print_msg("📥", f"[{i}/{len(files)}] Worker completato: {file_path.name}")

                        try:
                            success, duration, metadata = future.result()
                            results[file_path.name] = (success, duration, metadata)
                            self.performance.track_compilation(file_path.name, duration, success)

                            status_emoji = "✅" if success else "❌"
                            progress.update(
                                task,
                                advance=1,
                                description=f"Parallela: {status_emoji} {file_path.name}"
                            )
                        except Exception as e:
                            print_msg("💥", f"Errore worker {file_path.name}: {e}")
                            results[file_path.name] = (False, 0, {'error': str(e)})
                            progress.advance(task)
        else:
            with ThreadPoolExecutor(max_workers=num_workers) as executor:
                future_to_file = {executor.submit(self.compile_single_file, f): f for f in files}

                for i, future in enumerate(as_completed(future_to_file), 1):
                    file_path = future_to_file[future]
                    print_msg("📋", f"[{i}/{len(files)}] Worker completato: {file_path.name}")

                    try:
                        success, duration, metadata = future.result()
                        results[file_path.name] = (success, duration, metadata)
                        self.performance.track_compilation(file_path.name, duration, success)
                    except Exception as e:
                        print_msg("💥", f"Errore worker {file_path.name}: {e}")
                        results[file_path.name] = (False, 0, {'error': str(e)})

        return results

    def compile_sequential(self, files):
        """Modalità sequenziale - un file alla volta"""
        print_msg("🔄", f"=== COMPILAZIONE SEQUENZIALE: {len(files)} file ===")

        results = {}

        if RICH_AVAILABLE:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
                TimeElapsedColumn(),
                console=console
            ) as progress:
                task = progress.add_task("Compilazione sequenziale...", total=len(files))

                for i, file_path in enumerate(files, 1):
                    progress.update(task, description=f"Sequenziale: {file_path.name}...")
                    print_msg("🔨", f"[{i}/{len(files)}] SEQUENZIALE: {file_path.name}")

                    success, duration, metadata = self.compile_single_file(file_path)
                    results[file_path.name] = (success, duration, metadata)
                    self.performance.track_compilation(file_path.name, duration, success)

                    status_emoji = "✅" if success else "❌"
                    progress.update(
                        task,
                        advance=1,
                        description=f"Sequenziale: {status_emoji} {file_path.name}"
                    )
        else:
            for i, file_path in enumerate(files, 1):
                print_msg("📋", f"[{i}/{len(files)}] SEQUENZIALE: {file_path.name}")
                success, duration, metadata = self.compile_single_file(file_path)
                results[file_path.name] = (success, duration, metadata)
                self.performance.track_compilation(file_path.name, duration, success)

        return results

    # Tutti gli altri metodi identici al compilatore parallelo funzionante
    def create_noimage_version(self):
        src = self.config.base_dir / "OBSSv2.tex"
        dst = self.config.base_dir / "OBSSv2-noimage.tex"
        if not src.exists():
            print_msg("⚠️", f"{src.name} mancante — salto no-image")
            return None
        lines = src.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
        for i, ln in enumerate(lines):
            if ln.lstrip().startswith(r"\documentclass"):
                lines.insert(i + 1, r"\PassOptionsToPackage{draft}{graphicx}")
                break
        else:
            lines.insert(0, r"\PassOptionsToPackage{draft}{graphicx}")
        dst.write_text(''.join(lines), encoding='utf-8')
        print_msg("🖼️", f"Creato {dst.name} in modalità draft")
        return dst

    def create_nocopertina_version(self):
        src = self.config.base_dir / "OBSSv2.tex"
        dst = self.config.base_dir / "OBSSv2-nocopertina.tex"
        if not src.exists():
            print_msg("⚠️", f"{src.name} mancante — salto nocopertina")
            return None
        lines = src.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
        new_lines = []
        found = False

        full_cover_line = r"\cleardoublepage \thispagestyle{empty} \tikz[remember picture,overlay] \node[opacity=1] at (current page.center){\includegraphics[width=21cm,height=\paperheight]{immagini/copertina2-ai.png}}; \begin{textblock*}{20cm}(2cm,8cm)\Huge {\textbf{Old Bell School System}}\medskip \end{textblock*} \begin{textblock*}{22cm}(3.5cm,9cm) \Large {\textbf{(\textbf{OBSS})}}\medskip \end{textblock*} \begin{textblock*}{13cm}(9cm,15cm) \Huge{\color{black} \Huge{Fantasy Adventure Game}} \end{textblock*} \newpage~\thispagestyle{empty} \newpage~\thispagestyle{empty} %input{copertina} %deve rimanere su riga 230"

        for ln in lines:
            if r"\input{copertina" in ln.replace(" ", "") or ln.strip() == full_cover_line.strip():
                found = True
                continue
            new_lines.append(ln)
        if not found:
            print_msg("⚠️", f"Copertina non trovata in {src.name}")
        dst.write_text(''.join(new_lines), encoding='utf-8')
        print_msg("📄", f"Creato {dst.name} senza copertina")
        return dst

    def check_dependencies(self):
        required = ['latexmk', 'xelatex', 'biber']
        missing = []
        for cmd in required:
            if not shutil.which(cmd):
                missing.append(cmd)
        if missing:
            print_msg("❌", f"Comandi mancanti: {', '.join(missing)}")
            return False
        print_msg("✅", "Dipendenze verificate")
        return True

    def get_aux_dir(self, filename):
        if filename == "OBSSv2.tex":
            return self.aux_dir / "italian"
        elif filename == "OBSSv2-eng.tex":
            return self.aux_dir / "english"
        elif filename == "OBSSv2-noimage.tex":
            return self.aux_dir_noimage
        elif filename == "OBSSv2-nocopertina.tex":
            return self.aux_dir_nocopertina
        else:
            return self.aux_dir

    def needs_compilation(self, tex_file):
        pdf_file = tex_file.with_suffix('.pdf')
        if not pdf_file.exists():
            print_msg("📄", f"{pdf_file.name} non esiste - compilazione necessaria")
            return True
        try:
            tex_mtime = tex_file.stat().st_mtime
            pdf_mtime = pdf_file.stat().st_mtime
            if tex_mtime > pdf_mtime:
                print_msg("🔄", f"{tex_file.name} più recente - compilazione necessaria")
                return True
            if tex_file.name == "OBSSv2-eng.tex":
                bib_file = tex_file.parent / "bibliography.tex"
            else:
                bib_file = tex_file.parent / "bibliografia.tex"
            if bib_file.exists() and bib_file.stat().st_mtime > pdf_mtime:
                print_msg("🔄", f"Bibliografia più recente - compilazione necessaria")
                return True
            converter = tex_file.parent / "latex_to_bib_converter.py"
            if converter.exists() and converter.stat().st_mtime > pdf_mtime:
                print_msg("🔄", f"Convertitore più recente - compilazione necessaria")
                return True
            print_msg("✅", f"{pdf_file.name} aggiornato - skip")
            return False
        except Exception as e:
            print_msg("⚠️", f"Errore verifica timestamp {tex_file.name}: {e}")
            return True

    def create_latexmk_config(self, aux_dir):
        config_content = f'''$pdf_mode = 4;
$xelatex = 'xelatex -synctex=1 -interaction=nonstopmode -halt-on-error -file-line-error %O %S';
$biber = 'biber %O %S';
$max_repeat = 6;
$aux_dir = '{aux_dir}';
$out_dir = '.';
$bibtex_use = 2;
'''
        config_file = aux_dir / "latexmkrc"
        config_file.write_text(config_content)
        return config_file

    def generate_bib(self, tex_file):
        if tex_file.name == "OBSSv2-eng.tex":
            bib_source = tex_file.parent / "bibliography.tex"
            bib_target = tex_file.parent / "bibliography.bib"
        else:
            bib_source = tex_file.parent / "bibliografia.tex"
            bib_target = tex_file.parent / "bibliografia.bib"
        if not bib_source.exists():
            return False
        converter = tex_file.parent / "latex_to_bib_converter.py"
        if not converter.exists():
            return False
        try:
            env = os.environ.copy()
            env.update({
                'PYTHONIOENCODING': 'utf-8:replace',
                'LANG': 'C.UTF-8',
                'LC_ALL': 'C.UTF-8'
            })
            result = subprocess.run(
                [sys.executable, str(converter), str(bib_source)],
                capture_output=True,
                timeout=30,
                env=env
            )
            return result.returncode == 0
        except Exception:
            return False

    def compile_single_file(self, tex_file):
        start_time = time.time()
        aux_dir = self.get_aux_dir(tex_file.name)
        aux_dir.mkdir(parents=True, exist_ok=True)

        # Mostra PID solo in modalità debug
        pid_info = f"[PID:{os.getpid()}] " if self.config.debug_mode else ""
        print_msg("🔨", f"{pid_info}Compilazione {tex_file.name}")

        self.generate_bib(tex_file)
        config_file = self.create_latexmk_config(aux_dir)

        try:
            env = os.environ.copy()
            env.update({
                'TEXMFCACHE': str(aux_dir / 'texmf'),
                'BIBER_CACHE': str(aux_dir / 'biber'),
                'LANG': 'C.UTF-8',
                'LC_ALL': 'C.UTF-8',
                'PYTHONIOENCODING': 'utf-8:replace'
            })

            cmd = [
                'latexmk',
                '-r', str(config_file),
                '-pdf', '-xelatex',
                '-interaction=nonstopmode',
                str(tex_file)
            ]

            if self.config.debug_mode:
                print_msg("🔧", f"{pid_info}Comando: {' '.join(cmd[:4])}")

            result = subprocess.run(
                cmd,
                cwd=tex_file.parent,
                capture_output=True,
                timeout=self.config.timeout,
                env=env
            )

            duration = time.time() - start_time
            pdf_file = tex_file.with_suffix('.pdf')

            try:
                stdout_text = result.stdout.decode('utf-8', errors='replace')
                stderr_text = result.stderr.decode('utf-8', errors='replace')
            except:
                stdout_text = str(result.stdout)
                stderr_text = str(result.stderr)

            if result.returncode == 0 and pdf_file.exists():
                size_mb = pdf_file.stat().st_size / (1024 * 1024)
                print_msg("✅", f"{pid_info}{tex_file.name} compilato in {duration:.2f}s ({size_mb:.1f}MB)")
                return True, duration, {'size_mb': size_mb, 'pid': os.getpid()}
            else:
                print_msg("❌", f"{pid_info}Compilazione {tex_file.name} fallita dopo {duration:.2f}s (exit code: {result.returncode})")

                if self.config.debug_mode:
                    # Debug output dettagliato solo se richiesto
                    if stdout_text.strip():
                        stdout_lines = stdout_text.strip().split('\n')[-10:]
                        for line in stdout_lines:
                            if line.strip() and ('error' in line.lower() or 'fatal' in line.lower()):
                                print_msg("📋", f"Output: {line.strip()[:100]}")
                    if stderr_text.strip():
                        stderr_lines = stderr_text.strip().split('\n')[-5:]
                        for line in stderr_lines:
                            if line.strip():
                                print_msg("📋", f"Errore: {line.strip()[:100]}")

                return False, duration, {'error': stderr_text[:500], 'exit_code': result.returncode, 'pid': os.getpid()}

        except subprocess.TimeoutExpired:
            duration = time.time() - start_time
            print_msg("⏰", f"{pid_info}Timeout {tex_file.name} dopo {duration:.2f}s")
            return False, duration, {'error': 'Timeout', 'pid': os.getpid()}
        except Exception as e:
            duration = time.time() - start_time
            print_msg("💥", f"{pid_info}Errore {tex_file.name}: {e}")
            return False, duration, {'error': str(e), 'pid': os.getpid()}

def main():
    print("🎯 COMPILATORE LATEX UNIFICATO")
    print("=" * 40)
    print("🚀 PARALLELO + 🔄 SEQUENZIALE")
    print("=" * 40)

    parser = argparse.ArgumentParser(description="Compilatore LaTeX Unificato - Parallelo e Sequenziale")

    # Modalità principale
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--parallel", action="store_true",
                            help="Forza modalità parallela (default se >1 file)")
    mode_group.add_argument("--sequential", action="store_true",
                            help="Forza modalità sequenziale")

    # Opzioni di compilazione
    parser.add_argument("--ultra", action="store_true",
                        help="Modalità ultra-veloce (tutti i file senza domande)")
    parser.add_argument("--no-git", action="store_true",
                        help="Salta operazioni Git")
    parser.add_argument("--timeout", type=int, default=300,
                        help="Timeout compilazione (secondi)")
    parser.add_argument("--max-workers", type=int, default=4,
                        help="Numero massimo worker paralleli")

    # Debug e output
    parser.add_argument("--debug", action="store_true",
                        help="Modalità debug (mostra PID, comandi dettagliati)")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Output verboso")
    parser.add_argument("--fast", action="store_true",
                        help="Modalità veloce (skip alcune verifiche)")

    args = parser.parse_args()

    # Crea configurazione
    config = UnifiedConfig()

    # Applica modalità
    if args.sequential:
        config.parallel_enabled = False
        print_msg("🔧", "Modalità SEQUENZIALE forzata da argomenti")
    elif args.parallel:
        config.parallel_enabled = True
        print_msg("🔧", "Modalità PARALLELA forzata da argomenti")
    else:
        # Default: parallelo se disponibile
        config.parallel_enabled = True
        print_msg("🔧", "Modalità AUTO (parallela se >1 file, sequenziale se 1 file)")

    # Applica altre opzioni
    if args.no_git:
        config.do_git_commit = False
        print_msg("🔧", "Git disabilitato da argomenti")

    if args.timeout:
        config.timeout = args.timeout
        print_msg("🔧", f"Timeout impostato: {config.timeout}s")

    if args.max_workers:
        config.max_workers = args.max_workers
        print_msg("🔧", f"Max worker: {config.max_workers}")

    if args.debug:
        config.debug_mode = True
        print_msg("🔧", "Modalità debug attivata")

    if args.fast:
        config.fast_mode = True
        print_msg("🔧", "Modalità veloce attivata")

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
        print_msg("🔧", "Modalità verbosa attivata")

    # Ultra mode
    if args.ultra:
        config.do_git_commit = True
        config.compile_no_cover = True
        config.compile_no_images = True
        print_msg("⚡", "Modalità ULTRA attivata da argomenti")

    # Mostra configurazione finale
    mode_name = "PARALLELA" if config.parallel_enabled else "SEQUENZIALE"
    print_msg("⚙️", f"Configurazione finale:")
    print_msg("⚙️", f"  🎯 Modalità: {mode_name}")
    print_msg("⚙️", f"  👥 Max worker: {config.max_workers}")
    print_msg("⚙️", f"  ⏱️ Timeout: {config.timeout}s")
    print_msg("⚙️", f"  🔍 Debug: {config.debug_mode}")

    # Inizializza e esegui compilatore
    compiler = UnifiedLaTeXCompiler(config)
    result = compiler.run()

    if result == 0:
        print_msg("🎉", "Compilazione completata con successo!")
    else:
        print_msg("❌", f"Compilazione terminata con errori (exit code: {result})")

    return result

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except Exception as e:
        print_msg("💥", f"Errore fatale: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
