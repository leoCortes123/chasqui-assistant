# Plan — del Chasqui Pet renombrado al demo de Abanimal

Estado al crear el repositorio: copia funcional de Chasqui Pet, renombrada
(`chasqui_assistant`) y repuerteada (5434 / 5680 / 3200 / 8082). **No se ha
podado nada todavía.**

Objetivo: demo presentable en ~1 semana de trabajo.

---

## Fase 0 — Verificar que la copia arranca

Antes de tocar nada, comprobar que el sistema heredado levanta con sus puertos
nuevos y sin chocar con Chasqui Pet.

- [ ] `cp .env.example .env` y completar claves
- [ ] `docker compose --profile local up -d`
- [ ] Base inicializada sin errores (`docker compose logs db`)
- [ ] Portal responde en `:3200/health`
- [ ] Chasqui Pet sigue en pie

Sin esto, cualquier error posterior es ambiguo.

---

## Fase 1 — Poda

Quitar lo que Abanimal no necesita. El orden importa: las migraciones se
referencian entre sí.

### Migraciones a eliminar
`030_turnos.sql`, `035_aviso_turno.sql`, `040_bot_turnos.sql`,
`045_inventario.sql`, `046_bot_inventario.sql`, `060_cobro.sql`,
`066_bot_cobro.sql`, `070_compras.sql`, `076_bot_compras.sql`.

### Migraciones a limpiar tras la poda
Estas referencian tablas que dejan de existir; hay que quitarles esas partes:

| Archivo | Referencias a quitar |
|---|---|
| `010_base.sql` | seeds de `config` de turnos, caja e inventario |
| `050_pacientes.sql` | vínculo consulta↔turno, consulta↔cuenta, descargo de inventario |
| `078_chasqui_ia.sql` | herramientas de turnos, inventario, cobro y compras del catálogo `ia_herramienta` |
| `080_reportes.sql` | reportes de caja, inventario y compras |
| `085_admin.sql` | administración de inventario y turnos |
| `088_mantenimiento.sql` | poda de `movimiento_inventario` |
| `090_grants.sql` | append-only sobre `movimiento_inventario` (conservarlo sobre `evento_auditoria`) |
| `100_seed_roles.sql` | permisos de turnos, caja, inventario y compras |
| `110_seed_operativo.sql` | seeds de turnos y compras |

### Worker
Eliminar `tareas/abrir_cuenta_turno.js`, `agregar_linea_cuenta.js`,
`alertas_inventario.js`, `enviar_recibo.js`, `notificar_turno_llamado.js`,
`notificar_turnos_proximos.js`, `recordar_llamado_vencido.js`, y sus entradas en
`tareas/index.js`. En `src/index.js`, quitar `marcarAviso` /
`aviso_turno_enviado`.

### Web
Eliminar `app/pantalla/`, `app/api/pantalla/`, `app/(portal)/inventario/`,
`app/(portal)/compras/`, y las secciones de caja del dashboard. Conservar
`entrar/`, `(portal)/layout`, `admin/`, `pacientes/`, `consulta[s]/`, `lib/`.

### n8n
`02-job-turnos.json` y `03-job-inventario.json` se van.
`01-telegram-webhook.json` se conserva como patrón para el webhook de WhatsApp.

### Demo
`db/demo/` completo se reescribe (§ Fase 3).

**Criterio de cierre de fase:** volumen `chasqui_assistant_pgdata` borrado, el
sistema levanta desde cero sin errores, se entra al portal y se ve un paciente.

---

## Fase 2 — Dominio de Abanimal

Migraciones nuevas, numeradas después de las heredadas.

### `120_estudios.sql` — catálogo y tarifas
- `estudio`: código, nombre, modalidad (ecografía / tomografía / radiología /
  endoscopia / intervencionismo), duración en minutos, requiere cita previa.
- `tarifa`: precio por estudio y por tipo de día. **Regla real conocida:**
  ecografía abdominal $172.000 lunes a sábado, $187.000 domingos y festivos.
- `festivo_colombia`: los festivos son ley 51 de 1983 (lunes trasladados); sin
  esta tabla la cotización se equivoca. Sembrar 2026 y 2027.
- `preparacion`: reglas por estudio. La primera y más importante: **ayuno de 8
  horas, sin alimento líquido ni sólido**, para ecografía abdominal.
