import re
import csv
import datetime


def clean_latex(text):
    r"""Rimuove i comandi LaTeX mantenendo il testo contenuto."""
    # Per i collegamenti interessa soltanto il testo visualizzato, non il link.
    text = re.sub(r'\\(?:hyperlink|href)\{[^{}]*\}\{([^{}]*)\}', r'\1', text)
    text = re.sub(r'\\(?:begin|end)\{[^{}]*\}', '', text)
    text = re.sub(r'\\includegraphics(?:\[[^]]*\])?\{[^{}]*\}', '', text)
    text = re.sub(r'\\(?:resizedown|resizebox)\{[^{}]*\}(?:\{!\})?\{', '', text)

    # Ripete la sostituzione per gestire comandi annidati, ad esempio
    # \emph{\textbf{Nome}}.
    while True:
        text, replacements = re.subn(r'\\[a-zA-Z]+\{([^{}]*)\}', r'\1', text)
        if replacements == 0:
            break

    text = re.sub(r'\\[a-zA-Z]+', '', text)
    text = text.replace('\\\\', ' ')
    text = text.replace('{', '').replace('}', '')
    return ' '.join(text.split()).strip()


def extract_emphasized_blocks(text):
    r"""Estrae blocchi del tipo \emph{\textbf{Nome.}} descrizione."""
    marker = re.compile(r'\\emph\{\\textbf\{([^{}]+)\}')
    matches = list(marker.finditer(text))
    blocks = []

    for index, match in enumerate(matches):
        start = match.end()
        if text[start:start + 1] == '}':
            start += 1
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        blocks.append((match.group(1).strip(), text[start:end]))

    return blocks


