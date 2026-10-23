#!/usr/bin/env bash

#=======================================================================================
# ddn2.sh - Build & publish pipeline per OBSS
#
# Compila i documenti LaTeX, ottimizza i PDF, genera il Markdown, prepara gli asset,
# aggiorna wiki/GitHub Pages, esegue commit/push e crea (o aggiorna) la release GitHub.
#
# Autore: Andres Zanzani
# Versione: 6.0
# Licenza: GPL-3.0
#
# Uso: ./ddn2.sh [opzioni]
#      ./ddn2.sh --help
#
# Variabili d'ambiente:
#   OBSS_DIR            directory di lavoro (default: directory dello script)
#   OBSS_FILE1          documento principale IT        (default: OBSSv2.tex)
#   OBSS_FILE2          documento principale EN        (default: OBSSv2-eng.tex)
#   OBSS_TEMP_DIR       directory build persistenti    (default: /dev/shm/temp)
#   OBSS_TOKEN_FILE     file con githubtoken=...       (default: .token)
#   OBSS_SECTIONS_DIR   directory sezioni              (default: sezioni)
#   OBSS_ASSETS_DIR     directory asset per release    (default: "per versione")
#   OBSS_ASSETS         lista asset separata da newline (sovrascrive quella interna)
#   OBSS_REPO_OWNER     owner GitHub                   (default: buzzqw)
#   OBSS_REPO_NAME      repo GitHub                    (default: TUS)
#   OBSS_API_URL        base URL API GitHub            (default: https://api.github.com)
#   OBSS_JOBS           job paralleli compilazione     (default: 4)
#   NO_COLOR            disabilita i colori
#=======================================================================================

set -o pipefail
shopt -s nullglob

SCRIPT_VERSION="6.0"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_START=$SECONDS

#==============================================================================
# CONFIGURAZIONE (sovrascrivibile da ambiente)
#==============================================================================

TARGET_DIR="${OBSS_DIR:-$SCRIPT_DIR}"
FILE1="${OBSS_FILE1:-OBSSv2.tex}"
FILE2="${OBSS_FILE2:-OBSSv2-eng.tex}"
MD1="${FILE1%.tex}.md"
MD2="${FILE2%.tex}.md"
TEMP_DIR="${OBSS_TEMP_DIR:-/dev/shm/temp}"
TOKEN_FILE="${OBSS_TOKEN_FILE:-$TARGET_DIR/.token}"
SECTIONS_DIR="${OBSS_SECTIONS_DIR:-sezioni}"
ASSETS_DIR="${OBSS_ASSETS_DIR:-per versione}"

REPO_OWNER="${OBSS_REPO_OWNER:-buzzqw}"
REPO_NAME="${OBSS_REPO_NAME:-TUS}"
API_URL="${OBSS_API_URL:-https://api.github.com}"

# Asset pubblicati nella release (sovrascrivibili con OBSS_ASSETS)
ASSETS=(
    "OBSSv2.pdf" "OBSSv2-eng.pdf" "OBSS-Iniziativa.pdf"
    "OBSSv2-scheda.pdf" "OBSSv2-scheda-v3.pdf"
    "OBSS-schema-narratore-personaggi.pdf"
    "OBSS-utilita.pdf" "screenv2.pdf" "screenv2-eng.pdf"
    "OBSSv2-scheda-eng.pdf" "OBSS-options.pdf" "OBSS-utility.pdf"
    "OBSS-schema-arbiter-character-eng.pdf"
    "combat-quick-ita.pdf" "combat-quick-eng.pdf"
    "magia-quick-eng.pdf" "magia-quick-ita.pdf"
)
if [[ -n "${OBSS_ASSETS:-}" ]]; then
    ASSETS=()
    while IFS= read -r _asset_line; do
        [[ -n "$_asset_line" ]] && ASSETS+=("$_asset_line")
    done <<< "$OBSS_ASSETS"
    unset _asset_line
fi

# File e directory gestiti da git (quelli inesistenti vengono saltati)
GIT_PATHS=(
    "immagini" "$SECTIONS_DIR" "${ASSETS[@]}"
    "$MD1" "$MD2" "markdown-separati"
    "CompileDROP.sh" "export_dati_mostri.py" "Latex2MarkDown.java"
    "latex2markdown.sh" "mostri_data.csv" "OBSS-options.tex"
    "$FILE1" "$FILE2" "OBSSv2-scheda.ods"
    "OBSSv2-scheda-eng.ods" "OBSSv2-scheda-v3.ods"
    "obsv2_wiki_script.js" "pages.py" "screenv2.tex"
    "screenv2-eng.tex" "ddn.sh" "ddn2.sh"
)

#==============================================================================
# STATO GLOBALE
#==============================================================================

OPERATION_COUNT=0
VERBOSE=0
INTERACTIVE=0

OPT_YES=0
OPT_CLEAN=0
OPT_VARIANTS=1
OPT_SECTIONS=1
OPT_MD=1
OPT_FORCE_MD=0
OPT_SYNCTEX=1
OPT_GIT=1
OPT_PUSH=1
OPT_RELEASE=2          # 0=no, 1=sì, 2=chiedi (default)
OPT_WIKI=""            # ""=chiedi, none, normal, reset, clean
OPT_PAGES=""           # ""=chiedi, none, it, eng, both
OPT_MESSAGE=""
OPT_TAG=""
OPT_DESC=""
OPT_PAGES_REPO=""
OPT_KEEP_TEMP=0
OPT_DOCTOR=0
OPT_JOBS="${OBSS_JOBS:-4}"
OPT_UPLOAD_JOBS="${OBSS_UPLOAD_JOBS:-3}"
OPT_ALLOW_MISSING=0
OPT_WIKI_SCRIPT="obsv2_wiki_script.js"
OPT_PAGES_SCRIPT="pages.py"

GITHUB_TOKEN=""
TMP_DIR=""
STATUS_DIR=""
LOG_DIR=""
LOCK_FD=""
ASKPASS=""
CURL_AUTH=""
SECTIONS_COUNT=0
MISSING_ASSETS=0
UPLOAD_URL=""
RELEASE_ID=""
RELEASE_URL=""
BUILT_DOCS=()

#==============================================================================
# COLORI E LOGGING
#==============================================================================

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    C_RED=$'\033[1;31m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;36m'
    C_MAGENTA=$'\033[1;35m'
    C_DIM=$'\033[2m'
    C_NC=$'\033[0m'
else
    C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_DIM="" C_NC=""
fi

log_with_level() {
    local level="$1"
    local message="$2"
    local color="" symbol="" timestamp

    case "$level" in
        INFO)    color="$C_BLUE";    symbol="ℹ️" ;;
        SUCCESS) color="$C_GREEN";   symbol="✅" ;;
        WARNING) color="$C_YELLOW";  symbol="⚠️" ;;
        ERROR)   color="$C_RED";     symbol="❌" ;;
        STEP)    color="$C_MAGENTA"; symbol="📋" ;;
        DEBUG)   color="$C_DIM";     symbol="·" ;;
        *)       symbol="·" ;;
    esac

    printf -v timestamp '%(%H:%M:%S)T' -1
    printf '%s[%s] %s %s%s\n' "$color" "$timestamp" "$symbol" "$message" "$C_NC" >&2
    ((OPERATION_COUNT++)) || true
}

log_info()    { log_with_level INFO "$*"; }
log_success() { log_with_level SUCCESS "$*"; }
log_warning() { log_with_level WARNING "$*"; }
log_error()   { log_with_level ERROR "$*"; }
log_step()    { log_with_level STEP "$*"; }
log_debug()   { if ((VERBOSE)); then log_with_level DEBUG "$*"; fi; }

die() {
    log_error "$*"
    exit 1
}

show_header() {
    {
        printf '%s' "$C_MAGENTA"
        printf '═%.0s' {1..80}; printf '\n'
        printf '  📚 OBSS BUILD & PUBLISH v%s\n' "$SCRIPT_VERSION"
        printf '═%.0s' {1..80}; printf '\n'
        printf '%s' "$C_NC"
    } >&2
}

show_section() {
    {
        printf '\n%s' "$C_YELLOW"
        printf '─%.0s' {1..80}; printf '\n'
        printf '  %s\n' "$1"
        printf '─%.0s' {1..80}; printf '\n'
        printf '%s' "$C_NC"
    } >&2
}

#==============================================================================
# UTILITY
#==============================================================================

have() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
    local cmd="$1" reason="${2:-}"
    if have "$cmd"; then
        return 0
    fi
    log_error "Comando mancante: $cmd${reason:+ ($reason)}"
    return 1
}

run_cmd() {
    if ((VERBOSE)); then
        printf '+ ' >&2
        printf '%q ' "$@" >&2
        printf '\n' >&2
    fi
    "$@"
}

sanitize_filename() {
    printf '%s' "$1" | tr -cd '[:alnum:]._-' | tr ' ' '_'
}

format_duration() {
    local total="$1"
    printf '%02d:%02d:%02d' $((total / 3600)) $(((total % 3600) / 60)) $((total % 60))
}

count_mark() {
    find "$STATUS_DIR" -maxdepth 1 -type f -name "$1" -printf 'x' 2>/dev/null | wc -c
}

mark_ok()   { : > "$STATUS_DIR/$1.ok"; }
mark_fail() { : > "$STATUS_DIR/$1.fail"; }

# Esegue comandi in parallelo a blocchi di "$1" job.
# I comandi sono stringhe generate con printf '%q'.
run_batch() {
    local max="$1"
    shift
    local -a cmds=("$@")
    local -a pids=()
    local rc=0 i j pid

    ((max > 0)) || max=1

    for ((i = 0; i < ${#cmds[@]}; i += max)); do
        pids=()
        for ((j = i; j < i + max && j < ${#cmds[@]}; j++)); do
            eval "${cmds[j]}" &
            pids+=("$!")
        done
        for pid in "${pids[@]}"; do
            wait "$pid" || rc=1
        done
    done
    return "$rc"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer=""

    if ((!INTERACTIVE)); then
        [[ "$default" == "y" ]]
        return
    fi

    printf '%s ' "$prompt" >&2
    IFS= read -r answer || answer=""
    answer="${answer:-$default}"
    case "${answer,,}" in
        s|si|sì|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

ask_line() {
    local prompt="$1"
    local default="${2:-}"
    local answer=""

    if ((!INTERACTIVE)); then
        printf '%s' "$default"
        return 0
    fi

    printf '%s' "$prompt" >&2
    IFS= read -r answer || answer=""
    [[ -n "$answer" ]] || answer="$default"
    printf '%s' "$answer"
}

urlencode() {
    if have python3; then
        python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
    else
        printf '%s' "$1"
    fi
}

#==============================================================================
# JSON (python3, senza interpolazione di stringhe)
#==============================================================================

json_extract() { # file chiave
    python3 - "$1" "$2" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
    value = data.get(sys.argv[2], "")
    if isinstance(value, (dict, list)):
        print(json.dumps(value))
    else:
        print(value)
except Exception:
    pass
PY
}

json_assets_list() { # file -> righe "nome<TAB>id"
    python3 - "$1" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
    for asset in data:
        print(f"{asset.get('name', '')}\t{asset.get('id', '')}")
except Exception:
    pass
PY
}

json_release_payload() { # mode outfile name desc sha [updated]
    python3 - "$@" <<'PY'
import json
import sys

mode, outfile, name, description, commit_sha = sys.argv[1:6]
updated = sys.argv[6] if len(sys.argv) > 6 else ""

body = f"{description}\n\nCommit: {commit_sha}"
if mode == "update" and updated:
    body += f"\nAggiornato: {updated}"

payload = {
    "tag_name": name,
    "target_commitish": commit_sha,
    "name": name,
    "body": body,
    "draft": False,
    "prerelease": False,
}
if mode == "create":
    payload["generate_release_notes"] = True

with open(outfile, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
PY
}

#==============================================================================
# CLEANUP
#==============================================================================

cleanup() {
    local rc="${1:-$?}"

    trap - EXIT INT TERM HUP

    # Ferma eventuali processi figli ancora attivi
    if have jobs; then
        jobs -p 2>/dev/null | while IFS= read -r _pid; do
            kill "$_pid" 2>/dev/null || true
        done
    fi

    if ((OPT_KEEP_TEMP)); then
        [[ -n "$TMP_DIR" ]] && log_info "File temporanei conservati in $TMP_DIR"
    else
        [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
        rm -f "${FILE1%.tex}-noimage.tex" "${FILE1%.tex}-nocopertina.tex" 2>/dev/null || true
    fi

    if ((rc != 0)) && [[ -n "$LOG_DIR" ]]; then
        log_warning "Log disponibili in $LOG_DIR"
    fi

    exit "$rc"
}

install_traps() {
    trap 'cleanup' EXIT
    trap 'cleanup 130' INT
    trap 'cleanup 143' TERM
    trap 'cleanup 129' HUP
}

#==============================================================================
# ARGOMENTI
#==============================================================================

show_help() {
    cat <<EOF
ddn2.sh v$SCRIPT_VERSION - build & publish OBSS

USO
  ./ddn2.sh [opzioni]

OPZIONI PRINCIPALI
  -y, --yes                 non interattivo (salta wiki/pages/release non richiesti)
  -m, --message TESTO       messaggio di commit
  -j, --jobs N              documenti compilati in parallelo (default: $OPT_JOBS)
      --upload-jobs N       upload release in parallelo (default: $OPT_UPLOAD_JOBS)
      --clean               ricompila da zero (ignora la cache di latexmk)
      --no-variants         non compila -noimage e -nocopertina
      --no-sections         non rigenera la directory $SECTIONS_DIR
      --no-md               non rigenera il Markdown
      --force-md            rigenera il Markdown anche se aggiornato
      --no-synctex          disabilita synctex anche sui documenti principali

WIKI E PAGES
      --wiki MODE           normal | reset | clean | none
      --no-wiki             salta la wiki
      --pages LANG          it | eng | both | none
      --no-pages            salta GitHub Pages
      --pages-repo NOME     nome repository Pages (default: OBSS-Pages)

GIT E RELEASE
      --build-only          solo build: niente git, push, release, wiki, pages
      --no-git              salta add/commit
      --no-push             salta il push
      --no-release          salta la release
      --release TAG         crea/aggiorna la release TAG (usa "auto" per il default)
      --release-desc TESTO  descrizione della release
      --allow-missing       pubblica anche se mancano asset

ALTRO
  -v, --verbose             output dettagliato
      --keep-temp           conserva build e file temporanei
      --doctor              diagnostica ambiente e configurazione
      --version             mostra la versione
  -h, --help                questo aiuto

ESEMPI
  ./ddn2.sh                                   # flusso interattivo classico
  ./ddn2.sh --build-only                      # compila e basta (nessuna pubblicazione)
  ./ddn2.sh -y -m "fix tabelle"               # build + commit/push, niente release
  ./ddn2.sh -y --release auto --no-wiki --no-pages
  ./ddn2.sh -y --clean --no-variants          # rebuild completo veloce
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            -h|--help)      show_help; exit 0 ;;
            --version)      printf '%s\n' "$SCRIPT_VERSION"; exit 0 ;;
            -y|--yes|--non-interactive) OPT_YES=1; shift ;;

            -m|--message)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_MESSAGE="$2"; shift 2 ;;
            --message=*)    OPT_MESSAGE="${1#*=}"; shift ;;

            -j|--jobs)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_JOBS="$2"; shift 2 ;;
            --jobs=*)       OPT_JOBS="${1#*=}"; shift ;;

            --upload-jobs)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_UPLOAD_JOBS="$2"; shift 2 ;;
            --upload-jobs=*) OPT_UPLOAD_JOBS="${1#*=}"; shift ;;

            --clean)        OPT_CLEAN=1; shift ;;
            --no-variants)  OPT_VARIANTS=0; shift ;;
            --no-sections)  OPT_SECTIONS=0; shift ;;
            --no-md)        OPT_MD=0; shift ;;
            --force-md)     OPT_FORCE_MD=1; OPT_MD=1; shift ;;
            --no-synctex)   OPT_SYNCTEX=0; shift ;;

            --wiki)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_WIKI="${2,,}"; shift 2 ;;
            --wiki=*)       OPT_WIKI="${1#*=}"; OPT_WIKI="${OPT_WIKI,,}"; shift ;;
            --no-wiki)      OPT_WIKI="none"; shift ;;

            --pages)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_PAGES="${2,,}"; shift 2 ;;
            --pages=*)      OPT_PAGES="${1#*=}"; OPT_PAGES="${OPT_PAGES,,}"; shift ;;
            --no-pages)     OPT_PAGES="none"; shift ;;
            --pages-repo)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_PAGES_REPO="$2"; shift 2 ;;
            --pages-repo=*) OPT_PAGES_REPO="${1#*=}"; shift ;;

            --build-only)
                OPT_GIT=0
                OPT_PUSH=0
                OPT_RELEASE=0
                OPT_WIKI="none"
                OPT_PAGES="none"
                shift
                ;;
            --no-git)       OPT_GIT=0; shift ;;
            --no-push)      OPT_PUSH=0; shift ;;
            --no-release)   OPT_RELEASE=0; shift ;;
            --release)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_RELEASE=1; OPT_TAG="$2"; shift 2 ;;
            --release=*)    OPT_RELEASE=1; OPT_TAG="${1#*=}"; shift ;;
            --release-desc)
                [[ $# -ge 2 ]] || die "Manca il valore per $1"
                OPT_DESC="$2"; shift 2 ;;
            --release-desc=*) OPT_DESC="${1#*=}"; shift ;;
            --allow-missing) OPT_ALLOW_MISSING=1; shift ;;

            -v|--verbose)   VERBOSE=1; shift ;;
            --keep-temp)    OPT_KEEP_TEMP=1; shift ;;
            --doctor)       OPT_DOCTOR=1; shift ;;
            --)             shift; break ;;
            *)              die "Opzione sconosciuta: $1 (usa --help)" ;;
        esac
    done

    [[ "$OPT_JOBS" =~ ^[1-9][0-9]*$ ]] || die "Valore non valido per --jobs: $OPT_JOBS"
    [[ "$OPT_UPLOAD_JOBS" =~ ^[1-9][0-9]*$ ]] || die "Valore non valido per --upload-jobs: $OPT_UPLOAD_JOBS"

    case "$OPT_WIKI" in
        ""|none|normal|reset|clean) ;;
        *) die "Valore non valido per --wiki: $OPT_WIKI (normal|reset|clean|none)" ;;
    esac
    case "$OPT_PAGES" in
        ""|none|it|ita|italian|eng|english|both) ;;
        *) die "Valore non valido per --pages: $OPT_PAGES (it|eng|both|none)" ;;
    esac
}

