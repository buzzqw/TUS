import re
import csv

def parse_tex_file(tex_file):
    with open(tex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    monster_data = []
    
    # Modifica il separatore per corrispondere al formato del documento
    blocks = re.split(r'\\smallskip\\noindent\\rule{\\linewidth}{2pt}', content)
    
    for block in blocks:
        if not block.strip():
            continue
            
        lines = block.split('\n')
        current_monster = {}
        
        # Estrai il nome del mostro
        name_match = re.search(r'\\index\[Mostruario\]{([^}]+)}', block)
        if name_match:
            current_monster['Nome'] = name_match.group(1)
        
        for line in lines:
            line = line.strip()
            
            # Tipo
            if '\\item[\\textbf{Tipo:}]' in line:
                tipo_match = re.search(r'\\item\[\\textbf{Tipo:}\](.*)', line)
                if tipo_match:
                    current_monster['Tipo'] = tipo_match.group(1).strip()
            
            # Caratteristiche
            elif '\\item[\\textbf{Caratt.:}]' in line:
                caratt_match = re.search(r'\\item\[\\textbf{Caratt.:}\]\s*For\s+(-?\d+)\s+Des\s+(-?\d+)\s+Cos\s+(-?\d+)\s+Int\s+(-?\d+)\s+Sag\s+(-?\d+)\s+Car\s+(-?\d+)', line)
                if caratt_match:
                    current_monster['For'] = caratt_match.group(1)
                    current_monster['Des'] = caratt_match.group(2)
                    current_monster['Cos'] = caratt_match.group(3)
                    current_monster['Int'] = caratt_match.group(4)
                    current_monster['Sag'] = caratt_match.group(5)
                    current_monster['Car'] = caratt_match.group(6)
            
            # Punti Ferita, Difesa, Iniziativa
            elif '\\item[\\textbf{Punti Ferita:}]' in line:
                pf_match = re.search(r'\\item\[\\textbf{Punti Ferita:}\]\s*(\d+),\s*\\textbf{Difesa:}\s*(\d+),\s*\\textbf{Iniziativa:}\s*([+-]?\d+)', line)
                if pf_match:
                    current_monster['PF'] = pf_match.group(1)
                    current_monster['Difesa'] = pf_match.group(2)
                    current_monster['Iniziativa'] = pf_match.group(3)
            
            # Tiri Salvezza - gestione dei casi con \resizebox
            elif '\\item[\\textbf{Tiri Salvezza:}]' in line:
                # Cerca prima il pattern con resizebox
                if '\\resizebox' in line:
                    ts_match = re.search(r'\\resizebox.*?{Tempra\s+([+-]?\d+),\s*Riflessi\s+([+-]?\d+),\s*Volontà\s+([+-]?\d+)}', line)
                    if ts_match:
                        current_monster['TS_Tempra'] = ts_match.group(1)
                        current_monster['TS_Riflessi'] = ts_match.group(2)
                        current_monster['TS_Volonta'] = ts_match.group(3)
                else:
                    # Pattern standard senza resizebox
                    ts_match = re.search(r'\\item\[\\textbf{Tiri Salvezza:}\]\s*Tempra\s+([+-]?\d+),\s*Riflessi\s+([+-]?\d+),\s*Volontà\s+([+-]?\d+)', line)
                    if ts_match:
                        current_monster['TS_Tempra'] = ts_match.group(1)
                        current_monster['TS_Riflessi'] = ts_match.group(2)
                        current_monster['TS_Volonta'] = ts_match.group(3)
            
            # Sfida e PX - migliorato per catturare correttamente i valori
            elif '\\item[\\textbf{Sfida:}]' in line:
                sfida_match = re.search(r'\\item\[\\textbf{Sfida:}\]\s*([\d/]+)\s*\((\d+)\s*PX\)', line)
                if sfida_match:
                    current_monster['Sfida'] = sfida_match.group(1)
                    current_monster['PX'] = sfida_match.group(2)
        
        if current_monster and 'Nome' in current_monster:
            monster_data.append(current_monster)
    
    return monster_data

def write_to_csv(monster_data, csv_file):
    header = ['Nome', 'Tipo', 'Difesa', 'PF', 'TS_Tempra', 'TS_Riflessi', 'TS_Volonta', 
              'For', 'Des', 'Cos', 'Int', 'Sag', 'Car', 'Iniziativa', 'Sfida', 'PX']
    
    with open(csv_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=header, restval='')
        writer.writeheader()
        for monster in monster_data:
            row = {k: monster.get(k, '') for k in header}  # Gestisce le chiavi mancanti
            writer.writerow(row)
    
    print(f"Dati estratti e salvati in '{csv_file}'")

# Esempio d'uso:
tex_file = 'OBSSv2.tex'
csv_file = 'mostri_data.csv'
monster_data = parse_tex_file(tex_file)
write_to_csv(monster_data, csv_file)
