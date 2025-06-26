#!/bin/bash

#=======================================================================================
# Script per la compilazione parallela di documenti LaTeX e commit automatico per OBSS
# Autore: [Andres Zanzani]
# Versione: 3.2 - Ottimizzato con aggiornamento release esistenti
# Licenza: GPL-3.0 License
#=======================================================================================

# Configurazione rigorosa per massima sicurezza
set -euo pipefail
IFS=$'\n\t'

# Flag per controllare se lo script è completato normalmente
declare SCRIPT_COMPLETED=false
declare EXIT_CALLED=false

#==============================================================================
# CONFIGURAZIONE E COSTANTI
#==============================================================================

# Cache per prestazioni
declare -r SCRIPT_START_TIME=$(date +%s)
declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configurazione file e directory (readonly per sicurezza)
declare -r FILE1="OBSSv2.tex"
declare -r FILE2="OBSSv2-eng.tex"
declare -r TEMP_DIR="/dev/shm/temp"
declare -r TARGET_DIR="$HOME/TUS/OBSS"
declare -r TOKEN_FILE=".token"
declare -r GITIGNORE_FILE=".gitignore"

# Colori ANSI compatibili
declare -r RED='\033[1;31m'
declare -r GREEN='\033[1;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[1;36m'
declare -r MAGENTA='\033[1;35m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m'

# Stati globali
declare GITHUB_TOKEN=""
declare CLEANUP_DONE=false
declare -a TEMP_FILES=()
declare -i OPERATION_COUNT=0

#==============================================================================
# SISTEMA DI LOGGING SEMPLIFICATO
#==============================================================================

log_info() { 
    local timestamp=$(date '+%H:%M:%S')
    printf "${BLUE}[%s] ℹ️  %s${NC}\n" "$timestamp" "$1" >&2
    ((OPERATION_COUNT++))
}

log_success() { 
    local timestamp=$(date '+%H:%M:%S')
    printf "${GREEN}[%s] ✅ %s${NC}\n" "$timestamp" "$1" >&2
    ((OPERATION_COUNT++))
}

log_warning() { 
    local timestamp=$(date '+%H:%M:%S')
    printf "${YELLOW}[%s] ⚠️  %s${NC}\n" "$timestamp" "$1" >&2
    ((OPERATION_COUNT++))
}

log_error() { 
    local timestamp=$(date '+%H:%M:%S')
    printf "${RED}[%s] ❌ %s${NC}\n" "$timestamp" "$1" >&2
    ((OPERATION_COUNT++))
}

log_step() { 
    local timestamp=$(date '+%H:%M:%S')
    printf "${MAGENTA}[%s] 📋 %s${NC}\n" "$timestamp" "$1" >&2
    ((OPERATION_COUNT++))
}

show_header() {
    printf "${MAGENTA}"
    printf '═%.0s' {1..64}; echo
    printf "  📚 COMPILAZIONE DOCUMENTI LATEX v3.2\n"
    printf '═%.0s' {1..64}; echo
    printf "${NC}"
}

show_section() {
    local title="$1"
    printf "\n${YELLOW}"
    printf '─%.0s' {1..64}; echo
    printf "  $title\n"
    printf '─%.0s' {1..64}; echo
    printf "${NC}"
}

format_duration() {
    local duration=$1
    printf "%02d:%02d:%02d" $((duration/3600)) $((duration%3600/60)) $((duration%60))
}

#==============================================================================
# GESTIONE FILE TEMPORANEI E PULIZIA
#==============================================================================

create_temp_file() {
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Impossibile creare file temporaneo"
        return 1
    }
    TEMP_FILES+=("$temp_file")
    printf '%s' "$temp_file"
}

manual_cleanup() {
    [[ "$CLEANUP_DONE" == "true" ]] && return 0
    CLEANUP_DONE=true
    
    log_info "Pulizia file temporanei..."
    
    # Rimozione file varianti
    local fbname1="${FILE1%.tex}"
    rm -f "${fbname1}-noimage.tex" "${fbname1}-nocopertina.tex" 2>/dev/null
    
    # Pulizia file temporanei
    for temp_file in "${TEMP_FILES[@]}"; do
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
    
    # Pulizia file di risposta API
    rm -f response.json upload_response.json assets_list.json release_details.json 2>/dev/null
    
    log_success "Pulizia completata"
}

#==============================================================================
# VERIFICA PREREQUISITI E SICUREZZA
#==============================================================================