#==============================================================================
# INIZIALIZZAZIONE
#==============================================================================

doctor() {
    local ok=1

    show_header
    printf 'Configurazione:\n'
    printf '  script          : %s\n' "$SCRIPT_DIR"
    printf '  target          : %s\n' "$TARGET_DIR"
    printf '  documenti       : %s, %s\n' "$FILE1" "$FILE2"
    printf '  build           : %s\n' "$TEMP_DIR"
    printf '  sezioni         : %s\n' "$SECTIONS_DIR"
    printf '  asset           : %s\n' "$ASSETS_DIR"
    printf '  token           : %s\n' "$TOKEN_FILE"
    printf '  repo            : %s/%s\n' "$REPO_OWNER" "$REPO_NAME"
    printf '  api             : %s\n' "$API_URL"
    printf '  jobs            : %s (upload %s)\n' "$OPT_JOBS" "$OPT_UPLOAD_JOBS"
    printf '\nStrumenti:\n'
    local tool
    for tool in bash latexmk xelatex qpdf git curl python3 java javac node zenity flock; do
        if have "$tool"; then
            printf '  ✅ %-10s %s\n' "$tool" "$(command -v "$tool")"
        else
            printf '  ❌ %-10s mancante\n' "$tool"
            [[ "$tool" == "zenity" || "$tool" == "node" ]] || ok=0
        fi
    done
    printf '\nFile:\n'
    local file
    for file in "$FILE1" "$FILE2"; do
        if [[ -f "$TARGET_DIR/$file" ]]; then
            printf '  ✅ %s\n' "$file"
        else
            printf '  ❌ %s mancante\n' "$file"
            ok=0
        fi
    done
    if [[ -f "$TOKEN_FILE" ]]; then
        printf '  ✅ token presente (permessi %s)\n' "$(stat -c '%a' "$TOKEN_FILE" 2>/dev/null || echo '?')"
    else
        printf '  ⚠️  token assente (solo push SSH/release senza token)\n'
    fi

    printf '\nGit:\n'
    if git -C "$TARGET_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        printf '  ✅ repository: %s\n' "$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)"
        printf '  ✅ branch    : %s\n' "$(git -C "$TARGET_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        printf '  ✅ remote    : %s\n' "$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || echo 'assente')"
    else
        printf '  ❌ non è un repository Git\n'
        ok=0
    fi
    printf '\n'
    return $((ok == 1 ? 0 : 1))
}

check_commands() {
    log_info "Verifica comandi richiesti..."
    local missing=0

    require_cmd latexmk "compilazione LaTeX" || missing=1
    require_cmd xelatex "compilazione LaTeX" || missing=1

    if ((OPT_GIT)) || ((OPT_RELEASE != 0)); then
        require_cmd git "commit/push/release" || missing=1
    fi

    if ((OPT_MD)); then
        require_cmd java "conversione Markdown" || missing=1
        require_cmd javac "conversione Markdown" || missing=1
    fi

    if ((OPT_RELEASE == 1)) || ((OPT_RELEASE == 2 && INTERACTIVE)); then
        require_cmd curl "release GitHub" || missing=1
        require_cmd python3 "release GitHub" || missing=1
    fi

    if [[ "$OPT_PAGES" != "none" ]] || [[ -z "$OPT_PAGES" && "$INTERACTIVE" = 1 ]]; then
        require_cmd python3 "GitHub Pages" || missing=1
    fi

    if [[ "$OPT_WIKI" != "none" ]] || [[ -z "$OPT_WIKI" && "$INTERACTIVE" = 1 ]]; then
        require_cmd node "wiki" || missing=1
    fi

    if ! have qpdf; then
        log_warning "qpdf assente: ottimizzazione PDF saltata"
    fi
    if ! have flock; then
        log_warning "flock assente: nessun lock contro esecuzioni concorrenti"
    fi
    if ! have zenity; then
        log_debug "zenity assente: messaggio di commit automatico"
    fi

    ((missing == 0)) || return 1
    log_success "Comandi disponibili"
}

load_token() {
    GITHUB_TOKEN=""

    if [[ ! -f "$TOKEN_FILE" ]]; then
        log_warning "Token GitHub non trovato in $TOKEN_FILE"
        return 1
    fi

    GITHUB_TOKEN="$(sed -n 's/^githubtoken=//p' "$TOKEN_FILE" | head -1 | tr -d '\r')"
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "Token non valido in $TOKEN_FILE"
        return 1
    fi

    # Il token non deve essere leggibile da altri utenti
    local perms
    perms="$(stat -c '%a' "$TOKEN_FILE" 2>/dev/null || echo '')"
    if [[ "$perms" != "600" && "$perms" != "400" ]]; then
        if chmod 600 "$TOKEN_FILE" 2>/dev/null; then
            log_info "Permessi di $TOKEN_FILE impostati a 600"
        else
            log_warning "$TOKEN_FILE è leggibile da altri utenti (chmod 600 fallito)"
        fi
    fi

    log_success "Token GitHub caricato"
    return 0
}

setup_curl_auth() {
    # Evita che il token compaia nella lista processi (ps) di curl.
    CURL_AUTH="$TMP_DIR/curl-auth.conf"
    (
        umask 077
        printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_TOKEN" > "$CURL_AUTH"
    )
}

ensure_gitignore() {
    local gitignore="$TARGET_DIR/.gitignore"
    local token_entry
    token_entry="$(basename "$TOKEN_FILE")"
    local entry

    for entry in "$token_entry" ".ddn2.lock" "*(copia *"; do
        if [[ ! -f "$gitignore" ]] || ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
            printf '%s\n' "$entry" >> "$gitignore"
            log_info ".gitignore aggiornato: $entry"
        fi
    done
    return 0
}

verify_latex_files() {
    local missing=0 file
    for file in "$FILE1" "$FILE2"; do
        if [[ ! -f "$file" ]]; then
            log_error "File mancante: $file"
            missing=1
        fi
    done
    ((missing == 0)) || { log_info "Directory corrente: $(pwd)"; return 1; }
    log_success "File LaTeX verificati"
}

setup_workdir() {
    cd "$TARGET_DIR" 2>/dev/null || die "Impossibile accedere a $TARGET_DIR"
    mkdir -p "$TEMP_DIR" 2>/dev/null || die "Impossibile creare $TEMP_DIR"
    [[ -w "$TEMP_DIR" ]] || die "$TEMP_DIR non è scrivibile"

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ddn2.XXXXXX")" || die "Impossibile creare la directory temporanea"
    STATUS_DIR="$TMP_DIR/status"
    LOG_DIR="$TEMP_DIR/logs"
    mkdir -p "$STATUS_DIR" "$LOG_DIR"
}

