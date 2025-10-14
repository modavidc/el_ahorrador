#!/bin/bash
# Script para monitorear y registrar métricas de rendimiento

OUTPUT_FILE="performance_results.txt"
TEMP_FILE="/tmp/share_timing.tmp"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📊 Monitoreando rendimiento de 'El Ahorrador'..."
echo "================================================"
echo ""
echo "Instrucciones:"
echo "1. Comparte imágenes desde Galería/WhatsApp → 'El Ahorrador'"
echo "2. Cada vez que compartas, se registrará el tiempo"
echo "3. Presiona Ctrl+C cuando termines para ver estadísticas"
echo ""
echo "Esperando eventos de compartir..."
echo ""

# Limpiar archivo temporal
> "$TEMP_FILE"

# Contador de pruebas
TEST_COUNT=0

# Función para procesar cada evento completo
process_share_event() {
    local total_time="$1"
    local ui_delay="$2"
    local file_persist="$3"
    local db_insert="$4"
    local ocr_time="$5"
    local parse_time="$6"
    local save_expense="$7"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    echo -e "${GREEN}✅ Prueba #${TEST_COUNT} completada:${NC}"
    echo "   Total: ${total_time}ms"
    echo "   UI: ${ui_delay}ms | File: ${file_persist}ms | DB: ${db_insert}ms"
    echo "   OCR: ${ocr_time}ms | Parse: ${parse_time}ms | Save: ${save_expense}ms"
    echo ""
    
    # Guardar en archivo temporal
    echo "$total_time,$ui_delay,$file_persist,$db_insert,$ocr_time,$parse_time,$save_expense" >> "$TEMP_FILE"
}

# Variables temporales para acumular datos de cada evento
CURRENT_TOTAL=""
CURRENT_UI=""
CURRENT_FILE=""
CURRENT_DB=""
CURRENT_OCR=""
CURRENT_PARSE=""
CURRENT_SAVE=""

# Monitorear logcat
adb logcat -c  # Limpiar logs anteriores
adb logcat | while read -r line; do
    # Detectar inicio de share
    if echo "$line" | grep -q "SHARE STARTED"; then
        # Reset variables
        CURRENT_TOTAL=""
        CURRENT_UI=""
        CURRENT_FILE=""
        CURRENT_DB=""
        CURRENT_OCR=""
        CURRENT_PARSE=""
        CURRENT_SAVE=""
        echo -e "${BLUE}📤 Nueva imagen compartida...${NC}"
    fi
    
    # Extraer tiempos individuales
    if echo "$line" | grep -q "UI delay:"; then
        CURRENT_UI=$(echo "$line" | sed -n 's/.*UI delay: \([0-9]\+\)ms.*/\1/p')
    fi
    
    if echo "$line" | grep -q "File persist:"; then
        CURRENT_FILE=$(echo "$line" | sed -n 's/.*File persist: \([0-9]\+\)ms.*/\1/p')
    fi
    
    if echo "$line" | grep -q "DB insert:"; then
        CURRENT_DB=$(echo "$line" | sed -n 's/.*DB insert: \([0-9]\+\)ms.*/\1/p')
    fi
    
    if echo "$line" | grep -q "OCR:"; then
        CURRENT_OCR=$(echo "$line" | sed -n 's/.*OCR: \([0-9]\+\)ms.*/\1/p')
    fi
    
    if echo "$line" | grep -q "Parse:"; then
        CURRENT_PARSE=$(echo "$line" | sed -n 's/.*Parse: \([0-9]\+\)ms.*/\1/p')
    fi
    
    if echo "$line" | grep -q "Save expense:"; then
        CURRENT_SAVE=$(echo "$line" | sed -n 's/.*Save expense: \([0-9]\+\)ms.*/\1/p')
    fi
    
    # Detectar tiempo total (último dato)
    if echo "$line" | grep -q "TOTAL TIME:"; then
        CURRENT_TOTAL=$(echo "$line" | sed -n 's/.*TOTAL TIME: \([0-9]\+\)ms.*/\1/p')
        
        # Si tenemos todos los datos, procesar
        if [[ -n "$CURRENT_TOTAL" ]] && [[ -n "$CURRENT_UI" ]] && [[ -n "$CURRENT_FILE" ]]; then
            process_share_event "$CURRENT_TOTAL" "$CURRENT_UI" "$CURRENT_FILE" "$CURRENT_DB" "$CURRENT_OCR" "$CURRENT_PARSE" "$CURRENT_SAVE"
        fi
    fi
done

# Esta parte se ejecuta al presionar Ctrl+C
trap 'calculate_stats' EXIT

calculate_stats() {
    echo ""
    echo "================================================"
    echo "📊 CALCULANDO ESTADÍSTICAS..."
    echo "================================================"
    echo ""
    
    if [ ! -s "$TEMP_FILE" ]; then
        echo "No se registraron pruebas."
        exit 0
    fi
    
    # Calcular promedios usando awk
    awk -F',' '
    {
        total_sum += $1; ui_sum += $2; file_sum += $3; 
        db_sum += $4; ocr_sum += $5; parse_sum += $6; save_sum += $7;
        count++;
        
        # Guardar para min/max
        if (NR == 1 || $1 < min_total) min_total = $1;
        if (NR == 1 || $1 > max_total) max_total = $1;
    }
    END {
        if (count > 0) {
            printf "Número de pruebas: %d\n\n", count;
            printf "⏱️  TIEMPO TOTAL:\n";
            printf "   Promedio: %.0fms (%.2fs)\n", total_sum/count, (total_sum/count)/1000;
            printf "   Mínimo:   %dms\n", min_total;
            printf "   Máximo:   %dms\n\n", max_total;
            
            printf "📈 DESGLOSE PROMEDIO:\n";
            printf "   UI delay:      %.0fms (%.1f%%)\n", ui_sum/count, (ui_sum/count)/(total_sum/count)*100;
            printf "   File persist:  %.0fms (%.1f%%)\n", file_sum/count, (file_sum/count)/(total_sum/count)*100;
            printf "   DB insert:     %.0fms (%.1f%%)\n", db_sum/count, (db_sum/count)/(total_sum/count)*100;
            printf "   OCR:           %.0fms (%.1f%%)\n", ocr_sum/count, (ocr_sum/count)/(total_sum/count)*100;
            printf "   Parse:         %.0fms (%.1f%%)\n", parse_sum/count, (parse_sum/count)/(total_sum/count)*100;
            printf "   Save expense:  %.0fms (%.1f%%)\n", save_sum/count, (save_sum/count)/(total_sum/count)*100;
        }
    }
    ' "$TEMP_FILE" | tee -a "$OUTPUT_FILE"
    
    echo ""
    echo "✅ Resultados guardados en: $OUTPUT_FILE"
    
    # Cleanup
    rm -f "$TEMP_FILE"
}

