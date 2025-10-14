#!/bin/bash
# Script para probar automáticamente múltiples imágenes

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuración
TEST_IMAGES_DIR="${1:-./test_images}"
RESULTS_FILE="performance_results.txt"
TEMP_FILE="/tmp/auto_test_timing.tmp"
WAIT_TIME=5  # Segundos de espera entre cada prueba

echo "🚀 Auto Test de Rendimiento - El Ahorrador"
echo "=========================================="
echo ""

# Verificar que existe el directorio
if [ ! -d "$TEST_IMAGES_DIR" ]; then
    echo -e "${RED}❌ Error: El directorio '$TEST_IMAGES_DIR' no existe${NC}"
    echo ""
    echo "Uso:"
    echo "  1. Crea un directorio con imágenes de prueba:"
    echo "     mkdir test_images"
    echo "     # Copia tus capturas de Yape/Banco ahí"
    echo ""
    echo "  2. Ejecuta el script:"
    echo "     ./auto_test_performance.sh test_images"
    exit 1
fi

# Contar imágenes
IMAGE_COUNT=$(find "$TEST_IMAGES_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | wc -l)

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ No se encontraron imágenes en '$TEST_IMAGES_DIR'${NC}"
    echo "Formatos soportados: .jpg, .jpeg, .png"
    exit 1
fi

echo -e "${GREEN}✅ Encontradas $IMAGE_COUNT imágenes${NC}"
echo ""

# Verificar que la app esté corriendo
echo "Verificando conexión con dispositivo..."
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}❌ No hay dispositivo conectado${NC}"
    echo "Ejecuta: adb devices"
    exit 1
fi

echo -e "${GREEN}✅ Dispositivo conectado${NC}"
echo ""

# Limpiar resultados anteriores
> "$TEMP_FILE"
> "$RESULTS_FILE"

echo "Iniciando pruebas automáticas..."
echo "Presiona Ctrl+C para detener"
echo ""

# Contador
TEST_NUM=0
SUCCESS_COUNT=0
FAIL_COUNT=0

# Procesar cada imagen
find "$TEST_IMAGES_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | while read -r image; do
    TEST_NUM=$((TEST_NUM + 1))
    IMAGE_NAME=$(basename "$image")
    
    echo -e "${BLUE}📤 Prueba #${TEST_NUM}: $IMAGE_NAME${NC}"
    
    # Enviar la imagen al dispositivo
    DEVICE_PATH="/sdcard/Download/test_${TEST_NUM}.jpg"
    adb push "$image" "$DEVICE_PATH" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}  ❌ Error al copiar imagen al dispositivo${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    
    # Limpiar logcat
    adb logcat -c
    
    # Compartir la imagen usando intent
    adb shell am start -a android.intent.action.SEND \
        -t "image/*" \
        --eu android.intent.extra.STREAM "file://$DEVICE_PATH" \
        -n com.example.mis_gastos/.MainActivity > /dev/null 2>&1
    
    # Esperar y capturar los logs
    sleep 1
    
    # Capturar resultados (timeout de 10 segundos)
    TOTAL_TIME=""
    UI_DELAY=""
    FILE_PERSIST=""
    DB_INSERT=""
    OCR_TIME=""
    PARSE_TIME=""
    SAVE_EXPENSE=""
    
    timeout 10s adb logcat | while read -r line; do
        if echo "$line" | grep -q "UI delay:"; then
            UI_DELAY=$(echo "$line" | sed -n 's/.*UI delay: \([0-9]\+\)ms.*/\1/p')
        fi
        
        if echo "$line" | grep -q "File persist:"; then
            FILE_PERSIST=$(echo "$line" | sed -n 's/.*File persist: \([0-9]\+\)ms.*/\1/p')
        fi
        
        if echo "$line" | grep -q "DB insert:"; then
            DB_INSERT=$(echo "$line" | sed -n 's/.*DB insert: \([0-9]\+\)ms.*/\1/p')
        fi
        
        if echo "$line" | grep -q "OCR:"; then
            OCR_TIME=$(echo "$line" | sed -n 's/.*OCR: \([0-9]\+\)ms.*/\1/p')
        fi
        
        if echo "$line" | grep -q "Parse:"; then
            PARSE_TIME=$(echo "$line" | sed -n 's/.*Parse: \([0-9]\+\)ms.*/\1/p')
        fi
        
        if echo "$line" | grep -q "Save expense:"; then
            SAVE_EXPENSE=$(echo "$line" | sed -n 's/.*Save expense: \([0-9]\+\)ms.*/\1/p')
        fi
        
        if echo "$line" | grep -q "TOTAL TIME:"; then
            TOTAL_TIME=$(echo "$line" | sed -n 's/.*TOTAL TIME: \([0-9]\+\)ms.*/\1/p')
            
            # Si tenemos el tiempo total, guardar y salir
            if [[ -n "$TOTAL_TIME" ]] && [[ -n "$UI_DELAY" ]]; then
                echo "$TOTAL_TIME,$UI_DELAY,$FILE_PERSIST,$DB_INSERT,$OCR_TIME,$PARSE_TIME,$SAVE_EXPENSE" >> "$TEMP_FILE"
                echo -e "${GREEN}  ✅ Completada: ${TOTAL_TIME}ms${NC}"
                pkill -P $$ adb
                exit 0
            fi
        fi
    done
    
    # Verificar si se guardó el resultado
    if tail -1 "$TEMP_FILE" | grep -q "^[0-9]"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}  ❌ No se pudo capturar el resultado${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Limpiar archivo del dispositivo
    adb shell rm "$DEVICE_PATH" 2>/dev/null
    
    # Esperar antes de la siguiente prueba
    echo "  ⏳ Esperando ${WAIT_TIME}s..."
    sleep "$WAIT_TIME"
    echo ""
done

echo ""
echo "=========================================="
echo "📊 CALCULANDO ESTADÍSTICAS..."
echo "=========================================="
echo ""

# Calcular estadísticas
if [ ! -s "$TEMP_FILE" ]; then
    echo "No se capturaron resultados válidos."
    exit 1
fi

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
        printf "Número de pruebas exitosas: %d\n\n", count;
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
        printf "   Save expense:  %.0fms (%.1f%%)\n\n", save_sum/count, (save_sum/count)/(total_sum/count)*100;
        
        printf "---\nDATOS RAW:\n";
    }
}
' "$TEMP_FILE" | tee "$RESULTS_FILE"

# Agregar datos raw
cat "$TEMP_FILE" >> "$RESULTS_FILE"

echo ""
echo -e "${GREEN}✅ Resultados guardados en: $RESULTS_FILE${NC}"
echo ""
echo "Resumen:"
echo "  • Exitosas: $SUCCESS_COUNT"
echo "  • Fallidas: $FAIL_COUNT"
echo "  • Total: $IMAGE_COUNT"
echo ""

# Cleanup
rm -f "$TEMP_FILE"

