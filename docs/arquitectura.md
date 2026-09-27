# Arquitectura

La app se organiza **por funcionalidad** (feature-first) y, dentro de cada
funcionalidad, **por capas** (clean architecture). Las reglas de dependencia
se verifican en `test/architecture_test.dart`: si una capa importa lo que no
debe, el test falla.

```
lib/
  main.dart            arranca la app (observabilidad, bloqueo, share handler)
  app/                 raíz de composición
    dependencies.dart  ÚNICO lugar que elige implementaciones (drift, ML Kit…)
    home/              shell: pestañas, botón +, hojas globales
  core/                transversal, sin funcionalidades
    clock/             AppClock (fijable en tests)
    database/          Drift + SQLCipher: tablas, DAOs, migraciones
    format/            Fmt: "S/ 1,234.56", meses, horas
    observability/     métricas y errores (Sentry)
    security/          bloqueo con huella, archivos cifrados, llaves
  design_system/       tokens.dart (colores, texto, íconos, categorías) y kit.dart
  features/
    <funcionalidad>/
      domain/          entidades, puertos (interfaces) y casos de uso. Dart puro.
      data/            implementaciones de los puertos (drift, ML Kit, archivos)
      application/     controladores que orquestan casos de uso para la UI
      presentation/    pantallas y widgets
```

## Reglas de dependencia

```
presentation ─┐
application ──┼──▶ domain ◀── data
app/ ─────────┴──────────────▶ (todas: compone)
core/, design_system/ ◀── cualquiera (no dependen de funcionalidades)
```

| Capa | Puede importar | No puede importar |
|---|---|---|
| `domain` | otros `domain`, `core/format` | Flutter, drift, `data`, `presentation` |
| `application` | `domain`, `core`, `flutter/foundation` | `data`, `core/database`, `presentation` |
| `presentation` | `domain`, `application`, `design_system`, `core` | `data`, `core/database`, drift |
| `data` | `domain`, `core` | `presentation`, `application`, `design_system` |
| `core`, `design_system` | paquetes; el diseño puede leer enums de dominio | `app`, capas de funcionalidades |

Las pantallas reciben **interfaces** (`LedgerRepository`, `AppPreferences`,
`CaptureRuleRepository`…) y nunca construyen implementaciones: eso ocurre en
`app/dependencies.dart`. Para probar, se arma `AppDependencies` con dobles
(`test/support/capture_fakes.dart`).

## Funcionalidades

| Funcionalidad | domain | data | application / presentation |
|---|---|---|---|
| `ledger` | `Movement`, `LedgerAccount`, `Category`, `LedgerRepository`, `MonthSummary`, intérprete de texto | `DriftLedgerRepository`, datos demo | Movimientos, registro manual, detalle, racha |
| `capture` | `ReceiptReader`, `CaptureRule`, `CaptureService`, puertos (`OcrEngine`, `CaptureImageStore`, `CaptureRecords`, `CaptureRuleRepository`, `BackgroundCapture`) | ML Kit, archivos cifrados, `captures` en drift, reglas en `app_settings` | `CaptureController`; hoja de lectura, Por revisar, Reglas |
| `settings` | `AppPreferences` (interruptores y textos) | `DriftAppPreferences` | Ajustes, Recordatorios, Personalizar Coach, Seguridad, Categorías |
| `accounts` | `AccountGroup`, `AccountsRepository` | `DriftAccountsRepository` | Cuentas, Nueva cuenta, Editar cuenta |
| `stats` | `StatsSummary`, `CategoryDetail` | — | Estadísticas, detalle por categoría, Presupuestos |
| `coach` | `CoachContext`, insights, `CoachAssistant`, `LocalCoach`, `ConversationRepository` | historial en `app_settings` | `CoachController`; Coach, Conversaciones |
| `import` | — | import histórico (solo debug) | pantalla de import |

## Cómo agregar algo

1. **Regla de negocio** → `domain/` como función o clase de Dart puro, con test
   unitario sin base de datos.
2. **Nuevo dato persistido** → puerto en `domain/`, implementación en `data/`,
   se conecta en `app/dependencies.dart`.
3. **Pantalla** → `presentation/`; estilos solo desde `design_system/tokens.dart`
   (lo exige `test/design_tokens_usage_test.dart`).
4. Validar: `flutter analyze` y `flutter test` (incluye arquitectura y diseño).
