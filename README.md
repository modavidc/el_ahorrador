# Requerimientos actualizados (v0.2)

## 1) Objetivo del producto

* Registrar gastos vía **Share → OCR on-device → DB local** (costo ≈ 0).
* **Gasto compartido simple**: quien paga comparte con 3–4 personas para que importen el gasto.
* **Round-Robin Colaborativo**: en grupos de 20–30, rotar “quién paga” o “quién colabora” para que no recaiga siempre en los mismos.

---

## 2) Reglas de negocio

* **Umbral mínimo** para compartir: no mostrar opción si **monto < S/3** (configurable).
* **Gasto compartido**:

  * Usuarios existentes → **push** con botón **Importar**.
  * No usuarios → **deep link** por WhatsApp/SMS (landing ultra-ligera).
* **Round-Robin**:

  * Cada **ciclo** define 1 o más eventos (p. ej., “snacks del viernes”, “taxi del equipo”).
  * El **siguiente responsable** se elige por rotación justa:

    * Se usa una **cola circular** de miembros activos.
    * Se **saltan** miembros en **cooldown** o con límite de aportes en el período.
    * Se registra el **historial** para auditar y evitar repeticiones cercanas.
  * Opcional: **peso** por participación anterior (dar chance a quien aportó menos).
  * Tolerar **excepciones**: si el asignado rechaza o no puede, se reasigna al siguiente.

---

## 3) Arquitectura (añadidos)

### Mobile (offline-first)

* OCR on-device (ML Kit / Tesseract).
* DB local Drift/SQLite + FTS5.
* Módulo **Shares** (enlace firmado + importación).
* Módulo **Groups & Round-Robin** (caché local + sync liviana).

### Backend mínimo (serverless, free tier)

