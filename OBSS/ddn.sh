#!/bin/bash

#=======================================================================================
# Script per la compilazione parallela di documenti LaTeX e commit automatico per OBSS
# Autore: [Andres Zanzani]
# Versione: 4.3
# Licenza: GPL-3.0 License
#=======================================================================================

# Configurazione base (set -e commentato per debug migliore)
# set -e
IFS=$'\n\t'

#==============================================================================
# CONFIGURAZIONE
#==============================================================================

SCRIPT_VERSION="4.3"
SCRIPT_START_TIME=$(date +%s)

# File e directory
FILE1="OBSSv2.tex"
FILE2="OBSSv2-eng.tex"
TEMP_DIR="/dev/shm/temp"
TARGET_DIR="$HOME/TUS/OBSS"
TOKEN_FILE=".token"
SECTIONS_DIR="sezioni"
ASSETS_DIR="per versione"

# Repository GitHub
REPO_OWNER="buzzqw"
REPO_NAME="TUS"
GITHUB_API_URL="https://api.github.com"

# Colori
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# Stati globali
GITHUB_TOKEN=""
OPERATION_COUNT=0
TEMP_FILES=()

#==============================================================================
# SISTEMA DI LOGGING
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
    printf '═%.0s' {1..80}; echo
    printf "  📚 COMPILAZIONE DOCUMENTI LATEX v%s\n" "$SCRIPT_VERSION"
    printf '═%.0s' {1..80}; echo
    printf "${NC}"
}

show_section() {
    local title="$1"
    printf "\n${YELLOW}"
    printf '─%.0s' {1..80}; echo
    printf "  %s\n" "$title"
    printf '─%.0s' {1..80}; echo
    printf "${NC}"
}

#==============================================================================
# GESTIONE CLEANUP
#==============================================================================

cleanup_files() {
    log_info "Pulizia file temporanei..."
    
    # File varianti
    rm -f "OBSSv2-noimage.tex" "OBSSv2-nocopertina.tex" 2>/dev/null || true
    
    # File temporanei registrati
    for temp_file in "${TEMP_FILES[@]}"; do
        rm -f "$temp_file" 2>/dev/null || true
    done
    
    # File API e pattern temporanei
    rm -f response.json upload_response.json assets_list.json 2>/dev/null || true
    rm -f /tmp/release_details_*.json /tmp/assets_list_*.json 2>/dev/null || true
    rm -f /tmp/update_response_*.json /tmp/upload_response_*.json 2>/dev/null || true
    
    log_success "Pulizia completata"
}

trap cleanup_files EXIT

#==============================================================================
# FUNZIONI DI VERIFICA
#==============================================================================

check_commands() {
    log_info "Verifica comandi richiesti..."
    
    local required_commands=(
        "latexmk" "parallel" "git" "zenity"
        "qpdf" "javac" "java" "node" "curl" "python3"
    )
    
    local missing=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
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
    
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "File $TOKEN_FILE non trovato"
        return 1
    fi
    
    local token
    token=$(grep "^githubtoken=" "$TOKEN_FILE" | cut -d'=' -f2)
    
    if [ -z "$token" ]; then
        log_error "Token non valido in $TOKEN_FILE"
        return 1
    fi
    
    GITHUB_TOKEN="$token"
    log_success "Token GitHub caricato"
    return 0
}

verify_latex_files() {
    log_info "Verifica file LaTeX..."
    
    local missing=()
    if [ ! -f "$FILE1" ]; then missing+=("$FILE1"); fi
    if [ ! -f "$FILE2" ]; then missing+=("$FILE2"); fi
    
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
    
    if [ ! -f ".gitignore" ] || ! grep -q "^\.token$" .gitignore; then
        echo ".token" >> .gitignore
        log_success ".gitignore aggiornato"
    else
        log_success ".gitignore già configurato"
    fi
    return 0
}

#==============================================================================
# ESTRAZIONE SEZIONI
#==============================================================================

sanitize_filename() {
    echo "$1" | tr -cd '[:alnum:]._-' | tr ' ' '_'
}

