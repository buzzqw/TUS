#!/bin/sh
# ============================================================================
# LaTeX Build & Sync Script v2.3
# ============================================================================
# Questo script compila un documento LaTeX e sincronizza l'intera cartella
# del progetto con una directory di destinazione (default: Dropbox).
#
# FUNZIONALITÀ PRINCIPALI:
# - Compilazione LaTeX con XeLaTeX e latexmk
# - Backup automatico dei file sorgente nella cartella backup/
# - Sincronizzazione completa della cartella progetto
# - Log dettagliato e rotativo delle operazioni (backup/rsync-[nome].log)
# - Analisi struttura progetto LaTeX
# - Notifiche desktop
# - Linearizzazione PDF per ottimizzazione
#
# DIRECTORY DI DESTINAZIONE: $HOME/Dropbox/OBSS
# LOG DI SINCRONIZZAZIONE: backup/rsync-[nome_file].log (rotazione a 5MB)
# ============================================================================

# ============================================================================
# CONFIGURAZIONE GLOBALE
# ============================================================================
SCRIPT_VERSION="2.3"
MAX_LOG_FILES=100                    # Numero massimo di file di backup da mantenere
NOTIFICATION_ENABLED=true            # Abilita notifiche desktop
BACKUP_TEX_ENABLED=true             # Backup remoto del file TEX (compresso)
BACKUP_TEX_LOCAL=true               # Backup locale del TEX nella cartella backup/
BACKUP_PDF_ENABLED=false            # Backup del PDF esistente prima della compilazione
VERBOSE=false                       # Output dettagliato
BACKUP_DIR="$HOME/RPG/Pazfinder/TUS/OBSS/old"  # Directory per backup remoti
BACKUP_FORMAT="7z"                  # Formato backup: 7z, zip, tar.gz
DEST_DIR="$HOME/Dropbox/OBSS"       # Directory di destinazione per sync
COPY_ENABLED=true                   # Abilita sincronizzazione finale

# Configurazione rotazione log rsync
RSYNC_LOG_MAX_SIZE=5242880          # 5MB in byte
RSYNC_LOG_MAX_FILES=4               # Mantieni ultimi 4 file di log

# ============================================================================
# PARSING ARGOMENTI DELLA RIGA DI COMANDO
# ============================================================================
while [ $# -gt 0 ]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-backup-tex)
            BACKUP_TEX_ENABLED=false
            BACKUP_TEX_LOCAL=false
            shift
            ;;
        --no-backup-pdf)
            BACKUP_PDF_ENABLED=false
            shift
            ;;
        --no-backup)
            BACKUP_TEX_ENABLED=false
            BACKUP_TEX_LOCAL=false
            BACKUP_PDF_ENABLED=false
            shift
            ;;
        --no-backup-local)
            BACKUP_TEX_LOCAL=false
            shift
            ;;
        --no-notify)
            NOTIFICATION_ENABLED=false
            shift
            ;;
        --no-copy)
            COPY_ENABLED=false
            shift
            ;;
        --dest-dir)
            if [ -n "$2" ]; then
                DEST_DIR="$2"
                shift 2
            else
                echo "Specificare directory dopo --dest-dir"
                exit 1
            fi
            ;;
        --backup-format)
            if [ -n "$2" ]; then
                case "$2" in
                    7z|zip|tar.gz)
                        BACKUP_FORMAT="$2"
                        shift 2
                        ;;
                    *)
                        echo "Formato backup non supportato: $2"
                        echo "Formati supportati: 7z, zip, tar.gz"
                        exit 1
                        ;;
                esac
            else
                echo "Specificare formato backup dopo --backup-format"
                exit 1
            fi
            ;;
        --backup-dir)
            if [ -n "$2" ]; then
                BACKUP_DIR="$2"
                shift 2
            else
                echo "Specificare directory dopo --backup-dir"
                exit 1
            fi
            ;;
        -h|--help)
            echo "LaTeX Build & Sync Script v$SCRIPT_VERSION"
            echo "============================================"
            echo "Compila un documento LaTeX e sincronizza l'intera cartella"
            echo "del progetto con la directory di destinazione."
            echo ""
            echo "Uso: $0 [opzioni] file.tex"
            echo ""
            echo "Opzioni:"
            echo "  -v, --verbose              Output dettagliato con analisi progetto"
            echo "  --no-backup-tex           Disabilita backup del file TEX (remoto e locale)"
            echo "  --no-backup-local         Disabilita solo backup locale del TEX"
            echo "  --no-backup-pdf           Disabilita backup del PDF esistente"
            echo "  --no-backup               Disabilita tutti i backup"
            echo "  --no-notify               Disabilita notifiche desktop"
            echo "  --no-copy                 Disabilita sincronizzazione finale"
            echo "  --dest-dir DIR            Directory destinazione [default: $DEST_DIR]"
            echo "  --backup-format FORMAT    Formato backup TEX (7z|zip|tar.gz) [default: 7z]"
            echo "  --backup-dir DIR          Directory backup TEX [default: $BACKUP_DIR]"
            echo "  -h, --help                Mostra questo aiuto"
            echo ""
            echo "Funzionalità:"
            echo "  • Compilazione con XeLaTeX e latexmk"
            echo "  • Sincronizzazione completa cartella progetto"
            echo "  • Backup automatico nella cartella backup/"
            echo "  • Log rotativo (backup/rsync-[nome].log, max 5MB × 4 file)"
            echo "  • Analisi struttura progetto LaTeX"
            echo "  • Linearizzazione PDF per ottimizzazione"
            echo "  • Notifiche desktop del risultato"
            echo ""
            echo "Esempi:"
            echo "  $0 documento.tex                    # Compilazione e sync standard"
            echo "  $0 -v documento.tex                 # Con output dettagliato"
            echo "  $0 --no-backup-pdf tesi.tex        # Senza backup PDF"
            echo "  $0 --dest-dir /home/user/docs documento.tex  # Directory custom"
            exit 0
            ;;
        -*)
            echo "Opzione sconosciuta: $1"
            echo "Usa '$0 -h' per l'aiuto completo"
            exit 1
            ;;
        *)
            TEX_FILE="$1"
            shift
            ;;
    esac
