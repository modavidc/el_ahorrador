¡Ya entendí 👌! Tú lo que quieres ahora es que todo lo que hemos hablado (OCR → registro automático, gastos compartidos, round-robin, etc.) quede condensado en un **nuevo listado de requerimientos** que sustituya al anterior. Te lo dejo armado como **v0.2 – Documento de Requerimientos**:

---

# 📘 Documento de Requerimientos – **Mis Gastos (v0.2)**

## 1) Objetivo del producto

* Evitar **registro manual** de gastos copiando datos.
* Capturar datos desde:

  * **Compartir imágenes, facturas, capturas, cuadernos** → OCR en dispositivo.
  * **Texto o links compartidos** → parser automático.
* Permitir **compartir gastos** con 3–4 personas de manera sencilla.
* Gestionar grupos grandes (20–30 personas) con un sistema **Round-Robin colaborativo** para rotar quién paga o colabora.

---

## 2) Funciones principales (MVP v0.2)

1. **Registro automático de gastos** vía OCR en dispositivo (ML Kit/Tesseract).
2. **Share-to-Transaction**: desde cualquier app, enviar texto/imagen/link → transacción prellenada.
3. **Gasto compartido**:

   * Usuarios de la app → notificación push con botón **Importar**.
   * No usuarios → deep link por WhatsApp/SMS (landing ligera).
4. **Round-Robin Colaborativo**:

   * Grupos de 20–30.
   * Rotación justa usando historial, cooldown y límites.
   * Reasignación automática en caso de rechazo o timeout.
5. **Multi-cuenta / multi-moneda** (conversión básica en local).
6. **Reportes básicos** (categoría/mes, balance).
7. **Exportación CSV/Excel** y backup local (Drive manual).
8. **Seguridad y privacidad**:

   * Todo OCR y parsing en local.
   * Tokens firmados con TTL para gastos compartidos.
   * PIN/biometría para abrir la app.

---

## 3) Reglas de negocio

* **Umbral mínimo**: no mostrar opción de compartir/round-robin si el gasto < S/3 (configurable).
* **Cooldown**: miembro asignado queda en reposo 48h.
* **Ventana anti-repetición**: un mismo miembro no se repite en las últimas K=3 asignaciones.
* **Límite de aportes por período**: configurable (ej. 2 por semana).
* **Fallback**: si todos están en cooldown/límite, se elige el menos reciente.

---

## 4) Modelo de datos (nuevo + existente)

* **groups** (id, name, description, created\_at).
* **group\_members** (id, group\_id, phone/email, is\_active, role, weight, cooldown\_until).
* **rr\_cycles** (id, group\_id, name, period, start\_at, end\_at, max\_contrib\_per\_period, status).
* **rr\_assignments** (id, cycle\_id, member\_id, due\_date, status, reason, created\_at).
* **shared\_expenses** (id, owner\_user\_id, expense\_payload JSON, token, expires\_at, created\_at).
* **push\_devices** (id, user\_id, device\_token, platform, updated\_at).
* **expenses** (id, type, amount, currency, account\_id, category\_id, notes, sourceHash).
* **categories, accounts, attachments** (igual a v0.1).

---

## 5) Algoritmo Round-Robin

1. Obtener miembros activos (`is_active = true`).
2. Ordenar por:

   * Menos aportes en el período.
   * No haber estado en últimas K asignaciones.
   * Peso (priorizar quien menos ha aportado).
   * Id estable como desempate.
3. Saltar miembros en cooldown o con límite alcanzado.
4. Si todos bloqueados → relajar reglas y elegir el menos reciente.

---

## 6) UX / Flujos

* **Botón flotante +** → pestañas: Ingreso, Gasto, Transferencia.
* **Flujo Compartir**:

  1. Compartir desde otra app → abrir pre-formulario con campos detectados (monto, fecha, moneda, categoría sugerida).
  2. Usuario confirma/edita → Guardar.
* **Gasto compartido**:

  * Selección rápida de 3–4 contactos.
  * Invitación vía push (usuarios) o deep link (no usuarios).
* **Round-Robin**:

  * Vista de grupo → ciclo activo → muestra “Próximo responsable”.
  * Botones: **“Lo cubro”** (DONE) / **“No puedo”** (DECLINED).
  * Historial transparente visible.

---

## 7) Backend mínimo (serverless)

* **/share**: crear/aceptar gasto compartido (con token y TTL).
* **/groups**: CRUD grupos y miembros.
* **/cycles**: crear ciclo, consultar próximo responsable.
* **/assignments**: cambiar estado (ASSIGNED → DONE/DECLINED/SKIPPED).
* **Push**: FCM para notificaciones.
* **Storage**: KV/Supabase con TTL para tokens.

---

## 8) Métricas (locales, sin costo)

* % de gastos registrados por OCR vs manual.
* % de gastos compartidos importados.
* Tiempo medio de resolución de una asignación RR.
* Equidad: distribución de aportes entre miembros.

---

## 9) Roadmap

* **v0.2**:

  * Tablas `groups`, `rr_cycles`, `rr_assignments`, `shared_expenses`.
  * UI básica de grupos, ciclo RR y compartir gasto.
  * Umbral S/3 + cooldown 48h + ventana K=3.
* **v0.3**:

  * Pesos dinámicos, transparencia (ranking aportes).
  * Export CSV por grupo/ciclo.
* **v0.4**:

  * Reglas avanzadas (cap por mes, feriados).
  * Integración opcional Yape/Plin como comprobante.
  * Admin web ligera.

---