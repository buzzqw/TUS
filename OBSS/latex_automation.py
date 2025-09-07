#!/usr/bin/env python3
"""
LaTeX Document Automation Tool - Complete Rewrite
Replaces ddn.sh with better architecture, using only Python standard library.
"""

import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Set

# Configuration Management
@dataclass
class Config:
    """Centralized configuration"""
    
    # Files
    latex_files: List[str] = field(default_factory=lambda: ["OBSSv2.tex", "OBSSv2-eng.tex"])
    sections_dir: str = "sezioni"
    assets_dir: str = "per versione"
    temp_dir: str = "/dev/shm/temp"
    target_dir: str = "~/TUS/OBSS"
    
    # GitHub
    github_owner: str = "buzzqw"
    github_repo: str = "TUS"
    github_token_file: str = ".token"
    
    # Processing
    parallel_jobs: int = 4
    pdf_optimize: bool = True
    auto_commit: bool = True
    
    # Assets
    required_assets: List[str] = field(default_factory=lambda: [
        "OBSSv2.pdf", "OBSSv2-eng.pdf", "OBSS-Iniziativa.pdf",
        "OBSSv2-scheda.pdf", "OBSSv2-scheda-v3.pdf",
        "OBSS-schema-narratore-personaggi.pdf",
        "OBSS-utilita.pdf", "screenv2.pdf", "screenv2-eng.pdf",
        "OBSSv2-scheda-eng.pdf", "OBSS-options.pdf", "OBSS-utility.pdf",
        "OBSS-schema-arbiter-character-eng.pdf",
        "combat-quick-ita.pdf", "combat-quick-eng.pdf",
        "magia-quick-eng.pdf", "magia-quick-ita.pdf"
    ])

# Task System
class TaskStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"

@dataclass
class TaskResult:
    success: bool
    message: str
    data: Optional[Dict] = None
    duration: float = 0.0

class Logger:
    """Simple colored logger using only standard library"""
    
    COLORS = {
        'RED': '\033[1;31m',
        'GREEN': '\033[1;32m',
        'YELLOW': '\033[1;33m',
        'BLUE': '\033[1;36m',
        'MAGENTA': '\033[1;35m',
        'NC': '\033[0m'
    }
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
    
    def _log(self, level: str, color: str, symbol: str, message: str):
        timestamp = time.strftime('%H:%M:%S')
        if sys.stdout.isatty():  # Only use colors if terminal supports it
            print(f"{self.COLORS[color]}[{timestamp}] {symbol} {message}{self.COLORS['NC']}")
        else:
            print(f"[{timestamp}] [{level}] {message}")
    
    def info(self, message: str):
        self._log("INFO", "BLUE", "ℹ️", message)
    
    def success(self, message: str):
        self._log("SUCCESS", "GREEN", "✅", message)
    
    def warning(self, message: str):
        self._log("WARNING", "YELLOW", "⚠️", message)
    
    def error(self, message: str):
        self._log("ERROR", "RED", "❌", message)
    
    def step(self, message: str):
        self._log("STEP", "MAGENTA", "📋", message)
    
    def debug(self, message: str):
        if self.verbose:
            self._log("DEBUG", "NC", "🔍", message)

class ExecutionContext:
    """Shared context for all tasks"""
    
    def __init__(self, config: Config, logger: Logger, dry_run: bool = False):
        self.config = config
        self.logger = logger
        self.dry_run = dry_run
        self.github_token: Optional[str] = None
        self.temp_files: Set[Path] = set()
    
    def add_temp_file(self, path: Path):
        """Register a temporary file for cleanup"""
        self.temp_files.add(path)
    
    def cleanup(self):
        """Clean up temporary files"""
        for temp_file in self.temp_files:
            try:
                if temp_file.is_file():
                    temp_file.unlink()
                elif temp_file.is_dir():
                    shutil.rmtree(temp_file)
            except Exception as e:
                self.logger.warning(f"Failed to cleanup {temp_file}: {e}")