done

# ============================================================================
# FUNZIONI UTILITY
# ============================================================================

# Funzione di logging con icone
log() {
    local level="$1"
    shift
    local message="$*"
    
    case $level in
        INFO) echo "✓ $message" ;;
        WARN) echo "⚠ $message" >&2 ;;
        ERROR) echo "✗ $message" >&2 ;;
        DEBUG) [ "$VERBOSE" = true ] && echo "→ $message" ;;
        COPY) echo "📁 $message" ;;
    esac
}

# Funzione per notifiche desktop
notify() {
    if [ "$NOTIFICATION_ENABLED" = true ] && command -v notify-send >/dev/null 2>&1; then
        notify-send "LaTeX Build" "$1" -i applications-science 2>/dev/null
    fi
}

# Verifica delle dipendenze necessarie
check_dependencies() {
    local missing_deps=""
    
    # Dipendenze base
    for cmd in latexmk xelatex qpdf rsync; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    # Dipendenze per compressione backup
    case "$BACKUP_FORMAT" in
        7z)
            if ! command -v 7z >/dev/null 2>&1; then
                missing_deps="$missing_deps 7z"
            fi
            ;;
        zip)
            if ! command -v zip >/dev/null 2>&1; then
                missing_deps="$missing_deps zip"
            fi
            ;;
        tar.gz)
            if ! command -v tar >/dev/null 2>&1; then
                missing_deps="$missing_deps tar"
            fi
            ;;
    esac
    
    if [ -n "$missing_deps" ]; then
        log ERROR "Dipendenze mancanti:$missing_deps"
        log INFO "Installa con: sudo apt install texlive-xetex latexmk qpdf rsync p7zip-full zip"
        exit 1
    fi
    
    log DEBUG "Tutte le dipendenze sono soddisfatte"
}

