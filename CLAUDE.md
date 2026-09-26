# Instrucciones de trabajo del repositorio

## Ramas

- La rama principal es `main`. No existe `develop`.
- Cada cambio se hace en una rama corta y entra a `main` por PR con CI en verde.

## Alcance

- El objetivo es la v1 descrita en `README.md` y en `design/`.
- `design/tokens.json` y el prototipo `design/*.html` son la fuente de verdad
  visual. En `lib/ui` todo color, estilo de texto, ícono y sombra sale de
  `lib/theme/design_tokens.dart`; `test/design_tokens_usage_test.dart` falla
  con hex, `fontSize`, `Icons.` o emojis literales.
- Tras cambiar la interfaz, compara con el prototipo:
  `VISUAL_OUT=/tmp/visual flutter test test/visual`.
- Las ideas fuera de la v1 van a `docs/ideas.md`, no a código ni a nuevos `.md`
  en la raíz.

## Documentación

- Specs vigentes en `docs/specs/`. No crear `.md` sueltos en la raíz.
- `assets/import/` contiene datos financieros personales y está en `.gitignore`:
  nunca commitear su contenido.

## Validación antes de subir

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
