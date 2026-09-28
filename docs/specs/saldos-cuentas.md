# Spec — Módulo de saldos por cuenta (y limpieza del módulo de ingresos)

## 0) Objetivo

Poder ver, dentro de la app, cuánto hay realmente en cada cuenta (BCP Soles, Visa Light, Interbank Dólares, Binance Funds USDT, etc.) — hoy esa cuenta la lleva Moisés a mano en `finanzas.html`. El registro de transacciones (gastos e ingresos) ya funciona; lo que falta es que las cuentas tengan **saldo**, no solo nombre.

## 1) Estado actual real (corrige `IMPORT_MASIVO_SPEC.md`)

`IMPORT_MASIVO_SPEC.md` (sección 1) dice *"Solito hoy no tiene concepto de ingreso"* — **eso ya no es cierto**, quedó desactualizado en algún punto sin que el doc se corrigiera. Verificado hoy (21/08) contra el código real:

| Qué | Dónde | Estado |
|---|---|---|
| Ingresos vs gastos | `lib/screens/home_screen.dart:1255-1269` (`_calculateTotals`) | Ya funciona por **signo**: `amountCents >= 0` = ingreso, negativo = gasto. Una sola tabla `Expenses`, sin tabla `Incomes` separada (diseño válido, solo mal nombrada la tabla). |
| Alta manual de ingreso | `lib/screens/add_transaction_screen.dart:153,157,1087` | Ya existe un toggle Income/Expense que fija el signo. |
| Import histórico | `lib/data/historical_import.dart:130,162` | Ya procesa filas `type=income` **y** `type=expense` del CSV (`row['type'] == 'expense' \|\| row['type'] == 'income'`), no solo gastos. |

**Cuentas** (`lib/data/app_database.dart:55-68`, tabla `Accounts`, schema v4): existe desde `feature/ux-001-accounts` (merge `a258058`). Campos: `id, name, currency, icon, order, isDefault, isArchived, createdAt, updatedAt`. `AccountRepository` (`lib/data/account_repository.dart`) solo gestiona metadata — crear, renombrar, archivar, marcar default, reordenar. **No hay ningún campo de saldo ni cálculo de balance.** `Expenses` tiene tanto `account` (texto libre, legado) como `accountId` (FK real a `Accounts`, nullable) — `insertExpenseFromParser` (`daos.dart:113-115`) usa la cuenta default si no se especifica.

## 2) Gaps reales encontrados (no asumidos — verificados en código)

1. **Sin saldo por cuenta.** No hay forma de saber "cuánto tengo en BCP Soles" dentro de la app — es exactamente el problema que hoy resuelve `finanzas.html` a mano, línea por línea. Este es el gap principal de este spec.
2. **Taxonomía de categorías duplicada e inconsistente.** `add_transaction_screen.dart:669-721` (`_getCategories()`) tiene una lista de categorías **hardcodeada y distinta** de `lib/data/money_manager_taxonomy.dart` (la que usa el import). Ejemplo: el picker manual tiene `{'icon': '🏛️', 'name': 'Préstamos Dados', ...}` con subcategorías `[]`, mientras que la taxonomía real (`money_manager_taxonomy.dart:54-64`) trae 9 subcategorías (Mamá, Valentina, Marcos, etc.). Dos fuentes de verdad para lo mismo.
3. **Categorías no filtran por ingreso/gasto.** Ni la lista hardcodeada ni `money_manager_taxonomy.dart` distinguen `kind` (income/expense) — se puede categorizar un ingreso como "Comida" sin que la UI lo impida. `money_manager_taxonomy.dart` sí trae ambos conjuntos mezclados (compará `category_0`/`category_1` de MoneyManager, ver líneas 245-268 para las de ingreso: Salario, Devoluciones de Préstamos, Binance P2P, etc., vs el resto que son de gasto) — pero sin campo para separarlos en la UI.

## 3) Diseño propuesto — saldo por cuenta

### 3.1 Migración de schema (v4 → v5)

Agregar a `Accounts` (`app_database.dart:55-68`):

```dart
IntColumn get startingBalanceCents => integer().withDefault(const Constant(0))();
IntColumn get startingBalanceDate => integer().nullable()(); // epoch ms
```

`startingBalanceDate` en null = el saldo inicial aplica desde siempre (se suman todas las transacciones de esa cuenta). Si se define, solo cuentan transacciones con `date >= startingBalanceDate` — así se puede "anclar" un saldo conocido a una fecha concreta sin tener que borrar el historial previo (mismo patrón que ya usa Moisés en `finanzas.html`: "confirmado real el 21/08", corrigiendo drift acumulado).

Actualizar `schemaVersion` a `5` y agregar el paso de migración correspondiente en `MigrationStrategy` (`app_database.dart:106-109` en adelante).

### 3.2 Cálculo de balance

Nuevo método en `AccountRepository` (o un DAO nuevo si se prefiere separar lectura de escritura):

