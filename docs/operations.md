# Entrega, observabilidad y operación

## Quality gate

Cada push y pull request ejecuta análisis estático con infos fatales, tests,
cobertura mínima de 25% y un build Android release. El AAB firmado y el LCOV se
guardan 14 días como artefactos. El branch principal debe protegerse exigiendo
el check `Quality gate / quality`.

Las dependencias Dart y las GitHub Actions reciben propuestas semanales de
actualización mediante Dependabot. Se debe confirmar el `pubspec.lock` generado
por el primer `flutter pub get` para mantener builds reproducibles.

## Releases

Un tag semántico (`v1.2.3`) repite los gates, construye un Android App Bundle
(AAB) y crea un GitHub Release con notas automáticas. La versión del artefacto
procede del tag y cada evento incluye el SHA inyectado como `APP_REVISION`.

El workflow exige una upload keystore de producción mediante secretos, verifica
la firma con `jarsigner`, publica un checksum SHA-256 y genera una attestación de
procedencia. Ninguna llave se almacena en el repositorio.

## Crash reporting y privacidad

Crear el secreto de Actions `SENTRY_DSN` para habilitar Sentry en releases. Si
no existe, la aplicación funciona normalmente y solo escribe eventos JSON en el
canal de diagnóstico local. El DSN identifica el proyecto, no autentica acceso
de lectura.

La configuración desactiva PII, screenshots y cuerpos de requests. La API de
observabilidad bloquea atributos cuyos nombres indiquen OCR, texto, rutas,
cuentas, usuarios, comercios o montos. No se deben enviar esos valores bajo
nombres alternativos.

Eventos operativos principales:

- `app_started`, con versión, ambiente, revisión y estado del reporte remoto.
- `bootstrap_duration`, para regresiones de arranque.
- `ocr_duration`, `parsing_duration` y `share_processing_duration`.
- `*_failed`, con tipo de error y atributos saneados, sin mensaje de excepción,
  stack trace local ni payload de usuario.

Para diagnosticar una incidencia, filtrar primero por `release`, `environment`
y `revision`; luego por `operation`. Nunca solicitar capturas OCR o bases de
datos completas si bastan los identificadores técnicos del release.

## Variables de compilación

```text
--dart-define=APP_ENV=production
--dart-define=APP_REVISION=<git-sha>
--dart-define=SENTRY_DSN=<project-dsn>
```

## Alertas, respuesta y rollback

- **P0:** arranque imposible o pérdida/corrupción de datos. El release owner
  detiene la promoción y restaura la última versión estable.
- **P1:** crash nuevo o sesiones sin crash por debajo de 99.5%. Mobile on-call
  investiga por `release` y `revision` en menos de un día.
- **P2:** p95 de `share_processing_duration` mayor a 30 s durante 15 minutos. El
  equipo móvil compara con la release anterior y abre una incidencia.

Antes de promover, provocar un error controlado sin datos reales y comprobar
que Sentry recibe `release`, `environment`, `revision` y `operation`, sin PII.
Ejecutar un smoke test de arranque, desbloqueo, compartir imágenes, editar,
eliminar, reiniciar y actualizar conservando datos. Registrar artefacto,
checksum, resultado y responsable en la evidencia de la release.
