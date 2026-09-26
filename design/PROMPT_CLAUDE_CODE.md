# Cómo usarlo con Claude Code

1. Descomprime esta carpeta dentro de tu repo como `design/`.
2. Abre la terminal en la raíz del repo y ejecuta `claude`.
3. Pega los prompts **uno por fase**. Revisa y haz commit al terminar cada una.

---

## Fase 0: Contexto (pégalo primero)
Lee `design/README.md` y `design/tokens.json`. `design/Money Manager IA v2.dc.html` es un prototipo HTML de referencia (no se copia: se recrea en nuestro stack). Explora el repo y dime: el stack, dónde viven hoy los estilos/tema, cómo está la navegación y el modelo de transacciones. Todavía no cambies nada.

## Fase 1: Tema
Crea el tema de la app con exactamente los tokens de `design/tokens.json`, en el formato nativo del stack y con nombres semánticos. Después busca en todo el repo colores, fontSize, paddings, radios y sombras escritos a mano y reemplázalos por tokens. Si algo no encaja, pregúntame. Añade una regla de lint o un test que falle si aparece un hex o un fontSize literal fuera del tema. Reemplaza los emojis por Material Symbols Rounded.

## Fase 2: Navegación y Trans.
Implementa el bottom nav de 5 items (Trans., Estad., Coach, Cuentas, Ajustes) y el FAB con su menú, según el README. Luego la pantalla Trans. con sus 4 pestañas: Diario (fila compacta como componente reutilizable), Calendario, Mensual y Total.

## Fase 3: Estadísticas
Estadísticas con dona + lista, y la pantalla de detalle de categoría (subcategorías, línea de 6 meses, movimientos). Usa la librería de gráficos que ya tenga el repo; si no hay ninguna, propón una antes de instalarla.

## Fase 4: Cuentas y Ajustes
Cuentas con saldos calculados (saldo inicial + movimientos) y la pantalla Ajustes con los toggles persistidos.

## Fase 5: Coach
Implementa la pantalla Coach: los 4 insights se calculan localmente con las fórmulas descritas en el README. El chat llama al LLM que ya usemos, mandando como contexto los agregados del mes (totales por categoría, presupuesto, proyección y suscripciones), no todas las transacciones. Tono: consejos de decisión, sin emojis.

## Fase 6: Datos mock (opcional)
Crea un seed de desarrollo con datos de junio a septiembre de 2026, equivalente a `genData()` del prototipo, detrás de un flag de desarrollo.
