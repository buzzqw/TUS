#!/bin/sh
# LaTeX Build Script v2.1
# Miglioramenti: logging, backup, notifiche, validazione, statistiche, backup compresso

# Configurazione
SCRIPT_VERSION="2.1"
MAX_LOG_FILES=100
NOTIFICATION_ENABLED=true
BACKUP_TEX_ENABLED=true
BACKUP_PDF_ENABLED=false
VERBOSE=false
BACKUP_DIR="/home/andres/RPG/Pazfinder/TUS/OBSS/old"
BACKUP_FORMAT="7z"  # Default: 7z, opzioni: 7z, zip, tar.gz

# Parsing argomenti opzionali
while [ $# -gt 0 ]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-backup-tex)
            BACKUP_TEX_ENABLED=false
            shift
            ;;
        --no-backup-pdf)
            BACKUP_PDF_ENABLED=false
            shift
            ;;
        --no-backup)
            BACKUP_TEX_ENABLED=false
            BACKUP_PDF_ENABLED=false
            shift
            ;;
        --no-notify)
            NOTIFICATION_ENABLED=false
            shift
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
            echo "LaTeX Build Script v$SCRIPT_VERSION"
            echo "Uso: $0 [opzioni] file.tex"
            echo ""
            echo "Opzioni:"
            echo "  -v, --verbose              Output dettagliato"
            echo "  --no-backup-tex           Disabilita backup del file TEX"
            echo "  --no-backup-pdf           Disabilita backup del PDF esistente"
            echo "  --no-backup               Disabilita entrambi i backup"
            echo "  --no-notify               Disabilita notifiche desktop"
            echo "  --backup-format FORMAT    Formato backup TEX (7z|zip|tar.gz) [default: 7z]"
            echo "  --backup-dir DIR          Directory backup TEX [default: $BACKUP_DIR]"
            echo "  -h, --help                Mostra questo aiuto"
            echo ""
            echo "Esempi:"
            echo "  $0 documento.tex"
            echo "  $0 -v --no-backup-pdf tesi.tex"
            echo "  $0 --backup-format zip --no-backup-pdf documento.tex"
            echo "  $0 --backup-dir /tmp/backup documento.tex"
            exit 0
            ;;
        -*)
            echo "Opzione sconosciuta: $1"
            echo "Usa -h per l'aiuto"
            exit 1
            ;;
        *)
            TEX_FILE="$1"
            shift
            ;;
    esac
done

# Funzione di logging compatta
log() {
    local level="$1"
    shift
    local message="$*"
    
    case $level in
        INFO) echo "✓ $message" ;;
        WARN) echo "⚠ $message" >&2 ;;
        ERROR) echo "✗ $message" >&2 ;;
        DEBUG) [ "$VERBOSE" = true ] && echo "→ $message" ;;
    esac
}

# Funzione di notifica desktop
notify() {
    if [ "$NOTIFICATION_ENABLED" = true ] && command -v notify-send >/dev/null 2>&1; then
        notify-send "LaTeX Build" "$1" -i applications-science 2>/dev/null
    fi
}

# Validazione input migliorata
if [ -z "$TEX_FILE" ]; then
    log ERROR "Specificare un file .tex come parametro"
    echo "Usa '$0 -h' per l'aiuto"
    exit 1
fi

if [ ! -f "$TEX_FILE" ]; then
    log ERROR "File '$TEX_FILE' non trovato"
    exit 1
fi

# Verifica che sia effettivamente un file .tex
if [ "${TEX_FILE##*.}" != "tex" ]; then
    log WARN "Il file non ha estensione .tex, continuando comunque..."
fi

# Verifica dipendenze
check_dependencies() {
    local missing_deps=""
    
    for cmd in latexmk xelatex qpdf; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    # Verifica dipendenze di compressione
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
        log INFO "Installa con: sudo apt install texlive-xetex latexmk qpdf p7zip-full zip"
        exit 1
    fi
    
    log DEBUG "Tutte le dipendenze sono soddisfatte"
}

check_dependencies

# Inizializzazione con validazione
start_time=$(date +%s)
fbname=$(basename "$TEX_FILE" .tex)
source_dir="$(dirname "$TEX_FILE")"
build_dir="/dev/shm/temp/build-$fbname"
log_dest="$source_dir/"
pdf_output="$source_dir/$fbname.pdf"

log INFO "LaTeX Build v$SCRIPT_VERSION - $fbname"
log DEBUG "Sorgente: $TEX_FILE"
log DEBUG "Build: $build_dir"
log DEBUG "Backup dir: $BACKUP_DIR"
log DEBUG "Backup format: $BACKUP_FORMAT"

# Crea directory di build se non esiste
if ! mkdir -p "$build_dir" 2>/dev/null; then
    log ERROR "Impossibile creare directory di build: $build_dir"
    exit 1
fi

