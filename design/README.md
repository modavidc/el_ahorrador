# Handoff: El Ahorrador v3 — app de finanzas personales con captura de pagos

## Overview
El Ahorrador es una app Android de finanzas personales para Perú (soles, Yape, Plin, BCP, BBVA). Su función principal es **registrar gastos sin escribir**: el usuario comparte el comprobante de Yape o de su banco (una o varias imágenes), o la app detecta pagos en segundo plano. Además tiene registro manual, escaneo de boletas, dictado por voz, estadísticas, presupuestos, cuentas y un Coach con IA.

Objetivo inmediato: **prueba cerrada en Google Play con 14 testers**. Auditoría UI/UX actual: 85/100 (ver `Auditoria El Ahorrador v3.dc.html`).

## About the Design Files
Los archivos de este paquete son **referencias de diseño hechas en HTML**: prototipos que muestran el aspecto y el comportamiento esperados. **No son código de producción para copiar.** La tarea es **recrear estos diseños en el entorno real de la app** (el stack Android que ya exista en el repo, o Kotlin + Jetpack Compose si se parte de cero) con sus patrones y librerías.

- Abre `Tema El Ahorrador v3.dc.html` en Chrome (necesita `support.js` al lado). Es un prototipo navegable dentro de un marco de teléfono de 390×844.
- En el panel Tweaks: `inicio` (Onboarding / Movimientos) y `ancho` (390 / 360).
- Los datos son **de ejemplo**. En la versión para testers la app debe **arrancar vacía** y mostrar los estados vacíos.

## Fidelity
**High-fidelity.** Colores, tipografía, espaciado, radios, estados e interacciones son finales. Recrear lo más fiel posible.

## Design Tokens
**Colores**
| Token | Hex | Uso |
|---|---|---|
| paper (fondo) | `#FAF6F1` | Fondo de todas las pantallas y hojas |
| card | `#FFFFFF` | Tarjetas |
| ink | `#1C1917` | Texto principal, botones finales, chip activo, bloque de Captura |
| ink-2 | `#6E6660` | Texto secundario (mínimo permitido: contraste AA) |
| brand red | `#D33F2B` | Botón +, CTA principales, alertas, tabs activos (fondo `#FBEAE5`) |
| red deep | `#A82E1E` | Texto rojo sobre fondo rosado |
| blush | `#FBEAE5` | Fondo de iconos/pastillas rojas |
| beige chip | `#F1EAE2` | Chip no seleccionado, botones secundarios, segmentos |
| beige tile | `#F5EFE8` | Tiles de iconos neutros |
| line | `#EDE6DE` / `#F1EAE2` | Bordes y separadores internos |
| border input | `#E3D9CF` | Bordes de inputs, track de toggle apagado |
| success | `#1E7D47` (fondo `#E6F3EA`) | Ingresos, OK, lectura OCR |
| warning | `#A15F00`–`#C77A12` (fondo `#FDF1DC`) | Falta dato, permisos pendientes |

Colores de categoría (icono sobre el mismo color al 12% de opacidad): Comida `#F59E0B`, Mercado `#22C55E`, Transporte `#8B5CF6`, Casa `#3B82F6`, Servicios `#EAB308`, Salud `#EC4899`, Ocio `#06B6D4`, Compras `#EF4444`, Sueldo `#10B981`, Extra `#14B8A6`, Otros `#94A3B8`.

**Tipografía:** una sola familia, **Schibsted Grotesk** (Google Fonts), sin serif ni cursiva.
- Título de pestaña: 28px/800, letter-spacing −0.03em
- Cifra grande (Puedes gastar hoy): 30px/800; montos de hoja 40–52px/800
- Número de día en lista: 22px/800
- Cuerpo y filas: 15px/600
- Secundario: 12–14px/400–600, color ink-2
- Etiqueta de sección: 13px/700 en MAYÚSCULAS, letter-spacing 0.02em, ink-2
- Navegación: 12px/700 (11px en 360dp). Mínimo absoluto: 11px.

**Radios:** tarjeta 22px · tarjeta grande 26–30px · hoja inferior 32px arriba · botón 14–18px · tile de icono 12–14px · chip 999px.
**Sombras:** tarjeta `0 1px 2px rgba(60,30,10,.06)` · botón + `0 10px 24px rgba(211,63,43,.4)` · menú `0 14px 40px rgba(28,25,23,.25)`.
**Espaciado:** padding lateral 18px · entre tarjetas 10–12px · antes de título de sección 22px, después 8px · filas de lista 60–64px de alto.
**Táctil:** chips mínimo 40px de alto; botones 44–56px; filas 60px.
**Iconos:** Material Symbols Rounded, peso 400; relleno (FILL 1) solo en el ícono activo de la navegación y en la llama de racha.

