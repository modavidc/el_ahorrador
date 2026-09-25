# Instrucciones de trabajo del repositorio

## Ramas

- La rama principal es `main`. No existe `develop`.
- Cada cambio se hace en una rama corta y entra a `main` por PR con CI en verde.

## Alcance

- El objetivo es la v1 descrita en `README.md` y en `design/`.
- `design/tokens.json` es la fuente de verdad visual: nada de colores, fontSize,
  paddings o radios literales en pantallas nuevas.
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