# Crea directory di backup se non esiste
if [ "$BACKUP_TEX_ENABLED" = true ]; then
    if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        log ERROR "Impossibile creare directory di backup: $BACKUP_DIR"
        exit 1
    fi
fi

# Funzione per creare backup compresso del file TEX
backup_tex_file() {
    if [ "$BACKUP_TEX_ENABLED" = true ] && [ -f "$TEX_FILE" ]; then
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local base_name="${fbname}-${timestamp}"
        local backup_file=""
        
        case "$BACKUP_FORMAT" in
            7z)
                backup_file="$BACKUP_DIR/${base_name}.7z"
                if 7z a -mx=9 "$backup_file" "$TEX_FILE" >/dev/null 2>&1; then
                    log DEBUG "Backup TEX: $(basename "$backup_file") (7z)"
                else
                    log WARN "Errore nel backup 7z del file TEX"
                fi
                ;;
            zip)
                backup_file="$BACKUP_DIR/${base_name}.zip"
                if zip -9 -j "$backup_file" "$TEX_FILE" >/dev/null 2>&1; then
                    log DEBUG "Backup TEX: $(basename "$backup_file") (zip)"
                else
                    log WARN "Errore nel backup zip del file TEX"
                fi
                ;;
            tar.gz)
                backup_file="$BACKUP_DIR/${base_name}.tar.gz"
                if tar -czf "$backup_file" -C "$source_dir" "$(basename "$TEX_FILE")" 2>/dev/null; then
                    log DEBUG "Backup TEX: $(basename "$backup_file") (tar.gz)"
                else
                    log WARN "Errore nel backup tar.gz del file TEX"
                fi
                ;;
        esac
        
        # Gestione backup vecchi nella directory di backup
        if [ -f "$backup_file" ]; then
            local backup_count=$(find "$BACKUP_DIR" -name "${fbname}-*.${BACKUP_FORMAT}" -o -name "${fbname}-*.7z" -o -name "${fbname}-*.zip" -o -name "${fbname}-*.tar.gz" | wc -l)
            if [ "$backup_count" -gt "$MAX_LOG_FILES" ]; then
                find "$BACKUP_DIR" \( -name "${fbname}-*.${BACKUP_FORMAT}" -o -name "${fbname}-*.7z" -o -name "${fbname}-*.zip" -o -name "${fbname}-*.tar.gz" \) -type f -printf '%T@ %p\n' | \
                sort -n | head -n -"$MAX_LOG_FILES" | cut -d' ' -f2- | \
                while read -r old_backup; do
                    rm -f "$old_backup"
                    log DEBUG "Rimosso backup vecchio: $(basename "$old_backup")"
                done
            fi
        fi
    fi
}

# Backup del PDF esistente
backup_existing_pdf() {
    if [ "$BACKUP_PDF_ENABLED" = true ] && [ -f "$pdf_output" ]; then
        local backup_name="${pdf_output%.pdf}-backup-$(date +%Y%m%d-%H%M%S).pdf"
        
        if cp "$pdf_output" "$backup_name"; then
            log DEBUG "Backup PDF: $(basename "$backup_name")"
            
            # Mantieni solo gli ultimi N backup
            local backup_count=$(find "$source_dir" -name "${fbname}-backup-*.pdf" | wc -l)
            if [ "$backup_count" -gt "$MAX_LOG_FILES" ]; then
                find "$source_dir" -name "${fbname}-backup-*.pdf" -type f -printf '%T@ %p\n' | \
                sort -n | head -n -"$MAX_LOG_FILES" | cut -d' ' -f2- | \
                while read -r old_backup; do
                    rm -f "$old_backup"
                done
            fi
        fi
    fi
}

# Esegui backup del file TEX e del PDF esistente
backup_tex_file
backup_existing_pdf

