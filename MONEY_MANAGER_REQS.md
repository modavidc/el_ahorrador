# Prompt para v0 — El Ahorrador (Frontend Flutter)

## 0) Alcance y objetivos

Quiero que construyas la **UI en Flutter** de una app tipo **Money Manager** (gestor de finanzas personales) lo más fiel posible a las capturas adjuntas (colores, tamaños, densidad, iconografía y jerarquía visual). Implementa navegación, estados de carga y componentes; usa **datos mock** persistidos localmente para poder navegar los flujos sin backend.

### Información de la App
- **Nombre:** El Ahorrador
- **Package (Android):** com.modavidc.elahorrador
- **Bundle ID (iOS):** com.modavidc.elahorrador
- **App label (Android/iOS):** El Ahorrador

### Branding y Estilos
- Mantén colores/estilos idénticos a las capturas (azul para ingresos, coral para gastos) para asegurar la fidelidad visual
- Icono y splash pueden decir El Ahorrador (si no defines branding propio ahora, usa versión genérica con "A")

### Detalles del Proyecto
* **Alcance:** Frontend Flutter (Android/iOS). Navegación completa, estados vacíos, búsqueda/filtros, formularios, charts y widgets. Persistencia local *mock* (Hive o Sqflite) para probar filtros y listas.
* **Objetivo:** Replicar la experiencia visual y de interacción de Money Manager:

  * Tabs inferiores: **Transactions**, **Stats**, **Accounts**, **Settings**.
  * Listas agrupadas por fecha, **filtros avanzados**, **gráficas** (donut/line), **presupuestos** (progress bars), **detalle/edición de transacción** con **fotos adjuntas**, **transferencias**, **recurrentes**, **bookmarks**.
  * **Modo claro/oscuro**, localización en **EN/ES**, formatos de **moneda** y **fecha**.

---

## 1) Requerimientos funcionales

### 1.1 Navegación & Shell

1. Barra de pestañas inferior con 4 ítems: **Transactions**, **Stats**, **Accounts**, **Settings**.
2. AppBar por pantalla con: título contextual, back, acciones (Search, Filter, Edit, Add).
3. Transiciones fluidas tipo Cupertino/M3. Deep-link mínimos: `app://transaction/:id`, `app://filter`, `app://accounts`.

### 1.2 Transactions (Lista principal)

4. Segmentos de periodo: **Daily / Calendar / Weekly / Monthly / Summary** (tabs horizontales bajo el AppBar).
5. **Header de totales** del periodo (tres columnas): **Income (azul)**, **Expenses (coral)**, **Total** (negro).
6. **Agrupación por fecha** (bloques con día grande “29”, sub-label “2020/07 Wed”).
7. **Celdas de transacción**:

   * Izquierda: *Category path* (ej. “Social Life / Friend”), **Título** (ej. “brunch with daniel”), **Cuenta** (ej. “RBO Debit Card”) en gris.
   * Derecha: monto **positivo en azul** (Ingresos) o **negativo en coral** (Gastos).
   * Para **Transfer**: chip gris con origen→destino (ej. “HIBD → HIBD Travel”) y monto en gris.
8. **FAB** circular rojo con ícono “+” (crear transacción).
9. Acciones en AppBar: **Search**, **Filter** (lista + modal).
10. Estados: **loading skeleton**, **empty state** (“No transactions”), **error state** con retry.

### 1.3 Filter (modal superior tipo sheet)

11. **Cabecera** con mes navegable (◀ Jul 2020 ▶), botón **Filter (primary)**.
12. Dos **donut charts**: **Income** (azul, % y valor) y **Expenses** (coral, % y valor).
13. **Tabs internas**: Income | Expenses | **Account**.
14. **Account tab**: checklist jerárquico con grupos: *Cash, Accounts, Card, Debit Card, Savings*.

    * Cada cuenta muestra columnas: **Income**, **Transfer in**, **Expenses**, **Transfer out** (cifras en azul/coral/gris).
15. Botones **Select All / Clear**; persistencia temporal del filtro hasta cerrar sesión de la app.

### 1.4 Accounts (Dashboard & Detalle)

16. **Accounts dashboard**: tres totales en el header: **Account**, **Liabilities**, **Total**.
17. Listado agrupado: *Cash*, *Accounts*, *Card*, *Debit Card*, *Savings*.

    * Por ítem: nombre, balance en azul, subtítulos como **Balance Payable / Outstanding** en rojo/gris cuando aplique.
18. **Detalle de account**:

    * **Line chart** de evolución del saldo mensual (punto activo con valor).
    * Lista de **Expenses por categoría** (badge de % y monto) + **Transfer in/out**.
    * Selector de mes.