class Task:
    """Base class for all automation tasks"""
    
    def __init__(self, name: str, dependencies: Optional[List[str]] = None):
        self.name = name
        self.dependencies = dependencies or []
        self.status = TaskStatus.PENDING
        self.result: Optional[TaskResult] = None
        self.start_time: Optional[float] = None
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        """Execute the task - override in subclasses"""
        raise NotImplementedError
    
    def run(self, context: ExecutionContext) -> TaskResult:
        """Run task with timing and error handling"""
        self.start_time = time.time()
        self.status = TaskStatus.RUNNING
        
        try:
            context.logger.info(f"Starting task: {self.name}")
            
            if context.dry_run:
                self.result = TaskResult(True, f"[DRY RUN] Would execute {self.name}")
            else:
                self.result = self.execute(context)
            
            self.result.duration = time.time() - self.start_time
            
            if self.result.success:
                self.status = TaskStatus.COMPLETED
                context.logger.success(f"{self.name}: {self.result.message}")
            else:
                self.status = TaskStatus.FAILED
                context.logger.error(f"{self.name}: {self.result.message}")
                
        except Exception as e:
            self.result = TaskResult(False, str(e))
            self.result.duration = time.time() - self.start_time
            self.status = TaskStatus.FAILED
            context.logger.error(f"{self.name} failed with exception: {e}")
        
        return self.result

# Task Implementations
class CheckDependenciesTask(Task):
    """Verify all required commands are available"""
    
    REQUIRED_COMMANDS = [
        "latexmk", "git", "qpdf", "python3", "curl"
    ]
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        missing = []
        for cmd in self.REQUIRED_COMMANDS:
            if not shutil.which(cmd):
                missing.append(cmd)
        
        if missing:
            return TaskResult(False, f"Missing commands: {', '.join(missing)}")
        
        return TaskResult(True, "All dependencies available")

class LoadGitHubTokenTask(Task):
    """Load GitHub token from file"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        token_file = Path(context.config.github_token_file)
        
        if not token_file.exists():
            return TaskResult(False, f"Token file {token_file} not found")
        
        try:
            content = token_file.read_text().strip()
            for line in content.splitlines():
                if line.startswith("githubtoken="):
                    context.github_token = line.split("=", 1)[1]
                    return TaskResult(True, "GitHub token loaded")
            
            return TaskResult(False, "No valid token found in file")
            
        except Exception as e:
            return TaskResult(False, f"Failed to read token: {e}")

class VerifyLatexFilesTask(Task):
    """Verify LaTeX files exist"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        missing = []
        for latex_file in context.config.latex_files:
            if not Path(latex_file).exists():
                missing.append(latex_file)
        
        if missing:
            return TaskResult(False, f"Missing LaTeX files: {', '.join(missing)}")
        
        return TaskResult(True, f"Verified {len(context.config.latex_files)} LaTeX files")

class ExtractSectionsTask(Task):
    """Extract sections from LaTeX document"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            sections_dir = Path(context.config.sections_dir)
            sections_dir.mkdir(exist_ok=True)
            
            # Clean existing files
            for file in sections_dir.glob("*.tex"):
                file.unlink()
            
            main_file = Path(context.config.latex_files[0])
            if not main_file.exists():
                return TaskResult(False, f"Main LaTeX file {main_file} not found")
            
            content = main_file.read_text()
            lines = content.splitlines()
            
            # Find \begin{document}
            doc_start = None
            for i, line in enumerate(lines):
                if "\\begin{document}" in line:
                    doc_start = i
                    break
            
            if doc_start is None:
                return TaskResult(False, "Could not find \\begin{document}")
            
            # Extract preamble
            preamble = "\n".join(lines[:doc_start + 1])
            (sections_dir / "00_preambolo.tex").write_text(preamble)
            
            # Find sections
            sections = []
            for i, line in enumerate(lines[doc_start:], doc_start):
                if "\\section{" in line and "}" in line:
                    try:
                        title_start = line.find("\\section{") + 9
                        title_end = line.find("}", title_start)
                        if title_end > title_start:
                            title = line[title_start:title_end]
                            sections.append((i, self._sanitize_filename(title)))
                    except:
                        continue
            
            # Extract sections
            for idx, (line_num, title) in enumerate(sections):
                start = line_num
                end = sections[idx + 1][0] if idx + 1 < len(sections) else len(lines)
                
                section_content = "\n".join(lines[start:end])
                filename = f"{idx + 2:02d}_{title}.tex"
                (sections_dir / filename).write_text(section_content)
            
            return TaskResult(True, f"Extracted {len(sections)} sections")
            
        except Exception as e:
            return TaskResult(False, f"Section extraction failed: {e}")
    
    def _sanitize_filename(self, name: str) -> str:
        """Sanitize filename"""
        import re
        return re.sub(r'[^\w\-_.]', '_', name)

class CreateVariantsTask(Task):
    """Create document variants"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            main_file = Path(context.config.latex_files[0])
            if not main_file.exists():
                return TaskResult(False, f"Main file {main_file} not found")
            
            content = main_file.read_text()
            
            # No-image variant
            noimage_content = content.replace(
                "\\documentclass[", "\\documentclass[draft,"
            )
            Path("OBSSv2-noimage.tex").write_text(noimage_content)
            
            # No-cover variant
            nocover_lines = [
                line for line in content.splitlines()
                if "Fantasy Adventure Game" not in line
            ]
            Path("OBSSv2-nocopertina.tex").write_text("\n".join(nocover_lines))
            
            return TaskResult(True, "Created document variants")
            
        except Exception as e:
            return TaskResult(False, f"Failed to create variants: {e}")

