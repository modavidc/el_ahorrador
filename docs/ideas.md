# Ideas fuera de la v1

Backlog de ideas. Nada de esto entra a la v1 (ver `README.md`) salvo decisión
explícita.

## Captura automática (entra a la v1, fase 5)

> Ícono de sistema arriba (como el de datos) y, cuando detecte una captura de
> pantalla, que la autolea. Acceso a fotos para que lea todos los Yapes y los
> procese al toque.

- Android: vigilar las capturas nuevas; para que funcione con la app cerrada
  hace falta un servicio en primer plano con notificación persistente.
- iOS: no es posible en segundo plano; solo compartir con la app.

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
- Recordatorio diario de registrar gastos ("Modo registra los gastos").
- Mejoras menores del roadmap anterior: detalles sin truncar, detección
  origen/destino en transferencias (Yape → Plin).
