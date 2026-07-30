# Checkpoint de la sesión 28–29 de julio — Redmi 15C

Sesión: 28–29 de julio de 2026 (una sola sesión continua)  
Dispositivo: Redmi 15C / Android 15 (API 35)  
Identificador del dispositivo: `25078RA3EL`  
Modalidad: ejecución `debug` mediante `flutter run`  
Flutter: 3.44.6 / Dart 3.12.2  
Estado del proyecto: **Fase 2 de 12 — smoke tests y flujo crítico en dispositivo**

Este documento continúa el registro histórico del
[`device-test-redmi-15c-2026-07-27.md`](device-test-redmi-15c-2026-07-27.md).
El build probado mediante `flutter run` no tiene todavía un APK versionado ni un
SHA-256 registrado como evidencia de release.

## Resumen ejecutivo

Todo lo documentado para el 28 y 29 pertenece a una única sesión continua. El
bloqueo de autenticación impedía entrar a la aplicación y, por tanto, también
impedía probar los demás flujos: esos resultados iniciales deben leerse como
**no verificables por bloqueo**, no como fallos funcionales independientes.
Una vez corregido el acceso se pudieron ejecutar, diagnosticar y corregir los
flujos que antes parecían no funcionar.

La fase 1 quedó superada: el proyecto compila, se instala, abre en el Redmi y
mantiene conexión de depuración. En la fase 2 se completó por primera vez el
flujo crítico real:

`Compartir imagen → OCR → interpretar Yape → guardar gasto`

Se guardó correctamente un gasto real de S/ 9 después de corregir una violación
de claves foráneas. Esto valida el flujo una vez, pero todavía no constituye una
alpha: falta repetirlo con una matriz de capturas, revalidar en dispositivo los
cambios de autenticación y rendimiento, y trabajar la pantalla principal.

## Resultados confirmados en la sesión del 28–29

- **Aprobado:** Flutter detecta el Redmi y mantiene `flutter run` conectado.
- **Aprobado:** la aplicación se desbloquea y permite entrar.
- **Aprobado:** el registro manual crea una transacción.
- **Aprobado:** una captura compartida desde otra app llega al handler.
- **Aprobado:** la imagen se persiste cifrada y se registra la captura.
- **Aprobado:** ML Kit ejecuta OCR sobre una captura de Yape.
- **Aprobado:** el parser detecta fecha, monto, moneda, destinatario, categoría,
  subcategoría, cuenta y confianza OCR.
- **Aprobado:** el gasto interpretado se inserta en SQLite y queda guardado.
- **Aprobado localmente:** pruebas automatizadas de claves foráneas, bloqueo y
  sesión en segundo plano.
- **Pendiente en Redmi:** repetir varias capturas y validar el último cambio de
  sesión de cinco minutos y el procesamiento paralelo.

## Evidencia del primer flujo Share exitoso

Datos extraídos:

- Fecha: 28 de julio de 2026, 17:46.
- Monto: S/ 9.00.
- Moneda: PEN.
- Categoría: Comida.
- Subcategoría: Otros.
- Cuenta: BCP Soles.
- Fuente: Yape.
- Confianza OCR: 77 %.

Tiempos registrados antes de la optimización paralela:

| Etapa | Tiempo |
| --- | ---: |
| Mostrar UI | 110 ms |
| Persistir y cifrar archivo | 2182 ms |
| Operaciones iniciales de base de datos | 260 ms |
| OCR | 1071 ms |
| Parseo | 57 ms |
| Total aproximado | 3704 ms |

La mayor demora observada estuvo en la lectura, cifrado y escritura de la
captura. Mantener la aplicación viva ya evita el arranque, pero no elimina el
trabajo de disco ni OCR.

## Incidencias y cambios

### MOB-007 — Regresión de desbloqueo

Severidad original: Bloqueante  
Estado: **Corregido y revalidado parcialmente en Redmi**

Cambios acumulados:

- La autenticación sólo comienza con el toque explícito en **Desbloquear**.
- Se desactivó `stickyAuth` para evitar solicitudes nativas estancadas en
  HyperOS.
- Los resultados de error o cancelación mantienen disponible el reintento.
- Una prueba confirma que un segundo intento puede desbloquear después de un
  error.

Pendiente: probar cancelación, rechazo y reintento en el teléfono.

Esta incidencia fue el bloqueo raíz de la sesión. Mientras estuvo presente no
fue posible evaluar correctamente Share, OCR, registro manual, navegación ni
persistencia. Recuperar el desbloqueo habilitó el resto del diagnóstico y las
correcciones descritas en este checkpoint.

### MOB-001 — Reautenticación demasiado frecuente

Severidad: Alta  
Estado: **Mejora implementada; pendiente de revalidación final en Redmi**

El periodo de gracia original de 30 segundos era insuficiente para abrir otra
app, escoger una captura y compartirla. Se amplió a cinco minutos:

- El contenido se cubre inmediatamente al pasar a segundo plano.
- Al regresar dentro de cinco minutos se restaura la sesión sin otro prompt.
- El tiempo usa un reloj monotónico.
- Un bloqueo explícito o el reinicio del proceso invalida la sesión.
- La prueba automatizada simula dos minutos fuera de la app y confirma una sola
  autenticación.

Pendiente: confirmar el comportamiento real al compartir desde Galería/Yape y
la expiración al superar cinco minutos.

### MOB-002 — Share, pantalla negra y procesamiento OCR

Severidad original: Crítica  
Estado: **Flujo crítico aprobado una vez; requiere repetición**

Cambios y hallazgos:

- Los intentos realizados mientras la app no permitía desbloquearse no cuentan
  como fallos concluyentes de Share u OCR; el flujo estaba bloqueado antes de
  poder ejecutarlos.