setup_lock() {
    have flock || return 0
    exec {LOCK_FD}>"$TARGET_DIR/.ddn2.lock" || { log_warning "Impossibile creare il lock"; return 0; }
    if ! flock -n "$LOCK_FD"; then
        die "Un'altra istanza di ddn2.sh è in esecuzione in $TARGET_DIR"
    fi
    log_debug "Lock acquisito"
}

initialize() {
    log_step "Inizializzazione"

    if ((OPT_YES)); then
        INTERACTIVE=0
    elif [[ -t 0 ]]; then
        INTERACTIVE=1
    else
        INTERACTIVE=0
    fi

    if ((OPT_YES)); then
        [[ -z "$OPT_WIKI" ]] && OPT_WIKI="none"
        [[ -z "$OPT_PAGES" ]] && OPT_PAGES="none"
        ((OPT_RELEASE == 2)) && OPT_RELEASE=0
    fi

    setup_workdir
    setup_lock
    install_traps
    ensure_gitignore

    check_commands || return 1

    if ! load_token; then
        if ((OPT_RELEASE == 1)); then
            log_error "La release richiede un token valido in $TOKEN_FILE"
            return 1
        fi
        if ((OPT_PUSH && OPT_GIT)) && git rev-parse --git-dir >/dev/null 2>&1; then
            local remote_url
            remote_url="$(git remote get-url origin 2>/dev/null || true)"
            if [[ "$remote_url" == https://* ]]; then
                log_error "Push via HTTPS richiede un token valido in $TOKEN_FILE"
                return 1
            fi
        fi
    else
        setup_curl_auth
    fi

    verify_latex_files || return 1

    log_success "Inizializzazione completata"
    return 0
}

#==============================================================================
# SEZIONI
#==============================================================================

extract_sections() {
    local file="$FILE1"
    local out="$SECTIONS_DIR"
    local preambolo_line

    log_step "Estrazione sezioni da $file"

    mkdir -p "$out" || return 1
    rm -f "$out"/*.tex 2>/dev/null || true

    preambolo_line="$(awk '/\\begin\{document\}/{print NR; exit}' "$file")"
    if [[ -z "$preambolo_line" ]]; then
        log_error "Impossibile trovare \\begin{document} in $file"
        return 1
    fi
    sed -n "1,${preambolo_line}p" "$file" > "$out/00_preambolo.tex"

    local scan="$TMP_DIR/sections.scan"
    awk '/\\section\{/{print NR ":" $0}' "$file" > "$scan"

    if [[ ! -s "$scan" ]]; then
        log_warning "Nessuna sezione trovata"
        SECTIONS_COUNT=0
        return 0
    fi

    local total_lines line_num line_content section_title clean_title
    local prev_line=0 section_count=0 prev_title=""

    total_lines="$(wc -l < "$file")"

    while IFS=: read -r line_num line_content; do
        section_title="$(sed -n 's/.*\\section{\([^}]*\)}.*/\1/p' <<< "$line_content")"
        clean_title="$(sanitize_filename "$section_title")"

        if ((section_count == 0 && prev_line == 0 && preambolo_line < line_num)); then
            sed -n "$((preambolo_line + 1)),$((line_num - 1))p" "$file" > "$out/01_introduzione.tex"
        fi

        if ((prev_line != 0)); then
            sed -n "${prev_line},$((line_num - 1))p" "$file" \
                > "$out/$(printf '%02d' $((section_count + 2)))_${prev_title}.tex"
            ((section_count++)) || true
        fi

        prev_line=$line_num
        prev_title=$clean_title
    done < "$scan"

    sed -n "${prev_line},${total_lines}p" "$file" \
        > "$out/$(printf '%02d' $((section_count + 2)))_${prev_title}.tex"
    ((section_count++)) || true

    SECTIONS_COUNT=$section_count
    log_success "Estratte $section_count sezioni"
}

#==============================================================================
# COMPILAZIONE
#==============================================================================

make_variant() {
    local variant="$1"
    local src="$2"
    local kind="$3"
    local tmp="$TMP_DIR/variant-${kind}-$$.tex"

    case "$kind" in
        noimage)
            sed 's/\\documentclass\[/\\documentclass[draft,/' "$src" > "$tmp" || return 1
            ;;
        nocopertina)
            sed '/Fantasy Adventure Game/d' "$src" > "$tmp" || return 1
            ;;
        *)
            return 1
            ;;
    esac

    if [[ -f "$variant" ]] && cmp -s "$tmp" "$variant"; then
        rm -f "$tmp"
        log_debug "Variante invariata: $variant"
    else
        mv -f "$tmp" "$variant"
        log_info "Aggiornata variante: $variant"
    fi
    return 0
}

create_variants() {
    ((OPT_VARIANTS)) || { log_info "Varianti disabilitate"; return 0; }

    log_step "Generazione varianti"
    make_variant "${FILE1%.tex}-noimage.tex" "$FILE1" noimage || return 1
    make_variant "${FILE1%.tex}-nocopertina.tex" "$FILE1" nocopertina || return 1
    log_success "Varianti pronte"
}

compile_one() {
    local tex="$1"
    local base="${tex%.tex}"
    local build_dir="$TEMP_DIR/build-$base"
    local pdf="$PWD/$base.pdf"
    local log_file="$LOG_DIR/compile-$base.log"
    local start=$SECONDS
    local synctex=0

    if [[ "$base" == "${FILE1%.tex}" || "$base" == "${FILE2%.tex}" ]]; then
        synctex=$OPT_SYNCTEX
    fi

    log_info "Compilazione avviata: $base"

    if ((OPT_CLEAN)); then
        rm -rf "$build_dir"
    fi
    mkdir -p "$build_dir"

    local -a args=(-xelatex -interaction=nonstopmode -auxdir="$build_dir")
    if ((synctex)); then
        args+=(-synctex=1)
    else
        args+=(-synctex=0)
    fi

    if ! run_cmd latexmk "${args[@]}" "$PWD/$tex" >"$log_file" 2>&1; then
        # La cache può essere corrotta: un solo retry da zero, ma solo se il log
        # non mostra un vero errore TeX (altrimenti si perderebbe solo tempo).
        if ((!OPT_CLEAN)) && [[ -d "$build_dir" ]] && ! grep -qE '^(!|.*(Fatal error|Emergency stop|Killed|Cannot allocate memory|Out of memory))' "$log_file"; then
            log_warning "Build fallita per $base, riprovo da zero"
            rm -rf "$build_dir"
            mkdir -p "$build_dir"
            if ! run_cmd latexmk "${args[@]}" "$PWD/$tex" >"$log_file" 2>&1; then
                log_error "Compilazione fallita: $base (log: $log_file)"
                tail -n 20 "$log_file" >&2 || true
                mark_fail "compile-$base"
                return 1
            fi
        else
            log_error "Compilazione fallita: $base (log: $log_file)"
            tail -n 20 "$log_file" >&2 || true
            mark_fail "compile-$base"
            return 1
        fi
    fi

    if [[ ! -s "$pdf" ]]; then
        log_error "PDF non generato: $pdf (log: $log_file)"
        tail -n 20 "$log_file" >&2 || true
        mark_fail "compile-$base"
        return 1
    fi

    local pages="" page_label=""
    pages="$(tr -d '\n' < "$build_dir/$base.log" 2>/dev/null \
        | sed -n 's/.*Output written on .* (\([0-9][0-9]*\) page[s]*[,)].*/\1/p')"
    if [[ -n "$pages" ]]; then
        if [[ "$pages" == "1" ]]; then page_label="pagina"; else page_label="pagine"; fi
        log_success "$base.pdf pronto ($pages $page_label, $((SECONDS - start))s)"
    else
        log_success "$base.pdf pronto ($((SECONDS - start))s)"
    fi
    mark_ok "compile-$base"
}