verify_prerequisites() {
    log_step "Verifica prerequisiti del sistema"
    
    # Comandi richiesti
    local -ra required_commands=(
        "latexmk" "parallel" "git" "zenity" 
        "qpdf" "javac" "java" "node" "curl"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || missing_commands+=("$cmd")
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Comandi mancanti: ${missing_commands[*]}"
        log_info "Installa i comandi mancanti: sudo apt install ${missing_commands[*]}"
        return 1
    fi
    
    log_success "Tutti i prerequisiti sono disponibili"
}

load_github_token() {
    log_info "Caricamento credenziali GitHub..."
    
    [[ -f "$TOKEN_FILE" ]] || {
        log_error "File $TOKEN_FILE non trovato!"
        log_info "Crea il file: echo 'githubtoken=tuotoken' > $TOKEN_FILE"
        return 1
    }
    
    local token
    if ! token=$(awk -F= '/^githubtoken=/ {print $2; exit}' "$TOKEN_FILE" 2>/dev/null) || [[ -z "$token" ]]; then
        log_error "Token non valido nel file $TOKEN_FILE"
        log_info "Formato richiesto: githubtoken=tuotoken"
        return 1
    fi
    
    GITHUB_TOKEN="$token"
    log_success "Credenziali GitHub caricate"
}

ensure_gitignore_security() {
    log_info "Controllo sicurezza repository..."
    
    if [[ -f "$GITIGNORE_FILE" ]]; then
        if ! grep -qx "\.token" "$GITIGNORE_FILE" 2>/dev/null; then
            echo ".token" >> "$GITIGNORE_FILE"
            log_success "Aggiunto .token al .gitignore"
        else
            log_success "Sicurezza .gitignore verificata"
        fi
    else
        echo ".token" > "$GITIGNORE_FILE"
        log_success "Creato .gitignore con sicurezza"
    fi
}

verify_latex_files() {
    log_info "Verifica file LaTeX..."
    
    local missing_files=()
    for file in "$FILE1" "$FILE2"; do
        [[ -f "$file" ]] || missing_files+=("$file")
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "File mancanti: ${missing_files[*]}"
        return 1
    fi
    
    log_success "File LaTeX verificati"
}

#==============================================================================
# ESTRAZIONE SEZIONI OTTIMIZZATA
#==============================================================================

extract_sections() {
    log_step "Estrazione sezioni da $FILE1"
    
    local -r input_file="$FILE1"
    local -r output_dir="sezioni"
    
    # Preparazione directory con pulizia efficiente
    if [[ -d "$output_dir" ]]; then
        find "$output_dir" -type f -delete 2>/dev/null
    else
        mkdir -p "$output_dir"
    fi
    
    # Trova preambolo una sola volta
    local preambolo_line
    preambolo_line=$(awk '/\\begin{document}/ {print NR; exit}' "$input_file")
    
    [[ -n "$preambolo_line" ]] && {
        sed -n "1,${preambolo_line}p" "$input_file" > "$output_dir/00_preambolo.tex"
        log_success "Preambolo estratto"
    }
    
    # Creazione file temporaneo per sezioni
    local temp_file
    temp_file=$(create_temp_file) || return 1
    
    # Estrazione sezioni con awk (più efficiente)
    awk '/\\section\{/ {print NR ":" $0}' "$input_file" > "$temp_file"
    
    if [[ ! -s "$temp_file" ]]; then
        log_warning "Nessuna sezione trovata"
        return 1
    fi
    
    # Elaborazione sezioni ottimizzata
    local -r total_lines=$(wc -l < "$input_file")
    local prev_line=0 section_count=0 prev_section_title="" prev_clean_title=""
    
    while IFS=: read -r line_num line_content; do
        # Estrazione titolo con sed (compatibile)
        local section_title
        section_title=$(echo "$line_content" | sed -n 's/.*\\section{\([^}]*\)}.*/\1/p')
        
        # Sanitizzazione nome file
        local clean_title
        clean_title=$(printf '%s' "$section_title" | tr -cd '[:alnum:]._-' | tr ' ' '_')
        
        # Gestione prima sezione
        if [[ $section_count -eq 0 && $prev_line -eq 0 && $preambolo_line -lt $line_num ]]; then
            sed -n "$((preambolo_line+1)),$((line_num-1))p" "$input_file" > "$output_dir/01_introduzione.tex"
        fi
        
        # Gestione sezioni intermedie
        if [[ $prev_line -ne 0 ]]; then
            local padded_num
            padded_num=$(printf "%02d" $((section_count+2)))
            sed -n "${prev_line},$((line_num-1))p" "$input_file" > "$output_dir/${padded_num}_${prev_clean_title}.tex"
            ((section_count++))
        fi
        
        prev_line=$line_num
        prev_section_title="$section_title"
        prev_clean_title="$clean_title"
        
    done < "$temp_file"
    
    # Gestione ultima sezione
    if [[ $prev_line -ne 0 ]]; then
        local padded_num
        padded_num=$(printf "%02d" $((section_count+2)))
        sed -n "${prev_line},${total_lines}p" "$input_file" > "$output_dir/${padded_num}_${prev_clean_title}.tex"
    fi
    
    log_success "Estratte $((section_count+1)) sezioni in '$output_dir'"
}

#==============================================================================
# GENERAZIONE VARIANTI E COMPILAZIONE
#==============================================================================

create_document_variants() {
    log_step "Generazione varianti documenti"
    local -r fbname1="${FILE1%.tex}"
    
    # Generazione parallela delle varianti per massima velocità
    {
        sed 's/\\documentclass\[/\\documentclass[draft,/' "$FILE1" > "${fbname1}-noimage.tex" &&
        log_success "Variante senza immagini creata"
    } &
    
    {
        sed '/Fantasy Adventure Game/d' "$FILE1" > "${fbname1}-nocopertina.tex" &&
        log_success "Variante senza copertina creata"  
    } &
    
    wait # Sincronizzazione processi paralleli
}

compile_documents() {
    log_step "Compilazione parallela documenti LaTeX"
    local -r fbname1="${FILE1%.tex}"
    local -r fbname2="${FILE2%.tex}"
    
    # Preparazione ambiente di compilazione
    mkdir -p "$TEMP_DIR"
    
    # Array comandi di compilazione ottimizzato
    local -ra compile_commands=(
        "latexmk -xelatex -synctex=1 -auxdir='$TEMP_DIR/build-$fbname1' '$FILE1'"
        "latexmk -xelatex -synctex=1 -auxdir='$TEMP_DIR/build-$fbname2' '$FILE2'"
        "latexmk -xelatex -synctex=1 -auxdir='$TEMP_DIR/build-$fbname1-noimage' '${fbname1}-noimage.tex'"
        "latexmk -xelatex -synctex=1 -auxdir='$TEMP_DIR/build-$fbname1-nocopertina' '${fbname1}-nocopertina.tex'"
    )
    
    log_info "Avvio di ${#compile_commands[@]} processi di compilazione paralleli"
    
    # Compilazione con GNU parallel ottimizzato
    printf '%s\n' "${compile_commands[@]}" | \
        parallel --progress --bar --tag --jobs 4 --joblog /tmp/latex_compile.log
    
    log_success "Compilazione completata"
}

copy_logs() {
    log_info "Archiviazione log di compilazione"
    local -r fbname1="${FILE1%.tex}"
    local -r fbname2="${FILE2%.tex}"
    
    local copied=0
    
    for name in "$fbname1" "$fbname2"; do
        local log_source="$TEMP_DIR/build-$name/$name.log"
        if [[ -f "$log_source" ]]; then
            if cp "$log_source" "$TARGET_DIR/" 2>/dev/null; then
                copied=$((copied + 1))
            fi
        fi
    done
    
    log_success "$copied log file archiviati"
    log_info "Fine copy_logs - proseguendo..."
}

#==============================================================================
# POST-PROCESSING OTTIMIZZATO  
#==============================================================================

latex2markdown() {
    log_step "Conversione LaTeX → Markdown"
    
    log_info "Compilazione classi Java..."
    if ! javac Latex2MarkDown.java 2>/dev/null; then
        log_warning "Errore compilazione Java - saltando conversione markdown"
        return 0
    fi
    
    log_info "Conversione file Markdown..."
    if java Latex2MarkDown OBSSv2.tex OBSSv2.md >/dev/null 2>&1; then
        log_success "OBSSv2.md generato"
    else
        log_warning "Errore conversione OBSSv2.md"
    fi
    
    if java Latex2MarkDown OBSSv2-eng.tex OBSSv2-eng.md >/dev/null 2>&1; then
        log_success "OBSSv2-eng.md generato"
    else
        log_warning "Errore conversione OBSSv2-eng.md"
    fi
    
    # Verifica risultati
    local converted=0
    for md_file in OBSSv2.md OBSSv2-eng.md; do
        [[ -f "$md_file" ]] && converted=$((converted + 1))
    done
    
    log_success "$converted file Markdown generati"
}

linearize_pdfs() {
    log_step "Linearizzazione PDF per web"
    
    local -ra pdf_files=(
        "OBSSv2.pdf" "OBSSv2-eng.pdf" 
        "OBSSv2-noimage.pdf" "OBSSv2-nocopertina.pdf"
    )
    
    local linearized=0
    
    # Linearizzazione parallela silente
    for pdf in "${pdf_files[@]}"; do
        {
            if [[ -f "$pdf" ]]; then
                local temp_pdf="${pdf%.pdf}-lin.pdf"
                if qpdf --linearize "$pdf" "$temp_pdf" 2>/dev/null; then
                    mv "$temp_pdf" "$pdf" && ((linearized++))
                fi
            fi
        } &
    done
    
    wait
    log_success "$linearized PDF linearizzati"
}

#==============================================================================
# GESTIONE GIT AVANZATA
#==============================================================================

git_operations() {
    log_step "Operazioni Git"
    
    cd "$TARGET_DIR" || {
        log_error "Impossibile accedere a $TARGET_DIR"
        return 1
    }
    
    # Verifica repository
    git rev-parse --git-dir >/dev/null 2>&1 || {
        log_error "Directory non è un repository Git valido"
        return 1
    }
    
    # Richiesta commit message con timeout
    local commento
    if ! commento=$(timeout 30 zenity \
        --width=400 --height=200 \
        --entry \
        --title="📝 Commit LaTeX Documents" \
        --text="Messaggio di commit:" \
        --entry-text="Update LaTeX documents - $(date '+%Y-%m-%d %H:%M')" \
        2>/dev/null); then
        
        commento="Auto-commit LaTeX documents - $(date '+%Y-%m-%d %H:%M:%S')"
        log_warning "Usando messaggio di commit automatico"
    fi
    
    # Operazioni Git ottimizzate
    [[ -d "$TARGET_DIR/immagini/" ]] && {
        git add "$TARGET_DIR/immagini/" 2>/dev/null
        git add "$TARGET_DIR/sezioni/" 2>/dev/null
        log_success "File immagini e sezioni aggiunti"
    }
    
    if git commit -am "$commento" 2>/dev/null; then
        local short_msg=$(echo "$commento" | cut -c1-50)
        log_success "Commit eseguito: ${short_msg}..."
    else
        log_warning "Nessuna modifica da committare"
    fi
    
    if git push "https://buzzqw:$GITHUB_TOKEN@github.com/buzzqw/TUS.git" 2>/dev/null; then
        log_success "Push su GitHub completato"
    else
        log_error "Errore durante il push"
        return 1
    fi
}

#==============================================================================
# GESTIONE ASSET FINALI
#==============================================================================

copy_final_pdfs() {
    log_step "Preparazione asset finali"
    
    local -r dest_dir="per versione"
    local -ra pdf_files=(
        "OBSSv2.pdf" "OBSSv2-eng.pdf" "OBSS-Iniziativa.pdf"
        "OBSSv2-scheda.pdf" "OBSSv2-scheda-v3.pdf" 
        "OBSS-schema-narratore-personaggi.pdf"
        "OBSS-utilita.pdf" "screenv2.pdf" "screenv2-eng.pdf"
        "OBSSv2-scheda-eng.pdf" "OBSS-options.pdf" "OBSS-utility.pdf"
        "OBSS-schema-arbiter-character-eng.pdf" 
        "combat-quick-ita.pdf" "combat-quick-eng.pdf" "magia-quick-eng.pdf" "magia-quick-ita.pdf"
    )
    
    # Preparazione directory
    [[ -d "$dest_dir" ]] && find "$dest_dir" -type f -delete 2>/dev/null
    mkdir -p "$dest_dir"
    
    local copied=0
    
    # Copia parallela ottimizzata
    for pdf_file in "${pdf_files[@]}"; do
        {
            [[ -f "$pdf_file" ]] && cp "$pdf_file" "$dest_dir/" 2>/dev/null && ((copied++))
        } &
    done
    
    wait
    log_success "$copied asset copiati in '$dest_dir'"
}

#==============================================================================
# GESTIONE WIKI INTERATTIVA
#==============================================================================

update_wiki() {
    show_section "📖 AGGIORNAMENTO WIKI"
    
    local -r wiki_script="obsv2_wiki_script.js"
    local -r latex2markdown_script="./latex2markdown.sh"
    
    # Verifica script
    local missing_scripts=()
    [[ -f "$wiki_script" ]] || missing_scripts+=("$wiki_script")
    [[ -f "$latex2markdown_script" ]] || missing_scripts+=("$latex2markdown_script")
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_warning "Script mancanti: ${missing_scripts[*]} - saltando wiki"
        return 0
    fi
    
    # Prompt utente compatto
    local choice
    printf "${BLUE}Vuoi aggiornare la wiki [Clean/Si/No] (c/s/N)? ${NC}"
    read -r choice
    
    [[ -z "$choice" ]] && choice="n"
    
    case "${choice,,}" in
        c|clean)
            log_info "Clean + aggiornamento completo wiki"
            node "$wiki_script" --clean &&
            "$latex2markdown_script" &&
            node "$wiki_script" &&
            log_success "Wiki aggiornata completamente"
            ;;
        s|si|sì)
            log_info "Aggiornamento normale wiki"
            "$latex2markdown_script" &&
            node "$wiki_script" &&
            log_success "Wiki aggiornata"
            ;;
        *)
            log_info "Aggiornamento wiki saltato"
            ;;
    esac
}