class CompileLatexTask(Task):
    """Compile LaTeX documents in parallel with progress tracking"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            temp_dir = Path(context.config.temp_dir)
            temp_dir.mkdir(exist_ok=True, parents=True)
            
            # Documents to compile
            documents = [
                *context.config.latex_files,
                "OBSSv2-noimage.tex",
                "OBSSv2-nocopertina.tex"
            ]
            
            # Filter existing documents
            existing_docs = [doc for doc in documents if Path(doc).exists()]
            
            if not existing_docs:
                return TaskResult(False, "No LaTeX documents found to compile")
            
            context.logger.info(f"Starting parallel compilation of {len(existing_docs)} documents (max {context.config.parallel_jobs} concurrent)")
            
            # Compile in parallel with progress tracking
            compilation_results = []
            with ThreadPoolExecutor(max_workers=context.config.parallel_jobs) as executor:
                # Submit all jobs
                future_to_doc = {
                    executor.submit(self._compile_single, doc, temp_dir, context.logger): doc
                    for doc in existing_docs
                }
                
                # Process results as they complete
                for future in as_completed(future_to_doc):
                    doc = future_to_doc[future]
                    try:
                        success, message = future.result()
                        compilation_results.append((success, message))
                        
                        if success:
                            context.logger.success(f"Compiled: {doc}")
                        else:
                            context.logger.error(f"Failed: {doc} - {message}")
                            
                    except Exception as e:
                        compilation_results.append((False, f"Exception compiling {doc}: {e}"))
                        context.logger.error(f"Exception compiling {doc}: {e}")
            
            successful = sum(1 for success, _ in compilation_results if success)
            total = len(compilation_results)
            
            if successful == 0:
                return TaskResult(False, "All compilations failed")
            elif successful < total:
                failed_docs = [
                    existing_docs[i] for i, (success, _) in enumerate(compilation_results) 
                    if not success
                ]
                return TaskResult(True, f"Compiled {successful}/{total} documents (failed: {', '.join(failed_docs)})")
            else:
                return TaskResult(True, f"Successfully compiled all {total} documents in parallel")
                
        except Exception as e:
            return TaskResult(False, f"Compilation failed: {e}")
    
    def _compile_single(self, tex_file: str, temp_dir: Path, logger: Logger) -> tuple[bool, str]:
        """Compile a single LaTeX file with optimized latexmk settings"""
        try:
            basename = Path(tex_file).stem
            build_dir = temp_dir / f"build-{basename}"
            build_dir.mkdir(exist_ok=True)
            
            logger.debug(f"Starting compilation: {tex_file} -> {build_dir}")
            
            # Optimized latexmk command for parallel execution
            result = subprocess.run([
                "latexmk", 
                "-xelatex",                    # Use XeLaTeX
                "-synctex=1",                  # Enable SyncTeX
                "-interaction=nonstopmode",    # Don't stop on errors
                "-file-line-error",            # Better error reporting
                "-halt-on-error",              # Stop on first error
                f"-auxdir={build_dir}",        # Auxiliary files directory
                f"-outdir=.",                  # Output to current directory
                "-f",                          # Force compilation
                tex_file
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                return True, f"Successfully compiled {tex_file}"
            else:
                # Extract meaningful error info
                error_lines = result.stderr.split('\n')
                relevant_errors = [line for line in error_lines if 'Error:' in line or 'Fatal:' in line]
                error_summary = '; '.join(relevant_errors[:3]) if relevant_errors else result.stderr[:200]
                return False, f"Compilation failed: {error_summary}"
                
        except subprocess.TimeoutExpired:
            return False, f"Compilation timeout after 300s"
        except Exception as e:
            return False, f"Compilation error: {str(e)}"

class OptimizePdfsTask(Task):
    """Optimize PDF files using qpdf"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        if not context.config.pdf_optimize:
            return TaskResult(True, "PDF optimization disabled")
        
        try:
            pdf_files = list(Path(".").glob("*.pdf"))
            if not pdf_files:
                return TaskResult(True, "No PDF files to optimize")
            
            optimized = 0
            with ThreadPoolExecutor(max_workers=context.config.parallel_jobs) as executor:
                futures = [
                    executor.submit(self._optimize_single, pdf_file, context.logger)
                    for pdf_file in pdf_files
                ]
                
                for future in futures:
                    if future.result():
                        optimized += 1
            
            return TaskResult(True, f"Optimized {optimized}/{len(pdf_files)} PDFs")
            
        except Exception as e:
            return TaskResult(False, f"PDF optimization failed: {e}")
    
    def _optimize_single(self, pdf_file: Path, logger: Logger) -> bool:
        """Optimize a single PDF file"""
        try:
            temp_file = pdf_file.with_suffix(".temp.pdf")
            
            logger.debug(f"Optimizing {pdf_file}")
            
            result = subprocess.run([
                "qpdf", "--linearize", str(pdf_file), str(temp_file)
            ], capture_output=True, timeout=60)
            
            if result.returncode == 0:
                temp_file.replace(pdf_file)
                return True
            
            return False
            
        except Exception:
            return False

