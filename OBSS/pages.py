#!/usr/bin/env python3
"""
Script per dividere OBSS (ITA/ENG) e deployare su GitHub Pages
Uso: python deploy_obss.py [repository-name]
"""

import os
import sys
import subprocess
import requests
import json
import re
import shutil
import datetime
import zipfile
from pathlib import Path
from typing import Optional, List, Tuple

# Configurazione
MARKDOWN_FILES = {
    "it": "OBSSv2.md",
    "en": "OBSSv2-eng.md"
}
TOKEN_FILE = ".token"
TEMP_DIR = "temp_obss_deploy"
OUTPUT_DIR = "docs"
DEFAULT_REPO = "OBSS-Pages"

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def log_info(message: str):
    print(f"{Colors.BLUE}ℹ️  {message}{Colors.NC}")

def log_success(message: str):
    print(f"{Colors.GREEN}✅ {message}{Colors.NC}")

def log_warning(message: str):
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.NC}")

def log_error(message: str):
    print(f"{Colors.RED}❌ {message}{Colors.NC}")

def extract_github_token() -> str:
    log_info("Estraendo token GitHub...")
    if not os.path.exists(TOKEN_FILE):
        log_error(f"File '{TOKEN_FILE}' non trovato!")
        sys.exit(1)
    try:
        with open(TOKEN_FILE, 'r') as f:
            content = f.read()
        for line in content.split('\n'):
            if line.startswith('githubtoken='):
                token = line.split('=', 1)[1].strip()
                if token:
                    log_success("Token GitHub estratto")
                    return token
        log_error("Token GitHub non trovato nel file")
        log_error("Formato atteso: githubtoken=xxxxx")
        sys.exit(1)
    except Exception as e:
        log_error(f"Errore leggendo il file token: {e}")
        sys.exit(1)
        
def zip_folder(folder_path: str, zip_path: str):
    """Crea uno zip della cartella specificata"""
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, folder_path)
                zipf.write(full_path, rel_path)        

def get_github_user(token: str) -> str:
    log_info("Ottenendo informazioni utente GitHub...")
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    try:
        response = requests.get('https://api.github.com/user', headers=headers)
        response.raise_for_status()
        user_data = response.json()
        username = user_data.get('login')
        if not username:
            log_error("Impossibile ottenere username GitHub")
            sys.exit(1)
        log_success(f"Utente GitHub: {username}")
        return username
    except requests.exceptions.RequestException as e:
        log_error(f"Errore API GitHub: {e}")
        sys.exit(1)

def clean_filename(title: str) -> str:
    clean = re.sub(r'[^\w\s-]', '', title)
    clean = re.sub(r'[-\s]+', '-', clean)
    return clean.strip('-').lower()

