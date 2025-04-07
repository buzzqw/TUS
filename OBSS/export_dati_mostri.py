import re
import csv
import datetime

def parse_tex_file(tex_file):
    with open(tex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    monster_data = []

    blocks = re.split(r'\\smallskip\\noindent\\rule{\\linewidth}{2pt}', content)

    for block in blocks:
        if not block.strip():
            continue

        lines = block.split('\n')
        current_monster = {}

        name_match = re.search(r'\\index\[Mostruario\]\{([^}]+)\}', block)
        if name_match:
            current_monster['Nome'] = name_match.group(1)

        for line in lines:
            line = line.strip()

            if '\\item[\\textbf{Tipo:}]' in line:
                tipo_match = re.search(r'\\item\[\\textbf{Tipo:}\](.*)', line)
                if tipo_match:
                    current_monster['Tipo'] = tipo_match.group(1).strip()

            elif '\\item[\\textbf{Caratt.:}]' in line:
                caratt_match = re.search(r'\\item\[\\textbf{Caratt.:}\]\s*For\s+(-?\d+)\s+Des\s+(-?\d+)\s+Cos\s+(-?\d+)\s+Int\s+(-?\d+)\s+Sag\s+(-?\d+)\s+Car\s+(-?\d+)', line)
                if caratt_match:
                    current_monster['For'] = caratt_match.group(1)
                    current_monster['Des'] = caratt_match.group(2)
                    current_monster['Cos'] = caratt_match.group(3)
                    current_monster['Int'] = caratt_match.group(4)
                    current_monster['Sag'] = caratt_match.group(5)
                    current_monster['Car'] = caratt_match.group(6)

            elif '\\item[\\textbf{Punti Ferita:}]' in line:
                pf_match = re.search(r'\\item\[\\textbf{Punti Ferita:}\]\s*(\d+),\s*\\textbf{Difesa:}\s*(\d+),\s*\\textbf{Iniziativa:}\s*([+-]?\d+)', line)
                if pf_match:
                    current_monster['PF'] = pf_match.group(1)
                    current_monster['Difesa'] = pf_match.group(2)
                    current_monster['Iniziativa'] = pf_match.group(3)

            elif '\\item[\\textbf{Tiri Salvezza:}]' in line:
                if '\\resizebox' in line:
                    ts_match = re.search(r'\\resizebox{[^}]+}{!}{Tempra\s+([+-]?\d+),\s*Riflessi\s+([+-]?\d+),\s*Volontà\s+([+-]?\d+)}', line)
                else:
                    ts_match = re.search(r'\\item\[\\textbf{Tiri Salvezza:}\]\s*Tempra\s+([+-]?\d+),\s*Riflessi\s+([+-]?\d+),\s*Volontà\s+([+-]?\d+)', line)
                if ts_match:
                    current_monster['TS_Tempra'] = ts_match.group(1)
                    current_monster['TS_Riflessi'] = ts_match.group(2)
                    current_monster['TS_Volonta'] = ts_match.group(3)

            elif '\\item[\\textbf{Competenze:}]' in line:
                comp_match = re.search(r'\\item\[\\textbf{Competenze:}\]\s*(.*)', line)
                if comp_match:
                    current_monster['Competenze'] = comp_match.group(1).strip()

            elif '\\item[\\textbf{Res. Danni:}]' in line:
                res_match = re.search(r'\\item\[\\textbf{Res. Danni:}\]\s*(.*)', line)
                if res_match:
                    current_monster['Res_Danni'] = res_match.group(1).strip()

            elif '\\item[\\textbf{Imm. Danni:}]' in line:
                imm_match = re.search(r'\\item\[\\textbf{Imm. Danni:}\]\s*(.*)', line)
                if imm_match:
                    current_monster['Imm_Danni'] = imm_match.group(1).strip()

            elif '\\item[\\textbf{Immunità:}]' in line:
                immunita_match = re.search(r'\\item\[\\textbf{Immunità:}\]\s*(.*)', line)
                if immunita_match:
                    current_monster['Immunita'] = immunita_match.group(1).strip()

            elif '\\item[\\textbf{Sensi:}]' in line:
                sensi_match = re.search(r'\\item\[\\textbf{Sensi:}\]\s*(.*)', line)
                if sensi_match:
                    current_monster['Sensi'] = sensi_match.group(1).strip()

            elif '\\item[\\textbf{Linguaggi:}]' in line:
                linguaggi_match = re.search(r'\\item\[\\textbf{Linguaggi:}\]\s*(.*)', line)
                if linguaggi_match:
                    current_monster['Linguaggi'] = linguaggi_match.group(1).strip()

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
              'For', 'Des', 'Cos', 'Int', 'Sag', 'Car', 'Iniziativa',
              'Competenze', 'Res_Danni', 'Imm_Danni', 'Immunita',
              'Sensi', 'Linguaggi', 'Sfida', 'PX']

    # Get current UTC timestamp
    timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    username = "Andres Zanzani"
    
    with open(csv_file, 'w', newline='', encoding='utf-8') as f:
        f.write(f'# Generato da {username} il {timestamp} UTC\n')
        writer = csv.DictWriter(f, fieldnames=header, delimiter='|', restval='')
        writer.writeheader()
        for monster in monster_data:
            row = {k: monster.get(k, '') for k in header}
            writer.writerow(row)

    print(f"Dati estratti e salvati in '{csv_file}'")

tex_file = 'OBSSv2.tex'
csv_file = 'mostri_data.csv'
monster_data = parse_tex_file(tex_file)
write_to_csv(monster_data, csv_file)