# Controllo spazio disponibile in /dev/shm
check_disk_space() {
    local available_kb=$(df /dev/shm | tail -1 | awk '{print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [ "$available_mb" -lt 100 ]; then
        log WARN "Poco spazio in /dev/shm: ${available_mb}MB"
    else
        log DEBUG "Spazio disponibile in /dev/shm: ${available_mb}MB"
    fi
}

# Funzione di cleanup per interruzioni
cleanup() {
    local exit_code=${1:-1}
    log WARN "Interruzione rilevata - cleanup in corso..."
    
    # Termina processi LaTeX attivi per questo file
    pkill -f "latexmk.*$fbname" 2>/dev/null
    pkill -f "xelatex.*$fbname" 2>/dev/null
    sleep 1
    # Force kill se necessario
    pkill -9 -f "latexmk.*$fbname" 2>/dev/null
    pkill -9 -f "xelatex.*$fbname" 2>/dev/null
    
    notify "Compilazione interrotta: $fbname"
    exit "$exit_code"
}

# ============================================================================
# FUNZIONI DI GESTIONE LOG RSYNC
# ============================================================================

# Funzione per gestire la rotazione dei log rsync
rotate_rsync_log() {
    local backup_local_dir="${source_dir}/backup"
    local log_file="$backup_local_dir/rsync-$fbname.log"
    
    # Crea la cartella backup se non esiste
    if ! mkdir -p "$backup_local_dir" 2>/dev/null; then
        log WARN "Impossibile creare cartella backup per log: $backup_local_dir"
        return 1
    fi
    
    # Controlla se il log esiste e la sua dimensione
    if [ -f "$log_file" ]; then
        local current_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
        
        # Se il log supera la dimensione massima, ruotalo
        if [ "$current_size" -ge "$RSYNC_LOG_MAX_SIZE" ]; then
            log DEBUG "Log rsync supera 5MB, rotazione in corso..."
            
            # Trova il numero progressivo più alto esistente
            local max_num=0
            for existing_log in "$backup_local_dir"/rsync-"$fbname".log.*; do
                if [ -f "$existing_log" ]; then
                    local num=$(echo "$existing_log" | sed "s/.*rsync-$fbname\.log\.//" | grep '^[0-9]*$' || echo "0")
                    if [ "$num" -gt "$max_num" ]; then
                        max_num=$num
                    fi
                fi
            done
            
            # Ruota il log corrente
            local next_num=$((max_num + 1))
            local rotated_log="$backup_local_dir/rsync-$fbname.log.$next_num"
            
            if mv "$log_file" "$rotated_log"; then
                log DEBUG "Log ruotato: backup/rsync-$fbname.log.$next_num"
                
                # Comprimi il log ruotato per risparmiare spazio
                if command -v gzip >/dev/null 2>&1; then
                    gzip "$rotated_log"
                    log DEBUG "Log compresso: backup/rsync-$fbname.log.$next_num.gz"
                fi
            else
                log WARN "Errore nella rotazione del log rsync"
            fi
        fi
    fi
    
    # Pulizia log vecchi (mantieni solo gli ultimi RSYNC_LOG_MAX_FILES)
    cleanup_old_rsync_logs "$backup_local_dir"
    
    echo "$log_file"
}

# Funzione per rimuovere log rsync vecchi
cleanup_old_rsync_logs() {
    local backup_dir="$1"
    
    # Conta i log esistenti (compressi e non)
    local log_count=$(find "$backup_dir" -name "rsync-$fbname.log.*" | wc -l)
    
    if [ "$log_count" -gt "$RSYNC_LOG_MAX_FILES" ]; then
        log DEBUG "Pulizia log rsync vecchi (mantengo ultimi $RSYNC_LOG_MAX_FILES)..."
        
        # Trova e rimuovi i log più vecchi
        find "$backup_dir" -name "rsync-$fbname.log.*" -type f -printf '%T@ %p\n' | \
        sort -n | head -n -"$RSYNC_LOG_MAX_FILES" | cut -d' ' -f2- | \
        while read -r old_log; do
            if [ -f "$old_log" ]; then
                rm -f "$old_log"
                log DEBUG "Rimosso log vecchio: backup/$(basename "$old_log")"
            fi
        done
    fi
}

# ============================================================================
# FUNZIONI DI BACKUP
# ============================================================================

# Backup compresso del file TEX (remoto)
backup_tex_file() {
    if [ "$BACKUP_TEX_ENABLED" = true ] && [ -f "$TEX_FILE" ]; then
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local base_name="${fbname}-${timestamp}"
        local backup_file=""
        
        log DEBUG "Creazione backup TEX remoto..."
        
        case "$BACKUP_FORMAT" in
            7z)
                backup_file="$BACKUP_DIR/${base_name}.7z"
                if 7z a -mx=9 "$backup_file" "$TEX_FILE" >/dev/null 2>&1; then
                    log DEBUG "Backup TEX remoto: $(basename "$backup_file") (7z)"
                else
                    log WARN "Errore nel backup 7z del file TEX"
                fi
                ;;
            zip)
                backup_file="$BACKUP_DIR/${base_name}.zip"
                if zip -9 -j "$backup_file" "$TEX_FILE" >/dev/null 2>&1; then
                    log DEBUG "Backup TEX remoto: $(basename "$backup_file") (zip)"
                else
                    log WARN "Errore nel backup zip del file TEX"
                fi
                ;;
            tar.gz)
                backup_file="$BACKUP_DIR/${base_name}.tar.gz"
                if tar -czf "$backup_file" -C "$source_dir" "$(basename "$TEX_FILE")" 2>/dev/null; then
                    log DEBUG "Backup TEX remoto: $(basename "$backup_file") (tar.gz)"
                else
                    log WARN "Errore nel backup tar.gz del file TEX"
                fi
                ;;
        esac
        
        # Pulizia backup vecchi
        if [ -f "$backup_file" ]; then
            local backup_count=$(find "$BACKUP_DIR" -name "${fbname}-*.${BACKUP_FORMAT}" -o -name "${fbname}-*.7z" -o -name "${fbname}-*.zip" -o -name "${fbname}-*.tar.gz" | wc -l)
            if [ "$backup_count" -gt "$MAX_LOG_FILES" ]; then
                find "$BACKUP_DIR" \( -name "${fbname}-*.${BACKUP_FORMAT}" -o -name "${fbname}-*.7z" -o -name "${fbname}-*.zip" -o -name "${fbname}-*.tar.gz" \) -type f -printf '%T@ %p\n' | \
                sort -n | head -n -"$MAX_LOG_FILES" | cut -d' ' -f2- | \
                while read -r old_backup; do
                    rm -f "$old_backup"
                    log DEBUG "Rimosso backup remoto vecchio: $(basename "$old_backup")"
                done
            fi
        fi
    fi
}