compile_documents() {
    log_step "Compilazione documenti LaTeX"

    local -a docs=("$FILE1" "$FILE2")
    local -a cmds=()

    if ((OPT_VARIANTS)); then
        local kind variant
        for kind in noimage nocopertina; do
            variant="${FILE1%.tex}-$kind.tex"
            if [[ ! -f "$variant" ]]; then
                log_warning "Variante assente: $variant"
            elif cmp -s "$variant" "$FILE1"; then
                log_warning "$variant identico a $FILE1: salto la compilazione"
            else
                docs+=("$variant")
            fi
        done
    fi

    BUILT_DOCS=("${docs[@]}")

    local doc
    for doc in "${docs[@]}"; do
        cmds+=("compile_one $(printf '%q' "$doc")")
    done

    log_info "Compilo ${#docs[@]} documenti in parallelo (jobs=$OPT_JOBS)"
    if ! run_batch "$OPT_JOBS" "${cmds[@]}"; then
        log_error "Una o più compilazioni sono fallite"
        return 1
    fi

    log_success "Compilazione completata"
}

#==============================================================================
# POST-PROCESSING
#==============================================================================

optimize_one() {
    local pdf="$1"
    local name
    name="$(basename "$pdf")"
    local tmp="${pdf%.pdf}.qpdf.tmp.pdf"
    local log_file="$LOG_DIR/qpdf-$name.log"
    local stamp="$TEMP_DIR/.optimized-$name.state"
    local state

    # qpdf non è deterministico (riscrive /ID): se il PDF non è cambiato
    # dall'ultima ottimizzazione, evita di riscriverlo e di sporcare git.
    state="$(stat -c '%s:%y' "$pdf" 2>/dev/null || true)"
    if ((!OPT_CLEAN)) && [[ -f "$stamp" && -n "$state" ]]; then
        if [[ "$(cat "$stamp" 2>/dev/null)" == "$state" ]]; then
            mark_ok "pdf-$name"
            log_debug "$name già ottimizzato"
            return 0
        fi
    fi

    if qpdf --linearize "$pdf" "$tmp" >"$log_file" 2>&1; then
        mv -f "$tmp" "$pdf"
        stat -c '%s:%y' "$pdf" > "$stamp" 2>/dev/null || true
        mark_ok "pdf-$name"
        log_success "Ottimizzato: $name"
    else
        rm -f "$tmp"
        mark_fail "pdf-$name"
        log_warning "qpdf fallito su $name (mantengo l'originale, log: $log_file)"
    fi
    return 0
}

optimize_pdfs() {
    log_step "Ottimizzazione PDF"

    if ! have qpdf; then
        log_warning "qpdf non disponibile: salto"
        return 0
    fi

    # Ottimizza solo i PDF dei documenti realmente compilati in questa run.
    local -a docs=("${BUILT_DOCS[@]}")
    (( ${#docs[@]} )) || docs=("$FILE1" "$FILE2")

    local -a cmds=()
    local doc pdf
    for doc in "${docs[@]}"; do
        pdf="${doc%.tex}.pdf"
        if [[ -f "$pdf" ]]; then
            cmds+=("optimize_one $(printf '%q' "$pdf")")
        else
            log_warning "PDF assente: $pdf"
        fi
    done

    (( ${#cmds[@]} )) || return 0

    run_batch "$OPT_JOBS" "${cmds[@]}" || true
    log_success "$(count_mark 'pdf-*.ok')/${#cmds[@]} PDF pronti"
    return 0
}

md_needs_update() {
    local md="$1"
    local tex="$2"
    local ref

    [[ -s "$md" ]] || return 0
    [[ "$md" -nt "$tex" ]] || return 0

    # Se il convertitore Java esiste ma non è compilato, rigenera.
    if [[ -f "Latex2MarkDown.java" && ! -f "Latex2MarkDown.class" ]]; then
        return 0
    fi

    for ref in "Latex2MarkDown.java" "Latex2MarkDown.class" "latex2markdown.sh"; do
        if [[ -f "$ref" && ! "$md" -nt "$ref" ]]; then
            return 0
        fi
    done
    return 1
}

convert_markdown() {
    log_step "Conversione LaTeX → Markdown"

    if ((!OPT_MD)); then
        log_info "Conversione Markdown disabilitata"
        return 0
    fi

    if ((!OPT_FORCE_MD)) && ! md_needs_update "$MD1" "$FILE1" && ! md_needs_update "$MD2" "$FILE2"; then
        log_info "Markdown già aggiornato"
        return 0
    fi

    if [[ ! -f "latex2markdown.sh" ]]; then
        log_warning "latex2markdown.sh assente: salto"
        return 0
    fi

    # Lo script converte entrambi i documenti: va invocato UNA sola volta.
    local start=$SECONDS
    local log_file="$LOG_DIR/markdown.log"
    if ! sh latex2markdown.sh >"$log_file" 2>&1; then
        log_warning "Conversione Markdown fallita (log: $log_file)"
        tail -n 10 "$log_file" >&2 || true
        return 0
    fi

    local generated=0
    if [[ -s "$MD1" ]]; then ((generated++)) || true; fi
    if [[ -s "$MD2" ]]; then ((generated++)) || true; fi

    log_success "$generated file Markdown generati ($((SECONDS - start))s)"
    return 0
}

prepare_assets() {
    log_step "Preparazione asset"

    mkdir -p "$ASSETS_DIR" || { log_error "Impossibile creare $ASSETS_DIR"; return 1; }
    find "$ASSETS_DIR" -maxdepth 1 -type f -name '*.pdf' -delete 2>/dev/null || true

    local -a existing=()
    local -a missing=()
    local asset

    for asset in "${ASSETS[@]}"; do
        if [[ -f "$asset" ]]; then
            existing+=("$asset")
        else
            missing+=("$asset")
        fi
    done

    if (( ${#existing[@]} )); then
        if ! cp -f -t "$ASSETS_DIR" -- "${existing[@]}"; then
            log_error "Copia asset fallita"
            MISSING_ASSETS=1
            return 1
        fi
    fi

    MISSING_ASSETS=0
    if (( ${#missing[@]} )); then
        MISSING_ASSETS=1
        log_warning "Asset mancanti (${#missing[@]}): ${missing[*]}"
    fi

    log_success "${#existing[@]}/${#ASSETS[@]} asset preparati in $ASSETS_DIR"
    return 0
}

run_postprocessing() {
    log_step "Post-processing"

    local rc=0
    local qpid mpid

    # qpdf e conversione Markdown sono indipendenti: eseguili insieme.
    ( optimize_pdfs ) & qpid=$!
    ( convert_markdown ) & mpid=$!

    wait "$qpid" || rc=1
    wait "$mpid" || rc=1

    prepare_assets || rc=1
    return "$rc"
}

#==============================================================================
# WIKI
#==============================================================================

prompt_wiki_action() {
    echo "Opzioni wiki disponibili:" >&2
    echo "  c - Clean COMPLETO (cancella tutto lo storico + rebuild)" >&2
    echo "  r - Reset wiki (mantiene lo storico, cancella il contenuto)" >&2
    echo "  s - Aggiornamento normale" >&2
    echo "  N - Salta (default)" >&2
    printf 'Aggiornare la wiki [Clean/Reset/Si/No] (c/r/s/N): ' >&2
    local choice=""
    IFS= read -r choice || choice=""
    printf '%s' "${choice,,}"
}

confirm_dangerous_action() {
    local action="$1"
    local message="$2"

    log_warning "ATTENZIONE: $message"
    if ((!INTERACTIVE)); then
        log_warning "$action confermato da --yes"
        return 0
    fi

    printf 'Sei sicuro? Operazione IRREVERSIBILE [si/No] (s/N): ' >&2
    local confirm=""
    IFS= read -r confirm || confirm=""
    case "${confirm,,}" in
        s|si|sì|yes|y) return 0 ;;
        *)
            log_info "$action annullato dall'utente"
            return 1
            ;;
    esac
}

wiki_available() {
    [[ -f "$OPT_WIKI_SCRIPT" ]] && [[ -f "latex2markdown.sh" ]]
}

run_wiki_normal() {
    if node "$OPT_WIKI_SCRIPT"; then
        log_success "Wiki aggiornata"
        return 0
    fi
    log_error "Errore durante l'aggiornamento della wiki"
    return 1
}

run_wiki_reset() {
    if node "$OPT_WIKI_SCRIPT" --reset && node "$OPT_WIKI_SCRIPT"; then
        log_success "Wiki resettata e ricostruita"
        return 0
    fi
    log_error "Errore durante il reset della wiki"
    return 1
}

nuclear_wiki_clean() {
    log_warning "Esecuzione clean nucleare wiki..."

    # Solo directory di output della wiki. NON toccare i .md della root:
    # OBSSv2.md, OBSSv2-eng.md e changelog.md sono file di progetto.
    local dir
    for dir in "wiki" "docs" "_wiki" "site" "_site" "public" "_public"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            log_info "Rimossa directory: $dir"
        fi
    done

    log_success "Clean nucleare completato"
}

run_wiki_clean() {
    if node "$OPT_WIKI_SCRIPT" --clean --force --purge-history 2>"$LOG_DIR/wiki-clean.log"; then
        log_success "Clean completo wiki eseguito"
    else
        log_warning "Clean standard fallito, uso il clean nucleare"
        nuclear_wiki_clean
    fi

    log_info "Ricostruzione wiki da zero..."
    if node "$OPT_WIKI_SCRIPT" --rebuild; then
        log_success "Wiki ricostruita completamente"
        return 0
    fi
    log_error "Errore nella ricostruzione della wiki"
    return 1
}

update_wiki() {
    show_section "📖 AGGIORNAMENTO WIKI"

    if ! wiki_available; then
        log_warning "Script wiki non disponibili"
        return 0
    fi

    local choice="$OPT_WIKI"

    if [[ -z "$choice" ]]; then
        if ((!INTERACTIVE)); then
            log_info "Wiki saltata"
            return 0
        fi
        choice="$(prompt_wiki_action)"
    fi

    case "$choice" in
        c|clean)
            if confirm_dangerous_action "Clean completo" "Il clean completo cancellerà TUTTO lo storico della wiki!"; then
                run_wiki_clean
            fi
            ;;
        r|reset) run_wiki_reset ;;
        s|si|sì|normal) run_wiki_normal ;;
        *) log_info "Wiki saltata" ;;
    esac
}

#==============================================================================
# GITHUB PAGES
#==============================================================================

prompt_pages_action() {
    echo "Opzioni GitHub Pages:" >&2
    echo "  i - Solo italiano" >&2
    echo "  e - Solo inglese" >&2
    echo "  b - Entrambe le lingue" >&2
    echo "  N - Salta (default)" >&2
    printf 'Scelta [i/e/b/N]: ' >&2
    local choice=""
    IFS= read -r choice || choice=""
    printf '%s' "${choice,,}"
}

deploy_pages() {
    local lang="$1"
    local option="$2"
    local repo_name="$OPT_PAGES_REPO"

    if [[ -z "$repo_name" ]]; then
        repo_name="$(ask_line 'Nome repository [OBSS-Pages]: ' 'OBSS-Pages')"
    fi

    log_info "Deploy GitHub Pages ($lang)..."
    if python3 "$OPT_PAGES_SCRIPT" "$repo_name" "$option"; then
        log_success "GitHub Pages aggiornate"
        printf '\n📋 Info Deploy:\n   Repository: %s\n   URL: https://%s.github.io/%s\n\n' \
            "$repo_name" "$REPO_OWNER" "$repo_name"
        return 0
    fi
    log_error "Errore deploy GitHub Pages"
    return 1
}

update_pages() {
    show_section "🌐 AGGIORNAMENTO GITHUB PAGES"

    if [[ ! -f "$OPT_PAGES_SCRIPT" ]]; then
        log_warning "$OPT_PAGES_SCRIPT non disponibile"
        return 0
    fi
    if ! have python3; then
        log_warning "python3 non disponibile"
        return 0
    fi

    if [[ ! -s "$MD1" && ! -s "$MD2" ]]; then
        log_warning "Nessun file Markdown disponibile"
        return 0
    fi

    local choice="$OPT_PAGES"
    if [[ -z "$choice" ]]; then
        if ((!INTERACTIVE)); then
            log_info "GitHub Pages saltate"
            return 0
        fi
        choice="$(prompt_pages_action)"
    fi

    case "$choice" in
        i|it|ita|italian)
            if [[ -s "$MD1" ]]; then
                deploy_pages "italiano" "--italian"
            else
                log_error "$MD1 non trovato"
            fi
            ;;
        e|eng|english)
            if [[ -s "$MD2" ]]; then
                deploy_pages "inglese" "--english"
            else
                log_error "$MD2 non trovato"
            fi
            ;;
        b|both|entrambe)
            deploy_pages "entrambe" "--both"
            ;;
        *)
            log_info "GitHub Pages saltate"
            ;;
    esac
}

#==============================================================================
# GIT
#==============================================================================

default_commit_message() {
    printf 'Update LaTeX documents - %s' "$(date '+%Y-%m-%d %H:%M')"
}

get_commit_message() {
    local default_msg
    default_msg="$(default_commit_message)"

    if [[ -n "$OPT_MESSAGE" ]]; then
        printf '%s' "$OPT_MESSAGE"
        return 0
    fi

    if ((INTERACTIVE)) && have zenity && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        local msg=""
        if msg="$(timeout 60 zenity --entry --title='Commit Message' \
            --text='Messaggio di commit:' --entry-text="$default_msg" 2>/dev/null)" \
            && [[ -n "$msg" ]]; then
            printf '%s' "$msg"
            return 0
        fi
        log_warning "Usando messaggio automatico"
    fi

    printf '%s' "$default_msg"
}

setup_askpass() {
    ASKPASS="$TMP_DIR/askpass.sh"
    cat > "$ASKPASS" <<'EOF'
#!/bin/sh
case "$1" in
    *Username*|*username*) printf '%s\n' "${GIT_USERNAME:-x-access-token}" ;;
    *Password*|*password*) printf '%s\n' "$GITHUB_TOKEN" ;;
    *) printf '\n' ;;
