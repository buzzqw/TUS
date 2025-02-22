import re
import csv

def parse_tex_file(tex_file):
    with open(tex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    monster_data = []
    blocks = content.split('\\rule{\\linewidth}{2pt}')  # Split by the separator
    
    for block in blocks:
        lines = block.split('\n')
        current_monster = {}
        
        for line in lines:
            line = line.strip()
            if line.startswith('\\index[Mostruario]'):
                current_monster['Nome'] = line.split('{')[1].split('}')[0]
            elif '\\item[\\textbf{Tipo:}]' in line:
                current_monster['Tipo'] = line.split('}]')[1].strip()
            elif '\\item[\\textbf{Caratt.:}]' in line:
                caratt = line.split('}]')[1].strip()
                # Extract individual stats using regex
                stats_pattern = r'For (-?\d+) Des (-?\d+) Cos (-?\d+) Int (-?\d+) Sag (-?\d+) Car (-?\d+)'
                stats_match = re.search(stats_pattern, caratt)
                if stats_match:
                    current_monster['For'] = stats_match.group(1)
                    current_monster['Des'] = stats_match.group(2)
                    current_monster['Cos'] = stats_match.group(3)
                    current_monster['Int'] = stats_match.group(4)
                    current_monster['Sag'] = stats_match.group(5)
                    current_monster['Car'] = stats_match.group(6)
            elif '\\item[\\textbf{Punti Ferita:}]' in line:
                # Extract all values from the line
                full_line = line.split('}]')[1].strip()
                
                # Extract PF
                pf_match = re.search(r'(\d+),\s*\\textbf{Difesa:', full_line)
                if pf_match:
                    current_monster['PF'] = pf_match.group(1)
                
                # Extract Difesa
                difesa_match = re.search(r'Difesa:\}\s*(\d+)', full_line)
                if difesa_match:
                    current_monster['Difesa'] = difesa_match.group(1)
                
                # Extract Iniziativa
                iniziativa_match = re.search(r'Iniziativa:\}\s*([+-]?\d+)', full_line)
                if iniziativa_match:
                    current_monster['Iniziativa'] = iniziativa_match.group(1)
            elif '\\item[\\textbf{Tiri Salvezza:}]' in line:
                ts_part = line.split('}]')[1].strip()
                # Extract saving throws using regex
                tempra_match = re.search(r'Tempra ([+-]?\d+)', ts_part)
                riflessi_match = re.search(r'Riflessi ([+-]?\d+)', ts_part)
                volonta_match = re.search(r'Volontà ([+-]?\d+)', ts_part)
                
                if tempra_match:
                    current_monster['TS_Tempra'] = tempra_match.group(1)
                if riflessi_match:
                    current_monster['TS_Riflessi'] = riflessi_match.group(1)
                if volonta_match:
                    current_monster['TS_Volonta'] = volonta_match.group(1)
            elif '\\item[\\textbf{Sfida:}]' in line:
                sfida_match = re.search(r'Sfida:\s*(\d+)', line)
                if sfida_match:
                    current_monster['Sfida'] = sfida_match.group(1)
        
        if current_monster:
            monster_data.append(current_monster)
    
    return monster_data

def write_to_csv(monster_data, csv_file):
    header = ['Nome', 'Tipo', 'Difesa', 'PF', 'TS_Tempra', 'TS_Riflessi', 'TS_Volonta', 
              'For', 'Des', 'Cos', 'Int', 'Sag', 'Car', 'Iniziativa', 'Sfida']
    with open(csv_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=header, restval='')
        writer.writeheader()
        for monster in monster_data:
            row = {k: monster.get(k, '') for k in header}  # Handle missing keys
            writer.writerow(row)
    print(f"Data extracted and saved to '{csv_file}'")

# Example usage:
tex_file = 'OBSSv2.tex'
csv_file = 'mostri_data.csv'
monster_data = parse_tex_file(tex_file)
write_to_csv(monster_data, csv_file)
