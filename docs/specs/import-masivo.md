# Spec — Import masivo de gastos históricos a Solito

## 0) Objetivo

Cargar ~397 gastos históricos (mayo–julio 2026) que ya están extraídos y limpios en un CSV, directo a la base de datos local de la app (sin pasar por UI, sin OCR).

**Origen de datos:** `Z:\personal\finanzas\moneymanager\importar.csv`
Columnas: `date,type,account,category,subcategory,content,detail,amount`
- `date`: `YYYY-MM-DD`
- `type`: `expense` | `income`
- `account`: nombre libre (ej. "BCP Soles", "Visa Light", "Cartera Efectivo", "Interbank Dólares", "Binance Funds USDT")
- `category`/`subcategory`: taxonomía de MoneyManager (ver mapeo en sección 3 — **no coincide 1:1** con las categorías de Solito)
- `content`: descripción de la transacción
- `detail`: tags internos tipo `[cuenta?]`, `[categoría?]`, `[USD]` — indican que ese campo fue **inferido por default**, no que venía explícito en el texto original. Útil para que el usuario revise después, pero no bloquea el import.
- `amount`: número, sin símbolo de moneda, en la moneda indicada por el tag `[USD]`/`[USDT]` en `detail` (si no hay tag, es PEN)

## 1) Limitación importante — SOLO GASTOS

**Solito hoy no tiene concepto de "ingreso"** — la tabla `Expenses` (`lib/data/app_database.dart:51`) no tiene un campo de tipo income/expense, es una tabla de gastos únicamente. No hay tabla `Incomes` en el schema (`@DriftDatabase(tables: [Captures, Categories, Subcategories, Expenses])`, línea 68).

→ **De las 397 filas del CSV, solo importar las que tengan `type=expense`** (aprox. 310-320 filas). Las filas `type=income` se quedan afuera de este import — si se quiere trackear ingresos en Solito es un feature nuevo, fuera de este scope.

## 2) Dónde vive todo (referencias de archivo)

| Qué | Archivo | Detalle |
|---|---|---|
| Schema de la BD (tablas) | `lib/data/app_database.dart` | `Captures` (L13), `Categories` (L29), `Subcategories` (L40), `Expenses` (L51) |
| DB encriptada, ruta y llave | `lib/data/app_database.dart` (función `_open()`, ~L260) | SQLite en `getApplicationDocumentsDirectory()/misgastos.sqlite`, encriptada con SQLCipher. Llave de 256 bits autogenerada, guardada en `flutter_secure_storage` — ver `lib/data/database_key_store.dart`. **No se puede tocar el `.sqlite` desde afuera de la app** sin extraer esa llave; el import tiene que correr código Dart dentro del propio proceso de la app (o un test/harness que instancie `AppDatabase` igual que la app). |
| Categorías/subcategorías default | `lib/data/app_database.dart` (`_initializeDefaultCategories`, ~L98-243) | 8 categorías, cada una con 3-11 subcategorías (lista completa en sección 3) |
| **Método clave para insertar un gasto** | `lib/data/daos.dart` → `insertExpenseFromParser` (L51-96) | Ya existe y hace justo lo que se necesita: recibe `categoryId`/`subcategoryId` como **string libre** (acepta el `id` real O el `name` — resuelve por `row.id.equals(x) \| row.name.equals(x)`, L64-77), y crea el `Expense` con `into(expenses).insert(...)`. Es un método de extensión sobre `AppDatabase` (`extension CapturesDao on AppDatabase`, L4) → se llama `await db.insertExpenseFromParser(...)`. |
| Crear categoría/subcategoría nueva si hace falta | `lib/data/category_repository.dart` → `addCategory` (~L52), `addSubcategory` (L140) | Reciben `CategoryModel`/`SubcategoryModel` (ver `lib/models/category_model.dart`) |
| Cómo se instancia la BD en la app real | `lib/main.dart:62` | `final db = AppDatabase();` |
| Generación de IDs | Ya se usa `package:uuid` en `category_repository.dart` (`const Uuid()`, `.v4()`) — reusar el mismo patrón para el `id` de cada `Expense`. |