# Backup locale del file TEX (nella cartella backup/ locale)
backup_tex_local() {
    if [ "$BACKUP_TEX_LOCAL" = true ] && [ -f "$TEX_FILE" ]; then
        local backup_local_dir="${source_dir}/backup"
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_name="${backup_local_dir}/${fbname}-backup-${timestamp}.tex"
        
        log DEBUG "Creazione backup TEX locale in cartella backup/..."
        
        # Crea la cartella backup se non esiste
        if ! mkdir -p "$backup_local_dir" 2>/dev/null; then
            log WARN "Impossibile creare cartella backup locale: $backup_local_dir"
            return 1
        fi
        
        if cp "$TEX_FILE" "$backup_name"; then
            log DEBUG "Backup TEX locale: backup/$(basename "$backup_name")"
            
            # Mantieni solo gli ultimi N backup locali nella cartella backup
            local backup_count=$(find "$backup_local_dir" -name "${fbname}-backup-*.tex" | wc -l)
            if [ "$backup_count" -gt "$MAX_LOG_FILES" ]; then
                find "$backup_local_dir" -name "${fbname}-backup-*.tex" -type f -printf '%T@ %p\n' | \
                sort -n | head -n -"$MAX_LOG_FILES" | cut -d' ' -f2- | \
                while read -r old_backup; do
                    rm -f "$old_backup"
                    log DEBUG "Rimosso backup locale vecchio: backup/$(basename "$old_backup")"
                done
            fi
        else
            log WARN "Errore nel backup locale del file TEX"
        fi
    fi
}

# Backup del PDF esistente prima della nuova compilazione (nella cartella backup/ locale)
backup_existing_pdf() {
    if [ "$BACKUP_PDF_ENABLED" = true ] && [ -f "$pdf_output" ]; then
        local backup_local_dir="${source_dir}/backup"
        local backup_name="${backup_local_dir}/${fbname}-backup-$(date +%Y%m%d-%H%M%S).pdf"
        
        log DEBUG "Backup PDF esistente in cartella backup/..."
        
        # Crea la cartella backup se non esiste
        if ! mkdir -p "$backup_local_dir" 2>/dev/null; then
            log WARN "Impossibile creare cartella backup locale: $backup_local_dir"
            return 1
        fi
        
        if cp "$pdf_output" "$backup_name"; then
            log DEBUG "Backup PDF: backup/$(basename "$backup_name")"
            
            # Mantieni solo gli ultimi N backup PDF nella cartella backup
            local backup_count=$(find "$backup_local_dir" -name "${fbname}-backup-*.pdf" | wc -l)
            if [ "$backup_count" -gt "$MAX_LOG_FILES" ]; then
                find "$backup_local_dir" -name "${fbname}-backup-*.pdf" -type f -printf '%T@ %p\n' | \
                sort -n | head -n -"$MAX_LOG_FILES" | cut -d' ' -f2- | \
                while read -r old_backup; do
                    rm -f "$old_backup"
                    log DEBUG "Rimosso backup PDF vecchio: backup/$(basename "$old_backup")"
                done
            fi
        else
            log WARN "Errore nel backup del PDF esistente"
        fi
    fi
}

# ============================================================================
# FUNZIONE DI LINEARIZZAZIONE PDF
# ============================================================================

# Linearizza il PDF per migliorare prestazioni e compatibilità
linearize_pdf() {
    local input_pdf="$1"
    local temp_pdf="${input_pdf%.pdf}-lin.pdf"
    
    if [ -f "$input_pdf" ]; then
        log DEBUG "Linearizzazione PDF: $(basename "$input_pdf")"
        local original_size=$(stat -c%s "$input_pdf" 2>/dev/null || echo "0")
        
        if qpdf --linearize "$input_pdf" "$temp_pdf" 2>/dev/null; then
            local new_size=$(stat -c%s "$temp_pdf" 2>/dev/null || echo "0")
            local diff=$((new_size - original_size))
            
            mv "$temp_pdf" "$input_pdf"
            
            if [ "$VERBOSE" = true ]; then
                if [ $diff -gt 0 ]; then
                    log DEBUG "Linearizzazione completata: +$diff byte"
                elif [ $diff -lt 0 ]; then
                    log DEBUG "Linearizzazione completata: $diff byte"
                else
                    log DEBUG "Linearizzazione completata: dimensione invariata"
                fi
            fi
        else
            log WARN "Errore nella linearizzazione PDF"
            rm -f "$temp_pdf"
        fi
    fi
}

# ============================================================================
# FUNZIONE DI ANALISI PROGETTO LATEX
# ============================================================================

# Funzione per formattare dimensioni file
format_file_size() {
    local size="$1"
    if [ "$size" -ge 1048576 ]; then
        echo "$size" | awk '{printf "%.1fMB", $1/1048576}'
    elif [ "$size" -ge 1024 ]; then
        echo "$size" | awk '{printf "%.1fKB", $1/1024}'
    else
        echo "${size}B"
    fi
}

