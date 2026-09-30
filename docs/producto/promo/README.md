# Promoción de Solito

| Archivo | Qué es |
|---|---|
| `merch.png` | Polo papel (pecho y espalda), polo rojo, polerón tinta y polo de la marca modavidc.com |
| `banner-rollup-85x200.png` | Roll-up de 85×200 cm (arte a 10 px/cm; pedir a la imprenta el vector desde `fuentes/banner.html`) |
| `flyer-a6-frente.png`, `flyer-a6-reverso.png` | Folleto A6 (105×148 mm) a 300 ppp |

El QR apunta a `https://modavidc.com/solito`: una redirección que tú controlas.
Hoy puede llevar al link de la prueba cerrada y, cuando la app sea pública, a
`https://play.google.com/store/apps/details?id=com.modavidc.solito`, sin
reimprimir nada.

Los HTML de `fuentes/` se renderizan con Playwright (`node r.js`) y usan las
fuentes de `assets/fonts/` y las pantallas de `test/visual` (`VISUAL_SCALE=3`).