def split_markdown_file(input_file: str, output_dir: str) -> List[Tuple[str, str]]:
    log_info(f"Dividendo file markdown '{input_file}' in sezioni...")
    Path(output_dir).mkdir(exist_ok=True)
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    sections = []
    current_section = ""
    section_title = ""
    header_content = ""
    in_header = True
    lines = content.split('\n')
    for line in lines:
        if line.startswith('# ') and not in_header:
            if section_title and current_section:
                sections.append((section_title, current_section.strip()))
            section_title = line[2:].strip()
            current_section = line + '\n'
        elif line.startswith('# ') and in_header:
            if header_content.strip():
                sections.append(("Header", header_content.strip()))
            in_header = False
            section_title = line[2:].strip()
            current_section = line + '\n'
        else:
            if in_header:
                header_content += line + '\n'
            else:
                current_section += line + '\n'
    if section_title and current_section:
        sections.append((section_title, current_section.strip()))
    created_files = []
    for i, (title, content) in enumerate(sections):
        if title == "Header":
            filename = "00-introduzione.md"
        else:
            clean_title = clean_filename(title)
            filename = f"{i:02d}-{clean_title}.md"
        filepath = os.path.join(output_dir, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        created_files.append((filename, title))
        print(f"   Creato: {filepath}")
    return created_files

def create_index_file(output_dir: str, created_files_dict: dict):
    """Crea il file index.md multilingua"""
    index_content = """# OBSS - Old Bell School System

Sistema di gioco di ruolo completo e testato.

## Lingua / Language

- [Italiano](it/index.md)
- [English](en/index.md)

---

*Generato automaticamente da script deploy*
"""
    with open(os.path.join(output_dir, "index.md"), 'w', encoding='utf-8') as f:
        f.write(index_content)
    # Crea gli indici per ogni lingua
    for lang, created_files in created_files_dict.items():
        if lang == "it":
            titolo = "Indice"
            lingua = "Italiano"
            licenza = "Libero per uso personale"
            formato = "LaTeX"
            stato = "Completo e testato"
            repo_link = "https://github.com/buzzqw/TUS"
        else:
            titolo = "Contents"
            lingua = "English"
            licenza = "Free for personal use"
            formato = "LaTeX"
            stato = "Complete and tested"
            repo_link = "https://github.com/buzzqw/TUS"
        index_md = f"# OBSS - Old Bell School System ({lingua})\n\n## {titolo}\n\n"
        for filename, title in created_files:
            if filename != "index.md":
                link_title = title if title != "Header" else ("Introduzione" if lang == "it" else "Introduction")
                index_md += f"- [{link_title}]({filename})\n"
        index_md += f"""
## Info

- **License**: {licenza}
- **Original format**: {formato}
- **Status**: {stato}

## Repository

This manual is also available in the [original repository]({repo_link}) in LaTeX format.

---

*Automatically generated by deploy script*
"""
        lang_dir = os.path.join(output_dir, lang)
        Path(lang_dir).mkdir(exist_ok=True)
        with open(os.path.join(lang_dir, "index.md"), 'w', encoding='utf-8') as f:
            f.write(index_md)

def create_config_file(output_dir: str):
    config_content = """title: OBSS - Old Bell School System
description: Sistema di gioco di ruolo completo e testato / Complete and tested RPG system
theme: minima
plugins:
  - jekyll-relative-links

relative_links:
  enabled: true
  collections: true

markdown: kramdown
highlighter: rouge

header_pages:
  - index.md

# SEO
lang: it
author: buzzqw
"""
    with open(os.path.join(output_dir, "_config.yml"), 'w', encoding='utf-8') as f:
        f.write(config_content)

def setup_github_repo(token: str, username: str, repo_name: str) -> bool:
    log_info("Configurando repository GitHub...")
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    try:
        response = requests.get(f'https://api.github.com/repos/{username}/{repo_name}', headers=headers)
        if response.status_code == 404:
            log_info(f"Creando nuovo repository: {repo_name}")
            data = {
                "name": repo_name,
                "description": "OBSS - Old Bell School System - Manuale di gioco di ruolo",
                "private": False,
                "has_issues": True,
                "has_projects": False,
                "has_wiki": False
            }
            response = requests.post('https://api.github.com/user/repos', 
                                   headers=headers, json=data)
            response.raise_for_status()
            log_success(f"Repository creato: https://github.com/{username}/{repo_name}")
            return True
        elif response.status_code == 200:
            log_info(f"Repository esistente trovato: {repo_name}")
            return True
        else:
            log_error(f"Errore verificando repository: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        log_error(f"Errore API GitHub: {e}")
        return False

def enable_github_pages(token: str, username: str, repo_name: str):
    log_info("Configurando GitHub Pages...")
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    data = {
        "source": {
            "branch": "main",
            "path": "/"
        }
    }
    try:
        response = requests.post(f'https://api.github.com/repos/{username}/{repo_name}/pages', 
                               headers=headers, json=data)
        if response.status_code in [201, 409]:
            log_success("GitHub Pages configurato")
        else:
            log_warning(f"GitHub Pages: {response.status_code} - potrebbe essere già attivo")
    except requests.exceptions.RequestException as e:
        log_warning(f"Errore configurando GitHub Pages: {e}")

def run_git_command(command: List[str], cwd: str = None) -> bool:
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
        if result.returncode != 0:
            log_error(f"Errore git: {result.stderr}")
            return False
        return True
    except Exception as e:
        log_error(f"Errore eseguendo comando git: {e}")
        return False

def deploy_to_github(token: str, username: str, repo_name: str, output_dir: str):
    log_info("Inizializzando repository Git...")
    if not run_git_command(['git', 'init'], cwd=output_dir):
        sys.exit(1)
    if not run_git_command(['git', 'config', 'user.name', 'OBSS Deploy Bot'], cwd=output_dir):
        sys.exit(1)
    if not run_git_command(['git', 'config', 'user.email', 'deploy@obss.local'], cwd=output_dir):
        sys.exit(1)
    readme_path = os.path.join(output_dir, "README.md")
    if not os.path.exists(readme_path):
        shutil.copy(os.path.join(output_dir, "index.md"), readme_path)
    if not run_git_command(['git', 'add', '.'], cwd=output_dir):
        sys.exit(1)
    commit_message = """Deploy OBSS manual to GitHub Pages

- Documento diviso in sezioni per navigazione facile
- Configurazione Jekyll per GitHub Pages
- Contiene versione italiana e inglese
- Generato automaticamente da script deploy

Fonte: https://github.com/buzzqw/TUS"""
    if not run_git_command(['git', 'commit', '-m', commit_message], cwd=output_dir):
        sys.exit(1)
    remote_url = f"https://{token}@github.com/{username}/{repo_name}.git"
    if not run_git_command(['git', 'remote', 'add', 'origin', remote_url], cwd=output_dir):
        sys.exit(1)
    log_info("Caricando su GitHub...")
    if not run_git_command(['git', 'branch', '-M', 'main'], cwd=output_dir):
        sys.exit(1)
    if not run_git_command(['git', 'push', '-u', 'origin', 'main', '--force'], cwd=output_dir):
        sys.exit(1)
    log_success("Deploy completato!")
    
def resolve_home(path):
    return path.replace("$HOME", os.path.expanduser("~"))    

def main():
    # Controlli iniziali
    for lang, filename in MARKDOWN_FILES.items():
        if not os.path.exists(filename):
            log_error(f"File '{filename}' non trovato!")
            sys.exit(1)
    repo_name = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPO
    log_info("🚀 Avvio deploy OBSS su GitHub Pages (IT+EN)")
    token = extract_github_token()
    username = get_github_user(token)
    log_info(f"Repository: {username}/{repo_name}")
    if os.path.exists(TEMP_DIR):
        shutil.rmtree(TEMP_DIR)
    temp_output_dir = os.path.join(TEMP_DIR, OUTPUT_DIR)
    os.makedirs(temp_output_dir, exist_ok=True)
    created_files_dict = {}
    try:
        # Divide i markdown
        for lang, filename in MARKDOWN_FILES.items():
            lang_dir = os.path.join(temp_output_dir, lang)
            created_files = split_markdown_file(filename, lang_dir)
            created_files_dict[lang] = created_files
        # Crea index multilingua e _config.yml
        create_index_file(temp_output_dir, created_files_dict)
        create_config_file(temp_output_dir)
        # Configura GitHub
        if not setup_github_repo(token, username, repo_name):
            sys.exit(1)
        # Deploy
        deploy_to_github(token, username, repo_name, temp_output_dir)
        # Abilita GitHub Pages
        enable_github_pages(token, username, repo_name)
        print()
        log_success("🎉 Deploy completato con successo!")
        print()
        print("📋 Informazioni:")
        print(f"   Repository: https://github.com/{username}/{repo_name}")
        print(f"   GitHub Pages: https://{username}.github.io/{repo_name}")
        print(f"   Sezioni create IT: {len(created_files_dict['it'])}")
        print(f"   Sezioni create EN: {len(created_files_dict['en'])}")
        print("   Tempo di attivazione: 5-10 minuti")
        print()
        log_info("Il sito sarà disponibile tra qualche minuto su GitHub Pages")
    finally:
         if os.path.exists(TEMP_DIR):
             today = datetime.datetime.now().strftime("%Y%m%d")
             zip_name = f"obss_deploy_{today}.zip"
             zip_path = os.path.join(os.getcwd(), zip_name)
             zip_folder(TEMP_DIR, zip_path)
             shutil.copy(zip_name, resolve_home("$HOME/RPG/Pazfinder/TUS/OBSS/old/"))
             try:
                 shutil.rmtree(resolve_home("$HOME/TUS/OBSS/markdown-separati/en/"))
             except FileNotFoundError:
                 log_success("Cartella markdown EN non trovata, saltata.")
             try: 
                 shutil.rmtree(resolve_home("$HOME/TUS/OBSS/markdown-separati/it/"))
             except FileNotFoundError:	 
                  log_success("Cartella markdown IT non trovata, saltata.")    

             os.makedirs(resolve_home("$HOME/TUS/OBSS/markdown-separati/en/"), exist_ok=True)
             os.makedirs(resolve_home("$HOME/TUS/OBSS/markdown-separati/it/"), exist_ok=True)
             shutil.copytree(
                 resolve_home("$HOME/TUS/OBSS/temp_obss_deploy/docs/en/"),
                 resolve_home("$HOME/TUS/OBSS/markdown-separati/en/"),
                 dirs_exist_ok=True  # Python ≥3.8
             )    
             shutil.copytree(
                 resolve_home("$HOME/TUS/OBSS/temp_obss_deploy/docs/it/"),
                 resolve_home("$HOME/TUS/OBSS/markdown-separati/it/"),
                 dirs_exist_ok=True  # Python ≥3.8
             )
             log_success(f"Cartella di appoggio zippata: {zip_path}")
             log_success(f"Copiato in: /home/azanzani/RPG/Pazfinder/TUS/OBSS/old/")
             shutil.rmtree(TEMP_DIR)
             log_success("Cleanup completato")
			
if __name__ == "__main__":
    main()
