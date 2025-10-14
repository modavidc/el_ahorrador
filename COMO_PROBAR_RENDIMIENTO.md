# 🧪 Guía para Probar el Rendimiento

## 📋 Preparación

### 1. Asegúrate de tener la app corriendo
```bash
flutter run
# O si ya está instalada, solo abre la app
```

### 2. Prepara imágenes de prueba
Necesitas tener en tu celular capturas de pantalla de:
- ✅ Recibos de Yape (varios montos)
- ✅ Comprobantes de banco
- ✅ Cualquier otro tipo de recibo

---

## 🚀 Ejecutar las Pruebas

### Opción 1: Monitoreo Automático (Recomendado)

En una terminal nueva (sin cerrar la del flutter run):

```bash
./monitor_performance.sh
```

**Qué hace:**
- Escucha todos los eventos de "Compartir con"
- Registra tiempos automáticamente
- Calcula estadísticas en tiempo real
- Guarda resultados en `performance_results.txt`

**Cómo usarlo:**

1. Ejecuta el script
2. En tu celular:
   - Abre Galería o WhatsApp
   - Comparte una imagen → "El Ahorrador"
   - Espera a que procese
   - Repite con diferentes imágenes (mínimo 5 pruebas)
3. Presiona `Ctrl+C` para terminar
4. Verás un resumen con promedios

### Opción 2: Monitoreo Manual

Si prefieres ver los logs directamente:

```bash
adb logcat | grep -E "TIMER|PROCESS|SHARE|UI"
```

Copia manualmente los resultados que veas en formato:
```
⏱️ TIMER] TOTAL TIME: XXXXms
⏱️ TIMER]   UI delay: XXms
⏱️ TIMER]   File persist: XXXms
...
```

---

## 📊 Ver Resultados

### Durante las Pruebas

El script muestra cada prueba en tiempo real:

```
✅ Prueba #1 completada:
   Total: 2654ms
   UI: 41ms | File: 551ms | DB: 200ms
   OCR: 1648ms | Parse: 87ms | Save: 65ms

✅ Prueba #2 completada:
   Total: 2800ms
   ...
```

### Al Finalizar (Ctrl+C)

Verás estadísticas completas:

```
================================================
📊 CALCULANDO ESTADÍSTICAS...
================================================

Número de pruebas: 5

⏱️  TIEMPO TOTAL:
   Promedio: 2700ms (2.70s)
   Mínimo:   2500ms
   Máximo:   2900ms

📈 DESGLOSE PROMEDIO:
   UI delay:      45ms (1.7%)
   File persist:  550ms (20.4%)
   DB insert:     195ms (7.2%)
   OCR:           1650ms (61.1%)
   Parse:         90ms (3.3%)
   Save expense:  70ms (2.6%)
```

---

## 📝 Generar Informe Final

### 1. Revisar resultados guardados

```bash
cat performance_results.txt
```

### 2. Actualizar el informe

Abre `INFORME_PRUEBAS_RENDIMIENTO.md` y:

1. Completa la información del dispositivo:
   ```bash
   # Ver modelo del dispositivo:
   adb shell getprop ro.product.model
   
   # Ver versión de Android:
   adb shell getprop ro.build.version.release
   ```

2. Copia las estadísticas de `performance_results.txt`

3. Reemplaza todos los `[Pendiente]` con los valores reales

4. Agrega observaciones y conclusiones

### 3. Ejemplo de cómo llenar el informe

**Antes:**
```markdown
| **Tiempo total promedio** | [Pendiente] ms | - |
```

**Después:**
```markdown
| **Tiempo total promedio** | 2700 ms | Excelente rendimiento |
```

---

## 🎯 Consejos para Mejores Resultados

### Pruebas Variadas
- ✅ Diferentes tipos de recibos (Yape, Banco, Binance)
- ✅ Diferentes tamaños de imagen
- ✅ Diferentes montos
- ✅ Diferentes condiciones de red

### Cantidad Mínima
- **Mínimo:** 5 pruebas
- **Recomendado:** 10-15 pruebas
- **Ideal:** 20+ pruebas para estadísticas confiables

### Condiciones Consistentes
- Cierra apps en background innecesarias
- Mantén el celular conectado al WiFi
- No interrumpas mientras procesa

---

## 🔍 Interpretar los Resultados

### Tiempos Buenos ✅

| Métrica | Objetivo | Si está en... |
|---------|----------|---------------|
| **UI Delay** | < 100ms | < 50ms → Excelente |
| **Total** | < 3000ms | < 2500ms → Muy bueno |
| **OCR** | Variable | ~1500-2000ms → Normal |

### Señales de Alerta 🚨

- UI delay > 200ms → Problema de bootstrap
- Total > 4000ms → Revisar optimizaciones
- File persist > 1000ms → Imagen muy grande
- DB > 500ms → Problema de base de datos

---

## 📤 Compartir Resultados

### Formato Corto (Chat/Email)

```
Resultados de pruebas (N=10):
- Tiempo total: 2700ms promedio (2.5s - 2.9s)
- UI delay: 45ms ✅
- OCR: 1650ms (61% del tiempo)
- Todo funcionando correctamente
```

### Formato Completo

Usa el `INFORME_PRUEBAS_RENDIMIENTO.md` completado

---

## ❓ Troubleshooting

### El script no detecta eventos

**Problema:** No aparece "Nueva imagen compartida"

**Solución:**
```bash
# Verifica que adb funcione:
adb devices

# Verifica que los logs lleguen:
adb logcat | grep "TIMER"
```

### Resultados inconsistentes

**Problema:** Tiempos muy variables

**Causas posibles:**
- Primera ejecución (caché de ML Kit)
- Apps en background
- Red lenta
- Imágenes muy diferentes en tamaño

**Solución:**
- Haz más pruebas
- Cierra apps innecesarias
- Usa imágenes similares

### El script se cierra solo

**Problema:** Termina antes de tiempo

**Solución:**
```bash
# Verifica permisos:
chmod +x monitor_performance.sh

# Ejecuta con bash explícito:
bash monitor_performance.sh
```

---

## 🎉 Ejemplo de Flujo Completo

```bash
# Terminal 1: App corriendo
flutter run

# Terminal 2: Monitor de rendimiento
./monitor_performance.sh

# En el celular:
# 1. Compartir imagen 1 → Esperar
# 2. Compartir imagen 2 → Esperar
# 3. Compartir imagen 3 → Esperar
# ... (hasta 10+ pruebas)

# Terminal 2: Ctrl+C para ver estadísticas
# Copiar resultados

# Actualizar informe
code INFORME_PRUEBAS_RENDIMIENTO.md
# Pegar estadísticas y completar observaciones

# ¡Listo! 🎉
```

---

## 📚 Archivos Relacionados

- `monitor_performance.sh` - Script de monitoreo automático
- `performance_results.txt` - Resultados guardados
- `INFORME_PRUEBAS_RENDIMIENTO.md` - Plantilla del informe
- Este archivo - Guía de uso

---

**¡Buena suerte con las pruebas!** 🚀

