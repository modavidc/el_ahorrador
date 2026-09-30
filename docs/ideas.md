# Ideas fuera de la v1

Backlog de ideas. Nada de esto entra a la v1 (ver `README.md`) salvo decisión
explícita.

## Después de la v1

- **Gasto compartido y Round-Robin de grupos** (backend serverless, push,
  deep links). Spec original: `producto/requerimientos-v0.2-gastos-compartidos.md`.
- **Supertransacciones**: PayPal → Ligo → Banco → Binance con comisiones
  automáticas. Detalle en `producto/casos-de-uso.md`.
- Conciliación con estado de tarjeta / Excel, "Alerta de bloqueo manual".
- Binance API (pull de transacciones).
- Separar un Yape en varios gastos por ítem (frutas, bebidas…).
- Proyección económica a 1–2 semanas con IA.
- Sync con Google Tasks (calendario de pagos).
- Integración con "El Estoico" (consejos sobre dinero).
- Captura en segundo plano en iOS (hoy no es posible: solo compartir).
- Mejoras menores del roadmap anterior: detalles sin truncar, detección
  origen/destino en transferencias (Yape → Plin).

## Retención y prueba cerrada (propuestas de setiembre 2026)

Quedan fuera de la v1 porque piden un servidor y cuentas de usuario, y la app
promete "sin cuenta" y datos solo en el teléfono.

- **Monedas por uso** con tope diario. Hoy la IA no le cuesta nada al
  proyecto: la voz y el OCR corren en el teléfono y el Coach usa la clave de
  cada usuario. Tiene sentido si algún día el Coach pasa por un servidor
  propio. Premiar días registrados (la racha) antes que minutos en la app.
- **Panel privado de testers** con `last_active_at`. Durante la prueba cerrada
  basta un grupo de WhatsApp con los testers.
- **Código de referido** para pagar por instalaciones efectivas. En prueba
  cerrada los testers entran por enlace de invitación y la atribución de Play
  no aplica; llevarlo en una hoja de cálculo.
- **Incentivos a testers**: pagar por probar y dar feedback, nunca por
  calificaciones o reseñas (lo prohíbe Google Play). Preferir una recompensa
  fija a un sorteo.