esac
EOF
    chmod 700 "$ASKPASS"
    export GITHUB_TOKEN GIT_USERNAME
}

perform_git_add() {
    local -a paths=()
    local p

    for p in "${GIT_PATHS[@]}"; do
        [[ -e "$p" ]] && paths+=("$p")
    done

    (( ${#paths[@]} )) || return 0

    # Un solo processo git invece di decine.
    git add -A -- "${paths[@]}" 2>/dev/null || {
        log_warning "git add parziale fallito, provo file per file"
        for p in "${paths[@]}"; do
            git add -A -- "$p" 2>/dev/null || true
        done
    }
}

git_operations() {
    log_step "Operazioni Git"

    if ((!OPT_GIT)); then
        log_info "Operazioni Git disabilitate"
        return 0
    fi

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Non è un repository Git valido ($(pwd))"
        return 1
    fi

    local commit_msg
    commit_msg="$(get_commit_message)"

    perform_git_add

    # Come il vecchio "commit -a": stage anche le modifiche ai file già tracciati.
    git add -u -- . 2>/dev/null || true

    if git diff --cached --quiet; then
        log_warning "Nessuna modifica da committare"
    else
        if git commit -m "$commit_msg" >/dev/null 2>&1; then
            log_success "Commit eseguito: $commit_msg"
        else
            log_error "Commit fallito"
            return 1
        fi
    fi

    if ((!OPT_PUSH)); then
        log_info "Push disabilitato"
        return 0
    fi

    local remote_url branch
    remote_url="$(git remote get-url origin 2>/dev/null || true)"
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

    if [[ -z "$remote_url" ]]; then
        log_error "Remote 'origin' non configurato"
        return 1
    fi
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
        log_error "Repository in stato detached HEAD: impossibile fare push"
        return 1
    fi

    setup_askpass

    # Il token non finisce né nella URL né nella lista processi.
    if GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0 \
        git push origin "HEAD:refs/heads/$branch"; then
        log_success "Push completato ($branch)"
    else
        log_error "Errore durante il push"
        return 1
    fi

    return 0
}

#==============================================================================
# GITHUB API
#==============================================================================

validate_tag_name() {
    local tag="$1"

    [[ -n "$tag" ]] || return 1
    (( ${#tag} <= 100 )) || return 1

    local invalid_patterns=(
        '[[:space:]]'
        '^[./-]'
        '[./-]$'
        '[:?*\[\]\\^~#%&]'
        '\.\.'
        '//'
        '@\{'
    )

    local pattern
    for pattern in "${invalid_patterns[@]}"; do
        [[ "$tag" =~ $pattern ]] && return 1
    done
    return 0
}

github_api() { # method endpoint outfile [datafile]
    local method="$1"
    local endpoint="$2"
    local outfile="$3"
    local datafile="${4:-}"

    local -a args=(
        -sS
        -w '%{http_code}'
        -o "$outfile"
        -X "$method"
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28"
        --connect-timeout 15
        --max-time 120
        --retry 2
        --retry-delay 2
    )
    if [[ -n "$CURL_AUTH" ]]; then
        args+=(--config "$CURL_AUTH")
    else
        args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi

    if [[ -n "$datafile" ]]; then
        args+=(-H "Content-Type: application/json" --data-binary "@$datafile")
    fi

    local code
    code="$(curl "${args[@]}" "$API_URL/repos/$REPO_OWNER/$REPO_NAME/$endpoint")" || true
    printf '%s' "$code"
}

check_existing_release() { # 0=esiste, 1=non esiste, 2=errore
    local tag_enc="$1"
    local code

    log_info "Verifica esistenza release..."
    code="$(github_api GET "releases/tags/$tag_enc" /dev/null)"

    case "$code" in
        200) return 0 ;;
        404) return 1 ;;
        *)
            log_error "Errore verificando la release (HTTP: ${code:-nessuna risposta})"
            return 2
            ;;
    esac
}

get_release_id() {
    local tag_enc="$1"
    local file="$TMP_DIR/release-details.json"
    local code release_id

    log_info "Ottenendo ID della release..."
    code="$(github_api GET "releases/tags/$tag_enc" "$file")"

    if [[ "$code" != "200" ]]; then
        log_error "Errore API GitHub (HTTP: ${code:-nessuna risposta})"
        return 1
    fi

    release_id="$(json_extract "$file" id)"

    if [[ "$release_id" =~ ^[0-9]+$ ]]; then
        log_success "ID release: $release_id"
        printf '%s' "$release_id"
        return 0
    fi

    log_error "Impossibile estrarre l'ID della release"
    return 1
}

delete_release_assets_by_name() {
    local rid="$1"
    local file="$TMP_DIR/release-assets.json"
    local code

    code="$(github_api GET "releases/$rid/assets?per_page=100" "$file")"
    if [[ "$code" != "200" ]]; then
        log_warning "Impossibile elencare gli asset esistenti (HTTP: ${code:-nessuna risposta})"
        return 0
    fi

    local name aid wanted
    while IFS=$'\t' read -r name aid; do
        [[ -n "$aid" ]] || continue
        wanted=0
        local asset_name
        for asset_name in "${ASSETS[@]}"; do
            if [[ "$(basename "$asset_name")" == "$name" ]]; then
                wanted=1
                break
            fi
        done
        if ((wanted)); then
            code="$(github_api DELETE "releases/assets/$aid" /dev/null)"
            if [[ "$code" == "204" ]]; then
                log_info "Asset rimosso: $name"
            else
                log_warning "Rimozione asset $name fallita (HTTP: ${code:-nessuna risposta})"
            fi
        fi
    done < <(json_assets_list "$file")

    return 0
}

delete_asset_by_name() {
    local rid="$1"
    local asset_name="$2"
    local file="$TMP_DIR/release-assets-replace.json"
    local code

    code="$(github_api GET "releases/$rid/assets?per_page=100" "$file")"
    [[ "$code" == "200" ]] || return 1

    local name aid
    while IFS=$'\t' read -r name aid; do
        if [[ "$name" == "$asset_name" && -n "$aid" ]]; then
            code="$(github_api DELETE "releases/assets/$aid" /dev/null)"
            [[ "$code" == "204" ]] && return 0
            return 1
        fi
    done < <(json_assets_list "$file")

    return 1
}

asset_content_type() {
    case "${1##*.}" in
        pdf) printf 'application/pdf' ;;
        zip) printf 'application/zip' ;;
        txt) printf 'text/plain' ;;
        *)   printf 'application/octet-stream' ;;
    esac
}

