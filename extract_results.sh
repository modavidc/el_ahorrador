#!/bin/bash
# Script simple para extraer resultados de los logs

echo "📊 Extrayendo resultados de los logs..."
echo ""

TEMP_FILE="/tmp/extract_results.tmp"
> "$TEMP_FILE"

# Extraer todos los bloques de TIMER con TOTAL TIME
adb logcat -d | grep -B 6 "TOTAL TIME:" | grep "TIMER]" | while read -r line; do
    if echo "$line" | grep -q "TOTAL TIME:"; then
        TOTAL=$(echo "$line" | sed -n 's/.*TOTAL TIME: \([0-9]\+\)ms.*/\1/p')
        
        # Ahora leer las siguientes líneas para obtener los detalles
        read -r ui_line
        read -r file_line
        read -r db_line
        read -r ocr_line
        read -r parse_line
        read -r save_line
        
        UI=$(echo "$ui_line" | sed -n 's/.*UI delay: \([0-9]\+\)ms.*/\1/p')
        FILE=$(echo "$file_line" | sed -n 's/.*File persist: \([0-9]\+\)ms.*/\1/p')
        DB=$(echo "$db_line" | sed -n 's/.*DB insert: \([0-9]\+\)ms.*/\1/p')
        OCR=$(echo "$ocr_line" | sed -n 's/.*OCR: \([0-9]\+\)ms.*/\1/p')
        PARSE=$(echo "$parse_line" | sed -n 's/.*Parse: \([0-9]\+\)ms.*/\1/p')
        SAVE=$(echo "$save_line" | sed -n 's/.*Save expense: \([0-9]\+\)ms.*/\1/p')
        
        if [[ -n "$TOTAL" ]] && [[ -n "$UI" ]]; then
            echo "$TOTAL,$UI,$FILE,$DB,$OCR,$PARSE,$SAVE" >> "$TEMP_FILE"
        fi
    fi
done

# Contar cuántos resultados
COUNT=$(wc -l < "$TEMP_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -eq 0 ]; then
    echo "❌ No se encontraron resultados en los logs"
    echo ""
    echo "¿Compartiste imágenes manualmente desde la Galería?"
    rm -f "$TEMP_FILE"
    exit 1
fi

echo "✅ Encontrados $COUNT resultados"
echo ""

# Calcular estadísticas
awk -F',' '
{
    total_sum += $1; ui_sum += $2; file_sum += $3; 
    db_sum += $4; ocr_sum += $5; parse_sum += $6; save_sum += $7;
    count++;
    
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
        printf "   Save expense:  %.0fms (%.1f%%)\n\n", save_sum/count, (save_sum/count)/(total_sum/count)*100;
        
        printf "---\nDATOS RAW:\n";
    }
}
' "$TEMP_FILE" | tee performance_results.txt

cat "$TEMP_FILE" >> performance_results.txt

echo ""
echo "✅ Resultados guardados en: performance_results.txt"

rm -f "$TEMP_FILE"

