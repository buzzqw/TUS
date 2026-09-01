#!/bin/bash

#=======================================================================================
# Script per la compilazione parallela di documenti LaTeX e commit automatico per OBSS
# Autore: [Andres Zanzani]
# Versione: 5.0 (Refactored)
# Licenza: GPL-3.0 License
#=======================================================================================

# Configurazione base
IFS=$'\n\t'
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# CONFIGURAZIONE CENTRALIZZATA
#==============================================================================

readonly SCRIPT_VERSION="5.0"
readonly SCRIPT_START_TIME=$(date +%s)

# File e directory
declare -Ar CONFIG=(
    [FILE1]="OBSSv2.tex"
    [FILE2]="OBSSv2-eng.tex"
    [TEMP_DIR]="${OBSS_TEMP_DIR:-/dev/shm/temp}"
    [TARGET_DIR]="${OBSS_DIR:-$SCRIPT_DIR}"
    [TOKEN_FILE]="${OBSS_TOKEN_FILE:-$SCRIPT_DIR/.token}"
    [SECTIONS_DIR]="sezioni"
    [ASSETS_DIR]="per versione"
)

# Repository GitHub
declare -Ar GITHUB=(
    [REPO_OWNER]="buzzqw"
    [REPO_NAME]="TUS"
    [API_URL]="https://api.github.com"
)

# Colori
readonly COLORS=(
    [RED]='\033[1;31m'
    [GREEN]='\033[1;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[1;36m'
    [MAGENTA]='\033[1;35m'
    [NC]='\033[0m'
)

# Comandi richiesti
readonly REQUIRED_COMMANDS=(
    "latexmk" "parallel" "git" "zenity"
    "qpdf" "javac" "java" "node" "curl" "python3"
)

# Asset predefiniti
readonly ASSETS=(
    "OBSSv2.pdf" "OBSSv2-eng.pdf" "OBSS-Iniziativa.pdf"
    "OBSSv2-scheda.pdf" "OBSSv2-scheda-v3.pdf"
    "OBSS-schema-narratore-personaggi.pdf"
    "OBSS-utilita.pdf" "screenv2.pdf" "screenv2-eng.pdf"
    "OBSSv2-scheda-eng.pdf" "OBSS-options.pdf" "OBSS-utility.pdf"
    "OBSS-schema-arbiter-character-eng.pdf"
    "combat-quick-ita.pdf" "combat-quick-eng.pdf"
    "magia-quick-eng.pdf" "magia-quick-ita.pdf"
)

# File per git add
readonly GIT_FILES=(
    "immagini/" "${CONFIG[SECTIONS_DIR]}/"
    "${ASSETS[@]}" "OBSSv2.md" "OBSSv2-eng.md" "markdown-separati/"
    "CompileDROP.sh" "export_dati_mostri.py" "Latex2MarkDown.java"
    "latex2markdown.sh" "mostri_data.csv" "OBSS-options.tex"
    "${CONFIG[FILE1]}" "${CONFIG[FILE2]}" "OBSSv2-scheda.ods"
    "OBSSv2-scheda-eng.ods" "OBSSv2-scheda-v3.ods"
    "obsv2_wiki_script.js" "pages.py" "screenv2.tex"
    "screenv2-eng.tex" "ddn.sh" "ddn2.sh"
)

# Stati globali
declare GITHUB_TOKEN=""
declare -i OPERATION_COUNT=0
declare -a TEMP_FILES=()

#==============================================================================
# SISTEMA DI LOGGING E UTILITY
#==============================================================================

log_with_level() {
    local level="$1"
    local message="$2"
    local color="${COLORS[$level]}"
    local symbol=""
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        "INFO") symbol="ℹ️" ;;
        "SUCCESS") symbol="✅" ;;
        "WARNING") symbol="⚠️" ;;
        "ERROR") symbol="❌" ;;
        "STEP") symbol="📋" ;;
    esac
    
    printf "${color}[%s] %s %s${COLORS[NC]}\n" "$timestamp" "$symbol" "$message" >&2
    ((OPERATION_COUNT++))
}

log_info() { log_with_level "BLUE" "$1"; }
log_success() { log_with_level "GREEN" "$1"; }
log_warning() { log_with_level "YELLOW" "$1"; }
log_error() { log_with_level "RED" "$1"; }
log_step() { log_with_level "MAGENTA" "$1"; }

show_header() {
    printf "${COLORS[MAGENTA]}"
    printf '═%.0s' {1..80}; echo
    printf "  📚 COMPILAZIONE DOCUMENTI LATEX v%s\n" "$SCRIPT_VERSION"
    printf '═%.0s' {1..80}; echo
    printf "${COLORS[NC]}"
}

show_section() {
    local title="$1"
    printf "\n${COLORS[YELLOW]}"
    printf '─%.0s' {1..80}; echo
    printf "  %s\n" "$title"
    printf '─%.0s' {1..80}; echo
    printf "${COLORS[NC]}"
}

# Utility per gestione array associativi
get_config() {
    echo "${CONFIG[$1]}"
}

get_github() {
    echo "${GITHUB[$1]}"
}

