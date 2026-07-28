# Prueba en dispositivo — Redmi 15C

Fecha: 27 de julio de 2026  
Dispositivo: Redmi 15C (gama básica; gestión agresiva de procesos en segundo plano)  
Build: `app-debug.apk`  
SHA-256: `A2EF361E00EBC68D73B3925376BBE634A97D5333B54BC655AA2C56B090364F15`

## Resultado positivo

- La autenticación local funciona con huella y con el PIN del dispositivo.

## Incidencias

### MOB-001 — Reautenticación demasiado frecuente

Severidad: Alta  
Estado: Confirmado en dispositivo

La aplicación solicita huella/PIN repetidamente, incluso pocos segundos después
de un desbloqueo correcto. Debe mantener una sesión desbloqueada durante un
periodo de gracia configurable y volver a bloquear únicamente al superar ese
periodo o cuando exista una condición de seguridad explícita.

Criterios de aceptación:

- Un cambio breve de aplicación no vuelve a solicitar autenticación.
- El tiempo de gracia se mide con reloj monotónico y no se amplía por accidente.
- Tras vencer el tiempo o reiniciar el proceso se solicita autenticación.
- El contenido continúa cubierto en el selector de aplicaciones.

### MOB-002 — Compartir hacia la app vuelve a autenticar y termina en negro

Severidad: Crítica  
Estado: Corrección implementada; pendiente de validación en dispositivo

Pasos observados:

1. Desbloquear El Ahorrador.
2. Aproximadamente cinco segundos después, compartir una imagen hacia la app.
3. La app vuelve a solicitar PIN/huella.
4. Después de autenticar, la pantalla queda negra.

Resultado esperado: reutilizar la sesión todavía válida, procesar el intent
compartido y mostrar progreso o un error recuperable; nunca una pantalla negra.

La interacción entre `singleTask`, el intent compartido, el ciclo de vida,
`AppLockGate` y los overlays permitía retirar la ruta principal durante el
arranque.

Trabajo realizado (28 de julio de 2026):

- `AppLockGate` reutiliza durante 30 segundos la sesión autenticada usando un
  reloj monotónico. El paso breve por el selector de compartir cubre el
  contenido, pero al volver no solicita otra autenticación.
- Los intents iniciales y posteriores permanecen en la cola serial hasta que
  termine el bootstrap y el `Navigator` esté montado tras el desbloqueo.
- El diálogo fallback registra explícitamente si fue abierto. Finalizar un
  share sin overlay ya no ejecuta `Navigator.pop()` sobre la ruta principal,
  causa concreta que podía dejar la actividad con fondo negro.
- Hay regresiones para la transición breve del ciclo de vida y para comprobar
  que cerrar un diálogo inexistente conserva la pantalla principal.

Pendiente:

- Probar el share con la app cerrada, abierta/desbloqueada y abierta/bloqueada,
  incluyendo un error de OCR recuperable.
- Confirmar en HyperOS que `singleTask` entrega el intent inicial y los intents
  posteriores sin duplicarlos.

### MOB-003 — Registro manual exitoso seguido de null-check fatal

Severidad: Crítica  
Estado: Corregido; pendiente de validación en dispositivo

Pasos observados:

1. Registrar manualmente un gasto de S/ 5.
2. La app confirma que el registro fue correcto.
3. En la pantalla inicial aparece `Null check operator used on a null value`.

El error sigue apareciendo después de salir y volver a entrar en la aplicación,
lo que indica que el registro persistido probablemente contiene un campo nulo
que la pantalla de inicio fuerza con `!` durante lectura o presentación.

Resultado esperado: el gasto se guarda y se renderiza sin excepciones. Los datos
legacy o incompletos deben usar valores seguros o mostrar una validación clara.

Criterios de aceptación:

- El gasto de S/ 5 puede abrirse, editarse y eliminarse.
- Reiniciar la app no reproduce la excepción.
- Una fila incompleta no impide renderizar el resto de transacciones.
- Añadir una prueba de regresión con los valores exactos permitidos por el flujo
  manual.

Trabajo realizado (28 de julio de 2026):

- Se confirmó que el flujo manual conserva la categoría seleccionada en
  `vendor`, mientras `categoryId` y `subcategoryId` quedan nulos.
- `HomeScreen` dejó de forzar con `!` las columnas opcionales: usa la categoría
  persistida, luego `vendor` y finalmente valores seguros para datos legacy.
- Se añadió una prueba widget con el formato exacto del gasto manual de S/ 5
  para verificar que la pantalla inicial lo renderiza sin excepciones.

Pendiente de validar:

- Abrir, editar y eliminar el gasto en el Redmi 15C.
- Reiniciar el proceso con el gasto persistido y confirmar que la excepción no
  reaparece.

### MOB-004 — Tabs y menús no navegan

Severidad: Alta  
Estado: Implementado, pendiente de verificación en dispositivo

Los tabs y opciones de menú visibles no cambian de pantalla ni ofrecen feedback.
Debe distinguirse entre controles todavía decorativos/deshabilitados y rutas
que deberían funcionar. Ningún control visualmente habilitado debe ignorar el
toque silenciosamente.

