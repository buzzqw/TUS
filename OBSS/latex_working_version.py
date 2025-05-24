#!/usr/bin/env python3

"""
Compilatore LaTeX Ultra-Ottimizzato Python - Versione Funzionante
"""

import os
import sys
import time
import subprocess
import shutil
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import argparse
import logging

# Import opzionali
try:
    from rich.console import Console
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
    from rich.table import Table
    from rich.panel import Panel
    console = Console()
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

try:
    import git
    GIT_AVAILABLE = True
except ImportError:
    GIT_AVAILABLE = False

def print_msg(emoji, message):
    """Print con emoji e timestamp"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {emoji} {message}")

class SimpleConfig:
    """Configurazione semplificata"""
    def __init__(self):
        self.base_dir = Path.cwd()  # Directory corrente
        self.files = ["OBSSv2.tex", "OBSSv2-eng.tex"]
        self.parallel_enabled = True
        self.max_workers = 2
        self.timeout = 300
        self.do_git_commit = False
        print_msg("⚙️", f"Configurazione: {self.base_dir}")

class PerformanceTracker:
    """Tracker performance semplificato"""
    def __init__(self):
        self.start_time = time.time()
        self.operations = []
        self.compilation_times = {}
    
    def track_compilation(self, filename, duration, success=True):
        """Traccia compilazione"""
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
    
    def show_report(self):
        """Mostra report finale"""
        total_time = self.get_total_time()
        
        if RICH_AVAILABLE:
            table = Table(title="📊 Report Performance")
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
            
            # Panel finale
            panel_content = f"⏱️ Tempo totale: {total_time:.2f}s\n"
            panel_content += f"📄 File compilati: {len(self.compilation_times)}\n"
            
            if total_time < 30:
                panel_content += "🏆 Performance ECCELLENTE!"
                style = "green"
            elif total_time < 60:
                panel_content += "✅ Performance BUONA!"
                style = "yellow"
            else:
                panel_content += "⏱️ Performance accettabile"
                style = "red"
            
            panel = Panel(panel_content, title="📊 Riassunto", border_style=style)
            console.print(panel)
        else:
            print("\n" + "="*50)
            print("📊 REPORT PERFORMANCE")
            print("="*50)
            for filename, duration in self.compilation_times.items():
                print(f"📄 {filename}: {duration:.2f}s")
            if self.compilation_times:
                print(f"⏱️ Tempo totale: {total_time:.2f}s")
                print(f"📊 Tempo medio: {sum(self.compilation_times.values()) / len(self.compilation_times):.2f}s")

class LaTeXCompiler:
    """Compilatore LaTeX semplificato ma funzionale"""
    
    def __init__(self, config):
        self.config = config
        self.performance = PerformanceTracker()
        self.setup_dirs()
        print_msg("🚀", "Compilatore inizializzato")
    
    def setup_dirs(self):
        """Setup directory di lavoro"""
        self.temp_dir = self.config.base_dir / "temp"
        self.aux_dir = self.temp_dir / "compilation"
        
        # Crea directory
        dirs = [
            self.temp_dir,
            self.aux_dir,
            self.aux_dir / "italian",
            self.aux_dir / "english"
        ]
        
        for d in dirs:
            d.mkdir(parents=True, exist_ok=True)
        
        print_msg("📁", f"Directory temporanee: {self.temp_dir}")
    
    def check_dependencies(self):
        """Verifica dipendenze essenziali"""
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
        """Directory ausiliaria per file"""
        if filename == "OBSSv2.tex":
            return self.aux_dir / "italian"
        elif filename == "OBSSv2-eng.tex":
            return self.aux_dir / "english"
        else:
            return self.aux_dir
    
    def needs_compilation(self, tex_file):
        """Verifica se compilazione è necessaria"""
        pdf_file = tex_file.with_suffix('.pdf')
        
        if not pdf_file.exists():
            print_msg("📄", f"{pdf_file.name} non esiste - compilazione necessaria")
            return True
        
        # Controlla se tex è più recente del pdf
        if tex_file.stat().st_mtime > pdf_file.stat().st_mtime:
            print_msg("🔄", f"{tex_file.name} più recente - compilazione necessaria")
            return True
        
        print_msg("✅", f"{pdf_file.name} aggiornato - skip")
        return False
    
    def generate_bib(self, tex_file):
        """Genera file .bib se necessario"""
        if tex_file.name == "OBSSv2-eng.tex":
            bib_source = tex_file.parent / "bibliography.tex"
            bib_target = tex_file.parent / "bibliography.bib"
        else:
            bib_source = tex_file.parent / "bibliografia.tex"
            bib_target = tex_file.parent / "bibliografia.bib"
        
        if not bib_source.exists():
            print_msg("⚠️", f"Bibliografia {bib_source.name} non trovata")
            return False
        
        converter = tex_file.parent / "latex_to_bib_converter.py"
        if not converter.exists():
            print_msg("⚠️", "Convertitore bibliografia non trovato")
            return False
        
        try:
            result = subprocess.run(
                [sys.executable, str(converter), str(bib_source)],
                capture_output=True, text=True, timeout=30
            )
            
            if result.returncode == 0:
                print_msg("📚", f"Bibliografia {bib_target.name} generata")
                return True
            else:
                print_msg("⚠️", f"Errore generazione bibliografia: {result.stderr[:100]}")
                return False
        except Exception as e:
            print_msg("⚠️", f"Errore bibliografia: {e}")
            return False
    
    def create_latexmk_config(self, aux_dir):
        """Crea configurazione latexmk"""
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
    
    def compile_single_file(self, tex_file):
        """Compila un singolo file"""
        start_time = time.time()
        aux_dir = self.get_aux_dir(tex_file.name)
        aux_dir.mkdir(parents=True, exist_ok=True)
        
        print_msg("🔨", f"Compilazione {tex_file.name}")
        
        # Genera bibliografia
        self.generate_bib(tex_file)
        
        # Crea config latexmk
        config_file = self.create_latexmk_config(aux_dir)
        
        try:
            # Comando compilazione
            cmd = [
                'latexmk',
                '-r', str(config_file),
                '-pdf', '-xelatex',
                '-interaction=nonstopmode',
                str(tex_file)
            ]
            
            result = subprocess.run(
                cmd,
                cwd=tex_file.parent,
                capture_output=True,
                text=True,
                timeout=self.config.timeout
            )
            
            duration = time.time() - start_time
            pdf_file = tex_file.with_suffix('.pdf')
            
            if result.returncode == 0 and pdf_file.exists():
                size_mb = pdf_file.stat().st_size / (1024 * 1024)
                print_msg("✅", f"{tex_file.name} compilato in {duration:.2f}s ({size_mb:.1f}MB)")
                
                # Linearizza PDF se possibile
                if shutil.which('qpdf'):
                    self.linearize_pdf(pdf_file)
                
                return True, duration, {'size_mb': size_mb}
            else:
                print_msg("❌", f"Compilazione {tex_file.name} fallita")
                if result.stderr:
                    print_msg("📋", f"Errore: {result.stderr[-200:]}")
                return False, duration, {'error': result.stderr}
        
        except subprocess.TimeoutExpired:
            duration = time.time() - start_time
            print_msg("⏰", f"Timeout {tex_file.name} dopo {duration:.2f}s")
            return False, duration, {'error': 'Timeout'}
        except Exception as e:
            duration = time.time() - start_time
            print_msg("💥", f"Errore {tex_file.name}: {e}")
            return False, duration, {'error': str(e)}
    
    def linearize_pdf(self, pdf_file):
        """Linearizza PDF con qpdf"""
        temp_file = pdf_file.with_suffix('.pdf.temp')
        try:
            result = subprocess.run(
                ['qpdf', '--linearize', str(pdf_file), str(temp_file)],
                capture_output=True, timeout=60
            )
            if result.returncode == 0 and temp_file.exists():
                shutil.move(temp_file, pdf_file)
                print_msg("🔗", f"PDF {pdf_file.name} linearizzato")
        except:
            temp_file.unlink(missing_ok=True)
    
    def compile_parallel(self, files):
        """Compilazione parallela"""
        if not files:
            return {}
        
        results = {}
        
        if RICH_AVAILABLE and len(files) > 1:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                console=console
            ) as progress:
                task = progress.add_task("Compilazione...", total=len(files))
                
                with ThreadPoolExecutor(max_workers=self.config.max_workers) as executor:
                    future_to_file = {executor.submit(self.compile_single_file, f): f for f in files}
                    
                    for future in as_completed(future_to_file):
                        file_path = future_to_file[future]
                        try:
                            success, duration, metadata = future.result()
                            results[file_path.name] = (success, duration, metadata)
                            self.performance.track_compilation(file_path.name, duration, success)
                            progress.advance(task)
                        except Exception as e:
                            print_msg("💥", f"Errore future {file_path.name}: {e}")
                            results[file_path.name] = (False, 0, {'error': str(e)})
                            progress.advance(task)
        else:
            # Sequenziale o fallback
            for i, file_path in enumerate(files, 1):
                print_msg("📋", f"[{i}/{len(files)}] {file_path.name}")
                success, duration, metadata = self.compile_single_file(file_path)
                results[file_path.name] = (success, duration, metadata)
                self.performance.track_compilation(file_path.name, duration, success)
        
        return results
    
    def show_pdfs(self):
        """Mostra PDF generati"""
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
    
    def git_commit(self):
        """Commit Git semplificato"""
        if not self.config.do_git_commit:
            return
        
        try:
            # Verifica se ci sono modifiche
            result = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True)
            
            if not result.stdout.strip():
                print_msg("📝", "Nessuna modifica da committare")
                return
            
            # Richiedi messaggio
            commit_msg = input("💬 Messaggio commit (Enter per default): ").strip()
            if not commit_msg:
                commit_msg = f"Aggiornamento LaTeX Python - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
            
            # Commit
            subprocess.run(['git', 'add', '.'], check=True)
            subprocess.run(['git', 'commit', '-m', commit_msg], check=True)
            subprocess.run(['git', 'push'], check=True)
            
            print_msg("🚀", f"Git commit completato: {commit_msg[:50]}")
        
        except Exception as e:
            print_msg("❌", f"Errore Git: {e}")
    
    def cleanup(self):
        """Pulizia file temporanei"""
        # Rimuovi file temp versioni alternative
        patterns = ["*-nocopertina.tex", "*-noimage.tex"]
        for pattern in patterns:
            for f in self.config.base_dir.glob(pattern):
                f.unlink(missing_ok=True)
        
        print_msg("🧹", "Pulizia completata")
    
    def run(self):
        """Esecuzione principale"""
        print_msg("🚀", "=== INIZIO COMPILAZIONE ===")
        
        try:
            # Verifica dipendenze
            if not self.check_dependencies():
                return 1
            
            # Opzioni utente
            response = input("\n🚀 Compilazione ULTRA-VELOCE? [Y/n]: ").strip().lower()
            if response not in ['n', 'no']:
                self.config.do_git_commit = True
                print_msg("⚙️", "Modalità ULTRA-VELOCE attivata")
            
            # Trova file da compilare
            files_to_compile = []
            for filename in self.config.files:
                file_path = self.config.base_dir / filename
                if not file_path.exists():
                    print_msg("⚠️", f"File {filename} non trovato")
                    continue
                
                if self.needs_compilation(file_path):
                    files_to_compile.append(file_path)
            
            print_msg("📋", f"Piano: {len(files_to_compile)} file da compilare")
            
            # Compilazione
            if files_to_compile:
                if self.config.parallel_enabled and len(files_to_compile) > 1:
                    print_msg("🚀", f"Compilazione parallela ({self.config.max_workers} worker)")
                else:
                    print_msg("🔄", "Compilazione sequenziale")
                
                results = self.compile_parallel(files_to_compile)
                
                # Verifica risultati
                failed = sum(1 for success, _, _ in results.values() if not success)
                if failed > 0:
                    print_msg("⚠️", f"{failed} compilazioni fallite")
            
            # Post-processing
            self.show_pdfs()
            self.cleanup()
            
            # Report performance
            self.performance.show_report()
            
            # Git
            self.git_commit()
            
            print_msg("🎉", "=== COMPILAZIONE COMPLETATA ===")
            return 0
        
        except KeyboardInterrupt:
            print_msg("🛑", "Operazione interrotta")
            return 1
        except Exception as e:
            print_msg("💥", f"Errore critico: {e}")
            import traceback
            traceback.print_exc()
            return 1

def main():
    print("🎯 COMPILATORE LATEX PYTHON")
    print("="*40)
    
    parser = argparse.ArgumentParser(description="Compilatore LaTeX Python")
    parser.add_argument("--parallel", action="store_true", help="Forza parallela")
    parser.add_argument("--sequential", action="store_true", help="Forza sequenziale")
    parser.add_argument("--no-git", action="store_true", help="Salta Git")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose")
    
    args = parser.parse_args()
    
    # Configurazione
    config = SimpleConfig()
    
    if args.parallel:
        config.parallel_enabled = True
    if args.sequential:
        config.parallel_enabled = False
    if args.no_git:
        config.do_git_commit = False
    
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    
    # Esecuzione
    compiler = LaTeXCompiler(config)
    return compiler.run()

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except Exception as e:
        print(f"💥 Errore fatale: {e}")
        sys.exit(1)