class ConvertMarkdownTask(Task):
    """Convert LaTeX to Markdown using Java converter"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            # Check if Java converter is available
            if not Path("Latex2MarkDown.java").exists():
                return TaskResult(True, "Java converter not available - skipping")
            
            if not Path("latex2markdown.sh").exists():
                return TaskResult(True, "Markdown script not available - skipping")
            
            # Compile Java converter if needed
            if not Path("Latex2MarkDown.class").exists():
                compile_result = subprocess.run([
                    "javac", "Latex2MarkDown.java"
                ], capture_output=True, text=True)
                
                if compile_result.returncode != 0:
                    return TaskResult(False, f"Failed to compile Java converter: {compile_result.stderr}")
            
            # Convert files
            converted = 0
            for latex_file in context.config.latex_files:
                if Path(latex_file).exists():
                    context.logger.debug(f"Converting {latex_file} to Markdown")
                    
                    result = subprocess.run([
                        "sh", "latex2markdown.sh", latex_file
                    ], capture_output=True, text=True, timeout=120)
                    
                    if result.returncode == 0:
                        converted += 1
                        markdown_file = latex_file.replace('.tex', '.md')
                        context.logger.success(f"Generated {markdown_file}")
                    else:
                        context.logger.warning(f"Failed to convert {latex_file}")
            
            if converted == 0:
                return TaskResult(True, "No files converted (converter not working)")
            
            return TaskResult(True, f"Converted {converted} files to Markdown")
            
        except Exception as e:
            return TaskResult(False, f"Markdown conversion failed: {e}")

class PrepareAssetsTask(Task):
    """Prepare assets for release"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            assets_dir = Path(context.config.assets_dir)
            
            # Create assets directory
            if assets_dir.exists():
                # Clean existing PDFs
                for pdf in assets_dir.glob("*.pdf"):
                    pdf.unlink()
            else:
                assets_dir.mkdir(exist_ok=True)
            
            # Copy assets
            copied = 0
            for asset in context.config.required_assets:
                asset_path = Path(asset)
                if asset_path.exists():
                    try:
                        shutil.copy2(asset_path, assets_dir)
                        copied += 1
                    except Exception as e:
                        context.logger.debug(f"Failed to copy {asset}: {e}")
            
            return TaskResult(True, f"Prepared {copied} assets")
            
        except Exception as e:
            return TaskResult(False, f"Asset preparation failed: {e}")

