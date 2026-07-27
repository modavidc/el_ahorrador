# Arquitectura de la aplicación

## Estado

Aceptada. Este documento registra la arquitectura que el repositorio protege de
forma automática; no pretende describir una migración ya terminada.

## Decisión

La aplicación usa una separación pragmática por features y límites explícitos:

- `main.dart` es el *composition root*: crea los recursos con ciclo de vida de
  aplicación, conecta implementaciones y los entrega por constructor.
- `lib/features/<feature>/application/` contiene casos de uso y máquinas de
  estado. Esta capa es Dart puro: no conoce Flutter, plugins ni persistencia.
- Los adaptadores de producción conectan los puertos de aplicación con plugins
  y datos. Para captura compartida, ese límite es
  `features/capture/shared_capture_runtime.dart`.
- `lib/data/` posee Drift, las tablas, migraciones y repositorios concretos.
- La presentación puede conservar estado efímero de widgets localmente. El
  estado de negocio asíncrono debe avanzar hacia controllers/stores de feature
  y estados explícitos, sin duplicar banderas en varias pantallas.

Las dependencias apuntan hacia los contratos y el dominio. En particular, una
capa interna nunca importa pantallas, `main.dart`, Flutter ni plugins.

```text
presentación / main ──> feature/application <── adaptador de producción
        │                                      │
        └──────────────────────────────────────> data / plugins
```

## Propiedad y ciclo de vida

Existe una sola instancia de `AppDatabase` por ejecución normal. Se crea en el
composition root, se inyecta y se cierra allí. Ninguna pantalla, controller o
caso de uso abre una conexión propia. Los servicios tampoco se publican mediante
singletons mutables o service locators globales.

El flujo de captura expone resultados y estados sellados. El coordinador posee
la exclusión mutua y la secuencia de validación, OCR, parsing y persistencia; la
UI observa ese estado y decide cómo representarlo. El adaptador traduce plugins
y base de datos a los puertos del coordinador.

## Guardrails verificables

`test/architecture_test.dart` impide regresiones estructurales:

1. solo el composition root o `data/` pueden construir `AppDatabase`;
2. ninguna biblioteca importa `main.dart`;
3. `core/` y `data/` no dependen de presentación;
4. la capa de aplicación de captura no importa Flutter, plugins ni `data/`;
5. `main.dart` no recupera el pipeline concreto de OCR/parsers;
6. el coordinador conserva puertos, estado explícito y exclusión mutua.

Estos controles son deliberadamente pequeños y basados en código fuente. Al
mover una responsabilidad, primero se mantiene el sentido del límite y después
se ajusta su ruta permitida junto con este ADR y sus pruebas.

## Consecuencias y migración

La decisión permite refactorizar por etapas sin introducir obligatoriamente un
framework de estado. El orden recomendado es captura compartida, alta/edición de
transacciones, inicio y estadísticas. Cada extracción debe añadir pruebas de
transiciones del controller y dejar en el widget únicamente estado visual.

Temporalmente algunas pantallas acceden a `AppDatabase` y conviven `screens/` y
`features/`. Es deuda conocida, no el destino arquitectónico. Código nuevo debe
entrar en la feature correspondiente y usar un repositorio o puerto cuando la
lógica sea de negocio.
