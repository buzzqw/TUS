#!/usr/bin/env python3
"""
Script per gestire la wiki di GitHub del progetto TUS
Legge la pagina Home, estrae i link ai giorni e permette di cancellarli
"""

import requests
import json
import re
import os
from typing import List, Dict, Optional, Tuple
from datetime import datetime
import sys
import subprocess
import tempfile
import shutil

class GitHubWikiManager:
    def __init__(self, repo_owner: str, repo_name: str, token_file: str = ".token"):
        self.repo_owner = repo_owner
        self.repo_name = repo_name
        self.base_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}"
        self.wiki_url = f"https://github.com/{repo_owner}/{repo_name}.wiki.git"
        self.wiki_clone_dir = None
        
        # Carica il token di accesso
        self.token = self._load_token(token_file)
        self.headers = {
            "Authorization": f"token {self.token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "TUS-Wiki-Manager/1.0"
        }
    
    def _load_token(self, token_file: str) -> str:
        """Carica il token GitHub dal file specificato"""
        try:
            with open(token_file, 'r') as f:
                content = f.read().strip()
                # Gestisce formato "githubtoken=valore" o solo "valore"
                if '=' in content:
                    return content.split('=', 1)[1].strip()
                return content
        except FileNotFoundError:
            print(f"❌ File token '{token_file}' non trovato!")
            print("Crea un file .token con il tuo GitHub token:")
            print("githubtoken=ghp_tuotoken")
            sys.exit(1)
        except Exception as e:
            print(f"❌ Errore nel caricamento del token: {e}")
            sys.exit(1)
    
    def force_refresh(self):
        """Forza un refresh completo pulendo tutte le cache locali"""
        print("🧹 Pulizia cache locali...")
        self.cleanup()
        print("✅ Cache pulite, il prossimo accesso sarà completamente aggiornato")
    
    def get_home_page_content(self, force_refresh: bool = False) -> Optional[str]:
        """Ottiene il contenuto della pagina Home della wiki"""
        # Prova l'URL principale (quello che funziona)
        home_url = f"https://raw.githubusercontent.com/wiki/{self.repo_owner}/{self.repo_name}/Home.md"
        
        # Se forziamo il refresh, aggiungiamo un timestamp per evitare la cache
        if force_refresh:
            import time
            home_url += f"?t={int(time.time())}"
        
        try:
            response = requests.get(home_url, headers=self.headers, timeout=10)
            if response.status_code == 200 and len(response.text.strip()) > 0:
                return response.text
        except requests.RequestException:
            pass
        
        # Se fallisce, prova gli altri metodi
        return self._get_home_alternative_methods()
    
    def _get_home_alternative_methods(self) -> Optional[str]:
        """Metodi alternativi per ottenere la Home se il primo fallisce"""
        alternative_urls = [
            f"https://raw.githubusercontent.com/{self.repo_owner}/{self.repo_name}/wiki/Home.md",
            f"https://api.github.com/repos/{self.repo_owner}/{self.repo_name}/contents/wiki/Home.md"
        ]
        
        for url in alternative_urls:
            try:
                response = requests.get(url, headers=self.headers, timeout=10)
                if response.status_code == 200:
                    # Se è l'API GitHub, decodifica il contenuto base64
                    if "api.github.com" in url:
                        try:
                            import base64
                            data = response.json()
                            content = base64.b64decode(data['content']).decode('utf-8')
                            return content
                        except Exception:
                            continue
                    else:
                        if len(response.text.strip()) > 0:
                            return response.text
            except requests.RequestException:
                continue
        
        # Ultimo tentativo: clonazione
        return self._get_home_via_clone()
    
    def _get_home_via_clone(self) -> Optional[str]:
        """Ottiene il contenuto della Home clonando temporaneamente la wiki"""
        temp_dir = None
        try:
            import tempfile
            temp_dir = tempfile.mkdtemp(prefix="wiki_read_")
            
            # URL con autenticazione
            auth_url = f"https://{self.token}@github.com/{self.repo_owner}/{self.repo_name}.wiki.git"
            
            print(f"   Clonazione in: {temp_dir}")
            result = subprocess.run([
                "git", "clone", auth_url, temp_dir
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                home_file = os.path.join(temp_dir, "Home.md")
                if os.path.exists(home_file):
                    with open(home_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        print(f"✅ Home.md letto dalla clonazione (lunghezza: {len(content)})")
                        return content
                else:
                    print("   Home.md non trovato nella wiki clonata")
            else:
                print(f"   Errore clonazione: {result.stderr}")
                
        except Exception as e:
            print(f"   Errore nella clonazione temporanea: {e}")
        finally:
            if temp_dir and os.path.exists(temp_dir):
                try:
                    shutil.rmtree(temp_dir)
                except:
                    pass
        
        return None
    
    def parse_day_pages_from_home(self, content: str) -> List[Dict]:
        """Estrae i link alle pagine dei giorni dalla pagina Home"""
        if not content:
            return []
        
        day_pages = []
        
        # Pattern per trovare i link alle pagine dei giorni nel formato markdown
        # Cerca pattern come "- 2025-06-24 - [OBSSv2 (Italiano)](2025-06-24-OBSSv2)"
        pattern = r'^\s*-\s*(\d{4}-\d{2}-\d{2})\s*-\s*\[([^\]]+)\]\(([^)]+)\)\s*$'
        
        lines = content.split('\n')
        for line_num, line in enumerate(lines, 1):
            match = re.match(pattern, line.strip())
            if match:
                date_part = match.group(1)        # "2025-06-24"
                description = match.group(2)      # "OBSSv2 (Italiano)"
                wiki_link = match.group(3)        # "2025-06-24-OBSSv2"
                
                # Il titolo completo per visualizzazione
                full_title = f"{date_part} - {description}"
                
                day_pages.append({
                    "title": full_title,
                    "date": date_part,
                    "description": description,
                    "wiki_name": wiki_link,
                    "url": f"https://github.com/{self.repo_owner}/{self.repo_name}/wiki/{wiki_link}",
                    "raw_url": f"https://raw.githubusercontent.com/wiki/{self.repo_owner}/{self.repo_name}/{wiki_link}.md",
                    "line_number": line_num
                })
        
        return day_pages
    
    def verify_page_exists(self, page: Dict, force_refresh: bool = False) -> bool:
        """Verifica se una pagina esiste davvero"""
        try:
            url = page["raw_url"]
            if force_refresh:
                import time
                url += f"?t={int(time.time())}"
            
            response = requests.get(url, headers=self.headers, timeout=5)
            return response.status_code == 200
        except requests.RequestException:
            return False
    
    def get_page_content(self, page: Dict) -> Optional[str]:
        """Ottiene il contenuto di una pagina specifica"""
        try:
            response = requests.get(page["raw_url"], headers=self.headers, timeout=10)
            if response.status_code == 200:
                return response.text
            return None
        except requests.RequestException:
            return None
    
    def clone_wiki(self, force_new: bool = False) -> bool:
        """Clona la wiki in una directory temporanea"""
        if not force_new and self.wiki_clone_dir and os.path.exists(self.wiki_clone_dir):
            return True
        
        # Se forziamo un nuovo clone, puliamo quello esistente
        if force_new:
            self.cleanup()
            
        try:
            self.wiki_clone_dir = tempfile.mkdtemp(prefix="tus_wiki_")
            
            # Configura l'URL con token per l'autenticazione
            auth_url = f"https://{self.token}@github.com/{self.repo_owner}/{self.repo_name}.wiki.git"
            
            print(f"🔄 Clonazione wiki in corso...")
            result = subprocess.run([
                "git", "clone", auth_url, self.wiki_clone_dir
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                print(f"✅ Wiki clonata in: {self.wiki_clone_dir}")
                return True
            else:
                print(f"❌ Errore nella clonazione: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ Timeout nella clonazione della wiki")
            return False
        except Exception as e:
            print(f"❌ Errore nella clonazione: {e}")
            return False
    
    def delete_page_from_wiki(self, page: Dict) -> bool:
        """Cancella una pagina dalla wiki locale"""
        if not self.wiki_clone_dir:
            print("❌ Wiki non clonata")
            return False
        
        # Il nome del file è il wiki_name + .md
        file_path = os.path.join(self.wiki_clone_dir, f"{page['wiki_name']}.md")
        
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f"✅ File rimosso: {page['wiki_name']}.md")
                return True
            else:
                print(f"❌ File non trovato: {file_path}")
                return False
        except Exception as e:
            print(f"❌ Errore nella rimozione del file: {e}")
            return False
    
    def commit_and_push_changes(self, commit_message: str) -> bool:
        """Esegue commit e push delle modifiche alla wiki"""
        if not self.wiki_clone_dir:
            return False
        
        try:
            # Configura git user se necessario
            subprocess.run([
                "git", "config", "user.email", "wiki-manager@example.com"
            ], cwd=self.wiki_clone_dir, capture_output=True)
            
            subprocess.run([
                "git", "config", "user.name", "Wiki Manager"
            ], cwd=self.wiki_clone_dir, capture_output=True)
            
            # Add, commit e push
            subprocess.run([
                "git", "add", "-A"
            ], cwd=self.wiki_clone_dir, check=True, capture_output=True)
            
            subprocess.run([
                "git", "commit", "-m", commit_message
            ], cwd=self.wiki_clone_dir, check=True, capture_output=True)
            
            subprocess.run([
                "git", "push", "origin", "master"
            ], cwd=self.wiki_clone_dir, check=True, capture_output=True)
            
            print("✅ Modifiche inviate alla wiki")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Errore nel commit/push: {e}")
            return False
    
    def update_home_page(self, pages_to_remove: List[Dict]) -> bool:
        """Rimuove i link delle pagine cancellate dalla pagina Home"""
        if not self.wiki_clone_dir:
            print("❌ Wiki non clonata")
            return False
        
        home_file = os.path.join(self.wiki_clone_dir, "Home.md")
        
        try:
            # Legge il contenuto attuale della Home
            if not os.path.exists(home_file):
                print("❌ File Home.md non trovato nella wiki")
                return False
            
            with open(home_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            print(f"🔄 Aggiornamento pagina Home...")
            
            # Rimuove le righe corrispondenti alle pagine cancellate
            lines = content.split('\n')
            updated_lines = []
            removed_count = 0
            
            for line in lines:
                should_remove = False
                
                for page in pages_to_remove:
                    # Controlla se la riga contiene il link a questa pagina
                    if f"({page['wiki_name']})" in line:
                        should_remove = True
                        removed_count += 1
                        print(f"   ✅ Rimossa riga: {line.strip()}")
                        break
                
                if not should_remove:
                    updated_lines.append(line)
            
            # Scrive il nuovo contenuto
            new_content = '\n'.join(updated_lines)
            with open(home_file, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            print(f"✅ Home aggiornata: {removed_count} righe rimosse")
            return True
            
        except Exception as e:
            print(f"❌ Errore nell'aggiornamento della Home: {e}")
            return False
    
    def clean_dead_links_from_home_local(self) -> bool:
        """Pulisce i link morti dalla Home nella wiki già clonata (senza fare clone separato)"""
        if not self.wiki_clone_dir:
            print("❌ Wiki non clonata")
            return False
        
        home_file = os.path.join(self.wiki_clone_dir, "Home.md")
        
        try:
            if not os.path.exists(home_file):
                print("❌ File Home.md non trovato")
                return False
            
            with open(home_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            print("🔄 Pulizia automatica link morti dalla pagina Home...")
            
            lines = content.split('\n')
            cleaned_lines = []
            removed_count = 0
            
            # Pattern per trovare righe con date (sia formato * che -)
            date_patterns = [
                r'^\s*[-*]\s*(\d{4}-\d{2}-\d{2})\s*-\s*(.+)$',  # * 2025-06-24 - OBSSv2 (Italiano)
                r'^\s*[-*]\s*(\d{4}-\d{2}-\d{2})\s*-\s*\[([^\]]+)\]\(([^)]+)\)\s*$'  # - 2025-06-24 - [desc](link)
            ]
            
            for line in lines:
                should_remove = False
                
                for pattern in date_patterns:
                    match = re.match(pattern, line.strip())
                    if match:
                        # Estrae la data e prova a determinare il nome della pagina wiki
                        date_part = match.group(1)  # 2025-06-24
                        
                        # Determina il nome della pagina in base al formato
                        if len(match.groups()) >= 3:
                            # Formato con link markdown: usa il link diretto
                            wiki_name = match.group(3)
                        else:
                            # Formato semplice: prova a indovinare il nome della pagina
                            description = match.group(2)  # "OBSSv2 (Italiano)"
                            if "(Italiano)" in description:
                                wiki_name = f"{date_part}-OBSSv2"
                            elif "(English)" in description:
                                wiki_name = f"{date_part}-OBSSv2-eng"
                            else:
                                # Fallback generico
                                wiki_name = f"{date_part}-OBSSv2"
                        
                        # Verifica se il file esiste nella wiki locale
                        local_file = os.path.join(self.wiki_clone_dir, f"{wiki_name}.md")
                        if not os.path.exists(local_file):
                            should_remove = True
                            removed_count += 1
                            print(f"   ✅ Rimossa riga: {line.strip()}")
                        break
                
                if not should_remove:
                    cleaned_lines.append(line)
            
            if removed_count > 0:
                # Scrive il nuovo contenuto
                new_content = '\n'.join(cleaned_lines)
                with open(home_file, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                
                print(f"✅ Home pulita automaticamente: {removed_count} link morti rimossi")
                return True
            else:
                print("✅ Nessun link morto trovato nella Home")
                return True
                
        except Exception as e:
            print(f"❌ Errore nella pulizia automatica della Home: {e}")
            return False
    
    def clean_dead_links_from_home(self) -> bool:
        """Rimuove dalla Home tutti i link a pagine che non esistono più"""
        if not self.clone_wiki():
            return False
        
        home_file = os.path.join(self.wiki_clone_dir, "Home.md")
        
        try:
            if not os.path.exists(home_file):
                print("❌ File Home.md non trovato")
                return False
            
            with open(home_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            print("🔄 Pulizia link morti dalla pagina Home...")
            
            lines = content.split('\n')
            cleaned_lines = []
            removed_count = 0
            
            # Pattern per trovare righe con date (sia formato * che -)
            date_patterns = [
                r'^\s*[-*]\s*(\d{4}-\d{2}-\d{2})\s*-\s*(.+)$',  # * 2025-06-24 - OBSSv2 (Italiano)
                r'^\s*[-*]\s*(\d{4}-\d{2}-\d{2})\s*-\s*\[([^\]]+)\]\(([^)]+)\)\s*$'  # - 2025-06-24 - [desc](link)
            ]
            
            for line in lines:
                should_remove = False
                
                for pattern in date_patterns:
                    match = re.match(pattern, line.strip())
                    if match:
                        # Estrae la data e prova a determinare il nome della pagina wiki
                        date_part = match.group(1)  # 2025-06-24
                        
                        # Determina il nome della pagina in base al formato
                        if len(match.groups()) >= 3:
                            # Formato con link markdown: usa il link diretto
                            wiki_name = match.group(3)
                        else:
                            # Formato semplice: prova a indovinare il nome della pagina
                            description = match.group(2)  # "OBSSv2 (Italiano)"
                            if "(Italiano)" in description:
                                wiki_name = f"{date_part}-OBSSv2"
                            elif "(English)" in description:
                                wiki_name = f"{date_part}-OBSSv2-eng"
                            else:
                                # Fallback generico
                                wiki_name = f"{date_part}-OBSSv2"
                        
                        # Verifica se la pagina esiste
                        page_url = f"https://raw.githubusercontent.com/wiki/{self.repo_owner}/{self.repo_name}/{wiki_name}.md"
                        try:
                            response = requests.get(page_url, headers=self.headers, timeout=5)
                            if response.status_code != 200:
                                should_remove = True
                                removed_count += 1
                                print(f"   ✅ Rimossa riga: {line.strip()}")
                        except requests.RequestException:
                            should_remove = True
                            removed_count += 1
                            print(f"   ✅ Rimossa riga: {line.strip()}")
                        break
                
                if not should_remove:
                    cleaned_lines.append(line)
            
            if removed_count > 0:
                # Scrive il nuovo contenuto
                new_content = '\n'.join(cleaned_lines)
                with open(home_file, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                
                # Fa commit e push
                if self.commit_and_push_changes(f"Pulizia {removed_count} link morti dalla Home"):
                    print(f"✅ Home pulita: {removed_count} link morti rimossi")
                    return True
                else:
                    print("❌ Errore nel salvataggio delle modifiche")
                    return False
            else:
                print("✅ Nessun link morto trovato nella Home")
                return True
                
        except Exception as e:
            print(f"❌ Errore nella pulizia della Home: {e}")
            return False
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Pulisce le directory temporanee"""
        if self.wiki_clone_dir and os.path.exists(self.wiki_clone_dir):
            try:
                shutil.rmtree(self.wiki_clone_dir)
                print(f"🧹 Directory temporanea rimossa")
                self.wiki_clone_dir = None
            except Exception as e:
                print(f"⚠️  Errore nella pulizia: {e}")
    
    def parse_selection(self, selection_input: str, max_pages: int) -> List[int]:
        """Parsa la selezione dell'utente e restituisce una lista di indici"""
        if not selection_input.strip():
            return []
        
        selection_input = selection_input.strip().lower()
        
        # Se è "all", restituisce tutti gli indici
        if selection_input == "all":
            return list(range(max_pages))
        
        indices = []
        parts = selection_input.split(',')
        
        for part in parts:
            part = part.strip()
            if '-' in part:
                # Range (es: 2-5)
                try:
                    start, end = part.split('-', 1)
                    start = int(start.strip()) - 1  # Converti a 0-based
                    end = int(end.strip()) - 1      # Converti a 0-based
                    if 0 <= start <= end < max_pages:
                        indices.extend(range(start, end + 1))
                    else:
                        print(f"⚠️  Range '{part}' non valido (fuori dai limiti 1-{max_pages})")
                except ValueError:
                    print(f"⚠️  Range '{part}' non valido (formato errato)")
            else:
                # Numero singolo
                try:
                    index = int(part) - 1  # Converti a 0-based
                    if 0 <= index < max_pages:
                        indices.append(index)
                    else:
                        print(f"⚠️  Numero '{part}' non valido (fuori dai limiti 1-{max_pages})")
                except ValueError:
                    print(f"⚠️  '{part}' non è un numero valido")
        
        # Rimuovi duplicati e ordina
        return sorted(list(set(indices)))
    
    def get_selected_pages(self, day_pages: List[Dict], prompt: str) -> List[Dict]:
        """Chiede all'utente di selezionare una o più pagine"""
        print(f"\n📋 Pagine disponibili:")
        for i, page in enumerate(day_pages, 1):
            print(f"{i:2d}. {page['title']}")
        
        print(f"\n💡 Esempi di selezione:")
        print(f"   • Un numero: 3")
        print(f"   • Numeri multipli: 1,3,5")
        print(f"   • Range: 2-5")
        print(f"   • Tutto: all")
        
        while True:
            selection_input = input(f"\n{prompt}: ").strip()
            if not selection_input:
                print("❌ Inserisci una selezione valida")
                continue
            
            indices = self.parse_selection(selection_input, len(day_pages))
            if indices:
                selected_pages = [day_pages[i] for i in indices]
                print(f"\n📌 Pagine selezionate ({len(selected_pages)}):")
                for page in selected_pages:
                    print(f"   • {page['title']}")
                return selected_pages
            else:
                print("❌ Nessuna pagina valida selezionata, riprova")
    
    def wait_for_user(self, message: str = "Premi INVIO per tornare al menu"):
        """Aspetta che l'utente prema INVIO per continuare"""
        input(f"\n{message}...")
    
    def confirm_action(self, message: str) -> bool:
        """Chiede conferma per un'azione"""
        response = input(f"{message} (s/n): ").strip().lower()
        return response in ['s', 'si', 'sì', 'y', 'yes']
    
    def show_wiki_summary(self, verbose: bool = False, force_refresh: bool = False) -> Optional[List[Dict]]:
        """Mostra un riassunto delle pagine dei giorni"""
        print(f"📚 Analisi Wiki - {self.repo_owner}/{self.repo_name}")
        print("=" * 50)
        
        # Se forziamo il refresh, puliamo prima le cache locali
        if force_refresh:
            print("🔄 Refresh forzato - pulizia cache...")
            self.cleanup()
        
        # Legge la pagina Home
        if verbose:
            print("🔍 Lettura pagina Home...")
        if force_refresh:
            print("🔄 Ricaricamento forzato dalla wiki...")
            
        content = self.get_home_page_content(force_refresh=force_refresh)
        if not content:
            print("❌ Impossibile leggere la pagina Home della wiki")
            if verbose:
                print("\n🔧 Suggerimenti per il debug:")
                print("1. Verifica che la wiki esista e abbia una pagina Home")
                print("2. Controlla che il token abbia i permessi corretti")
                print("3. Verifica la connessione a GitHub")
            return None
        
        if verbose:
            print(f"✅ Contenuto Home letto ({len(content)} caratteri)")
            print(f"\n📝 Contenuto completo:")
            print("-" * 40)
            print(content)
            print("-" * 40)
        
        # Estrae le pagine dei giorni
        day_pages = self.parse_day_pages_from_home(content)
        
        if not day_pages:
            print("❌ Nessuna pagina di giorni trovata nel contenuto")
            if verbose:
                print("🔍 Pattern cercati:")
                print("  - YYYY-MM-DD - [descrizione](link)")
                print("  - 2025-06-24 - [OBSSv2 (Italiano)](2025-06-24-OBSSv2)")
                
                # Mostra le righe che iniziano con - o *
                lines_with_dash = [line.strip() for line in content.split('\n') if line.strip().startswith('-') or line.strip().startswith('*')]
                if lines_with_dash:
                    print(f"\n🔍 Righe trovate che iniziano con '-' o '*' ({len(lines_with_dash)}):")
                    for line in lines_with_dash[:10]:  # Mostra solo le prime 10
                        print(f"  {line}")
                    if len(lines_with_dash) > 10:
                        print(f"  ... e altre {len(lines_with_dash) - 10} righe")
            return None
        
        print(f"📊 Trovate {len(day_pages)} pagine di giorni:")
        print()
        
        # Verifica esistenza e mostra dettagli (versione compatta)
        existing_pages = []
        print("🔍 Verifica esistenza pagine...")
        
        for i, page in enumerate(day_pages, 1):
            exists = self.verify_page_exists(page, force_refresh=force_refresh)
            status = "✅" if exists else "❌"
            print(f"{i:2d}. {status} {page['title']}")
            if exists:
                existing_pages.append(page)
        
        print(f"\n📈 Riepilogo: {len(existing_pages)}/{len(day_pages)} pagine esistenti")
        
        if force_refresh:
            print("✅ Refresh completato con dati aggiornati da GitHub")
        
        return existing_pages

def main():
    """Funzione principale con menu interattivo"""
    print("🚀 GitHub Wiki Manager per TUS")
    print("=" * 40)
    
    # Configurazione repository
    REPO_OWNER = "buzzqw"
    REPO_NAME = "TUS"
    
    try:
        manager = GitHubWikiManager(REPO_OWNER, REPO_NAME)
    except SystemExit:
        return
    
    try:
        while True:
            print("\n📋 Opzioni disponibili:")
            print("1. 📊 Analizza wiki e mostra giorni")
            print("2. 👁️  Visualizza contenuto di un giorno specifico")
            print("3. 🗑️  Cancella giorno specifico")
            print("4. 🔥 Cancella tutti i giorni")
            print("5. 🔧 Debug dettagliato")
            print("6. 🔄 Ricarica wiki (bypassa cache)")
            print("7. 🧹 Pulisci link morti dalla Home")
            print("8. ❌ Esci")
            
            choice = input("\nSeleziona un'opzione (1-8): ").strip()
            
            if choice == "1":
                day_pages = manager.show_wiki_summary()
                manager.wait_for_user()
                
            elif choice == "2":
                day_pages = manager.show_wiki_summary()
                if day_pages:
                    selected_pages = manager.get_selected_pages(day_pages, "Seleziona le pagine da visualizzare")
                    if selected_pages:
                        for page in selected_pages:
                            content = manager.get_page_content(page)
                            print(f"\n📄 Contenuto di: {page['title']}")
                            print("=" * 50)
                            if content:
                                print(content[:1000] + ("..." if len(content) > 1000 else ""))
                            else:
                                print("❌ Impossibile leggere il contenuto")
                            print()
                        manager.wait_for_user()
                    else:
                        manager.wait_for_user("Nessuna pagina selezionata. Premi INVIO per tornare al menu")
                else:
                    manager.wait_for_user("Nessuna pagina trovata. Premi INVIO per tornare al menu")
            
            elif choice == "3":
                day_pages = manager.show_wiki_summary()
                if day_pages:
                    selected_pages = manager.get_selected_pages(day_pages, "Seleziona le pagine da cancellare")
                    if selected_pages:
                        print(f"\n⚠️  Stai per cancellare {len(selected_pages)} pagina/e:")
                        for page in selected_pages:
                            print(f"   • {page['title']}")
                        
                        if manager.confirm_action("🗑️  Confermi la cancellazione?"):
                            if manager.clone_wiki():
                                deleted_count = 0
                                successfully_deleted = []
                                
                                for page in selected_pages:
                                    if manager.delete_page_from_wiki(page):
                                        deleted_count += 1
                                        successfully_deleted.append(page)
                                        print(f"✅ Cancellata: {page['title']}")
                                    else:
                                        print(f"❌ Errore nella cancellazione di: {page['title']}")
                                
                                if deleted_count > 0:
                                    # Aggiorna la pagina Home rimuovendo i link alle pagine cancellate
                                    print(f"\n🔄 Aggiornamento pagina Home...")
                                    manager.update_home_page(successfully_deleted)
                                    
                                    # Pulizia automatica di tutti i link morti
                                    manager.clean_dead_links_from_home_local()
                                    
                                    if manager.commit_and_push_changes(f"Rimozione di {deleted_count} pagine e pulizia Home"):
                                        print(f"\n🎉 {deleted_count} pagine cancellate con successo!")
                                        print("💡 Usa l'opzione 6 per ricaricare e vedere le modifiche")
                                    else:
                                        print("❌ Errore nel salvataggio delle modifiche")
                                else:
                                    print("❌ Nessuna pagina è stata cancellata")
                            else:
                                print("❌ Errore nella clonazione della wiki")
                        else:
                            print("❌ Cancellazione annullata")
                        manager.wait_for_user()
                    else:
                        manager.wait_for_user("Nessuna pagina selezionata. Premi INVIO per tornare al menu")
                else:
                    manager.wait_for_user("Nessuna pagina trovata. Premi INVIO per tornare al menu")
            
            elif choice == "4":
                day_pages = manager.show_wiki_summary()
                if day_pages:
                    print(f"\n⚠️  Stai per cancellare TUTTE le {len(day_pages)} pagine di giorni!")
                    print("Questa operazione è IRREVERSIBILE!")
                    
                    if manager.confirm_action("🔥 Confermi la cancellazione di TUTTE le pagine?"):
                        if manager.clone_wiki():
                            deleted_count = 0
                            successfully_deleted = []
                            
                            for page in day_pages:
                                if manager.delete_page_from_wiki(page):
                                    deleted_count += 1
                                    successfully_deleted.append(page)
                                    print(f"✅ Cancellata: {page['title']}")
                            
                            if deleted_count > 0:
                                # Aggiorna la pagina Home rimuovendo i link alle pagine cancellate
                                print(f"\n🔄 Aggiornamento pagina Home...")
                                manager.update_home_page(successfully_deleted)
                                
                                # Pulizia automatica di tutti i link morti
                                manager.clean_dead_links_from_home_local()
                                
                                if manager.commit_and_push_changes(f"Rimozione di {deleted_count} pagine di giorni e pulizia Home"):
                                    print(f"\n🎉 {deleted_count} pagine cancellate con successo!")
                                    print("💡 Usa l'opzione 6 per ricaricare e vedere le modifiche")
                                else:
                                    print("❌ Errore nel salvataggio delle modifiche")
                            else:
                                print("❌ Nessuna pagina è stata cancellata")
                        else:
                            print("❌ Errore nella clonazione della wiki")
                    else:
                        print("❌ Operazione annullata")
                    manager.wait_for_user()
                else:
                    manager.wait_for_user("Nessuna pagina trovata. Premi INVIO per tornare al menu")
            
            elif choice == "5":
                print("\n🔧 Modalità debug attivata...")
                day_pages = manager.show_wiki_summary(verbose=True)
                manager.wait_for_user()
            
            elif choice == "6":
                print("\n🔄 Ricaricamento forzato della wiki...")
                print("   • Pulizia cache locali")
                print("   • Aggiunta timestamp anti-cache alle richieste")
                print("   • Nuova verifica esistenza pagine")
                day_pages = manager.show_wiki_summary(force_refresh=True)
                manager.wait_for_user()
            
            elif choice == "7":
                print("\n🧹 Pulizia link morti dalla pagina Home...")
                if manager.clean_dead_links_from_home():
                    print("💡 Usa l'opzione 6 per ricaricare e vedere le modifiche")
                manager.wait_for_user()
            
            elif choice == "8":
                print("👋 Arrivederci!")
                break
            
            else:
                print("❌ Opzione non valida. Riprova.")
                manager.wait_for_user("Premi INVIO per continuare")
    
    finally:
        manager.cleanup()

if __name__ == "__main__":
    main()