add_temp_file() {
    TEMP_FILES+=("$1")
}

#==============================================================================
# GESTIONE CLEANUP
#==============================================================================

cleanup_files() {
    log_info "Pulizia file temporanei..."
    
    # File varianti
    rm -f "$(get_config FILE1 | sed 's/\.tex/-noimage.tex/')" \
          "$(get_config FILE1 | sed 's/\.tex/-nocopertina.tex/')" 2>/dev/null || true
    
    # File temporanei registrati
    for temp_file in "${TEMP_FILES[@]}"; do
        rm -rf "$temp_file" 2>/dev/null || true
    done
    
    # Pattern di file temporanei
    local temp_patterns=(
        "response.json" "upload_response.json" "assets_list.json"
        "/tmp/release_details_*.json" "/tmp/assets_list_*.json"
        "/tmp/update_response_*.json" "/tmp/upload_response_*.json"
    )
    
    for pattern in "${temp_patterns[@]}"; do
        rm -f $pattern 2>/dev/null || true
    done
    
    log_success "Pulizia completata"
}

trap cleanup_files EXIT

#==============================================================================
# FUNZIONI DI VERIFICA E INIZIALIZZAZIONE
#==============================================================================

check_command_availability() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

check_commands() {
    log_info "Verifica comandi richiesti..."
    
    local missing=()
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! check_command_availability "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Comandi mancanti: ${missing[*]}"
        return 1
    fi
    
    log_success "Tutti i comandi sono disponibili"
    return 0
}

load_github_token() {
    log_info "Caricamento token GitHub..."
    
    local token_file="$(get_config TOKEN_FILE)"
    
    if [ ! -f "$token_file" ]; then
        log_error "File $token_file non trovato"
        return 1
    fi
    
    local token
    if ! token=$(grep "^githubtoken=" "$token_file" | cut -d'=' -f2) || [ -z "$token" ]; then
        log_error "Token non valido in $token_file"
        return 1
    fi
    
    GITHUB_TOKEN="$token"
    log_success "Token GitHub caricato"
    return 0
}

verify_latex_files() {
    log_info "Verifica file LaTeX..."
    
    local missing=()
    local file1="$(get_config FILE1)"
    local file2="$(get_config FILE2)"
    
    [ ! -f "$file1" ] && missing+=("$file1")
    [ ! -f "$file2" ] && missing+=("$file2")
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "File mancanti: ${missing[*]}"
        log_info "Directory corrente: $(pwd)"
        return 1
    fi
    
    log_success "File LaTeX verificati"
    return 0
}

ensure_gitignore() {
    log_info "Verifica .gitignore..."
    
    local token_file="$(get_config TOKEN_FILE)"
    local token_entry="$(basename "$token_file")"
    local target_dir="$(get_config TARGET_DIR)"
    local gitignore="$target_dir/.gitignore"
    
    if [ ! -f "$gitignore" ] || ! grep -qFx "$token_entry" "$gitignore"; then
        printf '%s\n' "$token_entry" >> "$gitignore"
        log_success ".gitignore aggiornato"
    else
        log_success ".gitignore già configurato"
    fi
    return 0
}

#==============================================================================
# ESTRAZIONE E PROCESSAMENTO SEZIONI
#==============================================================================

sanitize_filename() {
    echo "$1" | tr -cd '[:alnum:]._-' | tr ' ' '_'
}

extract_document_preambolo() {
    local file="$1"
    local sections_dir="$2"
    
    local preambolo_line
    preambolo_line=$(awk '/\\begin{document}/ {print NR; exit}' "$file")
    
    if [ -z "$preambolo_line" ]; then
        log_error "Impossibile trovare \\begin{document}"
        return 1
    fi
    
    sed -n "1,${preambolo_line}p" "$file" > "$sections_dir/00_preambolo.tex"
    echo "$preambolo_line"
}

extract_document_sections() {
    local file="$1"
    local sections_dir="$2"
    local preambolo_line="$3"
    
    local temp_sections="/tmp/sections_$$"
    add_temp_file "$temp_sections"
    
    awk '/\\section\{/ {print NR ":" $0}' "$file" > "$temp_sections"
    
    if [ ! -s "$temp_sections" ]; then
        log_warning "Nessuna sezione trovata"
        return 0
    fi
    
    local total_lines prev_line=0 section_count=0 prev_title=""
    total_lines=$(wc -l < "$file")
    
    while IFS=: read -r line_num line_content; do
        local section_title clean_title
        section_title=$(echo "$line_content" | sed -n 's/.*\\section{\([^}]*\)}.*/\1/p')
        clean_title=$(sanitize_filename "$section_title")
        
        # Prima sezione (introduzione)
        if [ $section_count -eq 0 ] && [ $prev_line -eq 0 ] && [ $preambolo_line -lt $line_num ]; then
            sed -n "$((preambolo_line+1)),$((line_num-1))p" "$file" > "$sections_dir/01_introduzione.tex"
        fi
        
        # Sezioni intermedie
        if [ $prev_line -ne 0 ]; then
            local padded_num
            padded_num=$(printf "%02d" $((section_count+2)))
            sed -n "${prev_line},$((line_num-1))p" "$file" > "$sections_dir/${padded_num}_${prev_title}.tex"
            ((section_count++))
        fi
        
        prev_line=$line_num
        prev_title="$clean_title"
        
    done < "$temp_sections"
    
    # Ultima sezione
    if [ $prev_line -ne 0 ]; then
        local padded_num
        padded_num=$(printf "%02d" $((section_count+2)))
        sed -n "${prev_line},${total_lines}p" "$file" > "$sections_dir/${padded_num}_${prev_title}.tex"
        ((section_count++))
    fi
    
    echo "$section_count"
}