## 3) Mapeo de categorías — MoneyManager (CSV) → Solito

Solito solo tiene **8 categorías** con subcategorías fijas (todas creadas en `_initializeDefaultCategories`):

- **Comida**: Carnes y pollo, Vegetales y verduras, Verduras y túbérculos, Frutas, Lácteos, Pan y cereales, Snacks, Bebidas, Comidas fuera, Supermercado, Otros
- **Transporte**: Taxi, Uber/Didi, Bus, Metro, Gasolina, Estacionamiento, Otros
- **Servicios**: Luz, Agua, Internet, Teléfono, Streaming, Software, Otros
- **Salud**: Medicinas, Doctor, Farmacia, Seguro, Otros
- **Entretenimiento**: Cine, Música, Juegos, Deportes, Otros
- **Educación**: Cursos, Libros, Materiales, Otros
- **Familia**: Regalos, Ayuda económica, Actividades, Otros
- **Otros**: Misceláneos, Emergencias, Otros

El CSV trae **49 combinaciones distintas** de categoría>subcategoría (taxonomía de MoneyManager, mucho más granular — 20+ categorías). Tabla de mapeo sugerida (cantidad de filas afectadas entre paréntesis):

| CSV (MoneyManager) | → Solito (existente) | Acción |
|---|---|---|
| Comida > Bebidas (36), Agua (9) | Comida > Bebidas | directo |
| Comida > Comidas fuera (63) | Comida > Comidas fuera | directo |
| Comida > Frutas (4) | Comida > Frutas | directo |
| Comida > Snacks (11) | Comida > Snacks | directo |
| Comida > Abarrotes (3) | Comida > Supermercado | directo |
| Comida > Carnes, aves y pescado (1) | Comida > Carnes y pollo | directo |
| Comida > Postres (20) | Comida > **Postres** | **crear subcategoría nueva** (o usar Snacks si no quieren crear) |
| Transporte > Taxi (11) | Transporte > Taxi | directo |
| Transporte > Autobús (25) | Transporte > Bus | directo |
| Salud > Medicina (2) | Salud > Medicinas | directo |
| Educación > Inglés (2) | Educación > Cursos | directo |
| Educación > Material escolar (1) | Educación > Materiales | directo |
| Deportes > Fútbol (9) | Entretenimiento > Deportes | directo (Deportes ya es subcat de Entretenimiento acá) |
| Entretenimiento > Baile (4) | Entretenimiento > Otros | directo |
| Familia > Mamá (4), Papá (1) | Familia > Ayuda económica | directo |
| Servicios > Netflix (2) | Servicios > Streaming | directo |
| Servicios > Google One (2), ChatGPT (1), Fitia (1), Upwork (1) | Servicios > Software | directo |
| Servicios > Telefonía (2) | Servicios > Teléfono | directo |
| Servicios > YouTube Premium (1), Otros (2) | Servicios > Streaming / Otros | directo |
| Vivienda > Luz (2) | Servicios > Luz | directo |
| Vivienda > Internet (2) | Servicios > Internet | directo |
| Vivienda > Gas (1), Renta (1), Mantenimiento (1), (sin sub) (2) | Servicios > **Otros** o categoría nueva **Vivienda** | decidir |
| Otros > (sin sub) (82) | Otros > Misceláneos | directo |
| Cuidado Personal > Peluquería (3), Productos higiénicos (2) | Otros > Misceláneos o categoría nueva **Cuidado Personal** | decidir |
| Comisiones > Bancos (1), Ligo (2), PayPal (2) | Otros > Misceláneos o categoría nueva **Comisiones** | decidir |
| Préstamos Dados > Marcos (5), Ramón (5), Valentina (1) | Familia > Ayuda económica (si es familiar) u Otros, o categoría nueva **Préstamos** | decidir |
| Electrónica > Audífonos (1), Baterías (1) | Otros > Misceláneos o categoría nueva **Electrónica** | decidir |
| Ropa > Moda (2) | Otros > Misceláneos o categoría nueva **Ropa** | decidir |
| Mantenimiento del hogar > Baños (1), Lavandería (4), Limpieza (1) | Otros > Misceláneos o categoría nueva **Hogar** | decidir |
| Oficina > Impresiones (3) | Otros > Misceláneos | directo |
| Seguros > Tarjeta de Crédito (1) | Otros > Misceláneos | directo |
| Ayuda Social > Donaciones (1) | Familia > Ayuda económica u Otros | decidir |