# Analizza e verifica la struttura del progetto LaTeX sincronizzato
check_common_folders() {
    local common_folders="fonts immagini images img figures figs sezioni sections capitoli chapters appendici bibliography bib style styles templates bibliografia risorse resources assets tabelle tables grafici charts backup"
    local found_info=""
    local total_project_files=0
    
    log DEBUG "Analisi struttura progetto LaTeX..."
    
    for folder in $common_folders; do
        if [ -d "$source_dir/$folder" ]; then
            local file_count=$(find "$source_dir/$folder" -type f 2>/dev/null | wc -l)
            local dir_size=$(du -sh "$source_dir/$folder" 2>/dev/null | cut -f1)
            
            if [ "$file_count" -gt 0 ]; then
                # Determina il tipo e contenuto della cartella
                local folder_type=""
                local main_extensions=""
                
                case "$folder" in
                    fonts|font) 
                        folder_type="🔤 Font"
                        main_extensions=$(find "$source_dir/$folder" -name "*.ttf" -o -name "*.otf" -o -name "*.woff*" 2>/dev/null | wc -l)
                        ;;
                    immagini|images|img|figures|figs) 
                        folder_type="🖼️  Immagini"
                        main_extensions=$(find "$source_dir/$folder" -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.svg" -o -name "*.pdf" 2>/dev/null | wc -l)
                        ;;
                    sezioni|sections|capitoli|chapters) 
                        folder_type="📝 Sezioni"
                        main_extensions=$(find "$source_dir/$folder" -name "*.tex" 2>/dev/null | wc -l)
                        ;;
                    appendici) 
                        folder_type="📋 Appendici"
                        main_extensions=$(find "$source_dir/$folder" -name "*.tex" 2>/dev/null | wc -l)
                        ;;
                    bibliography|bib|bibliografia) 
                        folder_type="📚 Bibliografia"
                        main_extensions=$(find "$source_dir/$folder" -name "*.bib" 2>/dev/null | wc -l)
                        ;;
                    style|styles) 
                        folder_type="🎨 Stili"
                        main_extensions=$(find "$source_dir/$folder" -name "*.sty" -o -name "*.cls" 2>/dev/null | wc -l)
                        ;;
                    templates) 
                        folder_type="📋 Template"
                        main_extensions=$(find "$source_dir/$folder" -name "*.tex" 2>/dev/null | wc -l)
                        ;;
                    tabelle|tables) 
                        folder_type="📊 Tabelle"
                        main_extensions=$(find "$source_dir/$folder" -name "*.tex" -o -name "*.csv" 2>/dev/null | wc -l)
                        ;;
                    grafici|charts) 
                        folder_type="📈 Grafici"
                        main_extensions=$(find "$source_dir/$folder" -name "*.png" -o -name "*.pdf" -o -name "*.svg" 2>/dev/null | wc -l)
                        ;;
                    risorse|resources|assets) 
                        folder_type="📦 Risorse"
                        main_extensions="$file_count"
                        ;;
                    backup) 
                        folder_type="💾 Backup"
                        main_extensions=$(find "$source_dir/$folder" -name "*.tex" -o -name "*.pdf" 2>/dev/null | wc -l)
                        ;;
                    *) 
                        folder_type="📁 Altro"
                        main_extensions="$file_count"
                        ;;
                esac
                
                # Verifica stato sincronizzazione
                local sync_status="✓"
                if [ "$folder" = "backup" ]; then
                    sync_status="✗ (esclusa)"
                elif [ -d "$DEST_DIR/$folder" ]; then
                    local dest_file_count=$(find "$DEST_DIR/$folder" -type f 2>/dev/null | wc -l)
                    if [ "$dest_file_count" -ne "$file_count" ]; then
                        sync_status="⚠ ($dest_file_count/$file_count)"
                    fi
                else
                    sync_status="✗ (mancante)"
                fi
                
                total_project_files=$((total_project_files + file_count))
                
                # Output dettagliato o compatto
                if [ "$VERBOSE" = true ]; then
                    log COPY "  $folder_type $folder/ → $file_count file, $dir_size $sync_status"
                else
                    found_info="$found_info $folder($file_count)"
                fi
            fi
        fi
    done
    
    # Report riassuntivo del progetto
    if [ "$total_project_files" -gt 0 ]; then
        if [ "$VERBOSE" = false ] && [ -n "$found_info" ]; then
            log COPY "Cartelle progetto sincronizzate:$found_info"
        fi
        
        # Statistiche aggiuntive per modalità verbose
        if [ "$VERBOSE" = true ]; then
            local total_tex_files=$(find "$source_dir" -name "*.tex" -type f 2>/dev/null | wc -l)
            local total_img_files=$(find "$source_dir" \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.svg" -o -name "*.pdf" \) -type f 2>/dev/null | wc -l)
            local total_bib_files=$(find "$source_dir" -name "*.bib" -type f 2>/dev/null | wc -l)
            
            log COPY "📊 Statistiche progetto: $total_tex_files TEX, $total_img_files immagini, $total_bib_files bibliografie"
            
            # Mostra file TEX principali (livello root)
            local main_tex_files=$(find "$source_dir" -maxdepth 1 -name "*.tex" -type f 2>/dev/null)
            if [ -n "$main_tex_files" ]; then
                log COPY "📝 File TEX principali:"
                echo "$main_tex_files" | while read -r tex_file; do
                    if [ -n "$tex_file" ]; then
                        local tex_size=$(stat -c%s "$tex_file" 2>/dev/null || echo "0")
                        local tex_size_formatted=$(format_file_size "$tex_size")
                        local tex_lines=$(wc -l < "$tex_file" 2>/dev/null || echo "0")
                        log COPY "    📝 $(basename "$tex_file") → $tex_size_formatted, $tex_lines righe"
                    fi
                done
            fi
        fi
    else
        if [ "$VERBOSE" = true ]; then
            log COPY "📁 Progetto semplice: nessuna sottocartella rilevata"
        fi
    fi
}