upload_curl() { # file name
    local file="$1"
    local name="$2"
    local safe_name="${name// /_}"
    local body="$TMP_DIR/upload-$safe_name.json"
    local encoded
    encoded="$(urlencode "$name")"

    local -a args=(
        -sS -w '%{http_code}' -o "$body"
        --connect-timeout 15
        --max-time 900
        --retry 3
        --retry-delay 2
        -X POST
        -H "Accept: application/vnd.github+json"
        -H "Content-Type: $(asset_content_type "$name")"
        --data-binary @"$file"
    )
    if [[ -n "$CURL_AUTH" ]]; then
        args+=(--config "$CURL_AUTH")
    else
        args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi

    curl "${args[@]}" "$UPLOAD_URL?name=$encoded" || true
}

upload_one() {
    local file="$1"
    local name
    name="$(basename "$file")"
    local safe_name="${name// /_}"
    local code

    code="$(upload_curl "$file" "$name")"
    code="${code: -3}"

    if [[ "$code" == "201" ]]; then
        mark_ok "upload-$safe_name"
        log_success "$name caricato"
        return 0
    fi

    if [[ "$code" == "422" ]]; then
        log_warning "$name già presente: lo sostituisco"
        if [[ -n "$RELEASE_ID" ]] && delete_asset_by_name "$RELEASE_ID" "$name"; then
            code="$(upload_curl "$file" "$name")"
            code="${code: -3}"
            if [[ "$code" == "201" ]]; then
                mark_ok "upload-$safe_name"
                log_success "$name sostituito"
                return 0
            fi
        fi
    fi

    mark_fail "upload-$safe_name"
    log_warning "Caricamento $name fallito (HTTP: ${code:-nessuna risposta})"
    return 1
}