- Función `cotizar_estudio(estudio, fecha)` → precio + texto de preparación.

### `130_agenda.sql` — disponibilidad y citas
`050_pacientes.sql` ya trae `cita` y `disponibilidad`; aquí se activan.
- Bloques por modalidad y por equipo (el TAC es uno solo: no se puede
  sobreagendar).
- `horarios_disponibles(estudio, desde, hasta)` → lista de cupos libres.
- `agendar_cita`, `reagendar_cita`, `cancelar_cita`.
- `lista_espera`: al liberarse un cupo, se ofrece al siguiente. Este es el
  argumento económico del demo (§ PROPUESTA 4).

### `140_conversacion.sql` — estado del chat
- `conversacion`: un hilo por número de WhatsApp, con estado e intención.
- `mensaje`: entrada y salida, para el panel y para auditar qué dijo el bot.
- **Traspaso a humano:** bandera `atendida_por_humano`. Mientras esté activa el
  bot no responde en ese hilo. Se activa con "ASESOR" o por escalamiento.

### `150_triaje.sql` — urgencias
- `termino_urgencia`: convulsión, atropellado, no respira, sangra, intoxicación,
  parto, torsión, y variantes. Datos, no constantes en código.
- Al detectar: cortar el flujo, entregar instrucciones de traslado y dirección,
  marcar la conversación, encolar alerta al personal.
- **El bot nunca diagnostica ni aconseja tratamiento.** Este límite se prueba en
  vivo en la Escena 3 del demo.

### `160_ia_veterinaria.sql` — herramientas del asistente
Reemplaza el catálogo `ia_herramienta` de Chasqui Pet con las de este dominio:
cotizar, consultar disponibilidad, registrar tutor y paciente, agendar,
reagendar, cancelar, consultar cita. Se conserva intacta la regla heredada:
**leer se hace solo, escribir se confirma con un botón.**

### `170_registro.sql` — antiduplicado
El problema que Abanimal declara por escrito. Buscar por celular normalizado y
por documento antes de crear un `dueno`; si hay coincidencia, ofrecer confirmar
el paciente existente en vez de pedir los 11 campos.

---

## Fase 3 — Canal de WhatsApp

- Workflow n8n `01-whatsapp-webhook.json`, calcado de
  `01-telegram-webhook.json`: verificación del webhook (GET `hub.challenge`),
  recepción de mensajes, respuesta en menos de un segundo, todo lo lento a
  `tarea_async`.
- `worker/src/whatsapp.js`, equivalente de `telegram.js`: envío de texto,
  botones interactivos y plantillas.
- Transcripción de notas de voz (la gente manda audio).
- **Recordatorios programados** como tareas de la cola:
  - 8 pm del día anterior → aviso de ayuno.
  - 2 horas antes → confirmación con botón; si dice que no, liberar el cupo y
    ofrecerlo a la lista de espera.

### Credenciales
No hay número de producción de Meta. Para el demo:
1. **Número sandbox de Meta Cloud API** — funciona en celulares registrados
   previamente. Es lo que permite que el prospecto pruebe desde su propio
   teléfono (Escena 2).
2. **Simulador de chat en el portal** (`/simulador`) — respaldo obligatorio: si
   falla la red o el sandbox en la reunión, el demo sigue.

Construir el simulador primero. No depende de nadie externo.

---

## Fase 4 — Panel y datos del demo

- Vista de agenda del día.
- Conversaciones activas, con urgencias en rojo.
- Cupos liberados y lista de espera.
- `db/demo/`: catálogo real de estudios de Abanimal, agenda de una semana
  parcialmente ocupada, algunos pacientes con historia previa (para que el
  antiduplicado se pueda demostrar en vivo).

---

## Fase 5 — Ensayo

Cronometrar la Escena 2: el objetivo es **90 segundos** de principio a fin.
Ensayar con la red caída para verificar que el simulador cubre.

---

## Pendientes de información

Bloquean parte del alcance, no el demo:

1. Software de historia clínica que usa Abanimal (¿tiene API?).
2. Tabla de precios completa — solo se conoce ecografía abdominal.
3. Volumen real de mensajes por día y cuántas personas atienden el chat.
4. Si los tres números de WhatsApp se pueden unificar en uno.

Ver [`PROPUESTA.md`](PROPUESTA.md) § 6.