# ============================================================================
# FUNZIONE DI SINCRONIZZAZIONE COMPLETA
# ============================================================================

# Sincronizza l'intera cartella del progetto con la destinazione
safe_copy_files() {
    if [ "$COPY_ENABLED" = false ]; then
        log DEBUG "Sincronizzazione disabilitata con --no-copy"
        return 0
    fi
    
    if [ ! -d "$DEST_DIR" ]; then
        log ERROR "Directory di destinazione non esistente: $DEST_DIR"
        return 1
    fi
    
    log COPY "Sincronizzazione cartella completa con $DEST_DIR"
    
    # Gestione log rsync con rotazione nella cartella backup
    local rsync_log=$(rotate_rsync_log)
    
    # Aggiungi timestamp e separatore al log additivo
    {
        echo ""
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') - Sync cartella $fbname ==="
    } >> "$rsync_log"
    
    # Opzioni rsync per sincronizzazione completa
    local rsync_options="-avhu --itemize-changes --delete-excluded"
    
    # Pattern di esclusione per file temporanei e di sistema
    local exclude_patterns="--exclude=*.aux --exclude=*.log --exclude=*.out --exclude=*.toc --exclude=*.lot --exclude=*.lof --exclude=*.idx --exclude=*.ind --exclude=*.bbl --exclude=*.blg --exclude=*.fls --exclude=*.fdb_latexmk --exclude=*.synctex.gz --exclude=backup/ --exclude=.DS_Store --exclude=Thumbs.db --exclude=.git/ --exclude=.svn/ --exclude=build/ --exclude=temp/ --exclude=*.tmp"
    
    if [ "$VERBOSE" = false ]; then
        rsync_options="-ahu --itemize-changes --delete-excluded"
    fi
    
    # Pre-analisi della cartella sorgente
    log DEBUG "Scansione directory sorgente per la sincronizzazione..."
    local total_dirs=$(find "$source_dir" -type d | wc -l)
    local total_files=$(find "$source_dir" -type f | wc -l)
    log DEBUG "Trovate $((total_dirs-1)) cartelle e $total_files file da valutare"
    
    # Esecuzione sincronizzazione con rsync
    if rsync $rsync_options $exclude_patterns "$source_dir/" "$DEST_DIR/" >> "$rsync_log" 2>&1; then
        # Analisi risultati sincronizzazione
        local copied_files=$(grep -E '^[><]f' "$rsync_log" | tail -n +2 | wc -l)
        local copied_dirs=$(grep -E '^[><]d' "$rsync_log" | tail -n +2 | wc -l)
        local updated_files=$(grep -E '^[><]f.+' "$rsync_log" | tail -n +2 | awk '{print $2}' | sort)
        local updated_dirs=$(grep -E '^[><]d.+' "$rsync_log" | tail -n +2 | awk '{print $2}' | sort)
        
        # Report dei risultati
        local total_copied=$((copied_files + copied_dirs))
        if [ "$total_copied" -gt 0 ]; then
            if [ "$copied_dirs" -gt 0 ] && [ "$copied_files" -gt 0 ]; then
                log COPY "Sincronizzati: $copied_dirs cartelle, $copied_files file"
            elif [ "$copied_dirs" -gt 0 ]; then
                log COPY "Sincronizzate: $copied_dirs cartelle"
            elif [ "$copied_files" -gt 0 ]; then
                log COPY "Sincronizzati: $copied_files file"
            fi
            
            # Dettaglio cartelle sincronizzate (solo in verbose)
            if [ -n "$updated_dirs" ] && [ "$VERBOSE" = true ]; then
                echo "$updated_dirs" | while read -r dir; do
                    if [ -n "$dir" ]; then
                        log COPY "  📁 $dir/"
                    fi
                done
            fi
            
            # Dettaglio file sincronizzati
            if [ -n "$updated_files" ]; then
                echo "$updated_files" | while read -r file; do
                    if [ -n "$file" ]; then
                        local file_size=""
                        if [ -f "$DEST_DIR/$file" ]; then
                            local size_bytes=$(stat -c%s "$DEST_DIR/$file" 2>/dev/null || echo "0")
                            file_size=$(format_file_size "$size_bytes")
                        fi
                        
                        # Icona basata sul tipo di file
                        local icon="📄"
                        case "${file##*.}" in
                            pdf) icon="📕" ;;
                            tex|latex) icon="📝" ;;
                            png|jpg|jpeg|gif|svg) icon="🖼️" ;;
                            ttf|otf|woff|woff2) icon="🔤" ;;
                            bib) icon="📚" ;;
                            cls|sty) icon="📋" ;;
                            log) icon="📄" ;;
                            aux|out|toc|lot|lof) icon="⚙️" ;;
                            md) icon="📝" ;;
                            txt) icon="📄" ;;
                            *) icon="📄" ;;
                        esac
                        
                        if [ -n "$file_size" ]; then
                            log COPY "  $icon $file ($file_size)"
                        else
                            log COPY "  $icon $file"
                        fi
                    fi
                done
            fi
        else
            log COPY "Tutti i file e cartelle sono già aggiornati"
        fi
        
        # Verifica specifica del PDF principale
        if [ -f "$pdf_output" ]; then
            local pdf_dest="$DEST_DIR/$(basename "$pdf_output")"
            if [ -f "$pdf_dest" ]; then
                local pdf_dest_size=$(stat -c%s "$pdf_dest" 2>/dev/null || echo "0")
                local pdf_dest_formatted=$(format_file_size "$pdf_dest_size")
                log COPY "📕 PDF principale sincronizzato: $pdf_dest_formatted"
            fi
        fi
        
        # Analisi finale della struttura del progetto
        check_common_folders
        
        # Registra successo nel log
        echo "Risultato: SUCCESS - Cartella sincronizzata con successo ($total_copied elementi)" >> "$rsync_log"
        
        return 0
    else
        log ERROR "Errore durante la sincronizzazione della cartella"
        echo "Risultato: ERROR - Sincronizzazione fallita" >> "$rsync_log"
        return 1
    fi
}