**Antes de programar:** Moisés tiene que decidir, para las filas marcadas "decidir", si:
(a) todo va a **Otros > Misceláneos** (más rápido, pierde detalle), o
(b) se crean categorías nuevas (Vivienda, Cuidado Personal, Comisiones, Préstamos, Electrónica, Ropa, Hogar) vía `CategoryRepository.addCategory`/`addSubcategory` antes de correr el import.

El script de import debería recibir esta tabla de mapeo como una constante/config (`Map<String, (String categoria, String subcategoria)>` en Dart, keyed por `"$category > $subcategory"` del CSV) para que sea fácil de ajustar sin tocar la lógica.

## 4) Conversión de campos (CSV → `insertExpenseFromParser`)

| Campo CSV | Campo destino | Conversión |
|---|---|---|
| `date` (`YYYY-MM-DD`) | `dateEpochMs` | Parsear con `DateTime.parse(date).millisecondsSinceEpoch` (usar mediodía o medianoche local, a definir — no hay hora en el CSV) |
| `amount` | `amountCents` | `(double.parse(amount) * 100).round()` |
| moneda (tag `[USD]`/`[USDT]` en `detail`, si no PEN) | `currency` | `'PEN'` por default; `'USD'` o `'USDT'` si el tag está presente en `detail`. **No hay conversión de tasa de cambio acá** — se guarda el monto tal cual viene en su moneda original (mismo criterio que MoneyManager) |
| `category`/`subcategory` | `categoryId`/`subcategoryId` | vía tabla de mapeo (sección 3) → pasar el **nombre** de la categoría/subcategoría de Solito (el método ya resuelve por nombre) |
| `account` | `account` | pasar tal cual (campo de texto libre, no hay tabla de cuentas en este schema) |
| `content` | `description` | tal cual |
| `detail` | `notes` | tal cual (para que quede visible qué campos fueron inferidos, ej. `[cuenta?]`) |
| — | `sourceApp` | fijo: `'finanzas-html-import'` (para poder identificar/filtrar estos registros después si hace falta) |
| — | `captureId` | `null` (no viene de una foto/OCR) |
| — | `id` | `const Uuid().v4()` |

## 5) Cómo correrlo

No hay forma de tocar el `.sqlite` desde afuera (está encriptado, llave en secure storage). Opciones para el desarrollador:

1. **Script de integración/test** que instancie `AppDatabase` igual que un test (ver si ya existe algún test en `test/` que arme una instancia en memoria o real — si es la real, hay que correrlo en el dispositivo/emulador donde vive la app, no en cualquier máquina).
2. **Pantalla/botón de debug temporal** dentro de la app (ej. en Settings, solo visible en modo debug) que lea el CSV (empaquetado como asset o vía file picker) y llame a `db.insertExpenseFromParser(...)` en un loop — se borra el botón después de usarlo una vez.

Cualquiera de las dos formas necesita correr **dentro del proceso de la app** (mismo device/emulador), porque solo ahí está desbloqueada la llave de SQLCipher.

## 6) Verificación post-import

- Contar filas insertadas y compararlas contra el total de filas `type=expense` del CSV.
- Chequear con `watchExpenses()` (`daos.dart:102`) o la UI de Transactions que los montos y fechas coincidan con una muestra del CSV.
- Revisar cuántos registros quedaron con `notes` conteniendo `[categoría?]` o `[cuenta?]` — son los que probablemente el usuario quiera revisar/corregir a mano después.