# Controllo spazio disco in /dev/shm
check_disk_space() {
    local available_kb=$(df /dev/shm | tail -1 | awk '{print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [ "$available_mb" -lt 100 ]; then
        log WARN "Poco spazio in /dev/shm: ${available_mb}MB"
    fi
}

check_disk_space

# Killa processi esistenti per lo stesso file
EXISTING_LATEXMK=$(pgrep -f "latexmk.*$fbname" 2>/dev/null)
EXISTING_XELATEX=$(pgrep -f "xelatex.*$fbname" 2>/dev/null)

if [ -n "$EXISTING_LATEXMK" ] || [ -n "$EXISTING_XELATEX" ]; then
    log INFO "Terminando processi esistenti..."
    pkill -f "latexmk.*$fbname" 2>/dev/null
    pkill -f "xelatex.*$fbname" 2>/dev/null
    sleep 2
    pkill -9 -f "latexmk.*$fbname" 2>/dev/null
    pkill -9 -f "xelatex.*$fbname" 2>/dev/null
fi

# Statistiche compatte
source_size=$(stat -c%s "$TEX_FILE" 2>/dev/null || echo "0")
source_lines=$(wc -l < "$TEX_FILE" 2>/dev/null || echo "0")
log DEBUG "Sorgente: $(echo "$source_size" | awk '{print int($1/1024)}')KB, $source_lines righe"

# Funzione di cleanup migliorata
cleanup() {
    local exit_code=${1:-1}
    log WARN "Interruzione - cleanup..."
    pkill -f "latexmk.*$fbname" 2>/dev/null
    pkill -f "xelatex.*$fbname" 2>/dev/null
    sleep 1
    pkill -9 -f "latexmk.*$fbname" 2>/dev/null
    pkill -9 -f "xelatex.*$fbname" 2>/dev/null
    notify "Compilazione interrotta: $fbname"
    exit "$exit_code"
}

# Aggiungi trap
trap 'cleanup 130' INT TERM

# Compilazione LaTeX
if ! latexmk -xelatex -synctex=1 -auxdir="$build_dir" "$TEX_FILE" 2>&1; then
    log ERROR "Compilazione fallita"
    notify "❌ Compilazione fallita: $fbname"
    cleanup 1
fi

# Verifica PDF e ottieni statistiche
if [ ! -f "$pdf_output" ]; then
    log ERROR "PDF non generato"
    exit 1
fi

pdf_size=$(stat -c%s "$pdf_output" 2>/dev/null || echo "0")
pdf_size_mb=$(echo "$pdf_size" | awk '{printf "%.1f", $1/1024/1024}')

# Gestione log compatta
if [ -f "$build_dir/$fbname.log" ]; then
    cp "$build_dir/$fbname.log" "$log_dest/$fbname.log" 2>/dev/null
    
    # Analisi errori/warning solo se verbose
    if [ "$VERBOSE" = true ]; then
        local warnings=$(grep -c "LaTeX Warning" "$log_dest/$fbname.log" 2>/dev/null | head -1 || echo "0")
        local errors=$(grep -c "LaTeX Error\|! " "$log_dest/$fbname.log" 2>/dev/null | head -1 || echo "0")
        warnings=$(echo "$warnings" | tr -d ' ' | head -c 10)
        errors=$(echo "$errors" | tr -d ' ' | head -c 10)
        case "$warnings" in ''|*[!0-9]*) warnings=0 ;; esac
        case "$errors" in ''|*[!0-9]*) errors=0 ;; esac
        
        if [ "$warnings" -gt 0 ] || [ "$errors" -gt 0 ]; then
            log INFO "Log: $errors errori, $warnings warning"
        fi
    fi
fi

# Calcolo durata finale e output
end_time=$(date +%s)
duration=$((end_time - start_time))
hours=$((duration/3600))
minutes=$((duration%3600/60))
seconds=$((duration%60))

# Notifica con tempo e dimensione
notify "✅ $fbname → ${pdf_size_mb}MB ($(printf "%02d:%02d:%02d" $hours $minutes $seconds))"

# Output finale compatto - UN SOLO TEMPO
if [ "$VERBOSE" = true ]; then
    printf "✓ %s → %sMB in %02d:%02d:%02d\n" \
           "$fbname" "$pdf_size_mb" $hours $minutes $seconds
    printf "  Sorgente: %dKB (%d righe)\n" \
           $((source_size/1024)) $source_lines
else
    printf "✓ %s → %sMB (%02d:%02d:%02d)\n" \
           "$fbname" "$pdf_size_mb" $hours $minutes $seconds
fi

# Funzione per linearizzare PDF
linearize_pdf() {
    local input_pdf="$1"
    local temp_pdf="${input_pdf%.pdf}-lin.pdf"
    
    if [ -f "$input_pdf" ]; then
        echo "Linearizzazione: $input_pdf"
        local original_size=$(stat -c%s "$input_pdf" 2>/dev/null || echo "0")
        
        if qpdf --linearize "$input_pdf" "$temp_pdf"; then
            local new_size=$(stat -c%s "$temp_pdf" 2>/dev/null || echo "0")
            local diff=$((new_size - original_size))
            
            rm "$input_pdf"
            mv "$temp_pdf" "$input_pdf"
            
            if [ $diff -gt 0 ]; then
                echo "  Dimensione aumentata di +$diff byte"
            elif [ $diff -lt 0 ]; then
                echo "  Dimensione ridotta di $diff byte"
            else
                echo "  Dimensione invariata"
            fi
        else
            echo "Errore nella linearizzazione di $input_pdf"
            rm -f "$temp_pdf"
        fi
    else
        echo "File non trovato: $input_pdf"
    fi
}

# Calcolo durata compilazione
end_time=$(date +%s)
duration=$((end_time - start_time))
printf "Durata compilazione: %02d:%02d:%02d\n" $((duration/3600)) $((duration%3600/60)) $((duration%60))

# Durata totale
total_end_time=$(date +%s)
total_duration=$((total_end_time - start_time))
printf "Durata totale: %02d:%02d:%02d\n" $((total_duration/3600)) $((total_duration%3600/60)) $((total_duration%60))