extract_sections() {
    log_step "Estrazione sezioni da $FILE1"
    
    # Preparazione directory
    if [ -d "$SECTIONS_DIR" ]; then
        rm -f "$SECTIONS_DIR"/*.tex 2>/dev/null || true
    else
        mkdir -p "$SECTIONS_DIR"
    fi
    
    # Trova preambolo
    local preambolo_line
    preambolo_line=$(awk '/\\begin{document}/ {print NR; exit}' "$FILE1")
    
    if [ -z "$preambolo_line" ]; then
        log_error "Impossibile trovare \\begin{document}"
        return 1
    fi
    
    # Estrai preambolo
    sed -n "1,${preambolo_line}p" "$FILE1" > "$SECTIONS_DIR/00_preambolo.tex"
    
    # File temporaneo per sezioni
    local temp_sections="/tmp/sections_$$"
    TEMP_FILES+=("$temp_sections")
    awk '/\\section\{/ {print NR ":" $0}' "$FILE1" > "$temp_sections"
    
    if [ ! -s "$temp_sections" ]; then
        log_warning "Nessuna sezione trovata"
        return 0
    fi
    
    # Processa sezioni
    local total_lines prev_line=0 section_count=0 prev_title=""
    total_lines=$(wc -l < "$FILE1")
    
    while IFS=: read -r line_num line_content; do
        local section_title clean_title
        section_title=$(echo "$line_content" | sed -n 's/.*\\section{\([^}]*\)}.*/\1/p')
        clean_title=$(sanitize_filename "$section_title")
        
        # Prima sezione (introduzione)
        if [ $section_count -eq 0 ] && [ $prev_line -eq 0 ] && [ $preambolo_line -lt $line_num ]; then
            sed -n "$((preambolo_line+1)),$((line_num-1))p" "$FILE1" > "$SECTIONS_DIR/01_introduzione.tex"
        fi
        
        # Sezioni intermedie
        if [ $prev_line -ne 0 ]; then
            local padded_num
            padded_num=$(printf "%02d" $((section_count+2)))
            sed -n "${prev_line},$((line_num-1))p" "$FILE1" > "$SECTIONS_DIR/${padded_num}_${prev_title}.tex"
            ((section_count++))
        fi
        
        prev_line=$line_num
        prev_title="$clean_title"
        
    done < "$temp_sections"
    
    # Ultima sezione
    if [ $prev_line -ne 0 ]; then
        local padded_num
        padded_num=$(printf "%02d" $((section_count+2)))
        sed -n "${prev_line},${total_lines}p" "$FILE1" > "$SECTIONS_DIR/${padded_num}_${prev_title}.tex"
        ((section_count++))
    fi
    
    log_success "Estratte $section_count sezioni"
    return 0
}

#==============================================================================
# COMPILAZIONE
#==============================================================================

create_variants() {
    log_step "Generazione varianti documenti"
    
    # Generazione parallela
    sed 's/\\documentclass\[/\\documentclass[draft,/' "$FILE1" > "OBSSv2-noimage.tex" &
    sed '/Fantasy Adventure Game/d' "$FILE1" > "OBSSv2-nocopertina.tex" &
    
    wait
    log_success "Varianti create"
}

# CORRETTA: Funzione compile_single con TEMP_DIR locale (fix per parallel)
compile_single() {
    TEMP_DIR="/dev/shm/temp"  # Necessario per sub-shell di parallel
    local tex_file="$1"
    local basename="${tex_file%.tex}"
    local build_dir="$TEMP_DIR/build-$basename"
    
    echo "Compilando: $basename"
    echo "Build dir: $build_dir"
    
    latexmk -xelatex -synctex=1 -auxdir="$build_dir" "$tex_file"
}

compile_documents() {
    log_step "Compilazione documenti LaTeX"
    
    # Prepara directory una sola volta
    mkdir -p "$TEMP_DIR"
    
    # Export funzione per parallel
    export -f compile_single
    
    local documents=(
        "$FILE1"
        "$FILE2"
        "OBSSv2-noimage.tex"
        "OBSSv2-nocopertina.tex"
    )
    
    log_info "Compilazione di ${#documents[@]} documenti in parallelo..."
    
    printf '%s\n' "${documents[@]}" | parallel --jobs 4 compile_single
    
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
    
    if sh latex2markdown.sh "$FILE1"  >/dev/null 2>&1; then
        log_success "OBSSv2.md generato"
        ((converted++))
    fi
    
    if sh latex2markdown.sh "$FILE2" >/dev/null 2>&1; then
        log_success "OBSSv2-eng.md generato"
        ((converted++))
    fi
    
    log_success "$converted file Markdown generati"
}