#==============================================================================
# GESTIONE RELEASE GITHUB CON AGGIORNAMENTO
#==============================================================================

validate_tag_name() {
    local tag_name="$1"
    
    # Controlla se il tag è vuoto
    [[ -n "$tag_name" ]] || return 1
    
    # Controlla se contiene spazi
    [[ ! "$tag_name" =~ [[:space:]] ]] || return 1
    
    # Controlla se inizia o finisce con caratteri non validi
    [[ ! "$tag_name" =~ ^[./-] ]] || return 1
    [[ ! "$tag_name" =~ [./-]$ ]] || return 1
    
    # Controlla caratteri non validi
    [[ ! "$tag_name" =~ [:?*\[\]\\^~] ]] || return 1
    
    # Controlla sequenze non valide
    [[ ! "$tag_name" =~ \.\. ]] || return 1
    [[ ! "$tag_name" =~ // ]] || return 1
    [[ ! "$tag_name" =~ @\{ ]] || return 1
    
    # Controlla lunghezza massima
    [[ ${#tag_name} -le 100 ]] || return 1
    
    return 0
}

check_existing_release() {
    local tag_name="$1"
    local -r repo_owner="buzzqw"
    local -r repo_name="TUS"
    local -r github_api_url="https://api.github.com"
    
    log_info "Verifica esistenza release '$tag_name'..."
    
    local response http_code
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${github_api_url}/repos/${repo_owner}/${repo_name}/releases/tags/${tag_name}")
    
    http_code="${response: -3}"
    
    if [[ "$http_code" = "200" ]]; then
        return 0  # Release esiste
    else
        return 1  # Release non esiste
    fi
}

get_release_id() {
    local tag_name="$1"
    local -r repo_owner="buzzqw"
    local -r repo_name="TUS"
    local -r github_api_url="https://api.github.com"
    
    log_info "Richiesta dettagli release per tag: $tag_name"
    
    local response http_code
    response=$(curl -s -w "%{http_code}" -o release_details.json \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${github_api_url}/repos/${repo_owner}/${repo_name}/releases/tags/${tag_name}")
    
    http_code="${response: -3}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "Errore API GitHub (HTTP: $http_code)"
        [[ -f "release_details.json" ]] && {
            log_error "Risposta API:"
            head -5 release_details.json >&2
        }
        rm -f release_details.json
        return 1
    fi
    
    log_info "Risposta API ricevuta, prime righe:"
    head -3 release_details.json >&2
    
    local release_id
    
    # Metodo 1: Python se disponibile
    if command -v python3 >/dev/null 2>&1; then
        release_id=$(python3 -c "
import json
import sys
try:
    with open('release_details.json', 'r') as f:
        data = json.load(f)
    print(data.get('id', ''))
except:
    print('', file=sys.stderr)
" 2>/dev/null)
    fi
    
    # Se Python fallisce, usa sed
    if [[ -z "$release_id" ]]; then
        log_warning "Primo metodo fallito, provo metodo alternativo..."
        release_id=$(sed -n 's/.*"id": *\([0-9]*\).*/\1/p' release_details.json | head -1)
    fi
    
    rm -f release_details.json
    
    if [[ -n "$release_id" && "$release_id" =~ ^[0-9]+$ ]]; then
        log_success "ID release trovato: $release_id"
        echo "$release_id"
        return 0
    else
        log_error "Impossibile estrarre ID della release"
        return 1
    fi
}

delete_release_assets() {
    local release_id="$1"
    local -r repo_owner="buzzqw"
    local -r repo_name="TUS"
    local -r github_api_url="https://api.github.com"
    
    log_info "Eliminazione asset esistenti per release ID: $release_id"
    
    local assets_response http_code
    assets_response=$(curl -s -w "%{http_code}" -o assets_list.json \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${github_api_url}/repos/${repo_owner}/${repo_name}/releases/${release_id}/assets")
    
    http_code="${assets_response: -3}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "Errore ottenimento lista asset (HTTP: $http_code)"
        [[ -f "assets_list.json" ]] && head -3 assets_list.json >&2
        rm -f assets_list.json
        return 1
    fi
    
    log_info "Risposta API asset, prime righe:"
    head -3 assets_list.json >&2
    
    local asset_count
    asset_count=$(grep -c '"id": *[0-9]*' assets_list.json 2>/dev/null || echo "0")
    log_info "Asset trovati nella release: $asset_count"
    
    if [[ "$asset_count" -eq 0 ]]; then
        log_info "Nessun asset presente nella release"
        rm -f assets_list.json
        return 0
    fi
    
    local asset_ids deleted_count=0
    
    if command -v python3 >/dev/null 2>&1; then
        log_info "Estrazione ID asset con Python..."
        asset_ids=$(python3 -c "
import json
import sys
try:
    with open('assets_list.json', 'r') as f:
        data = json.load(f)
    if isinstance(data, list):
        for asset in data:
            if 'id' in asset and isinstance(asset['id'], int):
                print(asset['id'])
except Exception as e:
    print('', file=sys.stderr)
" 2>/dev/null)
    else
        log_info "Python non disponibile, uso grep/sed..."
        asset_ids=$(grep -o '"id": *[0-9]*' assets_list.json | sed 's/"id": *//' | sort -u 2>/dev/null)
        
        if [[ -z "$asset_ids" ]]; then
            asset_ids=$(sed -n 's/.*"id": *\([0-9]*\).*/\1/p' assets_list.json | sort -u)
        fi
    fi
    
    rm -f assets_list.json
    
    if [[ -z "$asset_ids" ]]; then
        log_warning "Impossibile estrarre ID degli asset"
        return 0
    fi
    
    asset_ids=$(echo "$asset_ids" | sort -u | grep -v '^$')
    local unique_count=$(echo "$asset_ids" | wc -w)
    log_info "Asset IDs unici trovati: $unique_count"
    
    set +e
    
    while IFS= read -r asset_id; do
        [[ -n "$asset_id" && "$asset_id" =~ ^[0-9]+$ ]] || continue
        
        log_info "Eliminazione asset ID: $asset_id"
        
        local delete_response
        delete_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -X DELETE \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "${github_api_url}/repos/${repo_owner}/${repo_name}/releases/assets/${asset_id}")
        
        local delete_http_code="${delete_response: -3}"
        
        if [[ "$delete_http_code" = "204" ]]; then
            ((deleted_count++))
            log_success "✓ Asset $asset_id eliminato"
        elif [[ "$delete_http_code" = "404" ]]; then
            log_info "- Asset $asset_id già eliminato o non esistente"
        else
            log_warning "✗ Errore eliminazione asset $asset_id (HTTP: $delete_http_code)"
        fi
        
    done <<< "$asset_ids"
    
    set -e
    
    log_success "$deleted_count asset eliminati con successo"
}

update_existing_release() {
    local tag_name="$1" version_description="$2"
    local -r repo_owner="buzzqw"
    local -r repo_name="TUS"
    local -r github_api_url="https://api.github.com"
    
    log_info "Aggiornamento release esistente: $tag_name"
    
    local release_id
    if ! release_id=$(get_release_id "$tag_name") || [[ -z "$release_id" ]]; then
        log_error "Impossibile ottenere l'ID della release"
        return 1
    fi
    
    log_info "ID release trovato: $release_id"
    
    delete_release_assets "$release_id"
    
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    
    local safe_description
    safe_description=$(printf '%s' "$version_description" | \
        sed 's/\\/\\\\/g' | \
        sed 's/"/\\"/g' | \
        sed "s/'/\\'/g" | \
        sed 's/\t/\\t/g' | \
        sed 's/\r/\\r/g' | \
        sed 's/\n/\\n/g' | \
        tr '\n' ' ')
    
    local full_description="${safe_description}\\n\\nAggiornato: $(date '+%d/%m/%Y alle %H:%M')\\nCommit: ${commit_sha}"
    
    local json_file
    json_file=$(mktemp)
    TEMP_FILES+=("$json_file")
    
    printf '{\n' > "$json_file"
    printf '  "tag_name": "%s",\n' "$tag_name" >> "$json_file"
    printf '  "target_commitish": "%s",\n' "$commit_sha" >> "$json_file"
    printf '  "name": "%s",\n' "$tag_name" >> "$json_file"
    printf '  "body": "%s",\n' "$full_description" >> "$json_file"
    printf '  "draft": false,\n' >> "$json_file"
    printf '  "prerelease": false\n' >> "$json_file"
    printf '}\n' >> "$json_file"
    
    local response
    response=$(curl -s -w "%{http_code}" -o response.json \
        -X PATCH \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        --data @"$json_file" \
        "${github_api_url}/repos/${repo_owner}/${repo_name}/releases/${release_id}")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" = "200" ]]; then
        log_success "Release aggiornata con successo"
        
        local release_url upload_url
        release_url=$(grep -o '"html_url":"[^"]*' response.json | sed 's/"html_url":"//') 
        upload_url=$(grep -o '"upload_url":"[^"]*' response.json | sed 's/"upload_url":"//') 
        
        if [[ -z "$release_url" ]]; then
            release_url=$(sed -n 's/.*"html_url": *"\([^"]*\)".*/\1/p' response.json | head -1)
        fi
        
        if [[ -z "$upload_url" ]]; then
            upload_url=$(sed -n 's/.*"upload_url": *"\([^"]*\)".*/\1/p' response.json | head -1)
        fi
        
        upload_url=$(echo "$upload_url" | sed 's/{.*}//')
        
        log_info "URL release: $release_url"
        log_info "URL upload: ${upload_url:0:50}..."
        
        upload_release_assets "$upload_url"
        
        printf "\n${BLUE}📋 Release aggiornata:\n"
        printf "   Nome: %s\n" "$tag_name"
        printf "   URL: %s\n" "$release_url"
        printf "   Commit: %s${NC}\n\n" "$(echo "$commit_sha" | cut -c1-8)"
        
    else
        log_error "Errore aggiornamento release (HTTP: $http_code)"
        [[ -f "response.json" ]] && head -5 response.json >&2
        return 1
    fi
    
    rm -f response.json
}

create_github_release_custom() {
    local version_name="$1" version_description="$2"
    
    log_info "Creazione release GitHub: $version_name"
    
    local -r repo_owner="buzzqw"
    local -r repo_name="TUS" 
    local -r github_api_url="https://api.github.com"
    
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    
    local safe_description
    safe_description=$(printf '%s' "$version_description" | \
        sed 's/\\/\\\\/g' | \
        sed 's/"/\\"/g' | \
        sed "s/'/\\'/g" | \
        sed 's/\t/\\t/g' | \
        sed 's/\r/\\r/g' | \
        sed 's/\n/\\n/g' | \
        tr '\n' ' ')
    
    local full_description="${safe_description}\\n\\nCommit: ${commit_sha}"
    
    local json_file
    json_file=$(mktemp)
    TEMP_FILES+=("$json_file")
    
    printf '{\n' > "$json_file"
    printf '  "tag_name": "%s",\n' "$version_name" >> "$json_file"
    printf '  "target_commitish": "%s",\n' "$commit_sha" >> "$json_file"
    printf '  "name": "%s",\n' "$version_name" >> "$json_file"
    printf '  "body": "%s",\n' "$full_description" >> "$json_file"
    printf '  "draft": false,\n' >> "$json_file"
    printf '  "prerelease": false,\n' >> "$json_file"
    printf '  "generate_release_notes": true\n' >> "$json_file"
    printf '}\n' >> "$json_file"
    
    log_info "JSON payload creato, validazione..."
    log_info "Prime righe JSON:"
    head -3 "$json_file" >&2
    
    local response
    response=$(curl -s -w "%{http_code}" -o response.json \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      --data @"$json_file" \
      "${github_api_url}/repos/${repo_owner}/${repo_name}/releases")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" = "201" ]]; then
        log_success "Release creata con successo"
        
        local release_url upload_url
        release_url=$(grep -o '"html_url":"[^"]*' response.json | sed 's/"html_url":"//') 
        upload_url=$(grep -o '"upload_url":"[^"]*' response.json | sed 's/"upload_url":"//') 
        
        if [[ -z "$release_url" ]]; then
            release_url=$(sed -n 's/.*"html_url": *"\([^"]*\)".*/\1/p' response.json | head -1)
        fi
        
        if [[ -z "$upload_url" ]]; then
            upload_url=$(sed -n 's/.*"upload_url": *"\([^"]*\)".*/\1/p' response.json | head -1)
        fi
        
        upload_url=$(echo "$upload_url" | sed 's/{.*}//')
        
        log_info "URL release: $release_url"
        log_info "URL upload: ${upload_url:0:50}..."
        
        upload_release_assets "$upload_url"
        
        printf "\n${BLUE}📋 Release creata:\n"
        printf "   Nome: %s\n" "$version_name"
        printf "   URL: %s\n" "$release_url"
        printf "   Commit: %s${NC}\n\n" "$(echo "$commit_sha" | cut -c1-8)"
        
    else
        echo "❌ Errore release (HTTP: $http_code)"
        [[ -f "response.json" ]] && head -5 response.json >&2
        log_error "JSON file per debug: $json_file"
        return 1
    fi
    
    rm -f response.json
}

upload_release_assets() {
    local upload_url="$1"
    local -r assets_dir="per versione"
    
    [[ -d "$assets_dir" ]] || {
        log_warning "Directory asset non trovata"
        return 0
    }
    
    local file_count
    file_count=$(find "$assets_dir" -type f | wc -l)
    
    [[ $file_count -eq 0 ]] && {
        log_warning "Nessun asset da caricare"
        return 0
    }
    
    if [[ -z "$upload_url" ]]; then
        log_error "URL di upload non valido"
        return 1
    fi
    
    log_info "Caricamento $file_count asset su: ${upload_url:0:50}..."
    
    local upload_success=0
    
    set +e
    
    while IFS= read -r -d '' filepath; do
        local filename content_type
        filename=$(basename "$filepath")
        
        case "${filename##*.}" in
            pdf) content_type="application/pdf" ;;
            zip) content_type="application/zip" ;;
            txt) content_type="text/plain" ;;
            *) content_type="application/octet-stream" ;;
        esac
        
        log_info "Caricamento: $filename"
        
        local upload_response http_code
        upload_response=$(curl -s -w "%{http_code}" -o upload_response.json \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Content-Type: ${content_type}" \
            --data-binary @"${filepath}" \
            "${upload_url}?name=${filename}")
        
        http_code="${upload_response: -3}"
        
        if [[ "$http_code" = "201" ]]; then
            ((upload_success++))
            log_success "✓ $filename caricato"
        elif [[ "$http_code" = "422" ]]; then
            log_warning "⚠ $filename già presente, saltando..."
        else
            log_warning "✗ Errore caricamento $filename (HTTP: $http_code)"
            [[ -f "upload_response.json" ]] && head -2 upload_response.json >&2
        fi
        
        rm -f upload_response.json
        
    done < <(find "$assets_dir" -type f -print0)
    
    set -e
    
    log_success "$upload_success/$file_count asset caricati con successo"
}

create_new_version() {
    show_section "🚀 CREAZIONE NUOVA VERSIONE"
    
    local choice
    printf "${BLUE}Produco una nuova versione [si/No](s/N)? ${NC}"
    read -r choice
    
    [[ -z "$choice" ]] && choice="n"
    
    case "${choice,,}" in
        s|si|sì|yes|y)
            log_info "Configurazione nuova versione GitHub..."
            
            local version_name timestamp default_version
            timestamp=$(date +"%Y-%m-%d-%H%M")
            default_version="OBSSv2-${timestamp}"
            
            while true; do
                printf "\n${BLUE}Nome della versione [${default_version}]: ${NC}"
                read -r version_name
                
                if [[ -z "$version_name" ]]; then
                    version_name="$default_version"
                    break
                fi
                
                if validate_tag_name "$version_name"; then
                    break
                else
                    printf "\n${RED}❌ Nome tag non valido!${NC}\n"
                    printf "${YELLOW}Regole per i nomi dei tag:${NC}\n"
                    printf "  • Non possono contenere spazi\n"
                    printf "  • Non possono iniziare/finire con '.', '/', '-'\n"
                    printf "  • Non possono contenere: : ? * [ ] \\ ^ ~\n"
                    printf "  • Esempi validi: v1.0.0, OBSSv2-finale, release-2025\n"
                fi
            done
            
            log_success "Nome versione: $version_name"
            
            if check_existing_release "$version_name"; then
                printf "\n${YELLOW}⚠️  La release '$version_name' esiste già!${NC}\n"
                printf "${BLUE}Vuoi aggiornarla [Si/No] (s/N)? ${NC}"
                read -r update_choice
                
                case "${update_choice,,}" in
                    s|si|sì|yes|y)
                        log_info "Procedo con l'aggiornamento della release esistente"
                        ;;
                    *)
                        log_info "Operazione annullata dall'utente"
                        return 0
                        ;;
                esac
            fi
            
            local version_description default_description
            default_description="Release automatica per OBSS v2\n\nData di creazione: $(date '+%d/%m/%Y alle %H:%M')"
            
            printf "\n${BLUE}Descrizione della versione (INVIO per default):${NC}\n"
            printf "${WHITE}Default: Release automatica per OBSS v2 - $(date '+%d/%m/%Y alle %H:%M')${NC}\n"
            printf "${YELLOW}Descrizione: ${NC}"
            read -r version_description
            
            [[ -z "$version_description" ]] && version_description="$default_description"
            
            log_success "Descrizione impostata"
            
            if check_existing_release "$version_name"; then
                if update_existing_release "$version_name" "$version_description"; then
                    log_success "Versione '$version_name' aggiornata con successo"
                else
                    log_error "Errore aggiornamento versione"
                    return 1
                fi
            else
                if create_github_release_custom "$version_name" "$version_description"; then
                    log_success "Versione '$version_name' pubblicata"
                else
                    log_error "Errore creazione versione"
                    return 1
                fi
            fi
            ;;
        *)
            log_info "Creazione versione saltata"
            ;;
    esac
}

#==============================================================================
# FUNZIONE PRINCIPALE OTTIMIZZATA
#==============================================================================

main() {
    show_header
    
    {
        verify_prerequisites &&
        ensure_gitignore_security &&
        load_github_token &&
        verify_latex_files
    } || exit 1
    
    extract_sections || exit 1
    create_document_variants
    compile_documents
    copy_logs
    
    log_step "Inizio post-processing"
    linearize_pdfs
    latex2markdown
    
    log_step "Inizio operazioni Git"
    git_operations || exit 1
    
    log_step "Inizio copia asset finali"
    copy_final_pdfs
    
    log_step "Inizio cleanup manuale"
    manual_cleanup
    
    log_step "Inizio gestione wiki"
    update_wiki
    
    log_step "Inizio gestione versioni"
    create_new_version
    
    SCRIPT_COMPLETED=true
    EXIT_CALLED=true
    
    local duration=$(($(date +%s) - SCRIPT_START_TIME))
    
    printf "\n${GREEN}"
    printf '═%.0s' {1..64}; echo
    printf "  🎉 COMPLETATO CON SUCCESSO!\n"
    printf "  ⏱️  Durata: %s (%d operazioni)\n" "$(format_duration $duration)" "$OPERATION_COUNT"
    if [[ $duration -gt 0 ]]; then
        local ops_per_sec=$((OPERATION_COUNT * 100 / duration))
        printf "  📊 Performance: %d.%02d op/sec\n" $((ops_per_sec / 100)) $((ops_per_sec % 100))
    else
        printf "  📊 Performance: N/A op/sec\n"
    fi
    printf '═%.0s' {1..64}; echo
    printf "${NC}\n"
}

#==============================================================================
# AVVIO SCRIPT
#==============================================================================

main "$@"