class UpdateWikiTask(Task):
    """Update wiki with interactive options"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            wiki_script = Path("obsv2_wiki_script.js")
            markdown_script = Path("latex2markdown.sh")
            
            if not wiki_script.exists() or not markdown_script.exists():
                return TaskResult(True, "Wiki scripts not available - skipping")
            
            if not shutil.which("node"):
                return TaskResult(True, "Node.js not available - skipping wiki update")
            
            # Interactive prompt for wiki action
            print("\nOpzioni wiki disponibili:")
            print("  c - Clean COMPLETO (cancella tutto storico + rebuild)")
            print("  r - Reset wiki (mantiene storico, cancella contenuto)")
            print("  s - Aggiornamento normale")
            print("  N - Salta (default)")
            
            try:
                choice = input("Aggiornare la wiki [Clean/Reset/Si/No] (c/r/s/N): ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                choice = 'n'
            
            if choice in ['c', 'clean']:
                return self._perform_wiki_clean(context, wiki_script, markdown_script)
            elif choice in ['r', 'reset']:
                return self._perform_wiki_reset(context, wiki_script, markdown_script)
            elif choice in ['s', 'si', 'sì']:
                return self._perform_wiki_update(context, wiki_script, markdown_script)
            else:
                return TaskResult(True, "Wiki update skipped by user")
                
        except Exception as e:
            return TaskResult(False, f"Wiki update failed: {e}")
    
    def _perform_wiki_clean(self, context: ExecutionContext, wiki_script: Path, markdown_script: Path) -> TaskResult:
        try:
            print("\nATTENZIONE: Clean completo cancellerà TUTTO lo storico wiki!")
            confirm = input("Sei sicuro? Questa operazione è IRREVERSIBILE [si/No] (s/N): ").strip().lower()
            
            if confirm not in ['s', 'si', 'sì', 'y', 'yes']:
                return TaskResult(True, "Clean completo annullato dall'utente")
            
            context.logger.info("Avvio clean completo wiki...")
            
            # Try clean with Node.js script
            clean_result = subprocess.run([
                "node", str(wiki_script), "--clean", "--force", "--purge-history"
            ], capture_output=True, text=True)
            
            if clean_result.returncode != 0:
                context.logger.warning("Errore durante clean - procedo con metodo alternativo")
                self._nuclear_wiki_clean(context)
            
            # Rebuild wiki
            context.logger.info("Ricostruzione wiki da zero...")
            
            # Run markdown conversion
            subprocess.run(["sh", str(markdown_script)], capture_output=True)
            
            # Rebuild with Node.js
            rebuild_result = subprocess.run([
                "node", str(wiki_script), "--rebuild"
            ], capture_output=True, text=True)
            
            if rebuild_result.returncode == 0:
                return TaskResult(True, "Wiki clean completo completato")
            else:
                return TaskResult(False, "Errore durante ricostruzione wiki")
                
        except Exception as e:
            return TaskResult(False, f"Wiki clean failed: {e}")
    
    def _perform_wiki_reset(self, context: ExecutionContext, wiki_script: Path, markdown_script: Path) -> TaskResult:
        try:
            # Reset wiki
            reset_result = subprocess.run([
                "node", str(wiki_script), "--reset"
            ], capture_output=True, text=True)
            
            if reset_result.returncode != 0:
                return TaskResult(False, "Wiki reset failed")
            
            # Regenerate markdown and update
            subprocess.run(["sh", str(markdown_script)], capture_output=True)
            
            update_result = subprocess.run([
                "node", str(wiki_script)
            ], capture_output=True, text=True)
            
            if update_result.returncode == 0:
                return TaskResult(True, "Wiki resettata e ricostruita")
            else:
                return TaskResult(False, "Errore durante aggiornamento wiki")
                
        except Exception as e:
            return TaskResult(False, f"Wiki reset failed: {e}")
    
    def _perform_wiki_update(self, context: ExecutionContext, wiki_script: Path, markdown_script: Path) -> TaskResult:
        try:
            # Normal wiki update
            markdown_result = subprocess.run(["sh", str(markdown_script)], capture_output=True)
            
            if markdown_result.returncode == 0:
                update_result = subprocess.run([
                    "node", str(wiki_script)
                ], capture_output=True, text=True)
                
                if update_result.returncode == 0:
                    return TaskResult(True, "Wiki aggiornata")
                else:
                    return TaskResult(False, "Errore aggiornamento wiki")
            else:
                return TaskResult(False, "Errore conversione markdown")
                
        except Exception as e:
            return TaskResult(False, f"Wiki update failed: {e}")
    
    def _nuclear_wiki_clean(self, context: ExecutionContext):
        """Nuclear option: remove wiki directories"""
        wiki_dirs = ["wiki/", "docs/", "_wiki/", ".wiki/", "site/", "_site/", "public/", "_public/"]
        
        for wiki_dir in wiki_dirs:
            wiki_path = Path(wiki_dir)
            if wiki_path.exists():
                context.logger.info(f"Rimozione directory: {wiki_dir}")
                shutil.rmtree(wiki_path)

class UpdatePagesTask(Task):
    """Update GitHub Pages"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            pages_script = Path("pages.py")
            
            if not pages_script.exists():
                return TaskResult(True, "pages.py script not found - skipping")
            
            # Check if markdown files exist
            has_md = any(Path(f).exists() for f in ["OBSSv2.md", "OBSSv2-eng.md"])
            
            if not has_md:
                return TaskResult(True, "No Markdown files available - skipping Pages")
            
            # Interactive prompt for pages action
            print("\nOpzioni GitHub Pages:")
            print("  i - Solo italiano")
            print("  e - Solo inglese")
            print("  b - Entrambe le lingue")
            print("  N - Salta (default)")
            
            try:
                choice = input("Scelta [i/e/b/N]: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                choice = 'n'
            
            if choice in ['i', 'ita']:
                if Path("OBSSv2.md").exists():
                    return self._deploy_pages(context, "italiano", "--italian")
                else:
                    return TaskResult(False, "OBSSv2.md non trovato")
            elif choice in ['e', 'eng']:
                if Path("OBSSv2-eng.md").exists():
                    return self._deploy_pages(context, "inglese", "--english")
                else:
                    return TaskResult(False, "OBSSv2-eng.md non trovato")
            elif choice in ['b', 'both']:
                return self._deploy_pages(context, "entrambe", "--both")
            else:
                return TaskResult(True, "GitHub Pages skipped by user")
                
        except Exception as e:
            return TaskResult(False, f"Pages update failed: {e}")
    
    def _deploy_pages(self, context: ExecutionContext, lang: str, option: str) -> TaskResult:
        try:
            repo_name = input("Nome repository [OBSS-Pages]: ").strip()
            if not repo_name:
                repo_name = "OBSS-Pages"
            
            context.logger.info(f"Deploy GitHub Pages ({lang})...")
            
            result = subprocess.run([
                "python3", "pages.py", repo_name, option
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"\n📋 Info Deploy:")
                print(f"   Repository: {repo_name}")
                print(f"   URL: https://{context.config.github_owner}.github.io/{repo_name}")
                print()
                return TaskResult(True, f"GitHub Pages aggiornate ({lang})")
            else:
                return TaskResult(False, f"Errore deploy Pages: {result.stderr}")
                
        except Exception as e:
            return TaskResult(False, f"Deploy Pages failed: {e}")

class CreateReleaseTask(Task):
    """Create GitHub release interactively"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        try:
            if not context.github_token:
                return TaskResult(True, "No GitHub token - skipping release creation")
            
            # Interactive prompt for release creation
            try:
                create_release = input("Creare una nuova release? [si/No] (s/N): ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                create_release = 'n'
            
            if create_release not in ['s', 'si', 'sì', 'y', 'yes']:
                return TaskResult(True, "Release creation skipped by user")
            
            # Get version name
            timestamp = time.strftime("%Y-%m-%d-%H%M")
            default_version = f"OBSSv2-{timestamp}"
            
            version_name = input(f"Nome della versione [{default_version}]: ").strip()
            if not version_name:
                version_name = default_version
            
            # Get description
            default_desc = f"Release automatica per OBSS v2 - {time.strftime('%d/%m/%Y alle %H:%M')}"
            print(f"\nDescrizione della versione (INVIO per default):")
            print(f"Default: {default_desc}")
            version_description = input("Descrizione: ").strip()
            if not version_description:
                version_description = default_desc
            
            # Create the release
            return self._create_github_release(context, version_name, version_description)
            
        except Exception as e:
            return TaskResult(False, f"Release creation failed: {e}")
    
    def _create_github_release(self, context: ExecutionContext, name: str, description: str) -> TaskResult:
        try:
            # Get current commit
            commit_result = subprocess.run([
                "git", "rev-parse", "HEAD"
            ], capture_output=True, text=True)
            
            if commit_result.returncode != 0:
                return TaskResult(False, "Could not get current commit")
            
            commit_sha = commit_result.stdout.strip()
            
            # Create release JSON
            release_data = {
                "tag_name": name,
                "target_commitish": commit_sha,
                "name": name,
                "body": f"{description}\n\nCommit: {commit_sha}",
                "draft": False,
                "prerelease": False,
                "generate_release_notes": True
            }
            
            # Write JSON to temp file
            temp_json = Path(f"/tmp/release_{os.getpid()}.json")
            context.add_temp_file(temp_json)
            temp_json.write_text(json.dumps(release_data, indent=2))
            
            # Create release via GitHub API
            api_url = f"https://api.github.com/repos/{context.config.github_owner}/{context.config.github_repo}/releases"
            
            result = subprocess.run([
                "curl", "-s", "-w", "%{http_code}",
                "-X", "POST",
                "-H", "Accept: application/vnd.github+json",
                "-H", f"Authorization: Bearer {context.github_token}",
                "-H", "X-GitHub-Api-Version: 2022-11-28",
                "-H", "Content-Type: application/json",
                "--data", f"@{temp_json}",
                api_url
            ], capture_output=True, text=True)
            
            # Parse response
            response_body = result.stdout[:-3]  # Remove HTTP code
            http_code = result.stdout[-3:]
            
            if http_code == "201":
                context.logger.success("Release creata con successo")
                print(f"\n📋 Release creata:")
                print(f"   Nome: {name}")
                print(f"   Commit: {commit_sha[:8]}")
                print()
                return TaskResult(True, f"Created release {name}")
            else:
                return TaskResult(False, f"Failed to create release (HTTP {http_code}): {response_body}")
                
        except Exception as e:
            return TaskResult(False, f"Release creation failed: {e}")

class GitOperationsTask(Task):
    """Handle Git operations (commit and push)"""
    
    def execute(self, context: ExecutionContext) -> TaskResult:
        if not context.config.auto_commit:
            return TaskResult(True, "Auto-commit disabled")
        
        try:
            target_dir = Path(context.config.target_dir).expanduser()
            
            # Check if we're in a git repository
            result = subprocess.run(
                ["git", "rev-parse", "--git-dir"],
                capture_output=True, cwd=target_dir
            )
            
            if result.returncode != 0:
                return TaskResult(False, "Not a Git repository")
            
            # Get commit message
            commit_msg = self._get_commit_message()
            
            # Add files
            self._git_add_files(context, target_dir)
            
            # Commit
            commit_result = subprocess.run([
                "git", "commit", "-am", commit_msg
            ], capture_output=True, text=True, cwd=target_dir)
            
            if commit_result.returncode != 0 and "nothing to commit" not in commit_result.stdout:
                return TaskResult(False, f"Commit failed: {commit_result.stderr}")
            
            # Push
            if context.github_token:
                push_url = f"https://{context.config.github_owner}:{context.github_token}@github.com/{context.config.github_owner}/{context.config.github_repo}.git"
                
                push_result = subprocess.run([
                    "git", "push", push_url
                ], capture_output=True, text=True, cwd=target_dir)
                
                if push_result.returncode != 0:
                    return TaskResult(False, f"Push failed: {push_result.stderr}")
            
            return TaskResult(True, "Git operations completed successfully")
            
        except Exception as e:
            return TaskResult(False, f"Git operations failed: {e}")
    
    def _get_commit_message(self) -> str:
        """Get commit message from user or use default"""
        default_msg = f"Update LaTeX documents - {time.strftime('%Y-%m-%d %H:%M')}"
        
        try:
            # Try to get message via GUI (zenity) or fall back to default
            result = subprocess.run([
                "zenity", "--entry", "--title=Commit Message",
                "--text=Messaggio di commit:", f"--entry-text={default_msg}"
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        return default_msg
    
    def _git_add_files(self, context: ExecutionContext, target_dir: Path):
        """Add specific files to git"""
        files_to_add = [
            "immagini/",
            context.config.sections_dir + "/",
            *context.config.required_assets,
            *context.config.latex_files,
            "OBSSv2.md", "OBSSv2-eng.md",
            "markdown-separati/",
            "ddn.sh"
        ]
        
        for file_pattern in files_to_add:
            try:
                subprocess.run([
                    "git", "add", file_pattern
                ], capture_output=True, cwd=target_dir)
            except:
                pass  # Ignore files that don't exist

# Task Runner
class TaskRunner:
    """Manages and executes tasks with dependency resolution"""
    
    def __init__(self, context: ExecutionContext):
        self.context = context
        self.tasks: Dict[str, Task] = {}
        self.execution_order: List[str] = []
    
    def add_task(self, task: Task) -> None:
        """Add a task to the runner"""
        self.tasks[task.name] = task
    
    def resolve_dependencies(self) -> List[str]:
        """Resolve task dependencies using topological sort"""
        visited = set()
        temp_visited = set()
        order = []
        
        def visit(task_name: str):
            if task_name in temp_visited:
                raise ValueError(f"Circular dependency detected involving {task_name}")
            
            if task_name not in visited:
                temp_visited.add(task_name)
                
                task = self.tasks[task_name]
                for dep in task.dependencies:
                    if dep not in self.tasks:
                        raise ValueError(f"Unknown dependency: {dep}")
                    visit(dep)
                
                temp_visited.remove(task_name)
                visited.add(task_name)
                order.append(task_name)
        
        for task_name in self.tasks:
            if task_name not in visited:
                visit(task_name)
        
        return order
    
    def run_all(self, fail_fast: bool = True) -> Dict[str, TaskResult]:
        """Run all tasks in dependency order"""
        self.execution_order = self.resolve_dependencies()
        results = {}
        
        for task_name in self.execution_order:
            task = self.tasks[task_name]
            
            # Check if dependencies succeeded
            failed_deps = [
                dep for dep in task.dependencies
                if dep in results and not results[dep].success
            ]
            
            if failed_deps:
                task.status = TaskStatus.SKIPPED
                results[task_name] = TaskResult(
                    False, f"Skipped due to failed dependencies: {', '.join(failed_deps)}"
                )
                continue
            
            result = task.run(self.context)
            results[task_name] = result
            
            if fail_fast and not result.success:
                self.context.logger.error(f"Task {task_name} failed, stopping execution")
                break
        
        return results

def show_summary(logger: Logger, results: Dict[str, TaskResult], execution_order: List[str]):
    """Show execution summary"""
    
    print("\n" + "="*80)
    print(" EXECUTION SUMMARY")
    print("="*80)
    
    total_duration = 0
    successful = 0
    
    for task_name in execution_order:
        if task_name in results:
            result = results[task_name]
            status = "✓" if result.success else "✗"
            duration = f"{result.duration:.2f}s"
            total_duration += result.duration
            
            if result.success:
                successful += 1
            
            print(f"{status} {task_name:<25} {duration:>8} {result.message}")
    
    print("="*80)
    print(f"Summary: {successful}/{len(results)} tasks successful in {total_duration:.2f}s")
    print("="*80)

def main():
    """Main entry point"""
    
    parser = argparse.ArgumentParser(description="LaTeX Document Automation Tool")
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without executing')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    parser.add_argument('--fail-fast', action='store_true', default=True, help='Stop on first failure')
    parser.add_argument('--no-fail-fast', dest='fail_fast', action='store_false', help='Continue on failures')
    
    args = parser.parse_args()
    
    # Setup logging
    logger = Logger(verbose=args.verbose)
    
    # Load configuration
    config = Config()
    
    if args.dry_run:
        logger.info("DRY RUN MODE - No changes will be made")
    
    # Create execution context
    context = ExecutionContext(config=config, logger=logger, dry_run=args.dry_run)
    
    try:
        # Setup task runner
        runner = TaskRunner(context)
        
        # Add tasks in logical order
        runner.add_task(CheckDependenciesTask("check_deps"))
        runner.add_task(LoadGitHubTokenTask("load_token", ["check_deps"]))
        runner.add_task(VerifyLatexFilesTask("verify_files", ["check_deps"]))
        runner.add_task(ExtractSectionsTask("extract_sections", ["verify_files"]))
        runner.add_task(CreateVariantsTask("create_variants", ["verify_files"]))
        runner.add_task(CompileLatexTask("compile_latex", ["extract_sections", "create_variants"]))
        runner.add_task(OptimizePdfsTask("optimize_pdfs", ["compile_latex"]))
        runner.add_task(ConvertMarkdownTask("convert_markdown", ["compile_latex"]))
        runner.add_task(PrepareAssetsTask("prepare_assets", ["optimize_pdfs"]))
        
        # Interactive tasks (only run if not in dry-run mode)
        if not args.dry_run:
            runner.add_task(UpdateWikiTask("update_wiki", ["convert_markdown"]))
            runner.add_task(UpdatePagesTask("update_pages", ["convert_markdown"]))
            runner.add_task(CreateReleaseTask("create_release", ["prepare_assets", "load_token"]))
        
        runner.add_task(GitOperationsTask("git_ops", ["prepare_assets", "load_token"]))
        
        # Run all tasks
        logger.step("Starting LaTeX automation pipeline...")
        results = runner.run_all(fail_fast=args.fail_fast)
        
        # Show summary
        show_summary(logger, results, runner.execution_order)
        
        # Exit with error code if any critical tasks failed
        critical_tasks = ["check_deps", "verify_files", "compile_latex"]
        failed_critical = [name for name in critical_tasks if name in results and not results[name].success]
        
        if failed_critical:
            logger.error(f"Critical tasks failed: {', '.join(failed_critical)}")
            sys.exit(1)
        
    except KeyboardInterrupt:
        logger.warning("Interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)
    finally:
        context.cleanup()

if __name__ == "__main__":
    main()
