# 🤖 Pruebas Automáticas de Rendimiento

## 🎯 Propósito

Probar automáticamente 20-30 capturas para obtener estadísticas precisas sin tener que compartir imágenes manualmente una por una.

---

## 📋 Preparación (Solo una vez)

### 1. Crea el directorio de imágenes
```bash
mkdir test_images
```

### 2. Copia tus capturas ahí
Pon manualmente 20-30 imágenes de:
- ✅ Recibos de Yape
- ✅ Comprobantes de banco
- ✅ Cualquier tipo de recibo/factura

**Ejemplo:**
```bash
# Copiar desde algún lugar
cp ~/Downloads/capturas_yape/*.png test_images/
```

### 3. Verifica que estén ahí
```bash
ls test_images/
# Deberías ver tus imágenes
```

---

## 🚀 Ejecutar las Pruebas

### Paso 1: Asegúrate de que la app esté corriendo
```bash
flutter run
# Deja esto abierto
```

### Paso 2: En otra terminal, ejecuta las pruebas
```bash
./auto_test_performance.sh test_images
```

### Paso 3: Espera (sin hacer nada)
El script va a:
1. ✅ Enviar cada imagen al celular
2. ✅ Compartirla automáticamente a la app
3. ✅ Capturar los tiempos
4. ✅ Esperar 5 segundos entre cada prueba
5. ✅ Repetir con todas las imágenes

**Progreso en tiempo real:**
```
📤 Prueba #1: yape_01.png
  ✅ Completada: 1337ms
  ⏳ Esperando 5s...

📤 Prueba #2: yape_02.png
  ✅ Completada: 1450ms
  ⏳ Esperando 5s...

...
```

### Paso 4: Ver resultados
Al finalizar, verás:
```
==========================================
📊 CALCULANDO ESTADÍSTICAS...
==========================================

Número de pruebas exitosas: 20

⏱️  TIEMPO TOTAL:
   Promedio: 1500ms (1.50s)
   Mínimo:   1200ms
   Máximo:   1800ms

📈 DESGLOSE PROMEDIO:
   UI delay:      30ms (2.0%)
   File persist:  250ms (16.7%)
   DB insert:     100ms (6.7%)
   OCR:           950ms (63.3%)
   Parse:         50ms (3.3%)
   Save expense:  70ms (4.7%)

✅ Resultados guardados en: performance_results.txt
```

---

## 📊 Resultados

Los resultados se guardan en:
- **`performance_results.txt`** - Estadísticas completas

### Ver resultados después:
```bash
cat performance_results.txt
```

---

## ⚙️ Configuración

### Cambiar tiempo de espera entre pruebas
Edita `auto_test_performance.sh`, línea 11:
```bash
WAIT_TIME=5  # Cambiar a 3 o 10 segundos
```

### Si algo falla
- Asegúrate que `adb devices` muestre tu celular
- Verifica que la app esté corriendo
- Revisa que las imágenes sean .jpg, .jpeg o .png

---

## 🎯 Checklist Rápido

- [ ] Crear carpeta `test_images`
- [ ] Copiar 20-30 imágenes de prueba
- [ ] `flutter run` en una terminal
- [ ] `./auto_test_performance.sh test_images` en otra terminal
- [ ] Esperar sin tocar nada
- [ ] Revisar `performance_results.txt`
- [ ] Actualizar `INFORME_PRUEBAS_RENDIMIENTO.md` con los datos

---

## 💡 Tips

### Para mejores resultados:
1. **Usa imágenes variadas** (diferentes tamaños, tipos)
2. **Cierra apps innecesarias** en el celular
3. **Mantén WiFi conectado** 
4. **No toques el celular** durante las pruebas
5. **Haz al menos 20 pruebas** para estadísticas confiables

### Ventajas vs Pruebas Manuales:
- ✅ **Sin fastidio** - Se hace solo
- ✅ **Consistente** - Mismas condiciones
- ✅ **Rápido** - 20 pruebas en ~2 minutos
- ✅ **Automático** - Estadísticas al final

---

## 📝 Ejemplo Completo

```bash
# 1. Preparar
mkdir test_images
cp ~/mis_capturas/*.png test_images/
ls test_images/  # Verificar

# 2. Ejecutar app
flutter run  # Terminal 1

# 3. Ejecutar pruebas (en otra terminal)
./auto_test_performance.sh test_images

# 4. Ver resultados
cat performance_results.txt

# 5. Actualizar informe
code INFORME_PRUEBAS_RENDIMIENTO.md
# Copiar los datos de performance_results.txt
```

---

## 🐛 Troubleshooting

### "No hay dispositivo conectado"
```bash
adb devices
# Si no aparece, reconecta el cable USB
```

### "No se encontraron imágenes"
```bash
ls test_images/*.{jpg,png,jpeg}
# Verifica que tengas imágenes ahí
```

### "Error al copiar imagen al dispositivo"
```bash
# Dale permisos al celular:
adb shell pm grant com.example.mis_gastos android.permission.READ_EXTERNAL_STORAGE
```

### Resultados inconsistentes
- Primera ejecución siempre es más lenta (caché de ML Kit)
- Borra `performance_results.txt` y prueba de nuevo
- Cierra apps en background

---

**¡Listo para probar! 🚀**