extract_sections() {
    log_step "Estrazione sezioni da $(get_config FILE1)"
    
    local sections_dir="$(get_config SECTIONS_DIR)"
    local file1="$(get_config FILE1)"
    
    # Preparazione directory
    if [ -d "$sections_dir" ]; then
        rm -f "$sections_dir"/*.tex 2>/dev/null || true
    else
        mkdir -p "$sections_dir"
    fi
    
    # Estrai preambolo
    local preambolo_line
    if ! preambolo_line=$(extract_document_preambolo "$file1" "$sections_dir"); then
        return 1
    fi
    
    # Estrai sezioni
    local section_count
    section_count=$(extract_document_sections "$file1" "$sections_dir" "$preambolo_line")
    
    log_success "Estratte $section_count sezioni"
    return 0
}

#==============================================================================
# COMPILAZIONE DOCUMENTI
#==============================================================================

create_document_variants() {
    local file1="$(get_config FILE1)"
    
    # Generazione parallela delle varianti
    {
        sed 's/\\documentclass\[/\\documentclass[draft,/' "$file1" > "${file1%.tex}-noimage.tex"
    } &
    {
        sed '/Fantasy Adventure Game/d' "$file1" > "${file1%.tex}-nocopertina.tex"
    } &
    
    wait
}

create_variants() {
    log_step "Generazione varianti documenti"
    create_document_variants
    log_success "Varianti create"
}

# Funzione di compilazione singola (per parallel)
compile_single() {
    local TEMP_DIR="${OBSS_TEMP_DIR:-/dev/shm/temp}"  # Necessario per sub-shell di parallel
    local tex_file="$1"
    local basename="${tex_file%.tex}"
    local build_dir="$TEMP_DIR/build-$basename"
    local source_file="$PWD/$tex_file"
    
    echo "Compilando: $basename"
    echo "Build dir: $build_dir"
    
    # Evita di riutilizzare indici parziali e mantiene il sorgente raggiungibile
    # quando latexmk cambia directory per eseguire makeindex.
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    latexmk -xelatex -synctex=1 -auxdir="$build_dir" "$source_file"
}

compile_documents() {
    log_step "Compilazione documenti LaTeX"
    
    local temp_dir="$(get_config TEMP_DIR)"
    local file1="$(get_config FILE1)"
    local file2="$(get_config FILE2)"
    
    # Prepara directory
    mkdir -p "$temp_dir"
    
    # Export funzione per parallel
    export -f compile_single
    
    local documents=(
        "$file1"
        "$file2"
        "${file1%.tex}-noimage.tex"
        "${file1%.tex}-nocopertina.tex"
    )
    
    log_info "Compilazione di ${#documents[@]} documenti in parallelo..."
    
    if ! printf '%s\n' "${documents[@]}" | parallel --jobs 4 compile_single; then
        log_error "Una o più compilazioni LaTeX sono fallite"
        return 1
    fi
    
    log_success "Compilazione completata"
}

#==============================================================================
# POST-PROCESSING
#==============================================================================

convert_markdown() {
    log_step "Conversione LaTeX → Markdown"
    
    if ! javac Latex2MarkDown.java 2>/dev/null; then
        log_warning "Java converter non disponibile"
        return 0
    fi
    
    local converted=0
    local file1="$(get_config FILE1)"
    local file2="$(get_config FILE2)"
    
    if sh latex2markdown.sh "$file1" >/dev/null 2>&1; then
        log_success "${file1%.tex}.md generato"
        ((converted++))
    fi
    
    if sh latex2markdown.sh "$file2" >/dev/null 2>&1; then
        log_success "${file2%.tex}.md generato"
        ((converted++))
    fi
    
    log_success "$converted file Markdown generati"
}

optimize_single_pdf() {
    local pdf="$1"
    local temp_pdf="${pdf%.pdf}-temp.pdf"
    
    if [ -f "$pdf" ] && qpdf --linearize "$pdf" "$temp_pdf" 2>/dev/null; then
        mv "$temp_pdf" "$pdf"
        return 0
    fi
    return 1
}

optimize_pdfs() {
    log_step "Ottimizzazione PDF"
    
    local file1="$(get_config FILE1)"
    local file2="$(get_config FILE2)"
    local pdfs=(
        "${file1%.tex}.pdf" "${file2%.tex}.pdf"
        "${file1%.tex}-noimage.pdf" "${file1%.tex}-nocopertina.pdf"
    )
    local optimized=0
    
    for pdf in "${pdfs[@]}"; do
        if optimize_single_pdf "$pdf"; then
            ((optimized++))
        fi &
    done
    
    wait
    log_success "$optimized PDF ottimizzati"
}

#==============================================================================
# GESTIONE GIT
#==============================================================================

get_commit_message() {
    local default_msg="Update LaTeX documents - $(date '+%Y-%m-%d %H:%M')"
    
    if timeout 30 zenity --entry --title="Commit Message" \
        --text="Messaggio di commit:" \
        --entry-text="$default_msg" 2>/dev/null; then
        return 0
    else
        echo "Auto-commit LaTeX documents - $(date '+%Y-%m-%d %H:%M')"
        log_warning "Usando messaggio automatico"
        return 0
    fi
}

perform_git_add() {
    local sections_dir="$(get_config SECTIONS_DIR)"
    
    # Aggiungi directory se esistono
    [ -d "immagini" ] && git add immagini/ 2>/dev/null || true
    [ -d "$sections_dir" ] && git add "$sections_dir/" 2>/dev/null || true
    
    # Aggiungi file/directory specifici
    for file in "${GIT_FILES[@]}"; do
        if [ -d "$file" ]; then
            git add "$file" 2>/dev/null || true
        elif [ -f "$file" ]; then
            git add "$file" 2>/dev/null || true
        fi
    done
}

git_operations() {
    log_step "Operazioni Git"
    
    local target_dir="$(get_config TARGET_DIR)"
    
    if ! cd "$target_dir" 2>/dev/null; then
        log_error "Impossibile accedere a $target_dir"
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Non è un repository Git valido"
        return 1
    fi
    
    local commit_msg
    commit_msg=$(get_commit_message)
    
    # Aggiungi file specifici
    perform_git_add
    
    # Commit
    if git commit -am "$commit_msg" >/dev/null 2>&1; then
        log_success "Commit eseguito"
    else
        log_warning "Nessuna modifica da committare"
    fi
    
    # Push
    local repo_owner="$(get_github REPO_OWNER)"
    local repo_name="$(get_github REPO_NAME)"
    local push_url="https://$repo_owner:$GITHUB_TOKEN@github.com/$repo_owner/$repo_name.git"
    
    if git push "$push_url" >/dev/null 2>&1; then
        log_success "Push completato"
    else
        log_error "Errore durante push"
        return 1
    fi
    
    return 0
}

#==============================================================================
# GESTIONE ASSET
#==============================================================================

copy_assets_parallel() {
    local assets_dir="$1"
    shift
    local assets=("$@")
    
    local copied=0
    for asset in "${assets[@]}"; do
        if [ -f "$asset" ] && cp "$asset" "$assets_dir/" 2>/dev/null; then
            ((copied++))
        fi &
    done
    
    wait
    echo "$copied"
}

prepare_assets() {
    log_step "Preparazione asset"
    
    local assets_dir="$(get_config ASSETS_DIR)"
    
    # Prepara directory
    [ -d "$assets_dir" ] && rm -f "$assets_dir"/*.pdf 2>/dev/null || true
    mkdir -p "$assets_dir"
    
    local copied
    copied=$(copy_assets_parallel "$assets_dir" "${ASSETS[@]}")
    
    log_success "$copied asset preparati"
}

#==============================================================================
# GESTIONE WIKI (MODULARIZZATA)
#==============================================================================

prompt_wiki_action() {
    echo "Opzioni wiki disponibili:" >&2
    echo "  c - Clean COMPLETO (cancella tutto storico + rebuild)" >&2
    echo "  r - Reset wiki (mantiene storico, cancella contenuto)" >&2
    echo "  s - Aggiornamento normale" >&2
    echo "  N - Salta (default)" >&2
    echo -n "Aggiornare la wiki [Clean/Reset/Si/No] (c/r/s/N): " >&2
    read -r choice
    echo "${choice,,}"
}

execute_wiki_script() {
    local script="$1"
    local action="$2"
    
    case "$action" in
        "normal")
            if ./latex2markdown.sh && node "$script"; then
                log_success "Wiki aggiornata"
                return 0
            fi
            ;;
        "reset")
            if node "$script" --reset && ./latex2markdown.sh && node "$script"; then
                log_success "Wiki resettata e ricostruita"
                return 0
            fi
            ;;
        "clean")
            return 1  # Richiede gestione speciale
            ;;
    esac
    
    log_error "Errore durante aggiornamento wiki"
    return 1
}

confirm_dangerous_action() {
    local action="$1"
    local message="$2"
    
    log_warning "ATTENZIONE: $message"
    echo -n "Sei sicuro? Questa operazione è IRREVERSIBILE [si/No] (s/N): "
    read -r confirm
    
    case "${confirm,,}" in
        s|si|sì|yes|y) return 0 ;;
        *) 
            log_info "$action annullato dall'utente"
            return 1
            ;;
    esac
}

update_wiki() {
    show_section "📖 AGGIORNAMENTO WIKI"
    
    local wiki_script="obsv2_wiki_script.js"
    local markdown_script="./latex2markdown.sh"
    
    if [ ! -f "$wiki_script" ] || [ ! -f "$markdown_script" ]; then
        log_warning "Script wiki non disponibili"
        return 0
    fi
    
    local choice
    choice=$(prompt_wiki_action)
    
    case "$choice" in
        c|clean)
            if confirm_dangerous_action "Clean completo" "Clean completo cancellerà TUTTO lo storico wiki!"; then
                perform_wiki_complete_clean "$wiki_script" "$markdown_script"
            fi
            ;;
        r|reset)
            execute_wiki_script "$wiki_script" "reset"
            ;;
        s|si|sì)
            execute_wiki_script "$wiki_script" "normal"
            ;;
        *)
            log_info "Wiki saltata"
            ;;
    esac
}

# Implementazioni specifiche per clean wiki (versioni semplificate)
perform_wiki_complete_clean() {
    local wiki_script="$1"
    local markdown_script="$2"
    
    log_info "Avvio clean completo wiki..."
    
    if node "$wiki_script" --clean --force --purge-history 2>/dev/null; then
        log_success "Clean completo wiki eseguito"
    else
        log_warning "Errore durante clean - procedo con metodo alternativo"
        perform_nuclear_wiki_clean
    fi
    
    log_info "Ricostruzione wiki da zero..."
    if "$markdown_script" && node "$wiki_script" --rebuild; then
        log_success "Wiki ricostruita completamente"
    else
        log_error "Errore ricostruzione wiki"
        return 1
    fi
    
    log_success "Clean completo wiki completato - storico cancellato"
}

perform_nuclear_wiki_clean() {
    log_warning "Esecuzione clean nucleare wiki..."
    
    local wiki_patterns=("wiki/" "docs/" "_wiki/" ".wiki/" "site/" "_site/" "public/" "_public/")
    
    for pattern in "${wiki_patterns[@]}"; do
        [ -d "$pattern" ] && rm -rf "$pattern" && log_info "Rimossa directory: $pattern"
    done
    
    find . -maxdepth 1 \( -name "*.wiki" -o -name "*.md" -o -name "index.html" \) -type f -delete 2>/dev/null || true
    
    log_success "Clean nucleare completato"
}

#==============================================================================
# GESTIONE GITHUB PAGES
#==============================================================================

prompt_pages_action() {
    echo "Opzioni GitHub Pages:" >&2
    echo "  i - Solo italiano" >&2
    echo "  e - Solo inglese" >&2
    echo "  b - Entrambe le lingue" >&2
    echo "  N - Salta (default)" >&2
    echo -n "Scelta [i/e/b/N]: " >&2
    read -r choice
    echo "${choice,,}"
}

deploy_pages() {
    local lang="$1"
    local option="$2"
    
    echo -n "Nome repository [OBSS-Pages]: "
    read -r repo_name
    [ -z "$repo_name" ] && repo_name="OBSS-Pages"
    
    log_info "Deploy GitHub Pages ($lang)..."
    
    if python3 pages.py "$repo_name" "$option"; then
        log_success "GitHub Pages aggiornate"
        echo
        echo "📋 Info Deploy:"
        echo "   Repository: $repo_name"
        echo "   URL: https://$(get_github REPO_OWNER).github.io/$repo_name"
        echo
    else
        log_error "Errore deploy GitHub Pages"
    fi
}

update_pages() {
    show_section "🌐 AGGIORNAMENTO GITHUB PAGES"
    
    local pages_script="pages.py"
    
    if [ ! -f "$pages_script" ] || ! check_command_availability "python3"; then
        log_warning "Script pages.py o Python3 non disponibili"
        return 0
    fi
    
    # Verifica file markdown
    local has_md=false
    [ -f "OBSSv2.md" ] && has_md=true
    [ -f "OBSSv2-eng.md" ] && has_md=true
    
    if [ "$has_md" = false ]; then
        log_warning "Nessun file Markdown disponibile"
        return 0
    fi
    
    local choice
    choice=$(prompt_pages_action)
    
    case "$choice" in
        i|ita)
            [ -f "OBSSv2.md" ] && deploy_pages "italiano" "--italian" || log_error "OBSSv2.md non trovato"
            ;;
        e|eng)
            [ -f "OBSSv2-eng.md" ] && deploy_pages "inglese" "--english" || log_error "OBSSv2-eng.md non trovato"
            ;;
        b|both)
            deploy_pages "entrambe" "--both"
            ;;
        *)
            log_info "GitHub Pages saltate"
            ;;
    esac
}

#==============================================================================
# GESTIONE RELEASE GITHUB (MODULARIZZATA)
#==============================================================================

validate_tag_name() {
    local tag="$1"
    
    # Validazioni base
    [ -n "$tag" ] || return 1
    [ ${#tag} -le 100 ] || return 1
    
    # Pattern non validi
    local invalid_patterns=(
        '[[:space:]]'       # spazi
        '^[./-]'           # inizio con . / -
        '[./-]$'           # fine con . / -
        '[:?*\[\]\\^~]'    # caratteri speciali
        '\.\.'             # doppi punti
        '//'               # doppi slash
        '@\{'              # sequence @{
    )
    
    for pattern in "${invalid_patterns[@]}"; do
        [[ "$tag" =~ $pattern ]] && return 1
    done
    
    return 0
}

github_api_call() {
    local method="$1"
    local endpoint="$2"
    local output_file="$3"
    local data_file="$4"
    
    local api_url="$(get_github API_URL)"
    local repo_owner="$(get_github REPO_OWNER)"
    local repo_name="$(get_github REPO_NAME)"
    
    local curl_args=(
        -s -w "%{http_code}" -o "$output_file"
        -X "$method"
        -H "Accept: application/vnd.github+json"
        -H "Authorization: Bearer $GITHUB_TOKEN"
        -H "X-GitHub-Api-Version: 2022-11-28"
    )
    
    [ -n "$data_file" ] && curl_args+=(-H "Content-Type: application/json" --data @"$data_file")
    
    curl "${curl_args[@]}" "$api_url/repos/$repo_owner/$repo_name/$endpoint"
}

check_existing_release() {
    local tag_name="$1"
    
    log_info "Verifica esistenza release '$tag_name'..."
    
    local response
    response=$(github_api_call "GET" "releases/tags/$tag_name" "/dev/null")
    
    local http_code="${response: -3}"
    [ "$http_code" = "200" ]
}

get_release_id() {
    local tag_name="$1"
    
    log_info "Ottenendo ID release per '$tag_name'..."
    
    local temp_file="/tmp/release_details_$$.json"
    add_temp_file "$temp_file"
    
    local response
    response=$(github_api_call "GET" "releases/tags/$tag_name" "$temp_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" != "200" ]; then
        log_error "Errore API GitHub (HTTP: $http_code)"
        return 1
    fi
    
    local release_id
    if command -v python3 >/dev/null 2>&1; then
        release_id=$(python3 -c "
import json
try:
    with open('$temp_file', 'r') as f:
        data = json.load(f)
    print(data.get('id', ''))
except:
    pass
" 2>/dev/null)
    else
        release_id=$(sed -n 's/.*"id": *\([0-9]*\).*/\1/p' "$temp_file" | head -1)
    fi
    
    if [ -n "$release_id" ] && [[ "$release_id" =~ ^[0-9]+$ ]]; then
        log_success "ID release trovato: $release_id"
        echo "$release_id"
        return 0
    else
        log_error "Impossibile estrarre ID della release"
        return 1
    fi
}

