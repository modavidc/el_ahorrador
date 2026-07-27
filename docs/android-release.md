# Release Android

El workflow `Tagged release` ejecuta `flutter analyze`, `flutter test` y
`flutter build appbundle --release`. Se activa manualmente o con tags `vX.Y.Z`
y conserva el AAB como artifact durante 30 dias.

Configurar el environment protegido `production` con estos secrets:

- `ANDROID_KEYSTORE_BASE64`: upload keystore en Base64, en una sola linea.
- `ANDROID_KEYSTORE_PASSWORD`: contrasena del keystore.
- `ANDROID_KEY_ALIAS`: alias de la upload key.
- `ANDROID_KEY_PASSWORD`: contrasena de la llave.

PowerShell para obtener el Base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

El runner decodifica el keystore dentro de su directorio temporal y Gradle lo
recibe mediante `ANDROID_KEYSTORE_PATH`; el archivo no se incorpora al repo ni
al artifact. Antes de etiquetar, actualizar `version` en `pubspec.yaml`. Tras
descargar el artifact `android-aab-*`, validarlo primero en la pista interna de
Play Console.