# ============================================================================
# VALIDAZIONE INPUT E INIZIALIZZAZIONE
# ============================================================================

# Validazione argomenti
if [ -z "$TEX_FILE" ]; then
    log ERROR "Specificare un file .tex come parametro"
    echo "Usa '$0 -h' per l'aiuto completo"
    exit 1
fi

if [ ! -f "$TEX_FILE" ]; then
    log ERROR "File '$TEX_FILE' non trovato"
    exit 1
fi

# Verifica estensione file
if [ "${TEX_FILE##*.}" != "tex" ]; then
    log WARN "Il file non ha estensione .tex, continuando comunque..."
fi

# Verifica dipendenze
check_dependencies

# Inizializzazione variabili globali
start_time=$(date +%s)
fbname=$(basename "$TEX_FILE" .tex)
source_dir="$(dirname "$TEX_FILE")"
build_dir="/dev/shm/temp/build-$fbname"
log_dest="$source_dir/"
pdf_output="$source_dir/$fbname.pdf"

# Output informazioni iniziali
log INFO "LaTeX Build & Sync Script v$SCRIPT_VERSION - $fbname"
log DEBUG "File sorgente: $TEX_FILE"
log DEBUG "Directory build: $build_dir"
log DEBUG "Directory backup: $BACKUP_DIR"
log DEBUG "Formato backup: $BACKUP_FORMAT"
log DEBUG "Directory destinazione: $DEST_DIR"

# Creazione directory necessarie
if ! mkdir -p "$build_dir" 2>/dev/null; then
    log ERROR "Impossibile creare directory di build: $build_dir"
    exit 1
fi

if [ "$BACKUP_TEX_ENABLED" = true ]; then
    if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        log ERROR "Impossibile creare directory di backup: $BACKUP_DIR"
        exit 1
    fi
fi

if [ "$COPY_ENABLED" = true ]; then
    if ! mkdir -p "$DEST_DIR" 2>/dev/null; then
        log ERROR "Impossibile creare directory di destinazione: $DEST_DIR"
        exit 1
    fi
fi

# ============================================================================
# ESECUZIONE PRINCIPALE
# ============================================================================

# Controlli preliminari
check_disk_space

# Terminazione processi LaTeX esistenti per lo stesso file
EXISTING_LATEXMK=$(pgrep -f "latexmk.*$fbname" 2>/dev/null)
EXISTING_XELATEX=$(pgrep -f "xelatex.*$fbname" 2>/dev/null)

if [ -n "$EXISTING_LATEXMK" ] || [ -n "$EXISTING_XELATEX" ]; then
    log INFO "Terminando processi LaTeX esistenti per $fbname..."
    pkill -f "latexmk.*$fbname" 2>/dev/null
    pkill -f "xelatex.*$fbname" 2>/dev/null
    sleep 2
    pkill -9 -f "latexmk.*$fbname" 2>/dev/null
    pkill -9 -f "xelatex.*$fbname" 2>/dev/null
