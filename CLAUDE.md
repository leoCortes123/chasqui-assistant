# Chasqui Assistant

Asistente de WhatsApp para clínicas veterinarias. Primer caso: **demo comercial
para Abanimal Clínica Veterinaria** (Bogotá), centro de referencia nacional en
imágenes diagnósticas.

Antes de trabajar, leer en este orden:
1. `docs/PROPUESTA.md` — el negocio, el diagnóstico y qué se prometió
2. `docs/PLAN.md` — qué podar, qué construir y en qué orden
3. `README.md` — puertos, estructura, cómo arranca

---

## Origen

Copia de trabajo de `../chasquiPet`, renombrada y repuerteada. Se copió el
sistema completo y funcionando porque las migraciones de Chasqui Pet se
referencian de forma cruzada y extraer "solo lo reutilizable" produce una base
que no arranca.

**Fases 0 y 1 hechas.** `db/migrations/` se vació y se repobló con numeración
nueva (`010`–`900`); el sistema levanta desde cero sin errores. El eje `usuario`
se generalizó a **`actor`** (contacto anónimo o usuario interno) y el catálogo
de herramientas se filtra por **audiencia** (`publica` / `interna`) antes que
por permiso. Falta el dominio: estudios, tarifas, agenda, triaje y el catálogo
de herramientas.

`referencia/` contiene el Chasqui Pet original SIN renombrar. Es material de
consulta: no se compila, no se ejecuta y no se edita.

---

## Principios heredados — se respetan

Vienen de Chasqui Pet y no se renegocian:

- **La base de datos es la fuente única de verdad.** El comportamiento vive en
  filas y funciones de Postgres, no en código de n8n ni del worker.
- **Los permisos son datos**, nunca constantes en código.
- **El asistente no escribe SQL.** Tiene un catálogo cerrado de herramientas
  (`ia_herramienta`) que llaman a las mismas funciones que usan los botones.
- **Leer se hace solo; escribir se confirma con un botón.** Toda herramienta con
  `escribe = true` deja una propuesta y la dispara la persona, no el modelo.
- **Append-only real** sobre auditoría: la aplicación no tiene `DELETE`. Se
  corrige con un registro inverso, no editando el original.
- **El webhook responde en menos de un segundo.** Todo lo lento va a la cola
  `tarea_async` y lo procesa el worker.
- **Todo en español**: nombres de tablas, funciones, variables, comentarios y
  mensajes al usuario.

## Principios propios de este proyecto

- **El bot nunca diagnostica ni aconseja tratamiento.** Ante una urgencia corta
  el flujo, da instrucciones de traslado y escala a un humano. Este límite es
  parte de la venta, no una limitación a disimular.
- **Las instrucciones de urgencia son datos literales, no texto generado.**
  Viven en `cuadro_urgencia.instruccion` (`130_triaje.sql`) y el bot las recita
  sin reescribirlas: a un atropellado hay que moverlo rígido y a un convulsivo
  hay que no meterle la mano en la boca, y esas diferencias no se improvisan.
  Se aprueban con `aprobada_por`; `v_urgencia_sin_aprobar` lista las que no.
- **La detección de urgencia y de «ASESOR» ocurre antes que el modelo**, en
  `asistente_recibir`, con un `SELECT`. Un límite clínico que depende de que el
  modelo se acuerde de llamar una herramienta se pierde el día que se distrae.
- **Un campo vacío en el contexto es una invitación a alucinar.** Con la sede
  sin sembrar, el modelo inventó dirección y horario completos. Cada dato del
  prompt necesita su rama de «no lo tengo», no solo la de «aquí está».
- **El asistente conversa con LAER** (escuchar, reconocer, explorar, responder)
  y cierra cada mensaje proponiendo el siguiente paso: el objetivo es que el
  paciente llegue a la clínica, igual que el de la persona que hoy atiende ese
  chat. Se propone una vez y se acepta el no.
- **Suena como persona, pero no miente sobre serlo.** Si le preguntan de frente
  si es un bot, lo dice. Es el único límite que no se negocia por naturalidad.
- **Ningún precio sale de la memoria del modelo.** Siempre `cotizar_estudio`:
  la tarifa cambia domingos y festivos, y `festivo_colombia` tiene el
  calendario. Las cifras con `estimado = true` se dan como referencia y se
  aclara en la misma frase que el profesional define el valor final.
- **Siempre hay salida a humano.** "ASESOR" en cualquier momento; el bot se
  calla en ese hilo hasta que la persona lo devuelva.
- **El antiduplicado de historia clínica es requisito, no mejora.** Abanimal
  declara el problema por escrito en su propio formulario.
- **Los recordatorios de preparación son clínicos.** Si el paciente rompe el
  ayuno se pierde el estudio y el cupo. El aviso de las 8 pm no es opcional.

---

## Puertos

Conviven tres sistemas en la misma máquina:

| | Chasqui (n8n) | Chasqui Pet | **este** |
|---|---|---|---|
| Postgres | 5432 | 5433 | **5434** |
| n8n | 5678 | 5679 | **5680** |
| Portal | — | 3100 | **3200** |
| Proxy | — | 8081 | **8082** |

Volúmenes: `chasqui_assistant_pgdata`, `chasqui_assistant_n8ndata`,
`chasqui_assistant_caddydata`. **Nunca tocar los volúmenes de `chasquipet_*`:
ese sistema está en manos de un cliente esperando confirmación.**

---

## Reglas de operación

- "Sube los servicios" significa `docker compose up -d`. Nunca `down`, nunca
  recrear contenedores, salvo pedido explícito.
- `db/migrations/` solo corre con el volumen vacío. Para rehacer el esquema en
  desarrollo hay que borrar `chasqui_assistant_pgdata` — verificar el nombre
  antes de borrar nada. Para *probar* un cambio de esquema, un Postgres
  desechable con las migraciones montadas (ver README) evita tocar el volumen.
- **Los permisos se siembran antes que cualquier catálogo que los referencie.**
  Chasqui Pet no lo hacía y por eso no inicializa desde cero: `078` insertaba
  `ia_herramienta` con FK a `permiso` antes de que `100_seed_roles` lo creara.
  Por eso `090_seed_roles.sql` va antes del dominio.
- Las migraciones del dominio van de `100` a `150`; el seed operativo, `810`.