- El procesamiento espera que el `Navigator` esté disponible antes de mostrar
  progreso.
- El seguimiento del diálogo evita retirar por error la ruta principal.
- La captura compartida ya llega a OCR y al parser.
- La primera inserción falló con `SqliteException(787): FOREIGN KEY constraint
  failed`; el problema no estaba en OCR sino en la relación de categorías.
- Después de corregir las claves foráneas, el gasto se guardó correctamente.

Pendiente: probar app cerrada, abierta/desbloqueada y abierta/bloqueada, además
de errores OCR recuperables y múltiples capturas consecutivas.

### MOB-008 — Nombres usados como claves foráneas

Severidad: Crítica  
Estado: **Corregido y validado en el primer flujo real**

El parser entregaba nombres (`Comida`, `Otros`) y la tabla `expenses` esperaba
IDs (`cat_1`, `sub_11`). `insertExpenseFromParser` ahora resuelve tanto nombres
como IDs existentes antes del `INSERT` y limita la subcategoría a la categoría
resuelta.

Validación automatizada:

- `Comida` / `Otros` se guardan como `cat_1` / `sub_11`.
- Los callers que ya envían IDs siguen funcionando.
- Las dos pruebas de regresión aprobaron.

### PERF-001 — Persistencia y OCR ejecutados en serie

Severidad: Media  
Estado: **Optimización implementada; pendiente de medición en Redmi**

Antes se cifraba la imagen, se guardaba, se descifraba a un temporal y recién
entonces comenzaba OCR. Ahora:

- La copia cifrada permanente y OCR sobre el archivo entrante comienzan en
  paralelo.
- Se evita el descifrado temporal inmediato para OCR.
- La copia durable continúa almacenándose cifrada.

Resultado esperado: el total debe acercarse al tiempo de la operación más lenta
en lugar de sumar persistencia y OCR. Registrar el próximo desglose antes de
considerar cerrada esta mejora.

### MOB-003 y MOB-005 — Null-check y error persistente

Severidad original: Crítica  
Estado: **Mitigado; validación funcional incompleta**

La pantalla principal dejó de forzar como no nulos `categoryId`,
`subcategoryId` y `description`. Existe una prueba con una fila incompleta.
El registro manual ya funciona en el dispositivo, pero falta confirmar que se
renderiza, edita, elimina y sobrevive a un reinicio completo.

### MOB-004 — Tabs y menús no navegan

Severidad: Alta  
Estado: **Corregido localmente; pendiente de revalidación en Redmi**

La causa era doble: el `TabBar` cambiaba únicamente el indicador porque no
controlaba el contenido, y el `onTap` del menú inferior estaba vacío. Ahora:

- **Diario** conserva el resumen y la lista de transacciones.
- **Calendario**, **Mensual**, **Total** y **Nota** cambian a un destino visible
  que identifica la sección y avisa explícitamente que está “Próximamente”.
- **Estad.**, **Cuentas** y **Más** responden con feedback visible en vez de
  ignorar el toque.
- Se añadió una prueba widget que recorre todos los tabs y opciones inferiores.

Pendiente: instalar el nuevo build y repetir los toques en el Redmi 15C.

### MOB-006 — Conservación del flujo en segundo plano

Severidad: Alta  
Estado: **Pendiente de diagnóstico completo**

La sesión de autenticación ya tolera una salida breve, pero aún no existe una
validación completa de restauración de pantallas, formularios y capturas OCR si
HyperOS termina el proceso.

### UX-001 — Selector de cuentas

Severidad: Media  
Estado: **Implementado en develop; pendiente de validación en Redmi**

El formulario usa cuentas persistidas y existe administración desde
**Más/Cuentas > Configuración**. Falta validar en el dispositivo la migración,
selección predeterminada, creación, edición y archivado.

## Validación local acumulada

Todas estas validaciones corresponden a la misma sesión continua del 28–29 de
julio:

- La APK de depuración compiló correctamente después de mover temporales y
  `PUB_CACHE` a rutas ASCII y usar Java 17.
- La prueba específica de claves foráneas aprobó: 2/2.
- El lote focalizado de bloqueo y claves foráneas aprobó: 7/7.
- El análisis estático focalizado terminó sin incidencias.
- Algunos lotes combinados del runner se quedaron sin emitir progreso y fueron
  interrumpidos; las pruebas focalizadas sí terminaron correctamente.

## Criterio para avanzar a fase 3 de 12

Completar una ronda mínima reproducible en el Redmi:

1. Compartir al menos cinco capturas válidas consecutivas.
2. Confirmar monto, fecha, categoría y persistencia de cada gasto.
3. Repetir con la app abierta, en segundo plano y cerrada.
4. Confirmar que volver antes de cinco minutos no pide otro desbloqueo.
5. Confirmar que después de cinco minutos sí vuelve a bloquear.
6. Medir el tiempo total después de paralelizar persistencia y OCR.
7. Probar una captura inválida y comprobar recuperación sin pantalla negra.
8. Reiniciar la app y verificar que los registros continúan visibles.

Cuando estos puntos estén aprobados, el proyecto puede pasar a **Fase 3/12:
estabilización del flujo principal y ampliación de casos**. Todavía no debe
etiquetarse como alpha.

## Próximo orden de trabajo

1. Revalidar MOB-001, MOB-002, MOB-008 y PERF-001 en el Redmi.
2. Completar MOB-003/MOB-005 con edición, eliminación y reinicio.
3. Diagnosticar MOB-006 con proceso vivo y proceso terminado.
4. Revalidar MOB-004 en el Redmi y continuar mejorando la pantalla principal.
5. Diseñar UX-001 y el modelo durable de cuentas.
