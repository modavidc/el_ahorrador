# Matriz de permisos, capacidades y datos

Revisión estática al 23 de julio de 2026. Debe repetirse sobre cada binario
release porque plugins/SDKs pueden agregar declaraciones durante el merge.

| Plataforma | Declaración/capacidad | Justificación observable | Acción |
| --- | --- | --- | --- |
| Android release | Sin `uses-permission` directo en manifest principal | Imágenes mediante `SEND`/`SEND_MULTIPLE`, copiadas al sandbox | Mantener mínimo; revisar manifest fusionado |
| Android debug/profile | `INTERNET` | Flutter tooling | No publicar esos artefactos |
| Android | Activity exportada, filtros `image/*` | Recibir capturas compartidas | Probar URI temporal, tipos/tamaños inválidos y remitente hostil |
| Android | Biometría (normalmente fusionada por `local_auth`) | Bloqueo local opcional | Confirmar permiso final, cancelación y fallback |
| Android | Backup desactivado y exclusiones | No extraer datos financieros | Confirmar en binario y prueba backup/restore |
| iOS | `NSFaceIDUsageDescription` | Proteger datos con Face ID | Declarado; probar en dispositivo |
| iOS | Keychain vía `flutter_secure_storage` | Guardar clave de base cifrada | Revisar accesibilidad, update/reinstall |
| iOS | Fotos/cámara | No hay selector/captura directa ni claves de uso | No declarar ni afirmar acceso |
| iOS | Share Extension/App Group | Recibir imágenes elegidas desde Compartir | Configurados; registrar `group.com.misgasticos.app` y probar en dispositivo |
| Ambas | Red/Sentry si hay DSN | Telemetría técnica sin PII | Documentar endpoint, base legal y retención |
| Ambas | OCR/almacenamiento local | Procesar y retener capturas | Verificar que no sube datos y definir borrado |

## Gate

- [ ] Archivar Android merged manifest e inspeccionar entitlements/Info.plist del archive.
- [ ] Instalación limpia sin solicitudes ajenas a esta matriz.
- [ ] Cada permiso nuevo enlaza requisito, UX de denegación y prueba.
- [ ] Formularios de tiendas y política coinciden con comportamiento y SDKs.
- [ ] Logs/crashes no incluyen imagen, OCR, ruta, cuenta, monto ni base de datos.

Un permiso final no listado bloquea el release. No añadir almacenamiento amplio
para procesar URIs compartidos puntuales.
