#!/bin/bash

# Nome del file LaTeX in input
INPUT_FILE="OBSSv2.tex"

# Directory di output
OUTPUT_DIR="sezioni"

# Crea la directory di output se non esiste
mkdir -p "$OUTPUT_DIR"

# Legge il contenuto del file in una variabile
CONTENT=$(cat "$INPUT_FILE")

# Trova dove inizia il documento e salva il preambolo
PREAMBOLO=$(awk '/\\begin{document}/{ print NR; exit }' "$INPUT_FILE")

if [ -n "$PREAMBOLO" ]; then
    sed -n "1,${PREAMBOLO}p" "$INPUT_FILE" > "$OUTPUT_DIR/00_preambolo.tex"
    echo "Preambolo salvato in $OUTPUT_DIR/00_preambolo.tex"
fi

# Crea un file temporaneo con le linee dei comandi section e relative informazioni
grep -n "\\\\section{" "$INPUT_FILE" > temp_sections.txt

# Se non sono state trovate sezioni, termina
if [ ! -s temp_sections.txt ]; then
    echo "Nessuna sezione trovata nel file $INPUT_FILE"
    rm temp_sections.txt
    exit 1
fi

# Leggi numero totale di righe
TOTAL_LINES=$(wc -l < "$INPUT_FILE")

# Inizializza variabili
PREV_LINE=0
SECTION_COUNT=0

# Processa ogni sezione trovata
while IFS=: read -r LINE_NUM LINE_CONTENT; do
    # Estrai il titolo della sezione
    SECTION_TITLE=$(echo "$LINE_CONTENT" | sed -n 's/.*\\section{\([^}]*\)}.*/\1/p')
    
    # Pulisci il titolo per usarlo come nome file
    CLEAN_TITLE=$(echo "$SECTION_TITLE" | tr -cd '[:alnum:]._-' | tr ' ' '_')
    
    # Se siamo alla prima sezione e c'è contenuto tra \begin{document} e la prima sezione
    if [ "$SECTION_COUNT" -eq 0 ] && [ "$PREV_LINE" -eq 0 ]; then
        # Se c'è del contenuto tra \begin{document} e la prima sezione, salvalo
        if [ "$PREAMBOLO" -lt "$LINE_NUM" ]; then
            sed -n "$((PREAMBOLO+1)),$((LINE_NUM-1))p" "$INPUT_FILE" > "$OUTPUT_DIR/01_introduzione.tex"
            echo "Contenuto iniziale salvato in $OUTPUT_DIR/01_introduzione.tex"
        fi
    fi
    
    # Per le sezioni successive alla prima
    if [ "$PREV_LINE" -ne 0 ]; then
        # Formatta il numero della sezione
        PADDED_NUM=$(printf "%02d" "$((SECTION_COUNT+2))")
        
        # Estrai il contenuto della sezione precedente
        sed -n "$PREV_LINE,$((LINE_NUM-1))p" "$INPUT_FILE" > "$OUTPUT_DIR/${PADDED_NUM}_${PREV_CLEAN_TITLE}.tex"
        echo "Sezione '$PREV_SECTION_TITLE' salvata in $OUTPUT_DIR/${PADDED_NUM}_${PREV_CLEAN_TITLE}.tex"
        
        SECTION_COUNT=$((SECTION_COUNT+1))
    fi
    
    # Salva i valori per la prossima iterazione
    PREV_LINE=$LINE_NUM
    PREV_SECTION_TITLE=$SECTION_TITLE
    PREV_CLEAN_TITLE=$CLEAN_TITLE
    
done < temp_sections.txt

# Gestisci l'ultima sezione
if [ "$PREV_LINE" -ne 0 ]; then
    PADDED_NUM=$(printf "%02d" "$((SECTION_COUNT+2))")
    sed -n "$PREV_LINE,$TOTAL_LINES p" "$INPUT_FILE" > "$OUTPUT_DIR/${PADDED_NUM}_${PREV_CLEAN_TITLE}.tex"
    echo "Sezione '$PREV_SECTION_TITLE' salvata in $OUTPUT_DIR/${PADDED_NUM}_${PREV_CLEAN_TITLE}.tex"
fi

# Elimina il file temporaneo
rm temp_sections.txt

echo "Completato! Le sezioni sono state salvate nella directory '$OUTPUT_DIR'"