optimize_pdfs() {
    log_step "Ottimizzazione PDF"
    
    local pdfs=("OBSSv2.pdf" "OBSSv2-eng.pdf" "OBSSv2-noimage.pdf" "OBSSv2-nocopertina.pdf")
    local optimized=0
    
    for pdf in "${pdfs[@]}"; do
        if [ -f "$pdf" ]; then
            local temp_pdf="${pdf%.pdf}-temp.pdf"
            if qpdf --linearize "$pdf" "$temp_pdf" 2>/dev/null; then
                mv "$temp_pdf" "$pdf"
                ((optimized++))
            fi
        fi &
    done
    
    wait
    log_success "$optimized PDF ottimizzati"
}

#==============================================================================
# GESTIONE GIT
#==============================================================================

git_operations() {
    log_step "Operazioni Git"
    
    if ! cd "$TARGET_DIR" 2>/dev/null; then
        log_error "Impossibile accedere a $TARGET_DIR"
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Non è un repository Git valido"
        return 1
    fi
    
    local commit_msg
    if ! commit_msg=$(timeout 30 zenity --entry --title="Commit Message" \
        --text="Messaggio di commit:" \
        --entry-text="Update LaTeX documents - $(date '+%Y-%m-%d %H:%M')" 2>/dev/null); then
        commit_msg="Auto-commit LaTeX documents - $(date '+%Y-%m-%d %H:%M')"
        log_warning "Usando messaggio automatico"
    fi
    
    # Aggiungi file specifici
    [ -d "immagini" ] && git add immagini/ 2>/dev/null || true
    [ -d "$SECTIONS_DIR" ] && git add "$SECTIONS_DIR"/ 2>/dev/null || true
	git add combat-quick-eng.pdf combat-quick-ita.pdf magia-quick-eng.pdf magia-quick-ita.pdf OBSS-Iniziativa.pdf OBSS-options.pdf OBSS-schema-arbiter-character-eng.pdf OBSS-schema-narratore-personaggi.pdf OBSS-utilita.pdf OBSS-utility.pdf OBSSv2.pdf	OBSSv2-eng.pdf OBSSv2-scheda.pdf OBSSv2-scheda-eng.pdf OBSSv2-scheda-v3.pdf screenv2.pdf screenv2-eng.pdf OBSSv2.md OBSSv2-eng.md markdown-separati/ CompileDROP.sh export_dati_mostri.py Latex2MarkDown.java latex2markdown.sh mostri_data.csv OBSS-options.tex OBSSv2.tex OBSSv2-eng.tex OBSSv2-scheda.ods OBSSv2-scheda-eng.ods OBSSv2-scheda-v3.ods obsv2_wiki_script.js pages.py screenv2.tex screenv2-eng.tex ddn.sh
    
    # Commit
    if git commit -am "$commit_msg" >/dev/null 2>&1; then
        log_success "Commit eseguito"
    else
        log_warning "Nessuna modifica da committare"
    fi
    
    # Push
    if git push "https://$REPO_OWNER:$GITHUB_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" >/dev/null 2>&1; then
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

prepare_assets() {
    log_step "Preparazione asset"
    
    local assets=(
        "OBSSv2.pdf" "OBSSv2-eng.pdf" "OBSS-Iniziativa.pdf"
        "OBSSv2-scheda.pdf" "OBSSv2-scheda-v3.pdf"
        "OBSS-schema-narratore-personaggi.pdf"
        "OBSS-utilita.pdf" "screenv2.pdf" "screenv2-eng.pdf"
        "OBSSv2-scheda-eng.pdf" "OBSS-options.pdf" "OBSS-utility.pdf"
        "OBSS-schema-arbiter-character-eng.pdf"
        "combat-quick-ita.pdf" "combat-quick-eng.pdf"
        "magia-quick-eng.pdf" "magia-quick-ita.pdf"
    )
    
    # Prepara directory
    [ -d "$ASSETS_DIR" ] && rm -f "$ASSETS_DIR"/*.pdf 2>/dev/null || true
    mkdir -p "$ASSETS_DIR"
    
    local copied=0
    for asset in "${assets[@]}"; do
        if [ -f "$asset" ] && cp "$asset" "$ASSETS_DIR/" 2>/dev/null; then
            ((copied++))
        fi &
    done
    
    wait
    log_success "$copied asset preparati"
}

#==============================================================================
# GESTIONE WIKI CON CLEAN COMPLETO
#==============================================================================

update_wiki() {
    show_section "📖 AGGIORNAMENTO WIKI"
    
    local wiki_script="obsv2_wiki_script.js"
    local markdown_script="./latex2markdown.sh"
    
    if [ ! -f "$wiki_script" ] || [ ! -f "$markdown_script" ]; then
        log_warning "Script wiki non disponibili"
        return 0
    fi
    
    echo "Opzioni wiki disponibili:"
    echo "  c - Clean COMPLETO (cancella tutto storico + rebuild)"
    echo "  r - Reset wiki (mantiene storico, cancella contenuto)"
    echo "  s - Aggiornamento normale"
    echo "  N - Salta (default)"
    echo -n "Aggiornare la wiki [Clean/Reset/Si/No] (c/r/s/N): "
    read -r choice
    
    case "${choice,,}" in
        c|clean)
            perform_wiki_complete_clean "$wiki_script" "$markdown_script"
            ;;
        r|reset)
            perform_wiki_reset "$wiki_script" "$markdown_script"
            ;;
        s|si|sì)
            log_info "Aggiornamento wiki normale"
            if "$markdown_script" && node "$wiki_script"; then
                log_success "Wiki aggiornata"
            fi
            ;;
        *)
            log_info "Wiki saltata"
            ;;
    esac
}

perform_wiki_complete_clean() {
    local wiki_script="$1"
    local markdown_script="$2"
    
    log_warning "ATTENZIONE: Clean completo cancellerà TUTTO lo storico wiki!"
    echo -n "Sei sicuro? Questa operazione è IRREVERSIBILE [si/No] (s/N): "
    read -r confirm
    
    case "${confirm,,}" in
        s|si|sì|yes|y)
            log_info "Avvio clean completo wiki..."
            
            # Step 1: Backup informazioni repository (se necessario)
            backup_wiki_info
            
            # Step 2: Clean completo con script Node.js
            if node "$wiki_script" --clean --force --purge-history; then
                log_success "Clean completo wiki eseguito"
            else
                log_warning "Errore durante clean - procedo con metodo alternativo"
                perform_nuclear_wiki_clean
            fi
            
            # Step 3: Ricostruzione completa
            log_info "Ricostruzione wiki da zero..."
            if "$markdown_script" && node "$wiki_script" --rebuild; then
                log_success "Wiki ricostruita completamente"
            else
                log_error "Errore ricostruzione wiki"
                return 1
            fi
            
            log_success "Clean completo wiki completato - storico cancellato"
            ;;
        *)
            log_info "Clean completo annullato dall'utente"
            ;;
    esac
}

perform_wiki_reset() {
    local wiki_script="$1"
    local markdown_script="$2"
    
    log_info "Reset wiki (mantiene storico, cancella contenuto)..."
    
    if node "$wiki_script" --reset && "$markdown_script" && node "$wiki_script"; then
        log_success "Wiki resettata e ricostruita"
    else
        log_error "Errore durante reset wiki"
        return 1
    fi
}

backup_wiki_info() {
    log_info "Backup informazioni wiki..."
    
    # Crea backup directory
    local backup_dir="/tmp/wiki_backup_$"
    mkdir -p "$backup_dir"
    TEMP_FILES+=("$backup_dir")
    
    # Backup configurazioni importanti (se esistono)
    local wiki_configs=(
        "wiki_config.json"
        ".wiki_settings"
        "wiki.conf"
        "_config.yml"
        "mkdocs.yml"
    )
    
    for config in "${wiki_configs[@]}"; do
        if [ -f "$config" ]; then
            cp "$config" "$backup_dir/" 2>/dev/null || true
            log_info "Backup: $config"
        fi
    done
    
    log_success "Backup configurazioni completato"
}

perform_nuclear_wiki_clean() {
    log_warning "Esecuzione clean nucleare wiki..."
    
    # Metodo drastico: rimozione fisica di tutto
    local wiki_dirs=(
        "wiki/"
        "docs/"
        "_wiki/"
        ".wiki/"
        "site/"
        "_site/"
        "public/"
        "_public/"
    )
    
    for wiki_dir in "${wiki_dirs[@]}"; do
        if [ -d "$wiki_dir" ]; then
            log_info "Rimozione directory: $wiki_dir"
            rm -rf "$wiki_dir"
        fi
    done
    
    # Rimozione file wiki comuni
    local wiki_files=(
        "*.wiki"
        "*.md"
        "index.html"
        "sitemap.xml"
        ".nojekyll"
    )
    
    for pattern in "${wiki_files[@]}"; do
        # Usa find per pattern matching sicuro
        find . -maxdepth 1 -name "$pattern" -type f -delete 2>/dev/null || true
    done
    
    # Reset Git della directory wiki (se è un repo separato)
    if [ -d ".git" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        perform_git_history_reset
    fi
    
    log_success "Clean nucleare completato"
}

perform_git_history_reset() {
    log_warning "Reset completo storico Git wiki..."
    
    # Verifica che siamo in un repo wiki e non nel repo principale
    local current_remote
    current_remote=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [[ "$current_remote" == *"wiki"* ]] || [[ "$current_remote" == *"docs"* ]]; then
        log_info "Rilevato repository wiki - procedo con reset storico"
        
        # Backup del branch corrente
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null || echo "main")
        
        # Metodo 1: Orphan branch (preferito)
        if perform_orphan_branch_reset "$current_branch"; then
            log_success "Reset storico tramite orphan branch completato"
        else
            # Metodo 2: Reset hard + force push (più aggressivo)
            log_warning "Metodo orphan fallito, uso reset hard..."
            perform_hard_reset "$current_branch"
        fi
    else
        log_warning "Non sembra essere un repository wiki - skip reset Git"
    fi
}

perform_orphan_branch_reset() {
    local branch_name="$1"
    
    log_info "Creazione nuovo branch orphan..."
    
    # Crea nuovo branch orphan (senza storia)
    if ! git checkout --orphan "temp_clean_$"; then
        return 1
    fi
    
    # Rimuovi tutti i file dal staging
    git rm -rf . >/dev/null 2>&1 || true
    
    # Crea commit iniziale vuoto
    echo "# Wiki Reset" > README.md
    git add README.md
    
    if ! git commit -m "Wiki clean reset - storico cancellato $(date '+%Y-%m-%d %H:%M')"; then
        return 1
    fi
    
    # Sostituisci il branch principale
    git branch -D "$branch_name" 2>/dev/null || true
    git branch -m "$branch_name"
    
    # Force push per sovrascrivere remoto
    if git push --force --set-upstream origin "$branch_name" >/dev/null 2>&1; then
        log_success "Storico Git cancellato e push forzato completato"
        return 0
    else
        log_warning "Push forzato fallito"
        return 1
    fi
}

perform_hard_reset() {
    local branch_name="$1"
    
    log_warning "Esecuzione reset hard..."
    
    # Reset completo al primo commit
    local first_commit
    first_commit=$(git rev-list --max-parents=0 HEAD 2>/dev/null || echo "")
    
    if [ -n "$first_commit" ]; then
        git reset --hard "$first_commit"
        git clean -fdx
        
        # Force push
        if git push --force origin "$branch_name" >/dev/null 2>&1; then
            log_success "Reset hard completato"
        else
            log_error "Force push fallito"
        fi
    else
        log_error "Impossibile trovare primo commit"
    fi
}

# Funzione helper per verificare se siamo in una directory wiki
is_wiki_repository() {
    if [ ! -d ".git" ]; then
        return 1
    fi
    
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    
    # Controlla se l'URL contiene indicatori di wiki
    if [[ "$remote_url" == *".wiki"* ]] || 
       [[ "$remote_url" == *"/wiki"* ]] || 
       [[ "$remote_url" == *"-wiki"* ]] || 
       [[ "$remote_url" == *"docs"* ]] ||
       [[ "$remote_url" == *"pages"* ]]; then
        return 0
    fi
    
    # Controlla se ci sono file tipici di wiki
    if [ -f "mkdocs.yml" ] || [ -f "_config.yml" ] || [ -d "_wiki" ] || [ -d "wiki" ]; then
        return 0
    fi
    
    return 1
}

show_wiki_clean_summary() {
    echo
    echo "📋 Opzioni Clean Wiki:"
    echo "   c - Clean COMPLETO: Cancella tutto (file + storico Git)"
    echo "   r - Reset: Cancella contenuto ma mantiene storico"
    echo "   s - Standard: Aggiornamento normale"
    echo
    echo "⚠️  ATTENZIONE: Clean completo è IRREVERSIBILE!"
    echo "   - Cancella tutto lo storico Git della wiki"
    echo "   - Rimuove tutti i file e directory wiki"
    echo "   - Ricrea la wiki da zero"
    echo
}

#==============================================================================
# GESTIONE GITHUB PAGES
#==============================================================================

update_pages() {
    show_section "🌐 AGGIORNAMENTO GITHUB PAGES"
    
    local pages_script="pages.py"
    
    if [ ! -f "$pages_script" ]; then
        log_warning "Script pages.py non trovato"
        return 0
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        log_warning "Python3 non disponibile"
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
    
    echo "Opzioni GitHub Pages:"
    echo "  i - Solo italiano"
    echo "  e - Solo inglese"
    echo "  b - Entrambe le lingue"
    echo "  N - Salta (default)"
    echo -n "Scelta [i/e/b/N]: "
    read -r choice
    
    case "${choice,,}" in
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

deploy_pages() {
    local lang="$1"
    local option="$2"
    
    echo -n "Nome repository [OBSS-Pages]: "
    read -r repo_name
    [ -z "$repo_name" ] && repo_name="OBSS-Pages"
    
    log_info "Deploy GitHub Pages ($lang)..."
    
    if python3 pages.py "$repo_name" $option; then
        log_success "GitHub Pages aggiornate"
        echo
        echo "📋 Info Deploy:"
        echo "   Repository: $repo_name"
        echo "   URL: https://buzzqw.github.io/$repo_name"
        echo
    else
        log_error "Errore deploy GitHub Pages"
    fi
}

#==============================================================================
# GESTIONE RELEASE GITHUB (CORRETTA)
#==============================================================================

validate_tag_name() {
    local tag="$1"
    
    [ -n "$tag" ] || return 1
    [[ ! "$tag" =~ [[:space:]] ]] || return 1
    [[ ! "$tag" =~ ^[./-] ]] || return 1
    [[ ! "$tag" =~ [./-]$ ]] || return 1
    [[ ! "$tag" =~ [:?*\[\]\\^~] ]] || return 1
    [[ ! "$tag" =~ \.\. ]] || return 1
    [[ ! "$tag" =~ // ]] || return 1
    [[ ! "$tag" =~ @\{ ]] || return 1
    [ ${#tag} -le 100 ] || return 1
    
    return 0
}

check_existing_release() {
    local tag_name="$1"
    
    log_info "Verifica esistenza release '$tag_name'..."
    
    local response
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$tag_name")
    
    local http_code="${response: -3}"
    [ "$http_code" = "200" ]
}

get_release_id() {
    local tag_name="$1"
    
    log_info "Ottenendo ID release per '$tag_name'..."
    
    local temp_file="/tmp/release_details_$$.json"
    TEMP_FILES+=("$temp_file")
    
    local response
    response=$(curl -s -w "%{http_code}" -o "$temp_file" \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$tag_name")
    
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

create_release() {
    show_section "🚀 CREAZIONE RELEASE GITHUB"
    
    echo -n "Creare una nuova release? [si/No] (s/N): "
    read -r choice
    
    case "${choice,,}" in
        s|si|sì|y|yes)
            log_info "Configurazione release GitHub..."
            
            # Version name with validation
            local version_name
            local timestamp default_version
            timestamp=$(date +"%Y-%m-%d-%H%M")
            default_version="OBSSv2-$timestamp"
            
            while true; do
                echo -n "Nome della versione [$default_version]: "
                read -r version_name
                
                if [ -z "$version_name" ]; then
                    version_name="$default_version"
                    break
                fi
                
                if validate_tag_name "$version_name"; then
                    break
                else
                    echo
                    echo "❌ Nome tag non valido!"
                    echo "Regole per i nomi dei tag:"
                    echo "  • Non possono contenere spazi"
                    echo "  • Non possono iniziare/finire con '.', '/', '-'"
                    echo "  • Non possono contenere: : ? * [ ] \\ ^ ~"
                    echo "  • Esempi validi: v1.0.0, OBSSv2-finale, release-2025"
                    echo
                fi
            done
            
            log_success "Nome versione: $version_name"
            
            # Version description
            echo
            echo "Descrizione della versione (INVIO per default):"
            echo "Default: Release automatica per OBSS v2 - $(date '+%d/%m/%Y alle %H:%M')"
            echo -n "Descrizione: "
            read -r version_description
            
            if [ -z "$version_description" ]; then
                version_description="Release automatica per OBSS v2 - $(date '+%d/%m/%Y alle %H:%M')"
            fi
            
            log_success "Descrizione impostata"
            
            # Check existing release and handle properly
            if check_existing_release "$version_name"; then
                echo
                echo "⚠️  La release '$version_name' esiste già!"
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
            else
                create_github_release "$version_name" "$version_description"
            fi
            ;;
        *)
            log_info "Release saltata"
            ;;
    esac
}

create_github_release() {
    local name="$1"
    local desc="$2"
    
    log_info "Creazione release GitHub: $name"
    
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    
    # Escape descrizione per JSON
    local escaped_description
    escaped_description=$(printf '%s' "$desc" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    # JSON payload
    local json_file="/tmp/release_$$.json"
    TEMP_FILES+=("$json_file")
    
    cat > "$json_file" << EOF
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
    
    # Crea release
    local response
    response=$(curl -s -w "%{http_code}" -o response.json \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        --data @"$json_file" \
        "$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/releases")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "201" ]; then
        log_success "Release creata con successo"
        
        # Estrai upload URL
        local upload_url
        if command -v python3 >/dev/null 2>&1; then
            upload_url=$(python3 -c "
import json
try:
    with open('response.json', 'r') as f:
        data = json.load(f)
    print(data.get('upload_url', '').split('{')[0])
except:
    pass
" 2>/dev/null)
        fi
        
        # Upload asset se disponibili
        if [ -n "$upload_url" ] && [ -d "$ASSETS_DIR" ]; then
            upload_release_assets "$upload_url"
        fi
        
        # Mostra info release
        local release_url
        if command -v python3 >/dev/null 2>&1; then
            release_url=$(python3 -c "
import json
try:
    with open('response.json', 'r') as f:
        data = json.load(f)
    print(data.get('html_url', ''))
except:
    pass
" 2>/dev/null)
        fi
        
        echo
        echo "📋 Release creata:"
        echo "   Nome: $name"
        echo "   URL: $release_url"
        echo "   Commit: ${commit_sha:0:8}"
        echo
        
    else
        log_error "Errore creazione release (HTTP: $http_code)"
        [ -f "response.json" ] && head -5 response.json >&2
        return 1
    fi
    
    rm -f response.json
}

upload_release_assets() {
    local upload_url="$1"
    
    if [ ! -d "$ASSETS_DIR" ]; then
        log_warning "Directory asset non trovata"
        return 0
    fi
    
    local file_count=0
    local upload_success=0
    
    # Conta file disponibili
    for asset in "$ASSETS_DIR"/*.pdf; do
        [ -f "$asset" ] && ((file_count++))
    done
    
    if [ $file_count -eq 0 ]; then
        log_warning "Nessun asset da caricare"
        return 0
    fi
    
    log_info "Caricamento $file_count asset..."
    
    # Upload asset uno per uno
    for asset in "$ASSETS_DIR"/*.pdf; do
        [ -f "$asset" ] || continue
        
        local filename content_type
        filename=$(basename "$asset")
        
        case "${filename##*.}" in
            pdf) content_type="application/pdf" ;;
            zip) content_type="application/zip" ;;
            txt) content_type="text/plain" ;;
            *) content_type="application/octet-stream" ;;
        esac
        
        log_info "Caricamento: $filename"
        
        local temp_response="/tmp/upload_response_$.json"
        TEMP_FILES+=("$temp_response")
        
        local response
        response=$(curl -s -w "%{http_code}" -o "$temp_response" \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "Content-Type: $content_type" \
            --data-binary @"$asset" \
            "$upload_url?name=$filename")
        
        local http_code="${response: -3}"
        
        case "$http_code" in
            201)
                ((upload_success++))
                log_success "✓ $filename caricato"
                ;;
            422)
                log_warning "⚠ $filename già presente"
                ;;
            *)
                log_warning "✗ Errore caricamento $filename (HTTP: $http_code)"
                ;;
        esac
    done
    
    log_success "$upload_success/$file_count asset caricati con successo"
}

#==============================================================================
# FUNZIONE PRINCIPALE
#==============================================================================

initialize() {
    log_step "Inizializzazione"
    
    echo "DEBUG: Inizio initialize()"
    
    if ! check_commands; then
        echo "[ERRORE] check_commands fallita"
        return 1
    fi
    echo "DEBUG: check_commands OK"
    
    if ! ensure_gitignore; then
        echo "[ERRORE] ensure_gitignore fallita"
        return 1
    fi
    echo "DEBUG: ensure_gitignore OK"
    
    if ! load_github_token; then
        echo "[ERRORE] load_github_token fallita"
        return 1
    fi
    echo "DEBUG: load_github_token OK"
    
    if ! verify_latex_files; then
        echo "[ERRORE] verify_latex_files fallita"
        return 1
    fi
    echo "DEBUG: verify_latex_files OK"
    
    log_success "Inizializzazione completata"
    return 0
}

main() {
    show_header
    
    log_info "🚀 Avvio workflow LaTeX"
    
    # Inizializzazione con debug dettagliato
    echo "DEBUG: Chiamando initialize()"
    initialize
    ret=$?
    echo "== INITIALIZE EXIT CODE: $ret =="
    
    if [ $ret -ne 0 ]; then
        echo "== INITIALIZE FALLITA =="
        log_error "Inizializzazione fallita"
        exit 1
    fi
    
    echo "DEBUG: Initialize OK, procedo con pipeline"
    
    # Pipeline compilazione
    if ! extract_sections; then
        log_error "Estrazione sezioni fallita"
        exit 1
    fi
    
    create_variants
    compile_documents
    
    # Post-processing
    optimize_pdfs
    convert_markdown
    
    # Asset preparation
    prepare_assets
    
    # Interactive operations
    update_wiki
    update_pages
    create_release
    
    # Git operations
    if ! git_operations; then
        log_error "Operazioni Git fallite"
        exit 1
    fi
    
    # Summary
    show_summary
}

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
    TEMP_FILES+=("$json_file")
    
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
    TEMP_FILES+=("$temp_response")
    
    local response
    response=$(curl -s -w "%{http_code}" -o "$temp_response" \
        -X PATCH \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/json" \
        --data @"$json_file" \
        "$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/releases/$release_id")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Release aggiornata con successo"
        
        # Get upload URL for assets
        local upload_url
        if command -v python3 >/dev/null 2>&1; then
            upload_url=$(python3 -c "
import json
try:
    with open('$temp_response', 'r') as f:
        data = json.load(f)
    print(data.get('upload_url', '').split('{')[0])
except:
    pass
" 2>/dev/null)
        fi
        
        # Upload assets if available
        if [ -n "$upload_url" ] && [ -d "$ASSETS_DIR" ]; then
            upload_release_assets "$upload_url"
        fi
        
        # Show release info
        local release_url
        if command -v python3 >/dev/null 2>&1; then
            release_url=$(python3 -c "
import json
try:
    with open('$temp_response', 'r') as f:
        data = json.load(f)
    print(data.get('html_url', ''))
except:
    pass
" 2>/dev/null)
        fi
        
        echo
        echo "📋 Release aggiornata:"
        echo "   Nome: $tag_name"
        echo "   URL: $release_url"
        echo "   Commit: ${commit_sha:0:8}"
        echo
        
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
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X DELETE \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/releases/$release_id")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        log_success "Release cancellata"
        
        # Also delete the tag
        log_info "Cancellazione tag associato..."
        local tag_response
        tag_response=$(curl -s -w "%{http_code}" -o /dev/null \
            -X DELETE \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$GITHUB_API_URL/repos/$REPO_OWNER/$REPO_NAME/git/refs/tags/$tag_name")
        
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


show_summary() {
    local duration=$(($(date +%s) - SCRIPT_START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo
    printf "${GREEN}"
    printf '═%.0s' {1..80}; echo
    printf "  🎉 COMPLETATO CON SUCCESSO!\n"
    printf "  ⏱️  Durata: %02d:%02d:%02d (%d operazioni)\n" $hours $minutes $seconds $OPERATION_COUNT
    printf '═%.0s' {1..80}; echo
    printf "${NC}\n"
}

#==============================================================================
# AVVIO
#==============================================================================

# Evita problemi con sourcing
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
