# Ficha de Google Play — Solito

Paquete: `com.modavidc.solito` · Idioma: Español (Latinoamérica), `es-419` · Categoría: Finanzas.

## Textos

**Nombre** (26/30)

```
Solito: gastos sin teclear
```

**Descripción breve** (65/80)

```
Deja de anotar tus gastos. Pagas, compartes y se registra solito.
```

**Descripción completa** (1670/4000)

```
¿Pagaste con Yape y ya no te acuerdas de cuánto fue? Tu mente no es una libreta de gastos.

Con Solito pagas, compartes el comprobante y listo: el gasto queda registrado solito, con su monto, categoría y cuenta. Sin teclear.

PAGASTE. COMPARTISTE. SE REGISTRÓ SOLITO.
• Compartir: desde Yape, Plin o la app de tu banco, toca Compartir y elige Solito. Lo lee en un segundo.
• Varios a la vez: comparte todas las capturas de la semana juntas. Solito separa los duplicados y te avisa si falta un dato.
• Captura automática: activa la captura en segundo plano y tus capturas de pantalla o avisos de pago se registran solos.
• Siempre con "Deshacer", por si acaso.

SABES CUÁNTO PUEDES GASTAR HOY
• Pon tu presupuesto del mes y Solito te dice cuánto puedes gastar cada día.
• Mira en qué se te fue la plata: por semana o por mes, con topes por categoría.
• Tus cuentas en un solo lugar: efectivo, bancos, billeteras y tarjetas.
• Racha de días registrando y un recordatorio en la noche, si lo quieres.

¿PAGASTE EN EFECTIVO?
Regístralo en segundos con el teclado rápido, dilo en voz alta o toma una foto a la boleta.

PREGÚNTALE A TU COACH
"¿Me alcanza hasta fin de mes?", "¿cuánto gasté en comida?". Te responde con tus propios números.

TU PLATA ES TUYA. TUS DATOS, TAMBIÉN.
• Sin cuenta: no te pedimos correo ni número.
• Sin claves: nunca tu clave del banco ni de Yape.
• Todo se guarda cifrado en tu teléfono. Los comprobantes se leen en el propio teléfono.
• Sin publicidad. No vendemos tus datos.
• Bloqueo con huella opcional.

Solito no es un banco ni está afiliado a Yape, Plin ni a ninguna entidad financiera. Solo lee los comprobantes que tú compartes o capturas.
```

**Etiquetas sugeridas:** Presupuesto, Finanzas personales, Control de gastos.

## Gráficos

| Archivo | Uso en Play Console |
|---|---|
| `icon-512.png` | Ícono de la app (512×512) |
| `grafico-funciones.png` | Gráfico de funciones (1024×500) |
| `capturas/01_registro.png` … `06_privacidad.png` | Capturas de pantalla del teléfono (1080×1920), en ese orden |

Orden de las capturas (lo importante primero; Coach y lo secundario al final):

1. **Deja de anotar tus gastos.** El comprobante se convierte en "Registrado".
2. **Sabes cuánto puedes gastar hoy.** Movimientos con "Puedes gastar hoy".
3. **¿Siete comprobantes? Compártelos juntos.** Lectura de varias imágenes.
4. **Mira en qué se te fue la plata.** Estadísticas.
5. **"¿Me alcanza hasta fin de mes?"** Coach.
6. **Tu plata es tuya. Tus datos, también.** Sin cuenta, sin claves, sin publicidad.

## Regenerar

Las capturas usan pantallas reales de la app con los datos del prototipo:

```bash
VISUAL_SCALE=3 VISUAL_OUT=<dir>/raw flutter test test/visual
```

Luego se componen con los HTML de `fuentes/` (copiarlos junto a `raw/` y
ejecutar `node render.js 01_registro 02_hoy 03_varias 04_mes 05_coach
06_privacidad feature_graphic` con Playwright).
