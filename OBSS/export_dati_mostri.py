import re
import csv
import datetime

def parse_tex_file(tex_file):
    with open(tex_file, 'r', encoding='utf-8') as f:
        content = f.read()
    monster_data = []

    # Dividi il contenuto usando il separatore dei mostri
    blocks = re.split(r'\\smallskip\\noindent\\rule{\\linewidth}{2pt}', content)

    for block in blocks:
        if not block.strip():
            continue

        lines = block.split('\n')
        current_monster = {}

        # Estrai il nome del mostro
        name_match = re.search(r'\\index\[Mostruario\]\{([^}]+)\}', block)
        if name_match:
            current_monster['Nome'] = name_match.group(1)
        else:
            # Se non trova il nome con \index, cerca con \textbf
            name_match = re.search(r'\\noindent\{\\large\\textbf\{([^}]+)\}\}', block)
            if name_match:
                current_monster['Nome'] = name_match.group(1)

        for line in lines:
            line = line.strip()

            # Estrai Taglia/Tipo
            if '\\item[\\textbf{Taglia/Tipo:}]' in line:
                tipo_match = re.search(r'\\item\[\\textbf{Taglia/Tipo:}\]\s*(.*)', line)
                if tipo_match:
                    current_monster['Tipo'] = tipo_match.group(1).strip()

            # Estrai le caratteristiche - gestisce sia il formato normale che quello con \resizebox
            elif '\\item[\\textbf{Caratt.:}]' in line:
                if '\\resizebox' in line:
                    caratt_match = re.search(r'\\resizebox{[^}]+}{!}{For\s+(-?\d+)\s+Des\s+(-?\d+)\s+Cos\s+(-?\d+)\s+Int\s+(-?\d+)\s+Sag\s+(-?\d+)\s+Car\s+(-?\d+)}', line)
                else:
                    caratt_match = re.search(r'\\item\[\\textbf{Caratt.:}\]\s*For\s+(-?\d+)\s+Des\s+(-?\d+)\s+Cos\s+(-?\d+)\s+Int\s+(-?\d+)\s+Sag\s+(-?\d+)\s+Car\s+(-?\d+)', line)
                
                if caratt_match:
                    current_monster['For'] = caratt_match.group(1)
                    current_monster['Des'] = caratt_match.group(2)
                    current_monster['Cos'] = caratt_match.group(3)
                    current_monster['Int'] = caratt_match.group(4)
                    current_monster['Sag'] = caratt_match.group(5)
                    current_monster['Car'] = caratt_match.group(6)

            # Estrai Punti Ferita, Difesa e Iniziativa
            elif '\\item[\\textbf{Punti Ferita:}]' in line:
                pf_match = re.search(r'\\item\[\\textbf{Punti Ferita:}\]\s*(\d+),\s*\\textbf{Difesa:}\s*(\d+),\s*\\textbf{Iniziativa:}\s*([+-]?\d+)', line)
                if pf_match:
                    current_monster['PF'] = pf_match.group(1)
                    current_monster['Difesa'] = pf_match.group(2)
                    current_monster['Iniziativa'] = pf_match.group(3)

            # Estrai Movimento
            elif '\\item[\\textbf{Movimento:}]' in line:
                movimento_match = re.search(r'\\item\[\\textbf{Movimento:}\]\s*(.*)', line)
                if movimento_match:
                    current_monster['Movimento'] = movimento_match.group(1).strip()

            # Estrai Tiri Salvezza - gestisce sia formato normale che \resizebox
            elif '\\item[\\textbf{Tiri Salvez.:}]' in line or '\\item[\\textbf{Tiri Salvezza:}]' in line:
                if '\\resizebox' in line:
                    # Gestisce i \resizebox annidati
                    ts_match = re.search(r'Tempra\s+([+-]?\d+),\s*Riflessi\s+([+-]?\d+),\s*Volontà\s+([+-]?\d+)', line)
                else:
                    ts_match = re.search(r'\\item\[\\textbf{Tiri Salve[zZ][^:]*:\]\s*Tempra\s+([+-]?\d+),\s*Riflessi\s+([+-]?\d+),\s*Volontà\s+([+-]?\d+)', line)
                
                if ts_match:
                    current_monster['TS_Tempra'] = ts_match.group(1)
                    current_monster['TS_Riflessi'] = ts_match.group(2)
                    current_monster['TS_Volonta'] = ts_match.group(3)

            # Estrai Competenze (nuovo campo)
            elif '\\item[\\textbf{Comp.:}]' in line or '\\item[\\textbf{Competenze:}]' in line:
                comp_match = re.search(r'\\item\[\\textbf{Comp[^:]*:\]\s*(.*)', line)
                if comp_match:
                    current_monster['Competenze'] = comp_match.group(1).strip()

            # Estrai Resistenza Danni
            elif '\\item[\\textbf{Res. Danni:}]' in line:
                res_match = re.search(r'\\item\[\\textbf{Res. Danni:}\]\s*(.*)', line)
                if res_match:
                    current_monster['Res_Danni'] = res_match.group(1).strip()

            # Estrai Immunità Danni
            elif '\\item[\\textbf{Imm. Danni:}]' in line:
                imm_match = re.search(r'\\item\[\\textbf{Imm. Danni:}\]\s*(.*)', line)
                if imm_match:
                    current_monster['Imm_Danni'] = imm_match.group(1).strip()

            # Estrai Immunità
            elif '\\item[\\textbf{Immunità:}]' in line:
                immunita_match = re.search(r'\\item\[\\textbf{Immunità:}\]\s*(.*)', line)
                if immunita_match:
                    current_monster['Immunita'] = immunita_match.group(1).strip()

            # Estrai Vulnerabilità (nuovo campo)
            elif '\\item[\\textbf{Vulnerabilità:}]' in line:
                vuln_match = re.search(r'\\item\[\\textbf{Vulnerabilità:}\]\s*(.*)', line)
                if vuln_match:
                    current_monster['Vulnerabilita'] = vuln_match.group(1).strip()

            # Estrai Sensi
            elif '\\item[\\textbf{Sensi:}]' in line:
                sensi_match = re.search(r'\\item\[\\textbf{Sensi:}\]\s*(.*)', line)
                if sensi_match:
                    current_monster['Sensi'] = sensi_match.group(1).strip()

            # Estrai Linguaggi
            elif '\\item[\\textbf{Linguaggi:}]' in line:
                linguaggi_match = re.search(r'\\item\[\\textbf{Linguaggi:}\]\s*(.*)', line)
                if linguaggi_match:
                    current_monster['Linguaggi'] = linguaggi_match.group(1).strip()

            # Estrai Sfida e PX
            elif '\\item[\\textbf{Sfida:}]' in line:
                sfida_match = re.search(r'\\item\[\\textbf{Sfida:}\]\s*([\d/]+)\s*\((\d+)\s*PX\)', line)
                if sfida_match:
                    current_monster['Sfida'] = sfida_match.group(1)
                    current_monster['PX'] = sfida_match.group(2)

        # Estrai informazioni dalla sezione Ecologia (dopo la descrizione delle azioni)
        ecology_section = re.search(r'\\textbf{Ecologia}\\\\(.*?)(?=\\textbf{Descrizione}|$)', block, re.DOTALL)
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

        # Estrai abilità speciali (tra description e Azioni)
        abilities_section = re.search(r'\\end{description}(.*?)\\textbf{Azioni}', block, re.DOTALL)
        if abilities_section:
            abilities_text = abilities_section.group(1)
            # Estrai le singole abilità speciali marcate con \emph{\textbf{
            special_abilities = []
            ability_matches = re.finditer(r'\\emph\{\\textbf\{([^}]+)\}\}[^\\]*([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{Azioni\}|$)', abilities_text, re.DOTALL)
            for match in ability_matches:
                ability_name = match.group(1)
                ability_desc = match.group(2).strip()
                ability_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', ability_desc)
                ability_clean = ' '.join(ability_clean.split())
                if ability_clean:
                    special_abilities.append(f"{ability_name}: {ability_clean}")
            
            if special_abilities:
                current_monster['Abilita_Speciali'] = '; '.join(special_abilities)[:800]
            else:
                # Fallback per strutture diverse
                abilities_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+|\{|\}', '', abilities_text)
                abilities_clean = ' '.join(abilities_clean.split())
                if abilities_clean.strip():
                    current_monster['Abilita_Speciali'] = abilities_clean.strip()[:500]

        # Estrai azioni (tra \textbf{Azioni} e \textbf{Ecologia} o altra sezione)
        actions_section = re.search(r'\\textbf{Azioni}(.*?)(?=\\textbf{Ecologia}|\\textbf{Reazione}|\\textbf{Azioni Aggiuntive}|\\smallskip|$)', block, re.DOTALL)
        if actions_section:
            actions_text = actions_section.group(1)
            # Estrai le singole azioni
            action_list = []
            action_matches = re.finditer(r'\\emph\{\\textbf\{([^}]+)\}\}[^\\]*([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{|$)', actions_text, re.DOTALL)
            for match in action_matches:
                action_name = match.group(1).replace('.', '')  # Rimuovi punti dai nomi
                action_desc = match.group(2).strip()
                action_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', action_desc)
                action_clean = ' '.join(action_clean.split())
                if action_clean:
                    action_list.append(f"{action_name}: {action_clean}")
            
            if action_list:
                current_monster['Azioni'] = '; '.join(action_list)[:1000]

        # Estrai reazioni
        reactions_section = re.search(r'\\textbf{Reazione[^}]*}(.*?)(?=\\textbf{|\\smallskip|$)', block, re.DOTALL)
        if reactions_section:
            reactions_text = reactions_section.group(1)
            reactions_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', reactions_text)
            reactions_clean = ' '.join(reactions_clean.split())
            if reactions_clean.strip():
                current_monster['Reazioni'] = reactions_clean.strip()[:300]

        # Estrai informazioni su incantesimi
        spells_section = re.search(r'\\emph\{\\textbf{Incantesimi[^}]*}\}(.*?)(?=\\emph\{\\textbf{|\\textbf{Azioni})', block, re.DOTALL)
        if spells_section:
            spells_text = spells_section.group(1)
            spells_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', spells_text)
            spells_clean = ' '.join(spells_clean.split())
            if spells_clean.strip():
                current_monster['Incantesimi'] = spells_clean.strip()[:400]

        # Estrai azione "Arrabbiato"
        angry_section = re.search(r'\\emph\{\\textbf{Arrabbiato[^}]*}\}(.*?)(?=\\textbf{|\\smallskip|$)', block, re.DOTALL)
        if angry_section:
            angry_text = angry_section.group(1)
            angry_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', angry_text)
            angry_clean = ' '.join(angry_clean.split())
            if angry_clean.strip():
                current_monster['Arrabbiato'] = angry_clean.strip()[:300]

        # Estrai azioni aggiuntive
        additional_actions = re.search(r'\\textbf{Azioni Aggiuntive}(.*?)(?=\\textbf{Ecologia}|$)', block, re.DOTALL)
        if additional_actions:
            add_actions_text = additional_actions.group(1)
            add_actions_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', add_actions_text)
            add_actions_clean = ' '.join(add_actions_clean.split())
            if add_actions_clean.strip():
                current_monster['Azioni_Aggiuntive'] = add_actions_clean.strip()[:400]

        # Estrai resistenza leggendaria
        legendary_resistance = re.search(r'\\emph\{\\textbf{Resistenza Leggendaria[^}]*}\}(.*?)(?=\\emph\{\\textbf{|\\textbf{)', block, re.DOTALL)
        if legendary_resistance:
            leg_res_text = legendary_resistance.group(1)
            leg_res_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', leg_res_text)
            leg_res_clean = ' '.join(leg_res_clean.split())
            if leg_res_clean.strip():
                current_monster['Resistenza_Leggendaria'] = leg_res_clean.strip()

        # Estrai presenza spaventosa
        frightening_presence = re.search(r'\\emph\{\\textbf{Presenza Spaventosa[^}]*}\}(.*?)(?=\\emph\{\\textbf{|\\textbf{)', block, re.DOTALL)
        if frightening_presence:
            pres_text = frightening_presence.group(1)
            pres_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', pres_text)
            pres_clean = ' '.join(pres_clean.split())
            if pres_clean.strip():
                current_monster['Presenza_Spaventosa'] = pres_clean.strip()[:200]

        # Gestisci casi speciali per mostri senza alcune sezioni standard
        # Se non troviamo Ecologia, prova a cercare direttamente Ambiente/Organizzazione
        if 'Ambiente' not in current_monster:
            ambiente_direct = re.search(r'Ambiente:\s*([^\\]+)', block)
            if ambiente_direct:
                current_monster['Ambiente'] = ambiente_direct.group(1).strip()
        
        if 'Organizzazione' not in current_monster:
            org_direct = re.search(r'Organizzazione:\s*([^\\]+)', block)
            if org_direct:
                current_monster['Organizzazione'] = org_direct.group(1).strip()
        
        # Estrai informazioni di costruzione per i Golem
        construction_section = re.search(r'\\textbf{Costruzione}(.*?)(?=\\smallskip|\\textbf|$)', block, re.DOTALL)
        if construction_section:
            construction_text = construction_section.group(1)
            construction_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', construction_text)
            construction_clean = ' '.join(construction_clean.split())
            if construction_clean.strip():
                current_monster['Costruzione'] = construction_clean.strip()[:300]

        # Estrai abilità uniche per creature speciali
        unique_abilities = []
        
        # Cerca abilità come "Berserk", "Forme Immutabile", ecc.
        unique_ability_patterns = [
            r'\\emph\{\\textbf\{([^}]*Berserk[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\emph\{\\textbf\{([^}]*Forma Immutabile[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\emph\{\\textbf\{([^}]*Riduzione del Danno[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\emph\{\\textbf\{([^}]*Assorbimento[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\emph\{\\textbf\{([^}]*Natura[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\emph\{\\textbf\{([^}]*Teste[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\emph\{\\textbf\{([^}]*Vincolato[^}]*)\}\}([^\\]*?)(?=\\emph\{\\textbf\{|\\textbf\{)',
            r'\\textbf\{([^}]*Odio[^}]*)\}([^\\]*?)(?=\\textbf\{|\\smallskip)',
            r'\\textbf\{([^}]*Natura inusuale[^}]*)\}([^\\]*?)(?=\\textbf\{|\\smallskip)'
        ]
        
        for pattern in unique_ability_patterns:
            matches = re.finditer(pattern, block, re.DOTALL | re.IGNORECASE)
            for match in matches:
                ability_name = match.group(1)
                ability_desc = match.group(2).strip()
                ability_clean = re.sub(r'\\[a-zA-Z]+\{[^}]*\}|\\[a-zA-Z]+', '', ability_desc)
                ability_clean = ' '.join(ability_clean.split())
                if ability_clean:
                    unique_abilities.append(f"{ability_name}: {ability_clean}")
        
        if unique_abilities and 'Abilita_Speciali' not in current_monster:
            current_monster['Abilita_Speciali'] = '; '.join(unique_abilities)[:800]

        # Aggiungi il mostro alla lista solo se ha almeno il nome
        if current_monster and 'Nome' in current_monster:
            monster_data.append(current_monster)

    return monster_data

def write_to_csv(monster_data, csv_file):
    # Header aggiornato con tutti i campi possibili
    header = ['Nome', 'Tipo', 'Difesa', 'PF', 'TS_Tempra', 'TS_Riflessi', 'TS_Volonta',
              'For', 'Des', 'Cos', 'Int', 'Sag', 'Car', 'Iniziativa', 'Movimento',
              'Competenze', 'Res_Danni', 'Imm_Danni', 'Immunita', 'Vulnerabilita',
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
            print("\nMostri estratti:")
            for i, monster in enumerate(monster_data, 1):
                print(f"{i}. {monster.get('Nome', 'Nome sconosciuto')} - Sfida: {monster.get('Sfida', 'N/A')}")
        else:
            print("Nessun mostro trovato nel file.")
            
    except FileNotFoundError:
        print(f"Errore: File '{tex_file}' non trovato.")
    except Exception as e:
        print(f"Errore durante l'elaborazione: {e}")
