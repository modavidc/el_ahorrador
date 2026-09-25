# Handoff: Money Manager IA — tema unificado + pantallas v2

## Qué es esto
Referencia de diseño para implementar en el repo real. `Money Manager IA v2.dc.html` es un **prototipo HTML** (se abre en el navegador): muestra el look y el comportamiento, **no es código para copiar**. Hay que recrearlo en el stack del repo usando sus patrones existentes.

Fidelidad: **alta** (colores, tipografía, iconos, espaciados y copy finales).

## Archivos
- `tokens.json`: fuente de verdad del tema (colores, tipografía, espaciado, radios, sombras, iconos, categorías, specs de componentes).
- `Money Manager IA v2.dc.html` + `support.js`: prototipo navegable (abrir en Chrome).
- `PROMPT_CLAUDE_CODE.md`: prompts listos para pegar, por fases.

## Reglas globales
- Ningún hex, fontSize, padding o radio literal en pantallas: todo sale del tema.
- Iconos: **Material Symbols Rounded**. Cero emojis en UI y en textos del Coach.
- Moneda `S/. 1,234.56`, montos con `tabular-nums`, alineados a la derecha.
- Colores semánticos: ingreso #2F80ED, gasto #F0523C, transferencia #8A8A8A.
- Semana empieza en domingo; fechas en formato `dd.mm`.

## Navegación (bottom nav, 5 items, alto 58)
Trans. (`receipt_long`) · Estad. (`bar_chart`) · **Coach** (`auto_awesome`) · Cuentas (`account_balance_wallet`) · **Ajustes** (`settings`). Activo #F0523C, inactivo #8A8A8A, label 11/500.
FAB 56px #F0523C (visible en Trans. y Estad.) → menú: Añadir manual · Escanear recibo · Preguntar al Coach.

## Pantallas

### 1. Trans.
Header: `‹ Sep 2026 ›` (20/700) + iconos star/search/tune. Pestañas (4 columnas iguales, 14px, activa 600 + subrayado 3px primario): **Diario · Calendario · Mensual · Total**. Barra resumen Ingresos / Gastos / Total (label 12 tertiary, valor 14/600).
- **Diario**: una card por día (radius 16). Header del día: número 20/700, chip día de semana (Dom rojo, Sáb azul, resto gris), `mm.yyyy`, ingreso y gasto del día. Filas compactas ~64px: tile de icono 36px (radius 10, colores de categoría), título 14/500 + monto 14/600, meta 12px `Categoría · Sub · Cuenta · Hora`, chips 20px: `Yape` (morado) y `OCR 92%` (verde).
- **Calendario**: grid 7 columnas, celdas de 64px con día + ingreso (azul) / gasto (rojo) / neto (gris) a 11px; ≥1000 sin decimales. Hoy = número con fondo #3A3A3A; seleccionado = borde interior de 2px primario. Debajo, lista de movimientos del día seleccionado.
- **Mensual**: el header cambia a año. Una fila por mes (desc) con ingreso/gasto/neto; tocar despliega las semanas (dom–sáb, recortadas al mes) sobre fondo #F7F7F8.
- **Total**: card Presupuesto (barra total + top 5 categorías ordenadas por % usado; verde en ritmo, naranja si % usado > % del mes + 5, rojo si >100%). Card Cuentas: gastos vs mes anterior %, gastos efectivo/cuentas, gastos tarjeta, transferencias. Botón "Exportar a Excel".

### 2. Estadísticas
Mes + selector "Mensual". Pestañas Ingresos / Gastos con total. Dona (r 66, grosor 30, gaps 1.5) con el total al centro. Lista: badge % con color de categoría, icono, nombre, monto, chevron.
**Detalle de categoría** (al tocar): back + icono + nombre + navegación de mes; total 28/700; filas por subcategoría (Todas / … con %); gráfico de línea de 6 meses (el punto del mes actual relleno); lista de movimientos (día + día de semana a la izquierda).

### 3. Coach (IA)
No repite estadísticas: da **insights accionables** calculados sobre los datos, en cards con kicker de color, título 16/600, cuerpo 13px, botón primario pill + secundario:
1. Ritmo del mes: proyección de cierre vs mes anterior + presupuesto restante por día (o "Ya superaste tu presupuesto por X").
2. Hábito detectado: frecuencia de delivery vs mes anterior + ahorro estimado.
3. Suscripciones: total mensual + solapamientos.
4. Gasto inusual: transacción ≥3x el promedio de la categoría.
Abajo: chips con preguntas de decisión ("¿Puedo gastar S/. 300 este finde?", "¿Qué suscripciones me sobran?", "Plan para ahorrar S/. 500", "¿Por qué gasto más que en agosto?") + input. En producción las respuestas vienen del LLM, con los agregados del mes como contexto.

### 4. Cuentas
Resumen Activos / Pasivos / Total. Cards por grupo: Efectivo, Cuentas bancarias, Tarjetas de crédito (muestra "Por pagar" + línea), Ahorros. Los saldos se **calculan** con saldo inicial + movimientos (las transferencias mueven dinero entre cuentas). Negativos en rojo.

### 5. Ajustes
Grupos: Coach e IA (toggles: auto-categorizar, guardar OCR sin revisar, resumen semanal; Modelo), General (moneda, inicio de mes, inicio de semana, categorías, presupuestos), Datos (exportar Excel, importar desde Money Manager, backup), Seguridad (huella, tema). Filas de 52px, toggles 40×24 primario.

### 6. Añadir / Escanear
- Añadir: header primario, pestañas Ingreso/Gasto/Transf., caja de "lenguaje natural" que rellena el formulario (monto, categoría, cuenta, Yape), campos de 52px, botón Guardar de 48px.
- Escanear: vista de cámara oscura con marco, estado escaneando (línea animada) y resultado con comercio/monto/cuenta/categoría + confianza → Añadir.

## Modelo de datos (mínimo)
`Transaction { id, date, type: income|expense|transfer, category, subcategory, note, account, toAccount?, amount, time, method?: 'Yape', ocrConfidence? }`
`Account { name, group: cash|bank|card|savings, startBalance, limit? }`
`Budget { category, monthlyCap }`
