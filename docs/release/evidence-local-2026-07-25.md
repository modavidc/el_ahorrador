# Evidencia local de release · 25 jul 2026

Esta ejecución comprueba que el repositorio puede producir un Android App
Bundle release. Usa una llave efímera de CI: no es el artefacto publicable ni
acredita Play Console.

## Resultado

- `flutter analyze --no-pub`: 0 incidencias.
- `flutter test --no-pub`: 61/61 pruebas aprobadas.
- `dart run tool/check_release_identifiers.dart`: OK.
- `dart run tool/check_release_readiness.dart`: 0 errores, 1 advertencia por build 1.
- `flutter build appbundle --release`: exitoso.
- Artefacto: `build/app/outputs/bundle/release/app-release.aab`.
- Tamaño: 78,824,194 bytes.
- SHA-256: `04C15DF0F2DC7652E8AFF0485B24D35008DBD93103A24AA51FF1EFAEF1848265`.
- `jarsigner -verify`: integridad de firma verificada; el certificado efímero es
  autofirmado y no corresponde a la futura upload key.

## Defectos descubiertos y corregidos

- Los plugins nativos requerían NDK 28.2 por encima del NDK 27 configurado.
- R8 necesitaba reconocer como opcionales Play Feature Delivery y los modelos
  ML Kit no incluidos (chino, devanagari, japonés y coreano).
- La validación posbuild de Flutter requería una instalación correcta de
  Android command-line tools para comprobar los símbolos nativos del AAB.

## Evidencia todavía obligatoria

- Ejecutar el workflow sobre un commit limpio.
- Construir con la upload key real almacenada en secretos.
- Cargar en Play Internal testing e instalar desde Play.
- Completar smoke test en dos dispositivos y revisar el pre-launch report.
- En iOS: registrar IDs/App Group, asignar Team y validar Archive/TestFlight en
  macOS.
