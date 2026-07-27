# Preparación de release

Estado estático revisado el 25 de julio de 2026. Estos documentos son gates de
evidencia: no demuestran por sí solos una publicación ni sustituyen las pruebas
del artefacto instalado desde la tienda.

| Área | Estado observable en el repositorio | Evidencia pendiente fuera del repo |
| --- | --- | --- |
| Android | ID `com.misgasticos.app`; firma sin fallback debug; AAB release local firmado y verificado | AAB con upload key real, Play Internal testing y pre-launch report |
| iOS | IDs definitivos, App Group y Share Extension para imágenes configurados; firma automática | Asignar Team, registrar IDs/App Group, instalar pods y validar Archive/TestFlight en macOS |
| Web/escritorio | Proyectos Flutter presentes | Builds e instalación no validados; fuera del alcance de la beta móvil |
| Privacidad | Matriz estática y checklist de fichas | Política/soporte públicos y formularios aprobados en tiendas |

## Gates locales

```powershell
dart run tool/check_release_identifiers.dart
dart run tool/check_release_readiness.dart
flutter analyze
flutter test
```

El primer comando falla mientras cualquier identificador de ejemplo permanezca
en Android o iOS. El segundo comprueba versión, controles estáticos, documentos
y exclusiones de secretos; no necesita credenciales ni imprime su contenido.

## Definition of done móvil

- [ ] [Android/Play](android-play.md) acreditado con AAB e instalación desde Play.
- [ ] [iOS/App Store](ios-app-store.md) acreditado con Archive y TestFlight, si entra en la beta.
- [ ] [Permisos y datos](permissions.md) contrastados con los binarios finales.
- [ ] [Fichas](store-listings.md), política, soporte y proceso de borrado públicos.
- [ ] [Plantilla de evidencia](release-evidence.md) completa para un único commit.
- [x] [Evidencia local del 25 jul 2026](evidence-local-2026-07-25.md) registrada; no sustituye la instalación desde tienda.
- [ ] Versión/build mayor que cualquier número previamente usado en cada tienda.

Nunca versionar llaves, certificados, perfiles, contraseñas, tokens ni
credenciales. Para una beta solo Android, declarar iOS fuera de alcance en vez
de presentar su proyecto existente como una plataforma validada.