## Navegación
Barra inferior de 5 pestañas (86px, fondo paper, borde superior line): **Movimientos · Estadísticas · Coach · Cuentas · Ajustes**. Activa = pastilla 56×30 `#FBEAE5` + icono relleno + texto ink.
**Botón +** flotante (62×62, radio 22, rojo) en Movimientos, Estadísticas, Cuentas, Presupuestos y detalle de categoría. Abre un menú con 2 grupos:
- REGISTRAR: Manual · Escanear boleta · Dictar
- CAPTURA: Compartir 1 imagen · Compartir 7 imágenes · Captura en segundo plano

## Screens / Views

### 1. Onboarding (3 pasos, overlay a pantalla completa)
Barra de progreso de 3 segmentos arriba (4px, rojo / `#E3D9CF`).
1. **Bienvenida**: logo 64px rojo, "Tu plata, en orden." (40px/800), texto de apoyo.
2. **Presupuesto**: "¿Cuánto quieres gastar al mes?", input grande S/ con subrayado y chips 1,800 / 2,400 / 3,000. **El valor se guarda como presupuesto real.**
3. **Registra sin escribir**: **video animado en bucle de unos 12 s** (`share-demo-ahorrador.js`, componente `ShareDemoAhorrador`) con el flujo completo: pagar con Yape → Compartir → elegir El Ahorrador → lectura → aparece en Movimientos con "Registrado · Deshacer". Tiene pausa y barra de progreso por tramos. En producción: exportar como video/Lottie o recrearlo con animaciones nativas.
CTA rojo 56px "Continuar" / "Activar captura y empezar"; secundario "Saltar" / "Ahora no".

### 2. Movimientos
- Cabecera: "Setiembre" (28px/800) + chip de racha (llama roja + número, abre hoja de Racha) + lupa.
- Búsqueda (al tocar la lupa): input + chips de filtro Todo / Gastos / Ingresos / Captura.
- Segmento Diario / Calendario / Mensual.
- **Resumen compacto** (tarjeta blanca): "Puedes gastar hoy" + cifra 30px; a la derecha "Quedan S/ X" y "N días · N% usado"; barra de 6px (gasto en rojo, marca negra de hoy); línea con Ingresos (verde) y Gastos.
  - Cálculo: `(presupuesto − gastado) / días restantes del mes (incluye hoy)`.
- **Carrusel de AVISOS** (scroll horizontal con snap, contador "AVISOS · N" y puntos). Tarjetas de 76px, cada una con icono, texto, CTA y × para descartar. Orden de prioridad:
  1. Si nunca compartió: **"Prueba la función principal"** (tarjeta oscura ink, CTA rojo "Probar").
  2. Si hay pendientes: "N pagos necesitan un dato" → Revisar.
  3. Si faltan permisos obligatorios: "Activa N permisos" → Activar.
  4. Si es de noche y no registró nada hoy: "Aún no registras nada hoy · tu racha de N días está en juego" → Registrar.
- Diario: grupos por día (número 22px/800 + "Hoy/Ayer/Viernes 25" + neto). Filas en tarjeta blanca: tile de icono 40px, nota, meta "Categoría · Cuenta" + etiqueta de origen (Compartido / Captura / Boleta / Voz), monto (ingreso verde con +, gasto ink con −, transferencia ink sin signo). Los movimientos nuevos llevan la pastilla verde "Registrado · Deshacer". Muestra 6 días y luego el botón "Ver días anteriores".
- Calendario: grilla de 7 columnas; celda con día, ingreso (11px verde) y gasto (11px); hoy en beige, seleccionado en rosado. Debajo, los movimientos del día elegido.
- Mensual: tarjetas por mes con neto, ingresos, gastos y barra frente al presupuesto (el mes actual lleva borde rojo).