def parse_tex_file(tex_file):
    with open(tex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    monster_data = []

    # Trova tutti i mostri usando il pattern \mostro{nome}
    mostro_pattern = r'\\mostro\{([^}]+)\}(.*?)(?=\\mostro\{|$)'
    mostro_matches = re.finditer(mostro_pattern, content, re.DOTALL)

    for match in mostro_matches:
        nome_mostro = match.group(1)
        block = match.group(2)
        
        if not block.strip():
            continue

        current_monster = {'Nome': nome_mostro}
        lines = block.split('\n')

        for line in lines:
            line = line.strip()

            item_match = re.search(r'\\item\[\\textbf\{([^}]+)\}\]\s*(.*)', line)
            if not item_match:
                continue

            label = item_match.group(1).rstrip(':').strip()
            value = clean_latex(item_match.group(2))

            if label == 'Taglia/Tipo':
                current_monster['Tipo'] = value
            elif label == 'Caratt.':
                caratt_match = re.search(
                    r'For\s+(\S+)(?:\s+\([^)]*\))?\s+'
                    r'Des\s+(\S+)(?:\s+\([^)]*\))?\s+'
                    r'Cos\s+(\S+)(?:\s+\([^)]*\))?\s+'
                    r'Int\s+(\S+)(?:\s+\([^)]*\))?\s+'
                    r'Sag\s+(\S+)(?:\s+\([^)]*\))?\s+'
                    r'Car\s+(\S+)(?:\s+\([^)]*\))?', value)
                if caratt_match:
                    for field, field_value in zip(
                            ('For', 'Des', 'Cos', 'Int', 'Sag', 'Car'),
                            caratt_match.groups()):
                        current_monster[field] = field_value
            elif label == 'Punti Ferita':
                pf_match = re.search(
                    r'(.+?),\s*Difesa:\s*([^,]+),\s*Iniziativa:\s*([^,]+)',
                    value)
                if pf_match:
                    pf_value = pf_match.group(1).strip()
                    numeric_pf = re.match(r'\d+', pf_value)
                    current_monster['PF'] = numeric_pf.group(0) if numeric_pf else pf_value
                    current_monster['Difesa'] = pf_match.group(2).strip()
                    current_monster['Iniziativa'] = pf_match.group(3).strip()
            elif label == 'Movimento':
                current_monster['Movimento'] = value
            elif label in ('Tiri Salvez.', 'Tiri Salvezza'):
                ts_match = re.search(
                    r'Tempra\s+(.+?),\s*Riflessi\s+(.+?),\s*Volontà\s+(.+)$',
                    value)
                if ts_match:
                    current_monster['TS_Tempra'] = ts_match.group(1).strip()
                    current_monster['TS_Riflessi'] = ts_match.group(2).strip()
                    current_monster['TS_Volonta'] = ts_match.group(3).strip()
            elif label in ('Comp.', 'Competenze'):
                current_monster['Competenze'] = value
            elif label == 'Incant.':
                current_monster['Incantesimi_Innati'] = value
            elif label == 'Res. Danni':
                current_monster['Res_Danni'] = value
            elif label == 'Imm. Danni':
                current_monster['Imm_Danni'] = value
            elif label == 'Immunità':
                current_monster['Immunita'] = value
            elif label == 'Vulnerabilità':
                current_monster['Vulnerabilita'] = value
            elif label == 'Sensi':
                current_monster['Sensi'] = value
            elif label == 'Linguaggi':
                current_monster['Linguaggi'] = value
            elif label == 'Sfida':
                sfida_match = re.search(r'(.+?)\s*\(([\d.]+)\s*PX\)', value)
                if sfida_match:
                    current_monster['Sfida'] = sfida_match.group(1).strip()
                    current_monster['PX'] = sfida_match.group(2).replace('.', '')
                elif value:
                    current_monster['Sfida'] = value

        # Estrai informazioni dalla sezione Ecologia (dopo la descrizione delle azioni)
        ecology_section = re.search(r'\\textbf{Ecologia}\\\\(.*?)(?=\\textbf{Descrizione}|\\mostro\{|$)', block, re.DOTALL)
        if ecology_section:
            ecology_text = ecology_section.group(1)
            
            # Estrai Ambiente
            ambiente_match = re.search(r'Ambiente:\s*([^\\]+)', ecology_text)
            if ambiente_match:
                current_monster['Ambiente'] = ambiente_match.group(1).strip()
            
            # Estrai Organizzazione  
            org_match = re.search(r'Organizzazione:\s*([^\\]+)', ecology_text)
            if org_match:
                current_monster['Organizzazione'] = org_match.group(1).strip()
                
            # Estrai Categoria Tesoro
            tesoro_match = re.search(r'\\textbf{Categoria Tesoro}:\s*([^\\]+)', ecology_text)
            if tesoro_match:
                current_monster['Categoria_Tesoro'] = tesoro_match.group(1).strip()

        # Estrai abilità speciali e sezioni nominate prima delle Azioni.
        abilities_section = re.search(r'\\end{description}(.*?)\\textbf{Azioni}', block, re.DOTALL)
        if abilities_section:
            abilities_text = abilities_section.group(1)
            special_abilities = []
            for ability_name, ability_desc in extract_emphasized_blocks(abilities_text):
                ability_name = ability_name.rstrip('.').strip()
                ability_clean = clean_latex(ability_desc)
                if not ability_clean:
                    continue
                if ability_name.startswith('Incantesimi Innati'):
                    current_monster['Incantesimi_Innati'] = clean_latex(
                        f"{current_monster.get('Incantesimi_Innati', '')} {ability_clean}")
                elif ability_name == 'Incantesimi':
                    current_monster['Incantesimi'] = ability_clean[:800]
                elif ability_name in ('Resistenza Leggendaria', 'Presenza Spaventosa',
                                      'Aura Speciale', 'Costruzione'):
                    current_monster[ability_name.replace(' ', '_')] = ability_clean[:400]
                elif ability_name != 'Arrabbiato:':
                    special_abilities.append(f"{ability_name}: {ability_clean}")
            
            if special_abilities:
                current_monster['Abilita_Speciali'] = '; '.join(special_abilities)[:800]

        # Estrai azioni (tra \textbf{Azioni} e \textbf{Ecologia} o altra sezione)
        actions_section = re.search(
            r'\\textbf\{Azioni\}(.*?)(?=\\textbf\{Ecologia\}|'
            r'\\textbf\{Azioni Aggiuntive\}|\\mostro\{|$)',
            block, re.DOTALL)
        if actions_section:
            actions_text = actions_section.group(1)
            action_list = []
            for action_name, action_desc in extract_emphasized_blocks(actions_text):
                action_name = action_name.rstrip('.').strip()
                if action_name.startswith('Arrabbiato:'):
                    continue
                action_desc = re.sub(
                    r'\\textbf\{Reazione:\s*\\emph\{[^{}]+\}\}\s*:?.*?(?='
                    r'\\emph\{\\textbf\{|$)',
                    '', action_desc, flags=re.DOTALL)
                action_clean = clean_latex(action_desc)
                if action_clean:
                    action_list.append(f"{action_name}: {action_clean}")
            
            if action_list:
                current_monster['Azioni'] = '; '.join(action_list)[:1000]

        # Estrai reazioni eventualmente presenti prima di Ecologia.
        reaction_matches = re.finditer(
            r'\\textbf\{Reazione:\s*\\emph\{([^{}]+)\}\}\s*:?(.*?)(?='
            r'\\textbf\{Reazione:|\\emph\{\\textbf\{|\\textbf\{Ecologia\}|'
            r'\\mostro\{|$)',
            block, re.DOTALL)
        reaction_list = []
        for reaction_match in reaction_matches:
            reaction_name = reaction_match.group(1).strip()
            reaction_desc = clean_latex(reaction_match.group(2))
            if reaction_desc:
                reaction_list.append(f"{reaction_name}: {reaction_desc}")
        if reaction_list:
            current_monster['Reazioni'] = '; '.join(reaction_list)[:800]

        # Estrai azioni aggiuntive
        additional_actions = re.search(r'\\textbf{Azioni Aggiuntive}(.*?)(?=\\textbf{Ecologia}|\\mostro\{|$)', block, re.DOTALL)
        if additional_actions:
            add_actions_text = additional_actions.group(1)
            add_actions_clean = clean_latex(add_actions_text)
            if add_actions_clean.strip():
                current_monster['Azioni_Aggiuntive'] = add_actions_clean.strip()[:400]

        # Estrai sezione "Arrabbiato" specifica per alcuni mostri
        angry_section = re.search(r'\\emph\{\\textbf{Arrabbiato:}\}(.*?)(?=\\textbf{Ecologia}|\\mostro\{|$)', block, re.DOTALL)
        if angry_section:
            angry_text = angry_section.group(1)
            angry_clean = clean_latex(angry_text)
            if angry_clean.strip():
                current_monster['Arrabbiato'] = angry_clean.strip()[:300]

        # Aggiungi il mostro alla lista
        monster_data.append(current_monster)

    return monster_data

def write_to_csv(monster_data, csv_file):
    # Header aggiornato con tutti i campi possibili
    header = ['Nome', 'Tipo', 'Difesa', 'PF', 'TS_Tempra', 'TS_Riflessi', 'TS_Volonta',
              'For', 'Des', 'Cos', 'Int', 'Sag', 'Car', 'Iniziativa', 'Movimento',
              'Competenze', 'Incantesimi_Innati', 'Res_Danni', 'Imm_Danni', 'Immunita', 'Vulnerabilita',
              'Sensi', 'Linguaggi', 'Sfida', 'PX', 'Ambiente', 'Organizzazione', 
              'Categoria_Tesoro', 'Azioni', 'Abilita_Speciali', 'Reazioni', 
              'Incantesimi', 'Arrabbiato', 'Azioni_Aggiuntive', 'Resistenza_Leggendaria',
              'Presenza_Spaventosa', 'Aura_Speciale', 'Costruzione']

    # Ottieni timestamp UTC
    timestamp = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%d %H:%M:%S")
    username = "Andres Zanzani"
    
    with open(csv_file, 'w', newline='', encoding='utf-8') as f:
        f.write(f'# Generato da {username} il {timestamp} UTC\n')
        writer = csv.DictWriter(f, fieldnames=header, delimiter='|', restval='')
        writer.writeheader()
        for monster in monster_data:
            row = {k: monster.get(k, '') for k in header}
            writer.writerow(row)

    print(f"Dati estratti e salvati in '{csv_file}'")
    print(f"Numero di mostri trovati: {len(monster_data)}")

# Esecuzione dello script
if __name__ == "__main__":
    tex_file = 'OBSSv2.tex'  # Modifica con il nome del tuo file
    csv_file = 'mostri_data.csv'
    
    try:
        monster_data = parse_tex_file(tex_file)
        if monster_data:
            write_to_csv(monster_data, csv_file)
            
            # Stampa un riepilogo dei mostri trovati
            print("\nPrimi 10 mostri estratti:")
            for i, monster in enumerate(monster_data[:10], 1):
                print(f"{i}. {monster.get('Nome', 'Nome sconosciuto')} - Sfida: {monster.get('Sfida', 'N/A')}")
                
            print(f"\n... e altri {len(monster_data)-10} mostri")
        else:
            print("Nessun mostro trovato nel file.")
            
    except FileNotFoundError:
        print(f"Errore: File '{tex_file}' non trovato.")
    except Exception as e:
        print(f"Errore durante l'elaborazione: {e}")