upload_release_assets() {
    local upload_url="$1"
    local rid="${2:-}"

    local -a files=("$ASSETS_DIR"/*.pdf)
    if (( ${#files[@]} == 0 )); then
        log_warning "Nessun asset da caricare in $ASSETS_DIR"
        return 0
    fi

    UPLOAD_URL="$upload_url"
    RELEASE_ID="$rid"

    local -a cmds=()
    local file
    for file in "${files[@]}"; do
        cmds+=("upload_one $(printf '%q' "$file")")
    done

    log_info "Carico ${#files[@]} asset (upload jobs=$OPT_UPLOAD_JOBS)..."
    local rc=0
    run_batch "$OPT_UPLOAD_JOBS" "${cmds[@]}" || rc=1

    local ok fail
    ok="$(count_mark 'upload-*.ok')"
    fail="$(count_mark 'upload-*.fail')"

    if ((fail > 0)); then
        log_error "$ok asset caricati, $fail falliti"
        return 1
    fi

    log_success "$ok/${#files[@]} asset caricati"
    return "$rc"
}

show_release_info() {
    local response_file="$1"
    local tag_name="$2"
    local title="${3:-Release creata:}"
    local url commit_sha

    url="$(json_extract "$response_file" html_url)"
    commit_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    RELEASE_URL="$url"

    printf '\n📋 %s\n   Nome: %s\n   URL: %s\n   Commit: %s\n\n' \
        "$title" "$tag_name" "$url" "${commit_sha:0:8}"
}

create_github_release() {
    local name="$1"
    local desc="$2"
    local json="$TMP_DIR/release.json"
    local response="$TMP_DIR/release-response.json"
    local commit_sha code upload_url rid

    log_info "Creazione release GitHub: $name"

    commit_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    json_release_payload create "$json" "$name" "$desc" "$commit_sha"

    code="$(github_api POST releases "$response" "$json")"
    if [[ "$code" != "201" ]]; then
        log_error "Errore creazione release (HTTP: ${code:-nessuna risposta})"
        [[ -s "$response" ]] && head -c 500 "$response" >&2 && printf '\n' >&2
        return 1
    fi

    log_success "Release creata"
    rid="$(json_extract "$response" id)"
    upload_url="$(json_extract "$response" upload_url)"
    upload_url="${upload_url%%\{*}"

    if [[ -n "$upload_url" ]]; then
        upload_release_assets "$upload_url" "$rid" || return 1
    else
        log_warning "upload_url non disponibile: asset non caricati"
    fi

    show_release_info "$response" "$name"
    return 0
}

update_existing_release() {
    local name="$1"
    local desc="$2"
    local rid json response code upload_url updated_at commit_sha

    log_info "Aggiornamento release esistente: $name"

    rid="$(get_release_id "$(urlencode "$name")")" || return 1
    [[ -n "$rid" ]] || { log_error "ID release non disponibile"; return 1; }

    commit_sha="$(git rev-parse HEAD 2>/dev/null || true)"
    updated_at="$(date '+%Y-%m-%d %H:%M')"
    json="$TMP_DIR/release-update.json"
    response="$TMP_DIR/release-update-response.json"
    json_release_payload update "$json" "$name" "$desc" "$commit_sha" "$updated_at"

    code="$(github_api PATCH "releases/$rid" "$response" "$json")"
    if [[ "$code" != "200" ]]; then
        log_error "Errore aggiornamento release (HTTP: ${code:-nessuna risposta})"
        [[ -s "$response" ]] && head -c 500 "$response" >&2 && printf '\n' >&2
        return 1
    fi

    log_success "Release aggiornata"

    log_warning "Nota: aggiornare una release non sposta il tag Git sul nuovo commit."
    log_warning "Per allineare il tag usa l'opzione 'd' (cancella e ricrea)."

    # Sostituisce i PDF: senza questo passaggio gli asset vecchi restano.
    delete_release_assets_by_name "$rid"

    upload_url="$(json_extract "$response" upload_url)"
    upload_url="${upload_url%%\{*}"
    if [[ -n "$upload_url" ]]; then
        upload_release_assets "$upload_url" "$rid" || return 1
    else
        log_warning "upload_url non disponibile: asset non aggiornati"
    fi

    show_release_info "$response" "$name" "Release aggiornata:"
    return 0
}

delete_existing_release() {
    local name="$1"
    local tag_enc rid code tag_code

    log_warning "Cancellazione release esistente: $name"

    tag_enc="$(urlencode "$name")"
    rid="$(get_release_id "$tag_enc")" || return 1
    [[ -n "$rid" ]] || { log_error "ID release non disponibile"; return 1; }

    code="$(github_api DELETE "releases/$rid" /dev/null)"
    if [[ "$code" != "204" ]]; then
        log_error "Errore cancellazione release (HTTP: ${code:-nessuna risposta})"
        return 1
    fi

    log_success "Release cancellata"

    log_info "Cancellazione tag associato..."
    tag_code="$(github_api DELETE "git/refs/tags/$name" /dev/null)"
    if [[ "$tag_code" == "204" ]]; then
        log_success "Tag cancellato"
    elif [[ "$tag_code" == "404" ]]; then
        log_info "Tag già assente"
    else
        log_warning "Errore cancellazione tag (HTTP: ${tag_code:-nessuna risposta})"
    fi

    return 0
}

prompt_version_name() {
    local timestamp default_version
    timestamp="$(date +"%Y-%m-%d-%H%M")"
    default_version="OBSSv2-$timestamp"

    if ((!INTERACTIVE)); then
        printf '%s' "$default_version"
        return 0
    fi

    while true; do
        printf 'Nome della versione [%s]: ' "$default_version" >&2
        local version_name=""
        IFS= read -r version_name || version_name=""
        version_name="${version_name:-$default_version}"

        if validate_tag_name "$version_name"; then
            printf '%s' "$version_name"
            return 0
        fi

        log_error "Nome tag non valido"
        cat >&2 <<'EOF'
Regole per i nomi dei tag:
  • niente spazi
  • non iniziare/finire con '.', '/', '-'
  • niente: : ? * [ ] \ ^ ~
  • esempi validi: v1.0.0, OBSSv2-finale, release-2025
EOF
        printf '\n' >&2
    done
}

prompt_version_description() {
    local default_desc
    default_desc="Release automatica per OBSS v2 - $(date '+%d/%m/%Y alle %H:%M')"

    if ((!INTERACTIVE)); then
        printf '%s' "$default_desc"
        return 0
    fi

    printf '\nDescrizione della versione (INVIO per il default):\n' >&2
    printf 'Default: %s\n' "$default_desc" >&2
    printf 'Descrizione: ' >&2

    local desc=""
    IFS= read -r desc || desc=""
    printf '%s' "${desc:-$default_desc}"
}

handle_existing_release() {
    local tag="$1"
    local desc="$2"
    local choice

    if ((!INTERACTIVE)); then
        log_info "Release esistente: la aggiorno (non interattivo)"
        update_existing_release "$tag" "$desc"
        return
    fi

    echo >&2
    log_warning "La release '$tag' esiste già"
    echo "Opzioni disponibili:" >&2
    echo "  u - Aggiorna release esistente" >&2
    echo "  d - Cancella e ricrea" >&2
    echo "  n - Annulla" >&2
    printf 'Scelta [u/d/n]: ' >&2
    IFS= read -r choice || choice=""

    case "${choice,,}" in
        u|update|aggiorna)
            update_existing_release "$tag" "$desc"
            ;;
        d|delete|cancella)
            if delete_existing_release "$tag"; then
                create_github_release "$tag" "$desc"
            fi
            ;;
        *)
            log_info "Operazione annullata dall'utente"
            ;;
    esac
}

release_flow() {
    show_section "🚀 CREAZIONE RELEASE GITHUB"

    if [[ "$OPT_RELEASE" == "0" ]]; then
        log_info "Release saltata"
        return 0
    fi

    if [[ "$OPT_RELEASE" == "2" ]]; then
        if ((!INTERACTIVE)); then
            log_info "Release saltata (non interattivo)"
            return 0
        fi
        if ! ask_yes_no "Creare una nuova release? [si/No] (s/N): " n; then
            log_info "Release saltata"
            return 0
        fi
    fi

    if ((MISSING_ASSETS)) && ((!OPT_ALLOW_MISSING)); then
        log_error "Mancano degli asset: release annullata (usa --allow-missing per forzare)"
        return 1
    fi

    local tag desc
    if [[ -n "$OPT_TAG" && "$OPT_TAG" != "auto" ]]; then
        tag="$OPT_TAG"
        if ! validate_tag_name "$tag"; then
            log_error "Nome tag non valido: $tag"
            return 1
        fi
    else
        tag="$(prompt_version_name)"
    fi
    log_success "Nome versione: $tag"

    desc="${OPT_DESC:-$(prompt_version_description)}"
    log_success "Descrizione impostata"

    local tag_enc
    tag_enc="$(urlencode "$tag")"

    local status
    check_existing_release "$tag_enc"
    status=$?

    case "$status" in
        0) handle_existing_release "$tag" "$desc" ;;
        1) create_github_release "$tag" "$desc" ;;
        *) log_error "Impossibile verificare la release: creazione annullata"; return 1 ;;
    esac
}

#==============================================================================
# PIPELINE
#==============================================================================

show_summary() {
    local duration=$((SECONDS - SCRIPT_START))

    printf '\n%s' "$C_GREEN" >&2
    printf '═%.0s' {1..80} >&2; printf '\n' >&2
    printf '  🎉 COMPLETATO CON SUCCESSO!\n' >&2
    printf '  ⏱️  Durata: %s\n' "$(format_duration "$duration")" >&2
    ((SECTIONS_COUNT > 0)) && printf '  📄 Sezioni: %d\n' "$SECTIONS_COUNT" >&2
    (( ${#BUILT_DOCS[@]} > 0 )) && printf '  📚 PDF compilati: %d\n' "${#BUILT_DOCS[@]}" >&2
    [[ -n "$RELEASE_URL" ]] && printf '  🚀 Release: %s\n' "$RELEASE_URL" >&2
    printf '═%.0s' {1..80} >&2; printf '\n' >&2
    printf '%s\n' "$C_NC" >&2
}

main() {
    parse_args "$@"

    if ((OPT_DOCTOR)); then
        doctor
        exit $?
    fi

    show_header
    log_info "Avvio workflow OBSS"

    if ! initialize; then
        log_error "Inizializzazione fallita"
        exit 1
    fi

    if ((OPT_SECTIONS)); then
        extract_sections || exit 1
    else
        log_info "Estrazione sezioni disabilitata"
    fi

    if ! create_variants; then
        log_error "Generazione varianti fallita"
        exit 1
    fi

    if ! compile_documents; then
        log_error "Pipeline di compilazione fallita"
        exit 1
    fi

    run_postprocessing || log_warning "Post-processing completato con avvisi"

    # Se wiki/pages sono richieste ma il Markdown è stato saltato, rigeneralo ora.
    if [[ "$OPT_WIKI" != "none" || "$OPT_PAGES" != "none" ]]; then
        if [[ ! -s "$MD1" || ! -s "$MD2" ]]; then
            OPT_FORCE_MD=1
            convert_markdown
        fi
    fi

    if [[ "$OPT_WIKI" != "none" ]] && { [[ -n "$OPT_WIKI" ]] || ((INTERACTIVE)); }; then
        update_wiki
    fi
    if [[ "$OPT_PAGES" != "none" ]] && { [[ -n "$OPT_PAGES" ]] || ((INTERACTIVE)); }; then
        update_pages
    fi

    if ! git_operations; then
        log_error "Operazioni Git fallite"
        exit 1
    fi

    # La release deve puntare al commit appena pubblicato.
    if ! release_flow; then
        log_error "Release non completata"
        exit 1
    fi

    show_summary
}

# Evita problemi con il sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