```dart
Stream<int> watchBalanceCents(String accountId) {
  // startingBalanceCents + SUM(amountCents) de Expenses con ese accountId
  // (y date >= startingBalanceDate si está seteado)
}
```

Nota: como el signo ya distingue ingreso/gasto (punto 1 de la sección 1), **no hace falta lógica especial** — sumar `amountCents` tal cual ya da el neto correcto.

### 3.3 Ajuste de saldo manual (equivalente al "Modified Bal." de MoneyManager)

Cuando el saldo calculado no coincide con el real (pasa seguido — ver la sesión de hoy en `finanzas.html`, donde apareció un "Triángulo de las Bermudas" de S/15 sin identificar), la corrección más simple es **insertar una transacción normal**, no una tabla nueva:

- `description`: `"Ajuste de saldo — Triángulo de las Bermudas"` (o el texto que el usuario ponga)
- `amountCents`: la diferencia (positivo o negativo)
- `sourceApp`: `'balance_adjustment'` (para poder filtrarlas/identificarlas después, mismo patrón que `kHistoricalImportSourceApp` en `historical_import.dart`)
- `accountId`: la cuenta que se está corrigiendo

No requiere cambios de schema adicionales — reusa `Expenses` tal cual.

### 3.4 UI

- `lib/screens/account_settings_screen.dart`: agregar campo "Saldo inicial" (+ fecha opcional) al crear o editar una cuenta.
- `lib/widgets/account_selector.dart` o una pantalla nueva de detalle de cuenta: mostrar el balance calculado (`watchBalanceCents`) junto al nombre — hoy el selector probablemente solo muestra nombre/ícono, sin monto.
- Botón/flujo de "Ajustar saldo" que abra un formulario simple (monto real actual → calcula la diferencia → crea la transacción de ajuste de 3.3).

## 4) Diseño propuesto — limpieza del módulo de ingresos (gaps 2 y 3)

1. Reemplazar `_getCategories()` hardcodeada en `add_transaction_screen.dart` por las categorías reales (`money_manager_taxonomy.dart` o, mejor, las `Categories`/`Subcategories` ya sembradas en la DB vía `CategoryRepository.getAllCategories()`) — una sola fuente de verdad para alta manual e import.
2. Agregar un campo `kind` (`'income' | 'expense'`) a `MoneyManagerCategorySeed` (`money_manager_taxonomy.dart:4-10`) — ya se sabe cuáles son de cada tipo (líneas 245+ son las de ingreso, calcadas de `category_0` de MoneyManager).
3. En `add_transaction_screen.dart`, filtrar el picker de categoría según el estado del toggle Income/Expense (línea 153) usando ese campo `kind`.

Esto es limpieza/consistencia, no bloqueante para el punto 3 (saldos) — se puede hacer en paralelo o después.

## 5) Orden sugerido de implementación

1. Migración schema v4→v5 (`startingBalanceCents`, `startingBalanceDate`) + tests (`test/account_migration_test.dart` ya existe, extender ahí)
2. `watchBalanceCents` en `AccountRepository` + tests (`test/account_repository_test.dart`)
3. UI de saldo inicial en `account_settings_screen.dart`
4. UI de balance visible por cuenta (selector o pantalla de detalle)
5. Flujo de ajuste de saldo (3.3 + UI)
6. (Paralelo, menor prioridad) Unificar taxonomía de categorías — puntos 4.1-4.3
7. Actualizar/marcar obsoleto `IMPORT_MASIVO_SPEC.md` sección 1, para que no vuelva a confundir a alguien (a mí me confundió hoy: excluí los ingresos del CSV de la semana por creer ese doc)

## 6) Decisiones que le tocan a Moisés

- **Ajuste de saldo:** ¿transacción normal con `sourceApp='balance_adjustment'` (reusa tabla, se mezcla en el historial pero es simple — lo propuesto arriba), o tabla `BalanceAdjustments` separada (más limpio de reportar, más trabajo de implementar)?
- **`kind` en categorías:** ¿vale la pena separar ingreso/gasto ahora, o convive con la ambigüedad actual (elegir cualquier categoría para cualquier tipo) hasta que moleste de verdad?
- **Total del home** (`_buildTotalView`, hoy income−expense acumulado histórico total): una vez existan saldos por cuenta, ¿debería mostrarse ahí la suma de balances de cuentas activas (= patrimonio líquido real) en vez del acumulado histórico? Son dos números distintos y hoy solo se ve el segundo.
- **Multi-moneda:** `Accounts.currency` ya existe (PEN por default) pero `startingBalanceCents` en la migración propuesta no lo cruza explícitamente — confirmar que el saldo inicial se ingresa en la moneda de la cuenta (ej. USD para Interbank Dólares, USDT para Binance) y que el cálculo de balance no intenta convertir nada (mismo criterio que ya usa `historical_import.dart` — sin conversión de tasa de cambio).