### 3. Hoja de registro manual
Segmento Gasto / Ingreso / Transferencia → monto grande → chips de frecuentes ("Menú · S/ 15") → grilla de categorías 4×2 (activa en negro) → **fila resumen plegable** ("Yape · Hoy · Sin nota") que abre cuenta, Hoy/Ayer y nota → teclado numérico propio (máx. 2 decimales; la tecla se hunde al tocar y vibra 8 ms) → **Guardar fijo abajo** ("Guardar S/ X"; gris si el monto es 0). En transferencia se muestran Desde/Hacia en lugar de categoría. Al guardar se ajustan los saldos de las cuentas y aparece un toast con Deshacer. Alto máximo de la hoja: 85%.

### 4. Detalle de movimiento (hoja)
Meta, nota, monto 44px, origen, chips para cambiar la categoría; botones Eliminar (con Deshacer), Repetir y Listo.

### 5. Escanear boleta (pantalla completa oscura)
Cámara con marco blanco → foto → línea roja de lectura → resultado (Plaza Vea S/ 99.50, lectura 94%) con **chips de categoría y cuenta editables** → Editar / Guardar.

### 6. Dictar (hoja)
Micrófono con pulso → transcripción → chips (monto, **categoría y cuenta editables**, Hoy) → Editar / Guardar.

### 7. Captura (flujos de sistema + hoja propia)
- **Compartir 1 imagen**: comprobante de Yape → hoja de compartir de Android → El Ahorrador → hoja "Leyendo comprobante…" → "Registrado" con nota, cuenta, categoría, % de lectura y la regla aplicada. Botones Deshacer / Listo.
- **Compartir 7 imágenes**: galería → compartir → progreso "Leyendo N de 7" (las filas aparecen una tras otra) → resumen "4 registrados · 1 duplicado · 2 con error". El error tiene "Reintentar", el duplicado "Ver original" y el de monto ilegible pasa a Por revisar.
- **Captura en segundo plano**: si faltan permisos, hoja "Faltan permisos" → Ir a permisos. Si están, destello de captura de pantalla → aviso flotante "Detectamos un pago" con **chip de categoría editable** y botones Guardar / Revisar.
- **Notificación fija** (panel de notificaciones): "Captura de pagos · Captura activa · N por revisar", con acciones Capturar pantalla / Pausar.

### 8. Por revisar
Tarjetas con icono, nota, origen, cuenta y monto. Pastilla ámbar con lo que falta. Chips de categoría o input de monto dentro de la tarjeta. Botones Descartar / **Aprobar** (deshabilitado muestra "Falta el monto" o "Falta la categoría"). También "Aprobar todo".

### 9. Estadísticas
Segmento Gastos / Ingresos · chips Semana / Mes · botón "Presupuestos". **Una tarjeta** con total, **pestañas Barras | Dona**, barras por día/semana (la última en rojo) o dona con las 5 categorías principales. Debajo "EN QUÉ SE FUE": filas por categoría con barra y chevron que llevan al detalle.
- **Detalle por categoría**: total, chip "vs agosto: ±N%", tope con barra y la lista de movimientos.
- **Presupuestos**: tarjeta oscura con gastado / presupuesto, marca de hoy, ritmo diario y botones −/+ S/ 100; toggles "Usar presupuesto mensual" y "Repetir cada mes"; "TOPES POR CATEGORÍA" con −/+ S/ 20 por categoría.

### 10. Coach
Título + historial + nueva conversación. Sin chat: "Lo que veo en setiembre" con 3 observaciones. Chat con burbujas (usuario ink, IA blanca), estado "Pensando…", 6 chips de sugerencia e input fijo con botón rojo. **Las respuestas se calculan con los datos reales** (saldo, días, categorías, suscripciones, comparación con el mes anterior, "¿cuánto gasté en X?"). En producción: llamada a un LLM con el contexto financiero del usuario.
- **Conversaciones**: buscador + grupos (Esta semana / Agosto). Estado vacío con "Hacer una pregunta".

### 11. Cuentas
Patrimonio neto (44px), Activos / Deudas, grupos Efectivo / Bancos / Billeteras / Tarjetas. Al tocar una cuenta: hoja para **editar nombre y saldo, Ocultar y Eliminar**. Las ocultas no suman y se muestran con "N cuentas ocultas · Mostrar". Hoja "Nueva cuenta" con sugerencias (Interbank, Scotiabank, Plin, Caja Arequipa), grupo y saldo inicial. Estado vacío con "Agregar cuenta".

