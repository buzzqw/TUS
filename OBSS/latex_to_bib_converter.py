#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Convertitore da bibliografia LaTeX (formato \bibitem) a formato BibTeX (.bib)
"""

import re
import sys
from pathlib import Path

def clean_latex_text(text):
    """
    Pulisce il testo da comandi LaTeX non necessari in BibTeX
    """
    # Rimuovi commenti LaTeX
    text = re.sub(r'%.*$', '', text, flags=re.MULTILINE)
    # Pulisci whitespace multipli
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def parse_authors(author_text):
    """
    Analizza e formatta correttamente gli autori
    """
    # Rimuovi il simbolo & LaTeX e sostituisci con 'and'
    author_text = re.sub(r'\\&', 'and', author_text)
    
    # Pattern per diversi formati di autori
    authors = []
    
    # Se contiene "and" esplicito, splittalo
    if ' and ' in author_text:
        author_parts = author_text.split(' and ')
        for part in author_parts:
            part = part.strip(' ,')
            if part and not part.isspace():
                authors.append(part)
    else:
        # Singolo autore
        author_text = author_text.strip(' ,')
        if author_text and not author_text.isspace():
            authors.append(author_text)
    
    return ' and '.join(authors)

def parse_bibitem(bibitem_text):
    """
    Estrae le informazioni da una voce \bibitem e le converte in formato BibTeX
    """
    # Pulisci il testo
    bibitem_text = clean_latex_text(bibitem_text)
    
    # Estrai la chiave della citazione
    key_match = re.search(r'\\bibitem\{([^}]+)\}', bibitem_text)
    if not key_match:
        return None
    
    key = key_match.group(1)
    
    # Rimuovi il comando \bibitem per analizzare il resto
    content = re.sub(r'\\bibitem\{[^}]+\}', '', bibitem_text).strip()
    
    # Inizializza i campi
    entry = {'key': key, 'type': 'book'}  # Default type
    
    # Trova l'anno tra parentesi
    year_match = re.search(r'\(.*?(\d{4}).*?\)', content)
    if year_match:
        entry['year'] = year_match.group(1)
        # Rimuovi l'anno dal contenuto per analisi successive
        content = re.sub(r'\([^)]*\d{4}[^)]*\)', '', content)
    
    # Trova il titolo in corsivo
    title_match = re.search(r'\\textit\{([^}]+)\}', content)
    if title_match:
        entry['title'] = title_match.group(1)
        # Rimuovi il titolo dal contenuto
        content = re.sub(r'\\textit\{[^}]+\}', '', content)
    
    # Il resto dovrebbe essere autore all'inizio e editore alla fine
    # Dividi per punti e analizza
    parts = [p.strip() for p in content.split('.') if p.strip()]
    
    if parts:
        # Il primo pezzo dovrebbe essere l'autore
        potential_author = parts[0].strip(' ,')
        if potential_author:
            entry['author'] = parse_authors(potential_author)
        
        # L'ultimo pezzo dovrebbe essere l'editore
        if len(parts) > 1:
            potential_publisher = parts[-1].strip(' ,')
            if potential_publisher and not re.match(r'^\d{4}$', potential_publisher):
                entry['publisher'] = potential_publisher
    
    # Determina il tipo di voce
    content_lower = content.lower()
    title_lower = entry.get('title', '').lower()
    
    if 'manuale' in title_lower or 'manual' in title_lower:
        entry['type'] = 'manual'
    elif 'magazine' in content_lower or 'rivista' in content_lower:
        entry['type'] = 'article'
        # Per gli articoli, il "publisher" dovrebbe essere "journal"
        if 'publisher' in entry:
            entry['journal'] = entry['publisher']
            del entry['publisher']
    
    return entry

def format_bib_entry(entry):
    """
    Formatta una voce nel formato BibTeX corretto
    """
    if not entry:
        return ""
    
    lines = [f"@{entry['type']}{{{entry['key']},"]
    
    # Ordine preferito dei campi
    field_order = ['author', 'title', 'journal', 'year', 'publisher', 'edition', 'address', 'note']
    
    for field in field_order:
        if field in entry and entry[field]:
            value = entry[field].strip()
            if value:
                if field == 'year':
                    lines.append(f"  {field} = {{{value}}},")
                else:
                    # Escape delle parentesi graffe e altri caratteri speciali
                    value = value.replace('{', '\\{').replace('}', '\\}')
                    lines.append(f"  {field} = {{{value}}},")
    
    # Rimuovi l'ultima virgola
    if lines[-1].endswith(','):
        lines[-1] = lines[-1][:-1]
    
    lines.append("}")
    return "\n".join(lines)

def split_bibitems(content):
    """
    Divide il contenuto in singole voci bibitem, gestendo meglio i commenti
    """
    # Rimuovi i commenti di sezione che non appartengono a nessuna voce
    content = re.sub(r'^\s*%[^\\]*$', '', content, flags=re.MULTILINE)
    
    # Trova tutte le voci \bibitem
    items = []
    pattern = r'(\\bibitem\{[^}]+\}.*?)(?=\\bibitem|\Z)'
    matches = re.findall(pattern, content, re.DOTALL)
    
    for match in matches:
        # Pulisci ogni voce dai commenti interni
        cleaned = re.sub(r'%.*$', '', match, flags=re.MULTILINE)
        # Rimuovi linee vuote eccessive
        cleaned = re.sub(r'\n\s*\n', '\n', cleaned)
        if cleaned.strip():
            items.append(cleaned.strip())
    
    return items

def convert_latex_to_bib(input_file, output_file=None):
    """
    Converte un file LaTeX con \bibitem in formato BibTeX
    """
    # Leggi il file di input
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Errore: File '{input_file}' non trovato.")
        return False
    except UnicodeDecodeError:
        # Prova con encoding latin-1 se UTF-8 fallisce
        with open(input_file, 'r', encoding='latin-1') as f:
            content = f.read()
    
    # Dividi in voci bibitem
    bibitems = split_bibitems(content)
    
    if not bibitems:
        print("Nessuna voce \\bibitem trovata nel file.")
        return False
    
    # Converti ogni bibitem
    bib_entries = []
    failed_entries = []
    
    for i, bibitem in enumerate(bibitems):
        try:
            entry = parse_bibitem(bibitem)
            if entry:
                formatted = format_bib_entry(entry)
                if formatted:
                    bib_entries.append(formatted)
                else:
                    failed_entries.append(f"Voce {i+1}: formattazione fallita")
            else:
                failed_entries.append(f"Voce {i+1}: parsing fallito")
        except Exception as e:
            failed_entries.append(f"Voce {i+1}: errore {str(e)}")
    
    # Genera il file di output
    if output_file is None:
        input_path = Path(input_file)
        output_file = input_path.with_suffix('.bib')
    
    # Scrivi il file BibTeX
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("% Bibliografia generata automaticamente dal convertitore LaTeX->BibTeX\n")
            f.write("% Compatibile con biblatex e backend biber\n")
            f.write("% VERSIONE CORRETTA - Sintassi BibTeX valida\n\n")
            f.write("\n\n".join(bib_entries))
            f.write("\n")
        
        print(f"Conversione completata! File generato: {output_file}")
        print(f"Voci convertite con successo: {len(bib_entries)}")
        
        if failed_entries:
            print(f"Voci con problemi: {len(failed_entries)}")
            for error in failed_entries:
                print(f"  - {error}")
        
        return True
        
    except Exception as e:
        print(f"Errore nella scrittura del file: {e}")
        return False

def fix_existing_bib_file(input_file, output_file=None):
    """
    Corregge un file .bib esistente che ha errori di sintassi
    """
    if output_file is None:
        path = Path(input_file)
        output_file = path.parent / f"{path.stem}_corrected{path.suffix}"
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Errore nella lettura del file: {e}")
        return False
    
    # Correggi problemi comuni
    fixed_content = content
    
    # 1. Correggi autori malformati
    fixed_content = re.sub(r'author = \{([^}]*) and ([^}]*) and \\& ([^}]*) and ([^}]*)\}', 
                          r'author = {\1 and \2 and \3 and \4}', fixed_content)
    
    # 2. Rimuovi simboli LaTeX problematici negli autori
    fixed_content = re.sub(r'\\&', 'and', fixed_content)
    
    # 3. Correggi publisher con commenti inclusi
    def fix_publisher(match):
        publisher = match.group(1)
        # Rimuovi tutto dopo il primo commento %
        publisher = re.sub(r'%.*$', '', publisher, flags=re.MULTILINE)
        # Rimuovi newline e whitespace extra
        publisher = re.sub(r'\s+', ' ', publisher).strip()
        return f'publisher = {{{publisher}}}'
    
    fixed_content = re.sub(r'publisher = \{([^}]*)\}', fix_publisher, fixed_content)
    
    # 4. Assicurati che ogni entry termini correttamente
    entries = re.findall(r'@\w+\{[^@]*\}', fixed_content, re.DOTALL)
    
    corrected_entries = []
    for entry in entries:
        # Rimuovi commenti interni
        entry = re.sub(r'%.*$', '', entry, flags=re.MULTILINE)
        # Pulisci whitespace
        entry = re.sub(r'\n\s*\n', '\n', entry)
        entry = entry.strip()
        
        # Assicurati che termini con }
        if not entry.endswith('}'):
            entry += '\n}'
        
        corrected_entries.append(entry)
    
    # Scrivi il file corretto
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("% Bibliografia corretta automaticamente\n")
            f.write("% Compatibile con biblatex e backend biber\n\n")
            f.write("\n\n".join(corrected_entries))
            f.write("\n")
        
        print(f"File corretto salvato come: {output_file}")
        print(f"Voci processate: {len(corrected_entries)}")
        return True
        
    except Exception as e:
        print(f"Errore nella scrittura del file corretto: {e}")
        return False

def main():
    """
    Funzione principale - può essere usata da linea di comando
    """
    if len(sys.argv) < 2:
        print("Uso:")
        print("  python convertitore.py <file.tex>           # Converte da LaTeX")
        print("  python convertitore.py --fix <file.bib>     # Corregge un file .bib")
        print("\nEsempio per correggere il tuo file:")
        print("  python convertitore.py --fix bibliografia.bib")
        return
    
    if sys.argv[1] == '--fix':
        if len(sys.argv) < 3:
            print("Errore: specificare il file .bib da correggere")
            return
        fix_existing_bib_file(sys.argv[2])
    else:
        input_file = sys.argv[1]
        output_file = sys.argv[2] if len(sys.argv) > 2 else None
        convert_latex_to_bib(input_file, output_file)

if __name__ == "__main__":
    main()
