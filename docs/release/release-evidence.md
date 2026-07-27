# Evidencia de candidato de release

Copiar esta plantilla por cada candidato. No marcar una casilla sin adjuntar el
artefacto o enlace indicado. No incluir secretos, DSN, certificados privados ni
archivos de firma.

## Identidad reproducible

- Versión/build:
- Commit SHA (árbol limpio):
- Fecha UTC y responsable:
- Flutter/Dart, Java/Gradle y Xcode usados:
- Plataforma y ambiente (`production`):

## Gates automatizados

- [ ] `dart run tool/check_release_identifiers.dart`
- [ ] `dart run tool/check_release_readiness.dart`
- [ ] CI, análisis y tests verdes para el mismo commit
- [ ] Artefacto release producido por CI o checkout limpio
- SHA-256 del AAB/IPA:
- Enlace a logs inmutables:

## Android

- [ ] AAB firmado con upload certificate esperado; `bundletool validate` exitoso
- [ ] Manifest fusionado archivado y revisado
- [ ] Subido a Internal testing e instalado desde Play
- [ ] Pre-launch report sin bloqueos
- Enlace de Play Console / versión:

## iOS

- [ ] Archive y `Validate App` exitosos en macOS/Xcode
- [ ] Build procesado e instalado desde TestFlight
- [ ] Privacy manifest/entitlements del archive revisados
- Enlace de App Store Connect / build:

## Privacidad y operación

- [ ] Política pública, URL de soporte y canal de borrado accesibles
- [ ] Data safety y Privacy Labels coinciden con binarios/SDKs finales
- [ ] Logs y crashes verificados sin imágenes, OCR, cuentas, montos ni rutas
- [ ] Pruebas limpia, actualización y rollback completadas
- [ ] Responsable, métricas y umbral para detener rollout definidos

Resultado: **APROBADO / RECHAZADO**. Aprobadores y fecha:
