# Prueba en dispositivo — Redmi 15C

Fecha: 30 de julio de 2026  
Dispositivo: Redmi 15C  
Identificador del dispositivo: `CQRWWGBQSKAIIRUO`  
Ejecución: `flutter run -d CQRWWGBQSKAIIRUO`  
Rama: `develop`  
Commit inicial: `a703a63`  
Tipo de build: debug mediante `flutter run`  
APK versionada/SHA-256: no aplica todavía

## Objetivo de la sesión

Validar en el dispositivo físico las correcciones integradas en `develop` para
los issues registrados el 27 y 29 de julio. Cada resultado debe clasificarse
como **Aprobado**, **Falló**, **Bloqueado** o **Pendiente**. Que una corrección
esté implementada localmente no significa que haya sido aprobada en el Redmi.

Documentos anteriores:

- [`device-test-redmi-15c-2026-07-27.md`](device-test-redmi-15c-2026-07-27.md)
- [`device-test-redmi-15c-2026-07-29.md`](device-test-redmi-15c-2026-07-29.md)

## Estado inicial

| Issue | Prueba de esta sesión | Estado inicial |
| --- | --- | --- |
| MOB-001 | Volver antes y después del periodo de gracia | Falló en develop |
| MOB-002 | Compartir con app cerrada, abierta y bloqueada | Pendiente |
| MOB-003 | Crear, abrir, editar y eliminar un gasto manual | Pendiente |
| MOB-004 | Tocar todos los tabs y destinos inferiores | Aprobado parcialmente en develop |
| MOB-005 | Reiniciar con gastos existentes e incompletos | Pendiente |
| MOB-006 | Interrumpir OCR y comprobar recuperación | Pendiente |
| MOB-007 | Cancelar, rechazar y reintentar autenticación | Aprobado parcialmente |
| MOB-008 | Guardar captura con categoría y subcategoría del parser | Pendiente |
| PERF-001 | Medir persistencia, OCR y tiempo total | Pendiente |
| UX-001 | Crear, seleccionar, editar y archivar cuentas | Pendiente |

## Ronda 1 — Navegación (MOB-004)

Estado: **Aprobado parcialmente en develop**

1. Tocar `Diario`.
2. Tocar `Calendario`.
3. Tocar `Mensual`.
4. Tocar `Total`.
5. Tocar `Nota`.
6. Tocar `Estad.`.
7. Tocar `Cuentas`.
8. Volver y tocar `Más`.
9. Regresar a `Trans.` y confirmar que se conserva la selección esperada.

Resultado observado:

- **Aprobado:** `Calendario`, `Mensual`, `Total` y `Nota` responden al toque y
  muestran explícitamente `Próximamente`.
- **Resultado que identificó el build incorrecto:** `Estad.`, `Cuentas` y `Más`
  mostraron únicamente un mensaje `Próximamente`. En `develop` `a703a63`,
  `Cuentas` y `Más` deben abrir `Configuración · Cuentas`. La conducta observada
  coincide con los cambios locales de `main`.
- Repetir toda la ronda después de iniciar Flutter desde el worktree correcto.
- **Aprobado en la ejecución correcta de `develop`:** la navegación inferior
  responde y `Cuentas` muestra la administración de cuentas.
- Pendiente: repetir los tabs superiores y confirmar el regreso a `Trans.`.

## Ronda 2 — Autenticación y sesión (MOB-001/MOB-007)

Estado: **Falló en develop**

1. Abrir la app y confirmar que la autenticación comienza únicamente al tocar
   `Desbloquear`.
2. Autenticar correctamente.
3. Pasar a segundo plano durante 1–2 minutos y volver.
4. Confirmar que no solicita autenticación nuevamente dentro de cinco minutos.
5. Repetir superando cinco minutos y confirmar que vuelve a bloquearse.
6. Cancelar o rechazar una solicitud y comprobar que el botón permite reintentar.

Resultado observado:

- **Aprobado:** el desbloqueo correcto con huella/PIN permite entrar a la app.
- **Falló (MOB-001):** después de exactamente un minuto en segundo plano, medido
  con cronómetro, la app volvió a solicitar huella/PIN. El periodo configurado
  esperado era de cinco minutos.
- Este resultado se obtuvo en una ejecución que posteriormente se identificó
  como distinta de `develop` `a703a63`; debe repetirse antes de concluir el
  estado de MOB-001.
- Pendiente: regreso dentro y después de cinco minutos, cancelación, rechazo y
  reintento.