### 1.5 Stats (Gráficas y Presupuesto)

19. **Stats tab**:

    * Sub-tabs: **Stats | Budget | Note** (implementa Stats y Budget; Note puede ser placeholder).
    * **Stats**: **Pie chart** de gastos del mes con leyenda (porcentaje y monto) y lista por categoría.
20. **Budget**:

    * Header con **Income** y **Expenses** del mes; **Remaining(Monthly)** grande.
    * **Progress bars** por categoría con meta, gasto y % (rojo si >100%, azul si <100%).
    * Etiqueta “Today” sobre el eje de progreso mensual.

### 1.6 Crear / Editar Transacción

21. Pantalla con tabs **Income | Expense | Transfer** (resalta tab activa).
22. Campos: **Date/Time picker**, **Account** (dropdown), **Category** (picker), **Amount** (numérico con máscara), **Note** (texto).
23. **Repeat** (ícono circular) para marcar como recurrente (solo estado visual; lógica mock).
24. **Description** (multilínea) + **Adjuntos** (grid de fotos, botón cámara/galería, ícono eliminar por foto).
25. Footer con acciones: **Delete**, **Copy**, **Bookmark** (estados con feedback).
26. Validaciones: campos obligatorios por tipo; en **Transfer** se requieren **cuenta origen** y **destino** y **monto**.

### 1.7 Búsqueda, Bookmarks, Pegar & SMS Save

27. **Search**: por texto libre en título/nota/categoría/cuenta, con historial reciente.
28. **Bookmarks**: lista rápida de transacciones marcadas; acción “Bookmark” on/off en detalle.
29. **Paste**: botón rápido para pegar texto y crear borrador (mock).
30. **SMS Save / Share intent**: botón de acceso rápido que abre un sheet explicando “importar desde SMS” (placeholder en esta versión, sin parsing real).

### 1.8 Calendario

31. **Calendar view** mensual con puntos por días con movimientos; al tocar un día, abre la lista filtrada del día.

### 1.9 Temas, Idiomas y Formatos

32. **Light/Dark** siguiendo sistema.
33. **Localización EN/ES**, **símbolo de moneda** configurable (por ahora fijo USD en mock + Intl).
34. Formatos de fecha tipo `YYYY/MM/DD (EEE)` como en las capturas (configurable por locale).

### 1.10 Accesos rápidos (Widget/Shortcut)

35. En home (pantalla de sistema) mostrar **Quick Actions** equivalentes a: **Search**, **Bookmark**, **Entry**, **Paste**, **SMS Save** (usar `quick_actions` para app shortcuts).

---

## 2) Requerimientos no funcionales

### 2.1 Rendimiento

* 60 fps en scroll de listas y charts; **jank < 1%** en perfiles de rendimiento.
* **Cold start < 2.5 s** en dispositivos medios (Android 10, 3GB RAM).
* Listas virtualizadas (Lazy) y **images cacheadas** (thumbnails).

### 2.2 Calidad/UX

* **Tamaños y pesos** tipográficos y **espaciados** que repliquen densidad de las capturas.
* **Estados**: loading, vacío, error, sin conexión (aunque sea mock).
* **Gestos**: pull-to-refresh en lista; swipe suave (sin acciones destructivas por ahora).
* **Haptics** en acciones clave (guardar, borrar, bookmark).

### 2.3 Accesibilidad

* **WCAG AA**: contraste mínimo 4.5:1.
* Soporte **Dynamic Type** (font scaling 80–120%).
* **Semantics** para lectores de pantalla y labels en íconos.

### 2.4 Arquitectura & Mantenibilidad

* Flutter **>=3.22**; null-safety.
* Estado con **Riverpod** (o Bloc, pero elige uno y sé consistente).
* **Rutas con `go_router`**.
* Modelos con **freezed + json_serializable** (aunque sea mock).
* **Theming centralizado** con **tokens** (ver abajo).

### 2.5 Portabilidad & Responsividad

* Soporte **Android 7+** y **iOS 13+**.
* Breakpoints: **phone portrait** prioridad; ajustar para **tablet** (list/detail side-by-side opcional si hay tiempo).

### 2.6 Seguridad (mínimo frontend)

* No almacenar fotos en ubicaciones públicas sin permiso.
* Permisos de cámara/galería declarados y justificados.

---

## 3) Tokens de diseño (aprox. según capturas)

> Aplica estos tokens y ajústalos suavemente si el contraste lo requiere. No cambiar la “sensación” de la UI.

**Colores principales**