* **/share/**: creación/aceptación de gastos compartidos.
* **/groups/**: creación de grupo, alta/baja de miembros, **rotación** y **ciclos**.
* **/push/**: FCM para notificaciones (gratis).
* Storage: **KV/Supabase** con TTL para tokens.

> Nota costo: seguimos usando on-device para OCR y solo persistimos **metadatos ligeros** de grupos/rotaciones. Todo lo pesado (imágenes, OCR, búsqueda) sigue local.

---

## 4) Modelo de datos (nuevas tablas)

**groups**

* id (uuid, PK), name, description, created\_at

**group\_members**

* id (uuid, PK), group\_id (FK), user\_id (FK o null si invitado por teléfono), phone/email, is\_active (bool), role (“owner”, “member”), weight (int default 1), cooldown\_until (epoch ms)

**rr\_cycles** (ciclos de round-robin)

* id (uuid, PK), group\_id (FK), name (“Snacks Q3”), period (“WEEKLY|MONTHLY|ADHOC”), start\_at, end\_at (nullable), max\_contrib\_per\_period (int), status (“ACTIVE|PAUSED|ENDED”)

**rr\_assignments** (historial/asignaciones)

* id, cycle\_id (FK), member\_id (FK), due\_date, status (“ASSIGNED|DECLINED|DONE|SKIPPED”), reason (nullable), created\_at

**shared\_expenses** (ya contemplado)

* id, owner\_user\_id, expense\_payload (json compacto), token (short), expires\_at, created\_at

**push\_devices**

* id, user\_id, device\_token, platform, updated\_at

> En el cliente seguimos con `captures`, `expenses`, `categories`, `attachments`.

---

## 5) Lógica de Round-Robin (algoritmo)

### Parámetros

* **M** = miembros activos del grupo con `is_active = true`.
* **Historial ventana**: evitar repetir a un miembro que **ya fue asignado** en las últimas **K** rondas (configurable, p. ej. K = 3).
* **Cooldown**: `member.cooldown_until > now` → saltar.
* **Límite por período**: si `assignments(DONE) >= max_contrib_per_period`, saltar.

### Selección (pseudocódigo)

```
function nextAssignee(groupId, cycleId, date):
  active = miembros_activos(groupId)
  queue = ordenar_por_ultima_participacion(active)  // menos recientes primero
  queue = aplicar_pesos(queue)                      // opcional, repetir miembro con menos aportes
  for member in queue.ciclo():
    if member.cooldown_until > now: continue
    if hizo_maximo_en_periodo(member, cycleId, date): continue
    if fue_asignado_en_ultimas_k(member, cycleId, K): continue
    return member
  return first(active) // fallback
```

### Estados y transiciones

* **ASSIGNED** → (usuario acepta y paga) → **DONE**
* **ASSIGNED** → (declina) → **DECLINED** → reasignar `nextAssignee()`
* **ASSIGNED** → (timeout X horas) → **SKIPPED** → reasignar

> Todo cambio escribe un `rr_assignments` y dispara **push** a afectados.

---

## 6) UX / Flujo de usuario

### Compartir gasto (3–4 personas)

1. Desde el gasto → **Compartir**.
2. Seleccionar contactos (máx 4).
3. Enviar:

   * Usuarios app → **push** “Te compartieron un gasto”.
   * No usuarios → **deep link** para importar (abre app o landing).

### Round-Robin (20–30 personas)

1. Crear **Grupo** → invitar miembros.
2. Crear **Ciclo RR** (nombre, periodicidad, reglas).
3. La app muestra el **Próximo responsable** con fecha límite.
4. Botones:

   * **“Lo cubro”** → marca **DONE** y notifica al grupo.
   * **“No puedo”** → **DECLINED** → reasignación automática.
5. Historial visible por transparencia (quién aportó, cuándo).

> Regla de simplicidad: no se sugiere round-robin para montos **< S/3**.

---

## 7) Notificaciones y deep links

* **FCM**: `topic: group_{id}` para avisos generales + `device_token` por usuario.
* **Deep links**:

  * `mis_gastos://share/{token}` → importar gasto.
  * `mis_gastos://group/{id}/cycle/{cycleId}` → ver asignación actual/aceptar/declinar.

---

## 8) Seguridad y privacidad

* Tokens de **share** firmados y con **TTL** (7–14 días).
* Datos sensibles **en local**; backend guarda solo metadatos de grupos/rotaciones.
* Opt-in para mostrar **nombre** en historial del grupo (sino alias/emoji).
* Enlaces para no usuarios muestran **solo lo mínimo** (monto total, concepto, fecha).

---

## 9) Métricas locales (sin costo)

* % de gastos importados por invitados.
* Tiempo medio de resolución de una asignación RR.
* Distribución de aportes por miembro (equidad).
* Ratio de “declinados” por ciclo.

---

## 10) Roadmap

### **v0.0.1 (Prototipo Actual) - Estado: ✅ COMPLETAMENTE FUNCIONAL**

#### ✅ **Completado:**
- [x] **Setup inicial del proyecto Flutter**
- [x] **OCR básico con Google ML Kit** (text recognition)
- [x] **Base de datos local con Drift/SQLite**
- [x] **Estructura de carpetas y arquitectura**
- [x] **Resolución de errores de build:**
  - [x] Cache de Gradle corrupto
  - [x] NDK de Android incompleto
  - [x] Namespace faltante en google_mlkit_commons
  - [x] Actualización de dependencias de desarrollo
- [x] **Funcionamiento en Web** ✅
- [x] **Build exitoso para Android** ✅
- [x] **Sistema de Share Handler** - Recibe capturas de pantalla
- [x] **OCR automático** - Procesa imágenes compartidas
- [x] **Parser especializado para Yape** - Extrae datos de transacciones
- [x] **Validación de capturas** - Identifica Yape, Binance, Banco
- [x] **Base de datos completa** - Esquema con migraciones
- [x] **UI principal** - HomeScreen con resumen financiero
- [x] **Modo nocturno** - Adapta al tema del sistema
- [x] **Campos completos de transacciones:**
  - [x] Fecha, Monto, Categoría, Subcategoría
  - [x] Cuenta, Descripción, Notas
  - [x] Captura (si disponible)
- [x] **Sistema de categorías** - 10 categorías con subcategorías
- [x] **Notas inteligentes:**
  - [x] **Manuales** - Escritura libre del usuario
  - [x] **Automáticas** - Generación con IA contextual
  - [x] **Estructuración** - Organización automática del contenido
  - [x] **Múltiples formatos** - Estructurado, lista, simple
- [x] **Dialog de edición** - Interfaz completa para editar transacciones
- [x] **Integración completa** - Flujo end-to-end funcional

#### 🎯 **Funcionalidades Principales Implementadas:**

##### **📱 Procesamiento de Capturas:**
- ✅ **Share Handler** - Recibe capturas de otras apps
- ✅ **OCR automático** - Extrae texto de imágenes
- ✅ **Validación inteligente** - Identifica Yape, Binance, Banco
- ✅ **Parser especializado** - Extrae datos estructurados
- ✅ **Registro automático** - Crea transacciones sin intervención

##### **🎨 Interfaz de Usuario:**
- ✅ **HomeScreen** - Resumen financiero y lista de transacciones
- ✅ **Modo nocturno** - Adapta automáticamente al tema del sistema
- ✅ **Dialog de edición** - Campos completos para transacciones
- ✅ **Categorías visuales** - 10 categorías con iconos y subcategorías
- ✅ **Notas inteligentes** - Manuales y automáticas con estructuración

##### **🤖 Notas Inteligentes:**
- ✅ **Escritura manual** - Campo libre para el usuario
- ✅ **Generación automática** - IA contextual basada en datos
- ✅ **Estructuración** - Organización automática del contenido
- ✅ **Múltiples formatos:**
  - Estructurado: `• Pago con Yape - Comida\n  → En Restaurante\n  → Gasto considerable`
  - Lista: `• Pago con Yape\n• Categoría: Comida\n• Lugar: Restaurante`
  - Simple: `Pago con Yape - Comida en Restaurante`

##### **💾 Base de Datos:**
- ✅ **Esquema completo** - Captures, Expenses con todos los campos
- ✅ **Migraciones** - Manejo de cambios de esquema
- ✅ **Relaciones** - Captures → Expenses
- ✅ **Campos adicionales** - sourceApp, category, subcategory, account, description

#### 🤖 **Sistema de Notas Inteligentes:**

##### **Funcionalidades:**
- ✅ **Notas manuales** - El usuario puede escribir libremente
- ✅ **Notas automáticas** - IA genera notas contextuales
- ✅ **Estructuración** - Organiza contenido existente automáticamente
- ✅ **Múltiples formatos** - 3 tipos de generación aleatoria

##### **Interfaz:**
```
┌─────────────────────────────────────────┐
│ Notas                    [🤖] [📝]     │
│ • Pago con Yape - Comida               │
│   → En Restaurante El Buen Sabor       │
│   → Gasto considerable                 │
└─────────────────────────────────────────┘
```

##### **Tipos de Notas Generadas:**

**1. Estructurada (33%):**
```
• Pago con Yape - Comida (Comidas fuera)
  → En Restaurante El Buen Sabor
  → Gasto considerable
```

**2. Lista (33%):**
```
• Pago con Yape
• Categoría: Comida
• Tipo: Comidas fuera
• Lugar: Restaurante El Buen Sabor
```

**3. Simple (34%):**
```
Pago con Yape - Comida (Comidas fuera) en Restaurante
```

##### **Características Técnicas:**
- ✅ **Contexto inteligente** - Basado en app de origen (Yape, Binance, Banco)
- ✅ **Categorización automática** - Usa datos de la transacción
- ✅ **Estructuración inteligente** - Detecta formato existente
- ✅ **Feedback visual** - Notificaciones cuando se usan las funciones
- ✅ **Tooltips informativos** - Explican cada función

#### 📱 **Flujo de Uso Actual:**

##### **1. Procesamiento Automático:**
1. **Usuario** toma captura de pantalla de Yape
2. **Usuario** comparte con "El Ahorrador" desde la galería
3. **App** recibe la imagen automáticamente
4. **OCR** extrae el texto de la imagen
5. **Parser** identifica que es de Yape y extrae datos
6. **App** registra automáticamente como gasto
7. **App** muestra mensaje de confirmación
8. **Usuario** puede editar detalles si lo desea

##### **2. Edición de Transacciones:**
1. **Usuario** toca una transacción en la lista
2. **App** abre dialog de edición
3. **Usuario** puede modificar:
   - Monto, fecha, categoría, subcategoría
   - Cuenta, destinatario, descripción
   - **Notas** (manuales o automáticas)
4. **Usuario** guarda cambios
5. **App** actualiza la transacción

##### **3. Notas Inteligentes:**
1. **Usuario** abre dialog de edición
2. **Usuario** puede:
   - **Escribir manualmente** en el campo de notas
   - **Presionar 🤖** para generar nota automática
   - **Presionar 📝** para estructurar contenido existente
3. **App** genera/estructura la nota
4. **App** muestra feedback visual
5. **Usuario** puede seguir editando o guardar

#### 📚 **Documentación Técnica:**

##### **Archivos de Documentación:**
- ✅ **`IMPLEMENTACION_YAPE.md`** - Implementación del parser de Yape
- ✅ **`MODO_NOCTURNO.md`** - Implementación del modo nocturno
- ✅ **`CAMPOS_COMPLETOS.md`** - Campos completos de transacciones
- ✅ **`NOTAS_INTELIGENTES.md`** - Sistema de notas inteligentes

##### **Estructura del Proyecto:**
```
lib/
├── core/                    # Lógica de negocio
│   ├── parser.dart         # Parser principal
│   ├── yape_parser.dart    # Parser de Yape
│   ├── categories.dart     # Sistema de categorías
│   ├── ai_notes_generator.dart # Generador de notas IA
│   └── capture_validator.dart # Validador de capturas
├── data/                   # Base de datos
│   ├── app_database.dart   # Esquema Drift
│   └── daos.dart          # Data Access Objects
├── screens/               # Pantallas
│   └── home_screen.dart   # Pantalla principal
├── widgets/               # Componentes UI
│   └── expense_edit_dialog.dart # Dialog de edición
└── main.dart              # Punto de entrada
```

#### 🚀 **Features Avanzadas Propuestas:**
- [ ] **Overlay System** - Icono flotante como sistema
- [ ] **Detección automática de capturas de pantalla**
- [ ] **OCR automático en fotos de galería**
- [ ] **Permisos de acceso a archivos y fotos**
- [ ] **Procesamiento automático de Binance y Banco**
- [ ] **Sistema de grupos y Round-Robin**
- [ ] **Compartir gastos entre usuarios**

---

**v0.2 (próxima iteración)**

* Tablas `groups`, `group_members`, `rr_cycles`, `rr_assignments`.
* UI Grupo: lista, detalle del ciclo, asignación vigente (aceptar/declinar).
* Selección de contactos para compartir (máx 4) + deep link.
* Reglas: umbral S/3, cooldown básico (48h), ventana K=3.

**v0.3**

* Pesos dinámicos (más turno a quien menos aportó).
* Panel de transparencia (top aportes, últimos 10).
* Export CSV por grupo/ciclo.

**v0.4**

* Reglas avanzadas (cap por mes, feriados, excepciones).
* Integración pagos (Yape/Plin) como comprobante (opcional).
* Admin web ligera (si hace falta).

---

## 11) Diagrama (Mermaid)

### Componentes con Round-Robin

```mermaid
flowchart LR
  subgraph Device (App)
    UI[UI mis_gastos]
    OCR[OCR Engine]
    Parser[Parser]
    DB[(Drift/SQLite)]
    Shares[Shares Module]
    Groups[Groups & RR Module]
  end

  subgraph Serverless (Free tier)
    API[/Share & Groups API/]
    KV[(KV/Supabase)]
    Push[FCM]
    Landing[Mini Landing]
  end

  UI -- "Share image" --> OCR --> Parser --> DB
  UI -- "Compartir gasto" --> Shares --> API
  API --> KV
  API --> Push
  UI <-- "push/import" --> Push
  Landing <-- deep link --> UI

  UI -- "Crear grupo/ciclo" --> Groups --> API --> KV
  UI <-- "asignación RR" --> API
```

### Secuencia Round-Robin

```mermaid
sequenceDiagram
  autonumber
  participant Owner as Creador Ciclo
  participant App as App mis_gastos
  participant API as API Groups
  participant KV as KV/Supa
  participant M as Miembro

  Owner->>App: Crear ciclo RR (params)
  App->>API: POST /groups/{id}/cycles
  API->>KV: persist cycle
  API-->>App: ciclo ACTIVE

  App->>API: POST /cycles/{id}/nextAssignee
  API->>KV: leer miembros, historial, reglas
  API-->>App: member_id seleccionado

  App-->>M: Push “Te toca cubrir”
  M->>App: Aceptar / Declinar
  App->>API: POST /assignments/{id}/status
  API->>KV: actualizar estado
  API-->>App: OK (y notifica grupo si aplica)
```

---

## 12) Validaciones y edge cases

* Grupo con <3 miembros: avisar que **RR pierde sentido**.
* Todos en cooldown/límite: **reset** ventanas y elegir menos reciente.
* Miembro sin app y sin teléfono válido: marcar **PENDING\_CONTACT**.
* Decline en cadena (3+): alertar al grupo/owner para intervención manual.
* Importación de gasto duplicado: **hash** del payload para dedup local.

---

Si quieres, te preparo el **esqueleto de DB Drift** (tablas nuevas + DAOs) y el **servicio RR** con la función `nextAssignee()` en Dart para que lo pegues directo en tu proyecto.