fi

# Statistiche file sorgente
source_size=$(stat -c%s "$TEX_FILE" 2>/dev/null || echo "0")
source_lines=$(wc -l < "$TEX_FILE" 2>/dev/null || echo "0")
source_size_formatted=$(format_file_size "$source_size")
log DEBUG "File sorgente: $source_size_formatted, $source_lines righe"

# Configurazione trap per cleanup
trap 'cleanup 130' INT TERM

# Esecuzione backup
log DEBUG "Esecuzione backup..."
backup_tex_file
backup_tex_local
backup_existing_pdf

# ============================================================================
# COMPILAZIONE LATEX
# ============================================================================

log INFO "Avvio compilazione LaTeX..."

if ! latexmk -xelatex -synctex=1 -auxdir="$build_dir" "$TEX_FILE" 2>&1; then
    log ERROR "Compilazione LaTeX fallita"
    notify "❌ Compilazione fallita: $fbname"
    cleanup 1
fi

# Verifica generazione PDF
if [ ! -f "$pdf_output" ]; then
    log ERROR "PDF non generato dopo la compilazione"
    exit 1
fi

# Statistiche PDF generato
pdf_size=$(stat -c%s "$pdf_output" 2>/dev/null || echo "0")
pdf_size_formatted=$(format_file_size "$pdf_size")

log INFO "PDF generato: $pdf_size_formatted"

# ============================================================================
# POST-PROCESSING
# ============================================================================

# Gestione log di compilazione
if [ -f "$build_dir/$fbname.log" ]; then
    cp "$build_dir/$fbname.log" "$log_dest/$fbname.log" 2>/dev/null
    
    # Analisi errori e warning (solo in modalità verbose)
    if [ "$VERBOSE" = true ]; then
        local warnings=$(grep -c "LaTeX Warning" "$log_dest/$fbname.log" 2>/dev/null | head -1 || echo "0")
        local errors=$(grep -c "LaTeX Error\|! " "$log_dest/$fbname.log" 2>/dev/null | head -1 || echo "0")
        warnings=$(echo "$warnings" | tr -d ' ' | head -c 10)
        errors=$(echo "$errors" | tr -d ' ' | head -c 10)
        case "$warnings" in ''|*[!0-9]*) warnings=0 ;; esac
        case "$errors" in ''|*[!0-9]*) errors=0 ;; esac
        
        if [ "$warnings" -gt 0 ] || [ "$errors" -gt 0 ]; then
            log INFO "Analisi log: $errors errori, $warnings warning"
        fi
    fi
fi

# Linearizzazione PDF
linearize_pdf "$pdf_output"

# ============================================================================
# SINCRONIZZAZIONE E FINALIZZAZIONE
# ============================================================================

# Calcolo tempo di compilazione
end_time=$(date +%s)
duration=$((end_time - start_time))
hours=$((duration/3600))
minutes=$((duration%3600/60))
seconds=$((duration%60))

# Notifica completamento compilazione
notify "✅ $fbname → $pdf_size_formatted ($(printf "%02d:%02d:%02d" $hours $minutes $seconds))"

# Output risultato compilazione
if [ "$VERBOSE" = true ]; then
    printf "✓ %s → %s in %02d:%02d:%02d\n" \
           "$fbname" "$pdf_size_formatted" $hours $minutes $seconds
    printf "  Sorgente: %s (%d righe)\n" \
           "$source_size_formatted" $source_lines
else
    printf "✓ %s → %s (%02d:%02d:%02d)\n" \
           "$fbname" "$pdf_size_formatted" $hours $minutes $seconds
fi

# Esecuzione sincronizzazione
log INFO "Avvio sincronizzazione..."
if ! safe_copy_files; then
    log ERROR "Sincronizzazione fallita, ma compilazione completata con successo"
    exit 1
fi

# ============================================================================
# REPORT FINALE
# ============================================================================

# Calcolo tempo totale
total_end_time=$(date +%s)
total_duration=$((total_end_time - start_time))
total_hours=$((total_duration/3600))
total_minutes=$((total_duration%3600/60))
total_seconds=$((total_duration%60))

if [ "$VERBOSE" = true ]; then
    printf "\n"
    printf "========================================\n"
    printf "PROCESSO COMPLETATO CON SUCCESSO\n"
    printf "========================================\n"
    printf "Durata totale: %02d:%02d:%02d\n" $total_hours $total_minutes $total_seconds
    printf "File principale: %s\n" "$TEX_FILE"
    printf "PDF generato: %s (%s)\n" "$pdf_output" "$pdf_size_formatted"
    printf "Destinazione: %s\n" "$DEST_DIR"
    printf "Log sincronizzazione: %s/backup/rsync-%s.log\n" "$source_dir" "$fbname"
    printf "========================================\n"
fi

log INFO "Processo completato con successo"

exit 0
