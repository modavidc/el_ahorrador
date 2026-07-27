# iOS y App Store

## Estado preparado en el repositorio

- Bundle ID de Runner: `com.misgasticos.app`.
- Bundle ID de la extensión: `com.misgasticos.app.ShareExtension`.
- Runner y Share Extension declaran el App Group
  `group.com.misgasticos.app`.
- La Share Extension acepta hasta 10 imágenes y usa
  `share_handler_ios_models` para entregarlas a Flutter mediante el deep link
  `ShareMedia-com.misgasticos.app`.
- Firma automática habilitada. `DEVELOPMENT_TEAM` queda deliberadamente fuera
  del repositorio: se asigna en Xcode o CI con la cuenta propietaria.
- Deployment target: iOS 14.0, requerido por el controlador de
  `share_handler_ios` usado por la extensión.

No se solicitan capacidades adicionales. Face ID conserva su descripción de
uso; no se añade acceso general a Fotos porque una Share Extension recibe los
archivos elegidos por el usuario sin leer su fototeca.

## Configuración única en Apple Developer/Xcode

- [ ] Registrar los dos App IDs explícitos indicados arriba.
- [ ] Crear el App Group `group.com.misgasticos.app` y asociarlo a ambos App IDs.
- [ ] En `Runner.xcworkspace`, asignar el mismo Team a Runner y ShareExtension.
- [ ] Confirmar que Xcode administra los perfiles de ambos targets.
- [ ] Crear la app en App Store Connect con `com.misgasticos.app`.

No cambies unilateralmente ninguno de los tres identificadores: deben coincidir
en Apple Developer, perfiles, App Store Connect y este proyecto.

## Gate de TestFlight

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter analyze
flutter test
flutter build ipa --release \
  --dart-define=APP_ENV=production \
  --dart-define=APP_REVISION=<git-sha> \
  --dart-define=SENTRY_DSN=<dsn-o-vacio>
```

- [ ] `Validate App` exitoso en Organizer.
- [ ] Build procesado en App Store Connect/TestFlight.
- [ ] iPhone físico: Face/Touch ID, cancelar/fallback y retorno del background.
- [ ] Compartir una y varias imágenes con Runner cerrado, abierto y en segundo
      plano; comprobar que cada imagen se procesa una sola vez.
- [ ] Actualizar desde el build anterior sin pérdida de la base cifrada.
- [ ] Revisar Privacy Labels, export compliance, política, edad, screenshots y
      notas de revisión.

Adjunta a la evidencia de release el commit, versión/build, versiones de Xcode
y Flutter, resultado de pruebas, ID de archive/TestFlight y `Validate App`. No
guardes certificados, perfiles ni claves privadas en el repositorio.
