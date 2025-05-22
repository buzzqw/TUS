import re
import os
from fractions import Fraction

# --- Configuration ---
input_filename = 'OBSSv2.tex'
output_filename = 'OBSSv2-mod.tex'
monster_block_start_pattern = r'^\s*\\smallskip\\noindent\\rule{\\linewidth}{2pt}'

# --- Stringhe Chiave da Cercare ---
sfida_label_key = r'\item[\textbf{Sfida'
caratt_label_key = r'\item[\textbf{Caratt.'
pf_def_ini_label_key = r'\item[\textbf{Punti Ferita'
saves_label_key = r'\item[\textbf{Tiri Salvezza'
movimento_label_key = r'\item[\textbf{Movimento'
competenze_label_key = r'\item[\textbf{Competenze'

# Stringhe complete
sfida_label_full_for_value = r'\item[\textbf{Sfida:}]'
pf_def_ini_label_full = r'\item[\textbf{Punti Ferita:}]'
saves_label_str_for_replace = r"\item[\textbf{Tiri Salvezza:}]"

# --- Regular Expressions ---
value_at_start_re = re.compile(r'^\s*([\d\./]+)')
for_re = re.compile(r"For\s+(-?\d+)")
des_re = re.compile(r"Des\s+(-?\d+)")
cos_re = re.compile(r"Cos\s+(-?\d+)")
int_re = re.compile(r"Int\s+(-?\d+)")
sag_re = re.compile(r"Sag\s+(-?\d+)")
car_re = re.compile(r"Car\s+(-?\d+)")
saves_values_inside_re = re.compile(r"(Tempra\s+[+-]?\d+,\s*Riflessi\s+[+-]?\d+,\s*Volontà\s+[+-]?\d+)")

# --- Helper Function ---
def parse_sfida(sfida_str):
    if not sfida_str: return 0.0
    try: val_part = sfida_str.strip().split()[0]
    except IndexError: return 0.0
    if '/' in val_part:
        try: return float(Fraction(val_part))
        except ValueError: return 0.0
    else:
        try:
            if '.' in val_part: return float(val_part)
            return float(int(val_part))
        except ValueError: return 0.0

def get_stat(line_strip, pattern, default=0):
    match = pattern.search(line_strip)
    if match:
        try: return int(match.group(1))
        except ValueError: return default
    return default

def calculate_and_modify_block(block_lines):
    sfida_str_raw = None
    sfida_val = 0.0
    stats = {}
    lines_to_modify = {}
    caratt_line_found = False
    sfida_line_found_flag = False
    pf_def_ini_line_found = False
    saves_line_found = False
    movimento_line_found = False
    competenze_line_found = False
    monster_name = "Sconosciuto"

    if len(block_lines) > 0:
         name_match = re.search(r'\\hypertarget\{([^}]+)\}', block_lines[0]) or \
                      re.search(r'\\textbf\{([^}]+)\}', block_lines[0])
         if name_match: monster_name = name_match.group(1)

    debug_this_monster = (monster_name == "Behir")
    # debug_this_monster = False
    if debug_this_monster: print(f"\n--- DEBUG BLOCK: {monster_name} ---")

    # 1. Extract data & Identify Lines using simplified keys
    for i, line in enumerate(block_lines):
        line_strip = line.strip() # Use stripped version for checks

        if not caratt_line_found and caratt_label_key in line_strip:
            caratt_line_found = True
            stats = { 'For': get_stat(line_strip, for_re), 'Des': get_stat(line_strip, des_re),
                      'Cos': get_stat(line_strip, cos_re), 'Int': get_stat(line_strip, int_re),
                      'Sag': get_stat(line_strip, sag_re), 'Car': get_stat(line_strip, car_re) }

        if not sfida_line_found_flag and sfida_label_key in line_strip:
            sfida_line_found_flag = True
            try:
                label_match_start = line_strip.find(sfida_label_full_for_value)
                if label_match_start != -1:
                    label_end_index = label_match_start + len(sfida_label_full_for_value)
                    content_after_label = line_strip[label_end_index:]
                    match_num = value_at_start_re.match(content_after_label)
                    if match_num: sfida_str_raw = match_num.group(1)
                    else: sfida_str_raw = None
                else: sfida_str_raw = None
            except Exception: sfida_str_raw = None

        if not pf_def_ini_line_found and pf_def_ini_label_key in line_strip:
             pf_def_ini_line_found = True
             lines_to_modify['hp_def_ini'] = {'index': i, 'content': block_lines[i]}

        if not saves_line_found and saves_label_key in line_strip:
             saves_line_found = True
             lines_to_modify['saves'] = {'index': i, 'content': block_lines[i]}

        if not movimento_line_found and movimento_label_key in line_strip:
             movimento_line_found = True
             lines_to_modify['movimento'] = {'index': i, 'content': block_lines[i]}

        if not competenze_line_found and competenze_label_key in line_strip:
             competenze_line_found = True
             lines_to_modify['competenze'] = {'index': i, 'content': block_lines[i]}

    # 2. Check data completeness
    if not (sfida_line_found_flag and caratt_line_found and pf_def_ini_line_found and saves_line_found):
        if len(block_lines) > 3:
             missing = []
             if not sfida_line_found_flag: missing.append("Sfida")
             if not caratt_line_found: missing.append("Caratteristiche")
             if not pf_def_ini_line_found: missing.append("Punti Ferita")
             if not saves_line_found: missing.append("Tiri Salvezza")
             if missing:
                 print(f"Attenzione [{monster_name}]: Linea/e {', '.join(missing)} non trovata/e. Blocco non modificato.")
        return block_lines

    if sfida_str_raw is None:
         print(f"Attenzione [{monster_name}]: Valore Sfida non estratto. Blocco non modificato.")
         return block_lines

    # 3. Parse Sfida Value and Calculations
    try:
        sfida_val = parse_sfida(sfida_str_raw)
        des_val = stats.get('Des', 0)
        cos_val = stats.get('Cos', 0)
        sag_val = stats.get('Sag', 0)
        int_val = stats.get('Int', 0)

        new_difesa = int(12 + sfida_val + (sfida_val / 3) + des_val)
        # new_tempra = int(sfida_val + (sfida_val / 7) + cos_val)
        # new_riflessi = int(sfida_val + (sfida_val / 7) + des_val)
        # new_volonta = int(sfida_val + (sfida_val / 7) + sag_val)
        new_tempra = int(max(3,sfida_val + cos_val))
        new_riflessi = int(max(3,sfida_val + des_val))
        new_volonta = int(max(3,sfida_val + sag_val))
        effective_sfida_for_pf = max(0, sfida_val)
        # new_pf = int((effective_sfida_for_pf + 1 + (effective_sfida_for_pf / 5)) * 15 + cos_val * effective_sfida_for_pf)
        new_pf = int((effective_sfida_for_pf + 1 + (effective_sfida_for_pf / 5)) * 15 + (cos_val * effective_sfida_for_pf/5))
        new_iniziativa = max(int_val, des_val)

    except Exception as e:
        print(f"Errore durante il calcolo per il blocco [{monster_name}] (Sfida raw: '{sfida_str_raw}', Parsed: {sfida_val}): {e}")
        return block_lines

    # 4. Modify the lines
    modified_block = list(block_lines)

    # Modify HP/Def/Ini line
    idx_hp = lines_to_modify['hp_def_ini']['index']
    original_line_hp = lines_to_modify['hp_def_ini']['content']
    new_values_str = f"{new_pf},  \\textbf{{Difesa:}} {new_difesa},  \\textbf{{Iniziativa:}} {new_iniziativa:+}"
    label_start_index = original_line_hp.find(pf_def_ini_label_full)

    if label_start_index != -1:
        label_end_index = label_start_index + len(pf_def_ini_label_full)
        prefix = original_line_hp[:label_end_index]
        match_ini_end = re.search(r"\\textbf{Iniziativa:}\s*[+-]?\d+(.*)", original_line_hp)
        trailing_content = match_ini_end.group(1) if match_ini_end else "\n"
        modified_line = prefix + " " + new_values_str + trailing_content.rstrip() + ("\n" if "\n" in trailing_content else "")
        modified_block[idx_hp] = modified_line

    # Ensure `\item[\textbf{Movimento:}]` does not get moved to `\item[\textbf{Difesa:}]` line
    idx_movimento = lines_to_modify.get('movimento', {}).get('index')
    if idx_movimento is not None and idx_movimento == idx_hp + 1:
        modified_block[idx_hp] = modified_block[idx_hp].rstrip() + "\n"

    # Ensure `\item[\textbf{Competenze:}]` does not get moved to `\item[\textbf{Tiri Salvezza:}]` line
    idx_saves = lines_to_modify.get('saves', {}).get('index')
    idx_competenze = lines_to_modify.get('competenze', {}).get('index')
    if idx_competenze is not None and idx_saves is not None and idx_competenze == idx_saves + 1:
        modified_block[idx_saves] = modified_block[idx_saves].rstrip() + "\n"

    # Modify Saves line (logic unchanged)
    if idx_saves is not None:
        original_line_saves = lines_to_modify['saves']['content']
        original_line_saves_strip = original_line_saves.strip()
        new_saves_str = f"Tempra {new_tempra:+}, Riflessi {new_riflessi:+}, Volontà {new_volonta:+}"

        if r'\resizebox' in original_line_saves_strip and r'{!' in original_line_saves_strip:
            modified_content, num_replacements = saves_values_inside_re.subn(new_saves_str, original_line_saves_strip)
            if num_replacements == 0:
                match_resize = re.match(r'(.*?\\resizebox.*?\{!)(.*?)(\}.*)', original_line_saves_strip)
                if match_resize:
                    modified_content = match_resize.group(1) + new_saves_str + match_resize.group(3)
                    modified_block[idx_saves] = original_line_saves.replace(original_line_saves_strip, modified_content)
            else:
                modified_block[idx_saves] = original_line_saves.replace(original_line_saves_strip, modified_content)
        else:  # Simple format replacement
            match_label = re.search(re.escape(saves_label_str_for_replace), original_line_saves)
            if match_label:
                start_index = match_label.end()
                indentation = original_line_saves[:match_label.start()]
                spacer = " " if not (start_index == len(original_line_saves) or original_line_saves[start_index:].startswith(" ")) else ""
                parts = original_line_saves.split('\n', 1)
                trailing_content = '\n' + parts[1] if len(parts) > 1 else '\n'
                modified_content = indentation + saves_label_str_for_replace + spacer + new_saves_str + trailing_content.rstrip('\n')
                modified_block[idx_saves] = modified_content

    # Ensure all list items are on their own line
    modified_block = [line if line.endswith("\n") else line + "\n" for line in modified_block]

    return modified_block

