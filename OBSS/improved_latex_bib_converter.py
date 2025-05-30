#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Convertitore da bibliografia LaTeX a formato BibTeX
Versione semplificata e robusta
"""

import re
import sys
from pathlib import Path

class BibConverter:
    def __init__(self):
        self.stats = {
            'processed': 0,
            'converted': 0,
            'failed': 0,
            'excluded': 0
        }
        self.excluded_items = []
        self.problematic_items = []

    def clean_text(self, text):
        """Pulisce il testo da comandi LaTeX"""
        text = re.sub(r'%.*$', '', text, flags=re.MULTILINE)
        text = re.sub(r'\s+', ' ', text)
        return text.strip()

    def extract_year(self, content):
        """Estrae l'anno"""
        patterns = [
            r'\(.*?(\d{4}).*?\)',
            r',\s*(\d{4})\s*[,.]',
            r'\b(\d{4})\b'
        ]
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1)
        return None

    def extract_title(self, content):
        """Estrae il titolo"""
        patterns = [
            r'\\textit\{([^}]+)\}',
            r'\\emph\{([^}]+)\}',
            r'\\textbf\{([^}]+)\}',
            r'"([^"]{5,})"',
            r"'([^']{5,})'"
        ]
        
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                title = match.group(1).strip()
                if len(title) > 3 and not re.match(r'^\d{4}$', title):
                    return title
        
        # Strategia alternativa per titoli non formattati
        temp = re.sub(r'\([^)]*\d{4}[^)]*\)', '', content)
        parts = [p.strip() for p in temp.split('.') if p.strip()]
        
        for part in parts[1:]:  # Salta la prima parte (probabilmente autore)
            clean_part = part.strip(' ,')
            if 5 < len(clean_part) < 200 and not re.match(r'^\d+$', clean_part):
                words = clean_part.lower().split()
                title_words = ['the', 'a', 'an', 'of', 'in', 'on', 'for', 'to', 
                              'il', 'la', 'lo', 'di', 'del', 'con', 'per']
                if any(word in title_words for word in words) or len(clean_part) > 20:
                    return clean_part
        
        return None

    def extract_author(self, content):
        """Estrae l'autore"""
        temp = re.sub(r'\\textit\{[^}]+\}', '', content)
        temp = re.sub(r'\\emph\{[^}]+\}', '', temp)
        temp = re.sub(r'"[^"]{5,}"', '', temp)
        temp = re.sub(r'\([^)]*\d{4}[^)]*\)', '', temp)
        
        parts = [p.strip() for p in temp.split('.') if p.strip()]
        if parts:
            author = parts[0].strip(' ,')
            if len(author) > 2 and re.search(r'[A-Za-z]', author):
                # Pulisce caratteri LaTeX
                author = re.sub(r'\\&', ' and ', author)
                return author
        return None

    def extract_publisher(self, content):
        """Estrae editore o rivista"""
        temp = re.sub(r'\\textit\{[^}]+\}', '', content)
        temp = re.sub(r'\([^)]*\d{4}[^)]*\)', '', temp)
        
        parts = [p.strip() for p in temp.split('.') if p.strip()]
        if len(parts) >= 2:
            publisher = parts[-1].strip(' ,')
            if publisher and not re.match(r'^\d+$', publisher):
                return publisher
        return None

    def determine_type(self, content, has_journal=False):
        """Determina il tipo di voce"""
        content_lower = content.lower()
        if has_journal or 'journal' in content_lower or 'rivista' in content_lower:
            return 'article'
        elif 'manual' in content_lower or 'manuale' in content_lower:
            return 'manual'
        elif 'proceedings' in content_lower or 'conference' in content_lower:
            return 'inproceedings'
        else:
            return 'book'

    def parse_bibitem(self, text):
        """Analizza una singola voce bibitem"""
        text = self.clean_text(text)
        
        # Estrai la chiave
        key_match = re.search(r'\\bibitem\{([^}]+)\}', text)
        if not key_match:
            return None
        
        key = key_match.group(1)
        content = re.sub(r'\\bibitem\{[^}]+\}', '', text).strip()
        
        # Estrai informazioni
        year = self.extract_year(content)
        title = self.extract_title(content)
        author = self.extract_author(content)
        publisher = self.extract_publisher(content)
        
        # Determina se è una rivista
        is_journal = any(word in content.lower() for word in ['journal', 'magazine', 'rivista'])
        entry_type = self.determine_type(content, is_journal)
        
        entry = {
            'key': key,
            'type': entry_type,
            'author': author,
            'title': title,
            'year': year,
            'publisher': publisher if not is_journal else None,
            'journal': publisher if is_journal else None
        }
        
        return entry

    def format_bibtex(self, entry):
        """Formatta una voce in BibTeX"""
        lines = [f"@{entry['type']}{{{entry['key']},"]
        
        field_order = ['author', 'title', 'journal', 'publisher', 'year']
        
        for field in field_order:
            if field in entry and entry[field]:
                value = entry[field].strip()
                if field == 'year':
                    lines.append(f"  {field} = {{{value}}},")
                else:
                    # Escape caratteri speciali
                    value = value.replace('&', '\\&')
                    lines.append(f"  {field} = {{{value}}},")
        
        # Rimuovi ultima virgola
        if lines[-1].endswith(','):
            lines[-1] = lines[-1][:-1]
        
        lines.append("}")
        return "\\n".join(lines)

    def is_valid_entry(self, entry):
        """Verifica se una voce è valida"""
        required_fields = {
            'book': ['author', 'title', 'publisher', 'year'],
            'article': ['author', 'title', 'journal', 'year'],
            'manual': ['title'],
            'inproceedings': ['author', 'title', 'year']
        }
        
        required = required_fields.get(entry['type'], ['title'])
        return all(entry.get(field) for field in required)

    def split_bibitems(self, content):
        """Divide il contenuto in voci bibitem"""
        pattern = r'(\\bibitem\{[^}]+\}.*?)(?=\\bibitem|\Z)'
        matches = re.findall(pattern, content, re.DOTALL)
        
        items = []
        for match in matches:
            cleaned = self.clean_text(match)
            if cleaned and '\\bibitem' in cleaned:
                items.append(cleaned)
        
        return items

    def convert_file(self, input_file, output_file=None):
        """Converte il file"""
        input_path = Path(input_file)
        
        if not input_path.exists():
            print(f"Errore: File '{input_file}' non trovato")
            return False
        
        # Leggi file
        try:
            with open(input_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(input_path, 'r', encoding='latin-1') as f:
                content = f.read()
        
        # Trova voci bibitem
        bibitems = self.split_bibitems(content)
        
        if not bibitems:
            print("Nessuna voce \\bibitem trovata")
            return False
        
        # Converti
        converted_entries = []
        
        for i, bibitem in enumerate(bibitems, 1):
            self.stats['processed'] += 1
            entry = self.parse_bibitem(bibitem)
            
            if entry:
                missing_fields = []
                if not self.is_valid_entry(entry):
                    # Identifica campi mancanti
                    required = {
                        'book': ['author', 'title', 'publisher', 'year'],
                        'article': ['author', 'title', 'journal', 'year'],
                        'manual': ['title'],
                        'inproceedings': ['author', 'title', 'year']
                    }.get(entry['type'], ['title'])
                    
                    missing_fields = [f for f in required if not entry.get(f)]
                    
                    self.problematic_items.append({
                        'key': entry['key'],
                        'type': entry['type'],
                        'missing': missing_fields,
                        'available': [k for k, v in entry.items() if v and k not in ['key', 'type']]
                    })
                
                formatted = self.format_bibtex(entry)
                converted_entries.append(formatted)
                self.stats['converted'] += 1
            else:
                self.stats['failed'] += 1
                self.excluded_items.append({
                    'number': i,
                    'reason': 'Parsing fallito'
                })
        
        # Scrivi output
        if output_file is None:
            output_file = input_path.with_suffix('.bib')
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write("% Bibliografia generata automaticamente\\n")
                f.write("% Convertitore LaTeX->BibTeX\\n\\n")
                f.write("\\n\\n".join(converted_entries))
                f.write("\\n")
            
            self.print_statistics()
            print(f"\\n✅ File salvato: {output_file}")
            return True
            
        except Exception as e:
            print(f"Errore nella scrittura: {e}")
            return False

    def print_statistics(self):
        """Stampa statistiche"""
        print(f"\\n{'='*60}")
        print("STATISTICHE CONVERSIONE")
        print(f"{'='*60}")
        print(f"Voci processate:    {self.stats['processed']}")
        print(f"Voci convertite:    {self.stats['converted']}")
        print(f"Voci fallite:       {self.stats['failed']}")
        print(f"Tasso successo:     {(self.stats['converted']/max(self.stats['processed'],1))*100:.1f}%")
        
        if self.excluded_items:
            print(f"\\n❌ VOCI ESCLUSE ({len(self.excluded_items)}):")
            print("-" * 40)
            for item in self.excluded_items:
                print(f"  Voce {item['number']}: {item['reason']}")
        
        if self.problematic_items:
            print(f"\\n⚠️  VOCI CON PROBLEMI ({len(self.problematic_items)}):")
            print("-" * 40)
            for item in self.problematic_items:
                print(f"  Chiave: '{item['key']}'")
                print(f"  Tipo: {item['type']}")
                print(f"  Campi mancanti: {', '.join(item['missing'])}")
                print(f"  Campi disponibili: {', '.join(item['available'])}")
                print()
        
        print(f"{'='*60}")

def main():
    if len(sys.argv) < 2:
        print("Uso: python convertitore.py <file.tex> [output.bib]")
        return
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    converter = BibConverter()
    converter.convert_file(input_file, output_file)

if __name__ == "__main__":
    main()
