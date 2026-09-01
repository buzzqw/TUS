import os
import re
from fractions import Fraction


# --- Configurazione ---
input_filename = 'OBSSv2.tex'
output_filename = 'OBSSv2-mod.tex'
monster_block_start_pattern = re.compile(r'^\s*\\mostro\{[^}]+\}')


# --- Funzioni di supporto ---
def parse_sfida(sfida_str):
    if not sfida_str:
        return None

    value = sfida_str.strip().split()[0]
    try:
        if '/' in value:
            return float(Fraction(value))
        return float(value)
    except (TypeError, ValueError, ZeroDivisionError):
        return None


def get_stat(value, stat_name):
    match = re.search(rf'\b{re.escape(stat_name)}\s+(-?\d+)', value)
    return int(match.group(1)) if match else 0


def replace_item_value(line, label, value):
    """Sostituisce il valore di un item, conservando l'eventuale resizedown."""
    label_pattern = (
        r'(\\item\[\\textbf\{'
        + re.escape(label)
        + r':?\}\])'
    )
    label_match = re.search(label_pattern, line)
    if not label_match:
        return line

    prefix = line[:label_match.end()]
    content = line[label_match.end():].strip()
    newline = '\n' if line.endswith('\n') else ''
    wrapper_match = re.match(
        r'(\\(?:resizedown|resizebox)\{[^{}]*\}(?:\{!\})?\{)(.*)\}$',
        content)

    if wrapper_match:
        content = wrapper_match.group(1) + value + '}'
    else:
        content = value

    return f'{prefix} {content}{newline}'


def calculate_and_modify_block(block_lines):
    stats = {}
    sfida_str_raw = None
    lines_to_modify = {}
    caratt_found = False
    all_stats_found = False
    monster_name = 'Sconosciuto'

    if block_lines:
        name_match = re.search(r'\\mostro\{([^}]+)\}', block_lines[0])
        if name_match:
            monster_name = name_match.group(1)

    # Estrae i valori e memorizza le righe da sostituire.
    for index, line in enumerate(block_lines):
        line_match = re.search(
            r'\\item\[\\textbf\{([^}]+)\}\]\s*(.*)', line.strip())
        if not line_match:
            continue

        label = line_match.group(1).rstrip(':').strip()
        value = line_match.group(2)

        if label == 'Caratt.':
            caratt_found = True
            stats = {
                'For': get_stat(value, 'For'),
                'Des': get_stat(value, 'Des'),
                'Cos': get_stat(value, 'Cos'),
                'Int': get_stat(value, 'Int'),
                'Sag': get_stat(value, 'Sag'),
                'Car': get_stat(value, 'Car'),
            }
            all_stats_found = all(
                re.search(rf'\b{stat}\s+-?\d+', value)
                for stat in stats
            )
        elif label == 'Sfida':
            value_match = re.match(r'\s*([\d]+(?:/[\d]+)?)', value)
            if value_match:
                sfida_str_raw = value_match.group(1)
        elif label == 'Punti Ferita':
            lines_to_modify['hp_def_ini'] = index
        elif label in ('Tiri Salvez.', 'Tiri Salvezza'):
            lines_to_modify['saves'] = index

    required = ('hp_def_ini', 'saves')
    if sfida_str_raw is None or any(key not in lines_to_modify for key in required):
        print(f"Attenzione [{monster_name}]: blocco non modificato (valori non numerici o campi mancanti).")
        return block_lines

    sfida_val = parse_sfida(sfida_str_raw)
    if sfida_val is None or not caratt_found or not all_stats_found:
        print(f"Attenzione [{monster_name}]: valore Sfida non elaborabile. Blocco non modificato.")
        return block_lines

    des_val = stats.get('Des', 0)
    cos_val = stats.get('Cos', 0)
    sag_val = stats.get('Sag', 0)
    int_val = stats.get('Int', 0)

    try:
        new_difesa = int(12 + sfida_val + (sfida_val / 3) + des_val)
        new_tempra = int(max(3, sfida_val + cos_val))
        new_riflessi = int(max(3, sfida_val + des_val))
        new_volonta = int(max(3, sfida_val + sag_val))
        effective_sfida_for_pf = max(0, sfida_val)
        new_pf = int(
            (effective_sfida_for_pf + 1 + (effective_sfida_for_pf / 5)) * 15
            + (cos_val * effective_sfida_for_pf / 5)
        )
        new_iniziativa = max(int_val, des_val)
    except Exception as error:
        print(f"Errore durante il calcolo per [{monster_name}]: {error}")
        return block_lines

    modified_block = list(block_lines)
    hp_index = lines_to_modify['hp_def_ini']
    saves_index = lines_to_modify['saves']

    hp_value = (
        f'{new_pf}, \\textbf{{Difesa:}} {new_difesa}, '
        f'\\textbf{{Iniziativa:}} {new_iniziativa:+}'
    )
    saves_value = (
        f'Tempra {new_tempra:+}, '
        f'Riflessi {new_riflessi:+}, '
        f'Volontà {new_volonta:+}'
    )

    modified_block[hp_index] = replace_item_value(
        modified_block[hp_index], 'Punti Ferita', hp_value)
    modified_block[saves_index] = replace_item_value(
        modified_block[saves_index], 'Tiri Salvez.', saves_value)
    if modified_block[saves_index] == block_lines[saves_index]:
        modified_block[saves_index] = replace_item_value(
            modified_block[saves_index], 'Tiri Salvezza', saves_value)

    return modified_block


def process_file(input_path, output_path):
    if not os.path.exists(input_path):
        print(f"Errore: File di input '{input_path}' non trovato.")
        return

    output_lines = []
    current_block = []
    in_block = False
    block_count = 0
    modified_count = 0

    def flush_block():
        nonlocal current_block, block_count, modified_count
        if not current_block:
            return

        block_count += 1
        original_block = list(current_block)
        try:
            modified_block = calculate_and_modify_block(current_block)
        except Exception as error:
            print(f"Errore nel blocco {block_count}: {error}")
            modified_block = original_block

        output_lines.extend(modified_block)
        if modified_block != original_block:
            modified_count += 1
        current_block = []

    print(f'Lettura del file: {input_path}')
    try:
        with open(input_path, 'r', encoding='utf-8') as infile:
            for line in infile:
                stripped_line = line.strip()
                if monster_block_start_pattern.match(stripped_line):
                    if in_block:
                        flush_block()
                    current_block = [line]
                    in_block = True
                elif in_block:
                    current_block.append(line)
                    if r'\end{description}' in stripped_line:
                        flush_block()
                        in_block = False
                else:
                    output_lines.append(line)

        if in_block:
            flush_block()
    except OSError as error:
        print(f"Errore durante la lettura di '{input_path}': {error}")
        return

    print(
        f'\nElaborazione completata. Blocchi trovati: {block_count}. '
        f'Blocchi modificati: {modified_count}'
    )
    print(f'Scrittura del file modificato: {output_path}')
    try:
        with open(output_path, 'w', encoding='utf-8') as outfile:
            outfile.writelines(output_lines)
        print('Operazione di scrittura completata con successo.')
    except OSError as error:
        print(f"Errore durante la scrittura di '{output_path}': {error}")


if __name__ == '__main__':
    process_file(input_filename, output_filename)
