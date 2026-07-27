# Android y Google Play

## Estado observado (25 de julio de 2026)

- `applicationId` y namespace usan `com.misgasticos.app`.
- La firma release admite archivo local ignorado o variables de entorno y aborta
  si faltan; no hay fallback silencioso a debug.
- Aún no hay evidencia verificable de AAB firmado, validación ni instalación
  desde Play. Esos gates requieren credenciales y acceso a Play Console.

El package definitivo ya está configurado, pero debe reservarse antes de
publicar: Play no permite cambiarlo en una aplicación existente.

## Preparación única

- [ ] Reservar y documentar package name definitivo.
- [ ] Crear upload key dedicada y guardarla fuera del repositorio.
- [ ] Configurar firma release con secretos y hacer fallar el build si faltan;
      nunca recurrir silenciosamente a firma debug.
- [ ] Activar Play App Signing y documentar recuperación de upload key.
- [ ] Confirmar `targetSdk`, icono, nombre, versión y pistas de distribución.

## Gate por versión

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release `
  --dart-define=APP_ENV=production `
  --dart-define=APP_REVISION=<git-sha> `
  --dart-define=SENTRY_DSN=<dsn-o-vacio>
Get-FileHash build/app/outputs/bundle/release/app-release.aab -Algorithm SHA256
```

- [ ] Gates exitosos en checkout limpio; registrar logs, commit y herramientas.
- [ ] AAB firmado con el certificado esperado y `bundletool validate` exitoso.
- [ ] Manifest final revisado: package, versión, permisos, exports y backup.
- [ ] Subida a Internal testing sin warnings bloqueantes.
- [ ] Instalación desde Play probada en Android mínimo y actual: arranque,
      biometría, una/múltiples imágenes, OCR, persistencia y actualización.
- [ ] Pre-launch report revisado (crashes, ANR, accesibilidad y seguridad).
- [ ] Data safety, clasificación, privacidad y acceso a la app revisados.
- [ ] Rollout escalonado, alertas y responsable de rollback definidos.

Adjuntar AAB protegido, SHA-256, versión/build, commit, certificado público,
logs, enlace de Play Console y resultados. Nunca adjuntar la upload key.