Criterios de aceptación:

- Cada tab habilitado abre su contenido y conserva la selección.
- Las funciones no implementadas se ocultan, aparecen deshabilitadas o muestran
  un mensaje explícito de “próximamente”.
- Se agregan pruebas widget de navegación para cada destino disponible.

Implementación del 28 de julio de 2026:

- La barra inferior conserva el destino seleccionado y muestra una vista
  explícita para Trans., Estadísticas, Cuentas y Más.
- Los destinos y tabs todavía no implementados muestran “Próximamente” en vez
  de ignorar el toque.
- Al volver a Trans., se conserva el tab seleccionado.
- Se añadió `home_screen_navigation_test.dart` para cubrir tabs y destinos de
  la barra inferior.

### MOB-005 — La excepción persiste entre reinicios

Severidad: Crítica  
Estado: Confirmado; probablemente relacionado con MOB-003

Después de cerrar y abrir la app continúa apareciendo
`Null check operator used on a null value`. Tratar inicialmente como consecuencia
del registro persistido de MOB-003, pero verificar también migración SQLCipher,
categoría, subcategoría, cuenta y campos opcionales.

Resultado esperado: la app debe tolerar y reparar o aislar registros inválidos,
sin quedar inutilizable en cada arranque.

### UX-001 — Cuenta debe seleccionarse, no escribirse libremente

Severidad: Media  
Tipo: Mejora funcional/UX

En el formulario, “Cuenta” debe ser un selector basado en cuentas previamente
configuradas, siguiendo el patrón de Money Manager. Las cuentas se crean,
editan, ordenan y archivan desde **Más > Configuración**.

Criterios de aceptación:

- El formulario sólo permite seleccionar una cuenta activa.
- Existe una cuenta predeterminada claramente identificada.
- Configuración permite crear, editar y archivar cuentas sin invalidar gastos
  históricos.
- Los registros existentes se migran a una cuenta predeterminada o conservan
  una referencia válida.

### MOB-006 — No se conserva el flujo en segundo plano

Severidad: Alta  
Estado: Recuperación OCR implementada; pendiente de validación en dispositivo

En el Redmi 15C la app no preserva el estado al pasar a segundo plano. El mismo
dispositivo presenta este comportamiento con otras aplicaciones, por lo que el
sistema puede estar terminando el proceso. Aun así, El Ahorrador debe restaurar
el estado durable y completar o recuperar operaciones interrumpidas.

Criterios de aceptación:

- Si Android conserva el proceso, la app vuelve a la misma pantalla y mantiene
  formularios no confirmados durante un periodo razonable.
- Si Android mata el proceso, las transacciones confirmadas permanecen y la app
  reinicia en una pantalla válida.
- Una captura OCR interrumpida queda marcada como recuperable o fallida, nunca
  bloqueada indefinidamente.
- Probar cierre desde recientes, restricción de batería, proceso terminado y
  reinicio completo del teléfono.

Trabajo realizado (28 de julio de 2026):

- Se confirmó por inspección que, mientras Android conserva el proceso, Flutter
  mantiene la ruta y el estado en memoria del formulario abierto.
- Al iniciar la aplicación, toda captura que haya quedado en `PROCESSING` se
  marca como `FAILED`. El trabajo OCR es una operación en memoria y no puede
  continuar después de que Android termina el proceso.
- Si el procesamiento OCR falla después de persistir la captura, el mismo flujo
  intenta marcarla inmediatamente como `FAILED` antes de retirar el indicador
  de progreso y mostrar el error recuperable.
- Se añadieron pruebas que comprueban que la recuperación sólo cambia capturas
  `PROCESSING`, conserva `PENDING` y `PROCESSED`, y es idempotente en arranques
  posteriores.

Pendiente de validar en el Redmi 15C:

- Confirmar que la misma pantalla y los campos sin confirmar se mantienen al
  enviar la app a segundo plano sin matar el proceso.
- Simular la muerte del proceso y verificar que las transacciones confirmadas
  permanecen y que una captura interrumpida cambia a `FAILED` al reiniciar.
- Ejecutar la matriz de cierre desde recientes, restricción de batería, proceso
  terminado y reinicio completo del teléfono.

## Orden recomendado de corrección

1. MOB-003 y MOB-005: excepción persistente que inutiliza la pantalla principal.
2. MOB-002: pantalla negra en el flujo principal de OCR compartido.
3. MOB-001: sesión de autenticación con periodo de gracia.
4. MOB-004: navegación de tabs y menús.
5. MOB-006: restauración ante ciclo de vida y muerte del proceso.
6. UX-001: modelo y selector de cuentas.

## Evidencia pendiente

- Captura o fotografía de la pantalla con la excepción.
- Versión de Android/HyperOS y cantidad de RAM del dispositivo.
- Confirmar si el gasto de S/ 5 usó categoría, subcategoría, fecha, nota y cuenta.
- Confirmar qué tabs y opciones de menú se tocaron.
- Repetir el share OCR con la app cerrada y con la app ya abierta.