# --- Main Script Logic ---
output_lines = []
current_block = []
in_block = False
block_count = 0
modified_count = 0
line_num = 0

print(f"Lettura del file: {input_filename}")
if not os.path.exists(input_filename):
    print(f"Errore: File di input '{input_filename}' non trovato.")
    exit()

try:
    with open(input_filename, 'r', encoding='utf-8') as infile:
        for line_num, line in enumerate(infile, 1):
            stripped_line = line.strip()
            if re.match(monster_block_start_pattern, stripped_line):
                if in_block and current_block:
                    block_count += 1
                    is_modified = False
                    original_block_ref = list(current_block)
                    try:
                        modified_block = calculate_and_modify_block(current_block)
                        if modified_block != original_block_ref:
                            is_modified = True
                        output_lines.extend(modified_block)
                    except Exception as e_block:
                        print(f"Errore irreversibile processando blocco {block_count} terminante prima di riga {line_num}: {e_block}")
                        output_lines.extend(original_block_ref)
                    if is_modified:
                        modified_count += 1
                current_block = [line]
                in_block = True
            elif in_block:
                current_block.append(line)
                if r'\end{description}' in stripped_line:
                    block_count += 1
                    is_modified = False
                    original_block_ref = list(current_block)
                    try:
                        modified_block = calculate_and_modify_block(current_block)
                        if modified_block != original_block_ref:
                            is_modified = True
                        output_lines.extend(modified_block)
                    except Exception as e_block:
                        print(f"Errore irreversibile processando blocco {block_count} terminante a riga {line_num}: {e_block}")
                        output_lines.extend(original_block_ref)
                    if is_modified:
                        modified_count += 1
                    in_block = False
                    current_block = []
            else:
                output_lines.append(line)
    if in_block and current_block:
        block_count += 1
        is_modified = False
        original_block_ref = list(current_block)
        try:
            modified_block = calculate_and_modify_block(current_block)
            if modified_block != original_block_ref:
                is_modified = True
            output_lines.extend(modified_block)
        except Exception as e_block:
            print(f"Errore irreversibile processando ultimo blocco {block_count}: {e_block}")
            output_lines.extend(original_block_ref)
        if is_modified:
            modified_count += 1
except Exception as e:
    print(f"Errore grave durante la lettura o elaborazione del file '{input_filename}' alla riga ~{line_num}: {e}")
    import traceback
    traceback.print_exc()
    exit()
print(f"\nElaborazione completata. Blocchi potenziali trovati: {block_count}. Blocchi modificati: {modified_count}")
print(f"Scrittura del file modificato: {output_filename}")
try:
    with open(output_filename, 'w', encoding='utf-8') as outfile:
        outfile.writelines(output_lines)
    print("Operazione di scrittura completata con successo.")
except Exception as e:
    print(f"Errore durante la scrittura del file '{output_filename}': {e}")