* **Azul (Ingresos):** `#2F80ED` (enlaces/valores positivos)
* **Coral (Gastos):** `#FF6B6B` ~ `#F66D6D` (valores negativos, barras >100%)
* **Texto principal:** `#111111`
* **Texto secundario/gris:** `#6B7280`
* **Dividers / lines:** `#E5E7EB`
* **Fondo app claro:** `#FFFFFF`
* **Fondo fila alterna:** `#FAFAFA`
* **FAB rojo:** `#FF4D4F`
* **Success (budget ok):** `#2F80ED` (mismo azul)
* **Warning (chips/labels):** gris `#9CA3AF`

**Tipografía** (Material 3 por defecto o Inter/Roboto)

* Título AppBar: 18–20 semibold
* Totales header: 16–18 bold; subtítulos 12–13
* Filas: Título 15–16 medium; sublíneas 12–13; montos 15–16 bold

**Espaciado**

* Padding horizontal de listas: 16
* Espacio entre elementos de celda: 4–6
* Radio tarjetas/sheets: 12–16

**Iconografía**

* Preferir **Cupertino**/Material Outlined para búsqueda, filtros, engranaje, más, calendario, gráfico.

---

## 4) Paquetes Flutter sugeridos

* **go_router** (navegación)
* **flutter_riverpod** (estado)
* **intl** (moneda/fecha)
* **hive** o **sqflite** (mock/persistencia local)
* **image_picker** + **photo_view** (adjuntos)
* **fl_chart** (pie/line charts)
* **quick_actions** (shortcuts)
* **cached_network_image** (si se usan urls; para mocks usar `Image.memory`/asset)
* **freezed** + **json_serializable** (modelos)

---

## 5) Criterios de aceptación (por módulos)

**Transactions**

* CA-T1: Cambiar entre **Daily/Calendar/Weekly/Monthly/Summary** actualiza los totales y la lista.
* CA-T2: Filtrar por **cuentas** actualiza lista y header; persistencia hasta cerrar app.
* CA-T3: FAB abre **crear transacción**; al guardar vuelve a la lista con *snackbar* “Saved”.

**Filter**

* CA-F1: Los **donut charts** reflejan proporciones de datos mock.
* CA-F2: “Select All / Clear” afectan checklist completo.

**Accounts (dashboard)**

* CA-A1: Totales de **Account/Liabilities/Total** se calculan a partir de datos mock.
* CA-A2: Tocar una cuenta abre su **detalle** con **line chart** y **breakdown**.

**Stats**

* CA-S1: **Pie chart** muestra mínimo 6 categorías con % y color.
* CA-S2: **Budget** pinta en **rojo** cuando >100% y **azul** cuando ≤100%.

**Create/Edit**

* CA-C1: Tab activa (Income/Expense/Transfer) cambia los campos visibles.
* CA-C2: En **Transfer**, es obligatorio origen, destino y monto; error si falta alguno.
* CA-C3: Adjuntar y eliminar fotos funciona (mock, guardadas localmente).

**Search/Bookmarks**

* CA-SB1: Buscar por texto encuentra en título/nota/categoría/cuenta.
* CA-SB2: “Bookmark” alterna estado y aparece en la lista de marcados.

**Calendar**

* CA-CAL1: Días con transacciones muestran un punto; al tocar, filtra por fecha.

**Theming & i18n**

* CA-TH1: Modo oscuro sigue el sistema.
* CA-I18N1: Cambiar idioma de la app alterna EN/ES (mínimo strings de navegación y labels clave).

---

## 6) Datos mock y modelos mínimos

* **Account** `{id, name, group: [cash|account|card|debit|savings], currency, balance, payable?, outstanding?}`
* **Category** `{id, name, parent?}`
* **Transaction** `{id, type: [income|expense|transfer], dateTime, accountId, accountToId?, categoryId?, amount, note?, description?, photos[]?, isBookmarked?, isRecurring?}`
* **Budget** `{categoryId, month, limit}`

Genera *seed data* suficiente para que gráficos, budgets y filtros tengan sentido (≥ 30 transacciones del mes).

---

## 7) Out of scope (por ahora)

* Sync/ backend real, OCR de recibos, importación real desde SMS/email, multi-moneda real, seguridad avanzada, autenticación de usuarios.

---

## 8) Entregables

* Proyecto Flutter ejecutable (Android/iOS).
* **Guía rápida** en README: cómo correr, cambiar idioma/tema, limpiar datos.
* **Golden tests** básicos de componentes críticos (celdas de transacción, pie chart, budget bar).
* **Capturas** comparativas de cada pantalla en light/dark.

---
