# El Ahorrador

App Android (Flutter) de finanzas personales. Registra gastos **a partir de
capturas de pantalla** (Yape, bancos, Binance…) con OCR en el propio teléfono,
sin escribirlos a mano.

## Objetivo v1

La v1 es la del handoff de diseño en [`design/`](design/README.md)
(handoff v3 de Claude Design: `design/README.md` + prototipo HTML), **más** el núcleo
que da sentido a la app:

1. **Captura → OCR → transacción.** Compartir una imagen con la app, leerla
   on-device y registrarla. *(Ya existe.)*
2. **Detección automática de capturas (Android).** Detectar capturas nuevas
   de Yape/bancos y procesarlas sin que el usuario las comparta. *(Pendiente.)*
3. **Pantallas del diseño:** Trans. (Diario, Calendario, Mensual, Total),
   Estadísticas, Coach IA, Cuentas y Ajustes.

Fuera de la v1: ver [`docs/ideas.md`](docs/ideas.md).

## Estado por fases

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Motor: OCR, parsers, cola de captura, DB cifrada (SQLCipher), bloqueo | Hecho |
| 1 | Tema v3 (papel, tinta y rojo), fuentes Schibsted Grotesk + Material Symbols Rounded | Hecho |
| 2 | Bottom nav de 5 ítems + FAB, pantalla Trans. (Diario, Calendario, Mensual, Total) | Hecho |
| 3 | Estadísticas + detalle de categoría | Hecho |
| 4 | Cuentas (saldos calculados) + Ajustes persistidos + Presupuestos | Hecho |
| 5 | Detección automática de capturas (Android) + Escanear recibo | Pendiente |
| 6 | Coach IA: insights locales (hecho) + chat con LLM (pendiente) | Parcial |

## Desarrollo

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenera Drift
flutter analyze
flutter test
```

- Flutter **3.35.4** (la misma versión que usa CI).
- Datos del prototipo para revisar la interfaz: `flutter run
  --dart-define=DEMO_DATA=true` (solo debug, con la base vacía).
- Comparación visual con el prototipo: `VISUAL_OUT=/tmp/visual flutter test
  test/visual` genera capturas de cada pantalla con los datos y el tamaño de
  teléfono del diseño.
- Import histórico opcional: copia tu CSV a `assets/import/importar.csv`
  (ignorado por git) y lanza con `--dart-define=IMPORT_HISTORICAL_CSV=true`.
  Ver [`docs/specs/import-masivo.md`](docs/specs/import-masivo.md).

## Estructura

```
lib/
  ui/         interfaz v1 (shell, Trans., Estad., Coach, Cuentas, Ajustes, Añadir)
  theme/      design_tokens.dart: colores, tipografía, íconos, sombras del diseño
  core/       parsers (Yape, banco, Binance), OCR, dominio financiero
  data/       Drift + SQLCipher, repositorios, backup, import
  features/   ledger (movimientos, demo), coach, ajustes, captura
  screens/    pantallas previas aún en uso (alta/edición de cuentas, import)
  widgets/    componentes
  security/   bloqueo con biometría
design/       handoff de diseño v3 (fuente de verdad visual)
docs/
  specs/          specs funcionales vigentes
  producto/       estrategia, casos de uso, requerimientos antiguos
  device-tests/   pruebas en dispositivo (Redmi 15C)
  operations.md, privacy-policy.md, mobile-security-evidence.md, ...
```

## Flujo de trabajo

- Rama principal: `main`. Cada cambio en una rama corta + PR a `main`.
- CI (`.github/workflows/ci.yml`) debe quedar en verde antes de mergear.