- **Revalidación en `develop` (continuación del 31 de julio): falló.** Después
  de permanecer menos de un minuto en segundo plano, la app volvió a solicitar
  desbloqueo. Falta determinar mediante logs si el proceso permaneció vivo o
  si HyperOS lo terminó y provocó un arranque nuevo.

## Ronda 3 — Registro manual y persistencia (MOB-003/MOB-005)

Estado: **Pendiente**

1. Crear un gasto manual de S/ 5.
2. Confirmar que aparece en la pantalla principal sin excepciones.
3. Abrirlo y editar monto, descripción y cuenta.
4. Eliminarlo y confirmar que desaparece.
5. Crear otro gasto, cerrar completamente la app y volver a abrirla.
6. Confirmar que los demás registros siguen visibles aunque exista información
   opcional incompleta.

Resultado observado:

- Pendiente.

## Ronda 4 — Compartir, OCR y claves foráneas (MOB-002/MOB-008)

Estado: **Pendiente**

Ejecutar el flujo en tres estados: app abierta y desbloqueada, abierta y
bloqueada, y cerrada.

Para cada estado:

1. Compartir una captura válida de Yape.
2. Confirmar que aparece progreso y nunca una pantalla negra.
3. Confirmar monto, fecha, categoría, subcategoría y cuenta.
4. Confirmar que el gasto se guarda sin `FOREIGN KEY constraint failed`.
5. Repetir hasta completar cinco capturas válidas consecutivas.
6. Compartir una imagen inválida y comprobar que el error es recuperable.

Resultado observado:

- Pendiente.

## Ronda 5 — Segundo plano y recuperación (MOB-006)

Estado: **Pendiente**

1. Iniciar el procesamiento de una captura.
2. Enviar la app a segundo plano durante OCR.
3. Volver y comprobar que la interfaz queda utilizable.
4. Repetir terminando el proceso desde Android.
5. Abrir nuevamente y confirmar que una captura interrumpida queda marcada como
   fallida o recuperable, nunca indefinidamente en `PROCESSING`.

Resultado observado:

- Pendiente.

## Ronda 6 — Cuentas (UX-001)

Estado: **Pendiente**

1. Abrir `Cuentas` o `Más > Configuración`.
2. Confirmar que existe una cuenta predeterminada.
3. Crear una cuenta.
4. Seleccionarla al registrar un gasto.
5. Editarla y confirmar el cambio.
6. Archivarla sin invalidar el gasto histórico.

Resultado observado:

- Pendiente.

## Ronda 7 — Rendimiento (PERF-001)

Estado: **Pendiente**

Registrar desde la consola de `flutter run`:

| Medición | Resultado |
| --- | ---: |
| Demora hasta mostrar UI | Pendiente |
| Persistencia cifrada | Pendiente |
| OCR | Pendiente |
| Parseo | Pendiente |
| Inserción del gasto | Pendiente |
| Tiempo total | Pendiente |

El tiempo total debe aproximarse a la operación paralela más lenta y no a la
suma directa de persistencia más OCR.

## Incidencias nuevas de esta sesión

Registrar cada hallazgo con pasos exactos, resultado esperado, resultado
observado, frecuencia y líneas relevantes de `flutter run`. No incluir datos
financieros reales, capturas, texto OCR completo ni información sensible.

### NEW-001 — Build nativo falla por ruta Unicode del caché de Pub

Estado: **Causa identificada; configuración de sesión corregida**

El build de `jni 0.14.2` intentó usar
`C:\Users\Moisés Cedeño\AppData\Local\Pub\Cache`; Ninja recibió la ruta
corrompida como `Mois�s Cede�o` y no pudo entrar al directorio `.cxx`.

Se regeneraron las dependencias con `PUB_CACHE=Z:\tmp\pub-cache`. El
`package_config.json` del worktree ahora resuelve `jni-0.14.2` desde una ruta
ASCII. La misma variable debe permanecer configurada en la terminal que ejecuta
`flutter run`.

## Criterio para generar una APK de prueba identificable

- Corregir los fallos bloqueantes o críticos encontrados en esta sesión.
- Ejecutar análisis estático y las pruebas focalizadas.
- Confirmar que `develop` contiene únicamente cambios intencionales.
- Crear un commit de cierre de sesión.
- Generar `app-debug.apk` desde ese commit de `develop`.
- Registrar nombre, fecha, commit y SHA-256 del APK.

## Resultado de la sesión

Estado general: **En ejecución**

Resumen:

- Pendiente de completar las rondas en el Redmi 15C.