### 12. Ajustes
Perfil → bloque oscuro de CAPTURA (interruptor, barra de permisos "N de 5 listos") → fila "Funciones de captura" que abre una página con las 7 funciones → grupos:
- HÁBITO: Recordatorios y recaps, Mi racha
- FINANZAS: Categorías, Presupuestos, Cuentas y grupos
- COACH E IA: Personalizar Coach, Categorizar automáticamente
- APP: Seguridad, Exportar a Excel, Ver bienvenida
- SOPORTE: Enviar comentarios, Acerca de

Subpáginas:
- **Recordatorios**: diario + hora, recaps, avisos, y "Probar recordatorio" que muestra el aviso de racha.
- **Personalizar Coach**: tono, objetivos, frecuencia, memoria.
- **Seguridad**: bloqueo y método.
- **Categorías**: cada fila abre su detalle.

**Permisos HyperOS** (5):
- Obligatorios: Inicio automático, Acceso a notificaciones, Batería sin restricciones, Mostrar sobre otras apps.
- Opcional: Bloquear en recientes.

**Reglas de captura**: "Si llega de {origen} con {texto}" + interruptor + chips de Tipo, Cuenta y Categoría (Automática IA).

## Interactions & Behavior
- Transiciones: hojas `translateY(100%)→0` en 280ms `cubic-bezier(.2,0,0,1)`; fade de 150–200ms; entrada de tarjetas rise de 8px en 300ms; aviso flotante drop en 300ms.
- Esqueleto de carga de 380ms (pulso de opacidad .5↔1) al entrar a Movimientos y Estadísticas.
- Toast inferior (ink, radio 16) con "Deshacer" en toda alta y baja; dura 3.5 s.
- Anillo de foco de 2px ink en todo elemento interactivo.
- Estados vacíos: Por revisar, búsqueda, día sin movimientos, Coach sin historial, Cuentas vacías y Estadísticas sin datos.

## State Management (mínimo)
- `transactions[]` {id, day, note, amount, category, account, type (expense|income|transfer), source (Compartido|Captura|Boleta|Voz|manual)}
- `accounts[]` {name, group, balance, hidden}
- `budget` (total) y `categoryBudgets{}`
- `inbox[]` {id, note, amount?, category?, account, source, missingReason}
- `permissions{autostart, notif, battery, overlay, recents}` y `captureOn`
- `rules[]` {match, from, type, account, category, enabled}
- `chat[]`, `coachPrefs`, `prefs` (recordatorios, seguridad), `usedShare`, `dismissedTips[]`

## Implementación Android (sugerida)
- **Compartir**: intent-filter `ACTION_SEND` / `ACTION_SEND_MULTIPLE` con `image/*`.
- **OCR**: ML Kit Text Recognition en el dispositivo. Parsear "¡Yapeaste!", monto, destinatario, fecha y número de operación.
- **Duplicados**: hash de la imagen + (monto, fecha, operación).
- **Segundo plano**: `NotificationListenerService` para avisos de Yape, Plin y bancos; `ContentObserver` sobre MediaStore para detectar capturas de pantalla.
- **Notificación y aviso flotante**: foreground service con la notificación fija; `SYSTEM_ALERT_WINDOW` para el aviso flotante.
- **HyperOS/MIUI**: intents a la pantalla de autoinicio y ahorro de batería del Centro de seguridad; verificar cada permiso al volver a la app.
- **Recordatorios**: WorkManager para el aviso diario y los recaps.

## Assets
- Fuentes: Schibsted Grotesk y Material Symbols Rounded (Google Fonts).
- Sin imágenes. El comprobante de Yape y las pantallas de sistema son recreaciones genéricas solo para el prototipo.

## Files
- `Tema El Ahorrador v3.dc.html`: prototipo principal (todas las pantallas).
- `capture-core.js`: lógica compartida de captura (flujos, lote, permisos, reglas, bandeja) y datos de ejemplo.
- `Android Share.dc.html`: pantallas de sistema simuladas (Yape, galería, hoja de compartir, panel de notificaciones, aviso flotante).
- `share-demo-ahorrador.js`: video animado del onboarding.
- `Auditoria El Ahorrador v3.dc.html`: auditoría UI/UX de 47 categorías con los pendientes para llegar a 90.
- `support.js`: runtime necesario para abrir los `.dc.html` en el navegador.

## Pendiente conocido (para después de la prueba)
- Probar en un dispositivo de 360dp.
- Pesos tipográficos: 600 para texto, 800 solo para cifras y títulos.
- Bajar la saturación de los colores de categoría que no son rojos.
- Reordenar cuentas arrastrando.
- Modo oscuro (retirado del prototipo; no incluirlo en la prueba).
