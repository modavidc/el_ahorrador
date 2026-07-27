# Plataformas y release

## Comprobación reproducible

Desde la raíz del proyecto:

```powershell
dart run tool/check_release_identifiers.dart
dart run tool/check_release_readiness.dart
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
```

Luego compilar únicamente la plataforma objetivo. Android release requiere
`android/key.properties` (basado en el ejemplo) o las variables
`ANDROID_KEYSTORE_*`; si faltan, Gradle debe abortar.

| Plataforma | Artefacto/gate | Estado para beta móvil |
| --- | --- | --- |
| Android | `flutter build appbundle --release`; instalar desde Play Internal | Objetivo primario, requiere credenciales/evidencia externa |
| iOS | `flutter build ipa --release`; Validate App y TestFlight | Bloqueado por IDs de ejemplo, macOS y cuenta Apple |
| Web | `flutter build web --release` | No equivale a validar el flujo móvil de compartir/biometría |
| Windows/macOS/Linux | build release e instalador firmado cuando aplique | Fuera de alcance salvo compromiso explícito de soporte |

## Versionado

`pubspec.yaml` es la fuente: `major.minor.patch+build`. Antes de cada subida,
consultar ambas consolas y usar un build estrictamente mayor a todos los usados;
un número aceptado por Git no garantiza que una tienda lo acepte. Registrar
versión, build, commit y hash del artefacto en `release-evidence.md`.

## Seguridad de distribución

- Mantener keystores, `key.properties`, certificados, perfiles y tokens fuera de Git.
- Revisar manifest/entitlements resultantes del artefacto, no solo fuentes.
- Instalar desde la pista real en dispositivo limpio y probar actualización.
- Conservar hashes y logs; no conservar secretos junto a la evidencia.