create_release_json() {
    local name="$1"
    local desc="$2"
    local output_file="$3"
    
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    
    # Escape descrizione per JSON
    local escaped_description
    escaped_description=$(printf '%s' "$desc" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    cat > "$output_file" << EOF
{
  "tag_name": "$name",
  "target_commitish": "$commit_sha",
  "name": "$name",
  "body": "$escaped_description\\n\\nCommit: $commit_sha",
  "draft": false,
  "prerelease": false,
  "generate_release_notes": true
}
EOF
}

extract_upload_url() {
    local response_file="$1"
    
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
try:
    with open('$response_file', 'r') as f:
        data = json.load(f)
    print(data.get('upload_url', '').split('{')[0])
except:
    pass
" 2>/dev/null
    fi
}

upload_single_asset() {
    local upload_url="$1"
    local asset_file="$2"
    
    local filename content_type
    filename=$(basename "$asset_file")
    
    case "${filename##*.}" in
        pdf) content_type="application/pdf" ;;
        zip) content_type="application/zip" ;;
        txt) content_type="text/plain" ;;
        *) content_type="application/octet-stream" ;;
    esac
    
    local temp_response="/tmp/upload_response_$$.json"
    add_temp_file "$temp_response"
    
    local response
    response=$(curl -s -w "%{http_code}" -o "$temp_response" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Content-Type: $content_type" \
        --data-binary @"$asset_file" \
        "$upload_url?name=$filename")
    
    local http_code="${response: -3}"
    
    case "$http_code" in
        201)
            log_success "✓ $filename caricato"
            return 0
            ;;
        422)
            log_warning "⚠ $filename già presente"
            return 0
            ;;
        *)
            log_warning "✗ Errore caricamento $filename (HTTP: $http_code)"
            return 1
            ;;
    esac
}

upload_release_assets() {
    local upload_url="$1"
    local assets_dir="$(get_config ASSETS_DIR)"
    
    if [ ! -d "$assets_dir" ]; then
        log_warning "Directory asset non trovata"
        return 0
    fi
    
    local file_count=0 upload_success=0
    
    # Conta file disponibili
    for asset in "$assets_dir"/*.pdf; do
        [ -f "$asset" ] && ((file_count++))
    done
    
    if [ $file_count -eq 0 ]; then
        log_warning "Nessun asset da caricare"
        return 0
    fi
    
    log_info "Caricamento $file_count asset..."
    
    # Upload asset
    for asset in "$assets_dir"/*.pdf; do
        [ -f "$asset" ] || continue
        
        log_info "Caricamento: $(basename "$asset")"
        
        if upload_single_asset "$upload_url" "$asset"; then
            ((upload_success++))
        fi
    done
    
    log_success "$upload_success/$file_count asset caricati con successo"
}

show_release_info() {
    local response_file="$1"
    local tag_name="$2"
    local title="${3:-Release creata:}"
    
    local release_url commit_sha
    commit_sha=$(git rev-parse HEAD)
    
    if command -v python3 >/dev/null 2>&1; then
        release_url=$(python3 -c "
import json
try:
    with open('$response_file', 'r') as f:
        data = json.load(f)
    print(data.get('html_url', ''))
except:
    pass
" 2>/dev/null)
    fi
    
    echo
    echo "📋 $title"
    echo "   Nome: $tag_name"
    echo "   URL: $release_url"
    echo "   Commit: ${commit_sha:0:8}"
    echo
}

create_github_release() {
    local name="$1"
    local desc="$2"
    
    log_info "Creazione release GitHub: $name"
    
    # Crea JSON payload
    local json_file="/tmp/release_$$.json"
    add_temp_file "$json_file"
    create_release_json "$name" "$desc" "$json_file"
    
    # Crea release
    local response_file="/tmp/response_$$.json"
    add_temp_file "$response_file"
    
    local response
    response=$(github_api_call "POST" "releases" "$response_file" "$json_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "201" ]; then
        log_success "Release creata con successo"
        
        # Estrai upload URL
        local upload_url
        upload_url=$(extract_upload_url "$response_file")
        
        # Upload asset se disponibili
        if [ -n "$upload_url" ] && [ -d "$(get_config ASSETS_DIR)" ]; then
            upload_release_assets "$upload_url"
        fi
        
        # Mostra info release
        show_release_info "$response_file" "$name"
        
    else
        log_error "Errore creazione release (HTTP: $http_code)"
        [ -f "$response_file" ] && head -5 "$response_file" >&2
        return 1
    fi
}

prompt_version_name() {
    local timestamp default_version
    timestamp=$(date +"%Y-%m-%d-%H%M")
    default_version="OBSSv2-$timestamp"
    
    while true; do
        echo -n "Nome della versione [$default_version]: " >&2
        read -r version_name
        
        if [ -z "$version_name" ]; then
            version_name="$default_version"
            break
        fi
        
        if validate_tag_name "$version_name"; then
            break
        else
            echo >&2
            echo "❌ Nome tag non valido!" >&2
            echo "Regole per i nomi dei tag:" >&2
            echo "  • Non possono contenere spazi" >&2
            echo "  • Non possono iniziare/finire con '.', '/', '-'" >&2
            echo "  • Non possono contenere: : ? * [ ] \\ ^ ~" >&2
            echo "  • Esempi validi: v1.0.0, OBSSv2-finale, release-2025" >&2
            echo >&2
        fi
    done
    
    echo "$version_name"
}

prompt_version_description() {
    echo >&2
    echo "Descrizione della versione (INVIO per default):" >&2
    echo "Default: Release automatica per OBSS v2 - $(date '+%d/%m/%Y alle %H:%M')" >&2
    echo -n "Descrizione: " >&2
    read -r version_description
    
    if [ -z "$version_description" ]; then
        version_description="Release automatica per OBSS v2 - $(date '+%d/%m/%Y alle %H:%M')"
    fi
    
    echo "$version_description"
}

handle_existing_release() {
    local version_name="$1"
    local version_description="$2"
    
    echo
    echo "⚠️ La release '$version_name' esiste già!"
    echo "Opzioni disponibili:"
    echo "  u - Aggiorna release esistente"
    echo "  d - Cancella e ricrea"
    echo "  n - Annulla operazione"
    echo -n "Scelta [u/d/n]: "
    read -r update_choice
    
    case "${update_choice,,}" in
        u|update|aggiorna)
            update_existing_release "$version_name" "$version_description"
            ;;
        d|delete|cancella)
            if delete_existing_release "$version_name"; then
                log_info "Creazione nuova release..."
                create_github_release "$version_name" "$version_description"
            else
                log_error "Impossibile cancellare release esistente"
            fi
            ;;
        *)
            log_info "Operazione annullata dall'utente"
            ;;
    esac
}

create_release() {
    show_section "🚀 CREAZIONE RELEASE GITHUB"
    
    echo -n "Creare una nuova release? [si/No] (s/N): "
    read -r choice
    
    case "${choice,,}" in
        s|si|sì|y|yes)
            log_info "Configurazione release GitHub..."
            
            local version_name version_description
            version_name=$(prompt_version_name)
            log_success "Nome versione: $version_name"
            
            version_description=$(prompt_version_description)
            log_success "Descrizione impostata"
            
            if check_existing_release "$version_name"; then
                handle_existing_release "$version_name" "$version_description"
            else
                create_github_release "$version_name" "$version_description"
            fi
            ;;
        *)
            log_info "Release saltata"
            ;;
    esac
}

# Funzioni per aggiornamento e cancellazione release
update_existing_release() {
    local tag_name="$1"
    local description="$2"
    
    log_info "Aggiornamento release esistente: $tag_name"
    
    # Get release ID
    local release_id
    release_id=$(get_release_id "$tag_name")
    
    if [ -z "$release_id" ]; then
        log_error "Impossibile ottenere ID della release"
        return 1
    fi
    
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    
    # Escape description for JSON
    local escaped_description
    escaped_description=$(printf '%s' "$description" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    # JSON payload for update
    local json_file="/tmp/update_release_$$.json"
    add_temp_file "$json_file"
    
    cat > "$json_file" << EOJ
{
  "tag_name": "$tag_name",
  "target_commitish": "$commit_sha",
  "name": "$tag_name",
  "body": "$escaped_description\\n\\nCommit: $commit_sha\\nAggiornato: $(date '+%Y-%m-%d %H:%M')",
  "draft": false,
  "prerelease": false
}
EOJ
    
    # Update release using PATCH
    local temp_response="/tmp/update_response_$$.json"
    add_temp_file "$temp_response"
    
    local response
    response=$(github_api_call "PATCH" "releases/$release_id" "$temp_response" "$json_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Release aggiornata con successo"
        
        # Upload assets if available
        local upload_url
        upload_url=$(extract_upload_url "$temp_response")
        
        if [ -n "$upload_url" ] && [ -d "$(get_config ASSETS_DIR)" ]; then
            upload_release_assets "$upload_url"
        fi
        
        # Show release info
        show_release_info "$temp_response" "$tag_name" "Release aggiornata:"
        
    else
        log_error "Errore aggiornamento release (HTTP: $http_code)"
        [ -f "$temp_response" ] && head -5 "$temp_response" >&2
        return 1
    fi
}

delete_existing_release() {
    local tag_name="$1"
    
    log_warning "Cancellazione release esistente: $tag_name"
    
    # Get release ID
    local release_id
    release_id=$(get_release_id "$tag_name")
    
    if [ -z "$release_id" ]; then
        log_error "Impossibile ottenere ID della release"
        return 1
    fi
    
    # Delete release
    local response
    response=$(github_api_call "DELETE" "releases/$release_id" "/dev/null")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        log_success "Release cancellata"
        
        # Also delete the tag
        log_info "Cancellazione tag associato..."
        local tag_response
        tag_response=$(github_api_call "DELETE" "git/refs/tags/$tag_name" "/dev/null")
        
        local tag_http_code="${tag_response: -3}"
        if [ "$tag_http_code" = "204" ]; then
            log_success "Tag cancellato"
        else
            log_warning "Errore cancellazione tag (HTTP: $tag_http_code)"
        fi
        
        return 0
    else
        log_error "Errore cancellazione release (HTTP: $http_code)"
        return 1
    fi
}

#==============================================================================
# PIPELINE PRINCIPALE
#==============================================================================

initialize() {
    log_step "Inizializzazione"
    
    local init_functions=(
        "check_commands"
        "ensure_gitignore"
        "load_github_token"
        "verify_latex_files"
    )
    
    for func in "${init_functions[@]}"; do
        if ! "$func"; then
            log_error "$func fallita"
            return 1
        fi
    done
    
    log_success "Inizializzazione completata"
    return 0
}

run_compilation_pipeline() {
    log_step "Pipeline compilazione"
    
    local pipeline_functions=(
        "extract_sections"
        "create_variants"
        "compile_documents"
    )
    
    for func in "${pipeline_functions[@]}"; do
        if ! "$func"; then
            log_error "$func fallita"
            return 1
        fi
    done
    
    return 0
}

run_postprocessing_pipeline() {
    log_step "Pipeline post-processing"
    
    # Queste funzioni possono fallire senza bloccare il workflow
    optimize_pdfs
    convert_markdown
    prepare_assets
}

run_interactive_pipeline() {
    log_step "Pipeline interattiva"
    
    # Operazioni interattive - l'utente può saltarle
    update_wiki
    update_pages
    create_release
}

show_summary() {
    local duration=$(($(date +%s) - SCRIPT_START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo
    printf "${COLORS[GREEN]}"
    printf '═%.0s' {1..80}; echo
    printf "  🎉 COMPLETATO CON SUCCESSO!\n"
    printf "  ⏱️ Durata: %02d:%02d:%02d (%d operazioni)\n" $hours $minutes $seconds $OPERATION_COUNT
    printf '═%.0s' {1..80}; echo
    printf "${COLORS[NC]}\n"
}

main() {
    local target_dir="$(get_config TARGET_DIR)"
    if ! cd "$target_dir" 2>/dev/null; then
        log_error "Impossibile accedere a $target_dir"
        exit 1
    fi

    show_header
    
    log_info "🚀 Avvio workflow LaTeX"
    
    # Pipeline sequenziale con controllo errori
    if ! initialize; then
        log_error "Inizializzazione fallita"
        exit 1
    fi
    
    if ! run_compilation_pipeline; then
        log_error "Pipeline compilazione fallita"
        exit 1
    fi
    
    run_postprocessing_pipeline
    run_interactive_pipeline
    
    # Operazioni Git (critiche)
    if ! git_operations; then
        log_error "Operazioni Git fallite"
        exit 1
    fi
    
    show_summary
}

#==============================================================================
# AVVIO SCRIPT
#==============================================================================

# Evita problemi con sourcing
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
