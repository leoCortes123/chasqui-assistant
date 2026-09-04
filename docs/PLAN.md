# Plan — de la copia de Chasqui Pet al demo de Abanimal

**Estado: fases 0 y 1 hechas.** El núcleo está construido, el sistema levanta
desde cero sin un solo error y el circuito mensaje → cola → worker → respuesta
cierra de extremo a extremo. Falta el dominio (fase 2).

Objetivo: demo presentable, con un núcleo conversacional que sirva para el
siguiente cliente sin volver a empezar.

---

## Cambio de rumbo: no se poda, se refunda por copia selectiva

La primera versión de este plan proponía **podar** la copia heredada: borrar 9
migraciones y editar quirúrgicamente otras 10. Se descarta, por tres razones.

1. **El costo es el mismo y el riesgo es peor.** Podar no es borrar archivos:
   es corregir `050`, `078`, `080`, `085`, `090`, `100` y `110` sin romper
   referencias cruzadas. Y para validar hay que borrar el volumen y levantar de
   cero igual. Se paga el mismo precio con un modo de falla silencioso — un
   seed que ya no aplica, un permiso que nadie otorga, una vista que consulta
   una tabla vacía en vez de inexistente.
2. **Queda lastre conceptual.** `turno`, `consultorio`, `sesion_consultorio`,
   `cuenta`: vocabulario que en Abanimal no significa nada, pero que sobrevive
   dentro de funciones que sí se conservan.
3. **No resuelve la ruptura real** (§ siguiente), que es lo único que de verdad
   hay que diseñar.

Refundar **no** significa reescribir. Significa un `db/migrations/` vacío que se
repuebla copiando archivos verbatim desde `../chasquiPet`, en un orden nuevo.
Lo que no se copia, no existe — y una referencia a una tabla que no se copió
**revienta al primer arranque**, en voz alta, en vez de quedar viva y muda.

> `referencia/` de este repositorio **solo contiene documentación** de Chasqui
> Pet, no su código. La fuente de copia es el repositorio hermano
> `../chasquiPet`, o el árbol actual antes de vaciarlo.

---

## La ruptura real: el núcleo heredado no es genérico todavía

`078_chasqui_ia.sql` es el activo del proyecto: 1069 líneas que ya implementan
catálogo cerrado de herramientas, `ia_leer` / `ia_escribir`, propuesta con
confirmación por botón y salida en el formato de *function calling*. Eso es el
core reutilizable para cualquier negocio que atienda por chat.

Pero está construido para **personal interno**. Todo pivota sobre un usuario
autenticado:

| Función | Supuesto |
|---|---|
| `ia_disponible(p_usuario_id)` | exige fila en `usuario`, activa |
| `ia_herramientas(p_usuario_id)` | filtra el catálogo por `tiene_permiso(...)` |
| `ia_contexto(p_usuario_id, p_sede_id)` | asume sesión abierta en un consultorio |
| `ia_historial(p_chat_id bigint)` | el hilo es un `chat_id` de Telegram |

El bot de Abanimal atiende al **público**: un número de WhatsApp desconocido,
sin fila en `usuario`, sin rol y sin permisos. Ninguna poda arregla eso.

**La generalización:** sustituir el eje `usuario` por **`actor`** —
un contacto anónimo o un usuario interno — y filtrar el catálogo por
**audiencia** (`publica` / `interna`), no por permiso. `tiene_permiso` no
desaparece: sigue aplicando, pero solo al actor interno. El principio heredado
—*los permisos son datos*— se mantiene; se le agrega un eje.

Este es el único diseño nuevo de verdad. Todo lo demás es copiar o escribir
dominio.

---

## Arquitectura en dos capas

```
núcleo    genérico, agnóstico del negocio y del canal
          config · auditoría · cola · identidad · actor · conversación
          motor del asistente · auth del portal · grants

dominio   veterinario, específico de Abanimal
          dueño · paciente · estudios · tarifas · agenda · triaje
          catálogo de herramientas · antiduplicado
```

La frontera se respeta en las dos direcciones: **ninguna migración del núcleo
menciona un estudio, una cita ni un paciente.** Si el núcleo necesita saber algo
del negocio, lo lee de `config` o de una tabla de datos, no de una constante.

Esa disciplina es lo que permite que el siguiente cliente sea `dominio/` nuevo
sobre el mismo núcleo.

---

## Fase 0 — Verificar que la copia arranca ✔

- [x] `cp .env.example .env` con secretos aleatorios
- [x] `docker compose --profile local up -d`
- [x] Chasqui Pet sigue en pie, con sus volúmenes intactos
- [x] Portal responde en `:3200/health`
- [ ] ~~Base inicializada sin errores~~ — **no inicializa**

### El hallazgo: la copia heredada no arranca desde un volumen vacío

```
running /docker-entrypoint-initdb.d/078_chasqui_ia.sql
psql:078_chasqui_ia.sql:246: ERROR: insert or update on table "ia_herramienta"
violates foreign key constraint "ia_herramienta_permiso_fkey"
```

`078` siembra el catálogo `ia_herramienta` con una FK a `permiso`, pero los
permisos se crean en `100_seed_roles.sql`, que corre **después**. La
inicialización aborta ahí y `080`, `085`, `088`, `090`, `100`, `110` y `900`
nunca corren: no existe el rol `chasqui_assistant_app`, el worker cicla con
*password authentication failed* y el portal responde 503.

No es del renombrado: `../chasquiPet` tiene el mismo orden. Su volumen de
producción se creó bajo otra numeración; el árbol actual, desde cero, no
arranca.

**La regla que sale de aquí, y que la fase 1 aplica:** los permisos se siembran
antes que cualquier catálogo que los referencie. Por eso `090_seed_roles.sql`
va antes del dominio, y no al final como en Chasqui Pet.

Lejos de bloquear la refundación, la confirma: el modo de falla silencioso que
el plan temía de la poda ya estaba ahí, y solo se vio al levantar de cero.

---

## Fase 1 — El núcleo ✔

`db/migrations/` se vació y se repobló. Numeración nueva desde `010`: es un
esquema nuevo, no una continuación. Quedó así:

| Archivo | Origen | Trabajo |
|---|---|---|
| `000_n8n_db.sh` | igual | copia |
| `010_base.sql` | `010_base.sql` | verbatim + `esc`/`pesos`/`fmt_cant` y el canal `whatsapp` en auditoría |
| `020_identidad.sql` | `020_identidad.sql` | **verbatim** |
| `030_actor.sql` | — | **nuevo** |
| `040_asistente.sql` | `078_chasqui_ia.sql` | reenganche al eje `actor` |
| `050_auth_web.sql` | `058_auth_web.sql` + `077_portal_enlace.sql` | verbatim, fusionados, sin los despachadores de seis módulos |
| `060_admin.sql` | `085_admin.sql` | sin medicamentos, tarifas ni libro de inventario |
| `070_mantenimiento.sql` | `088_mantenimiento.sql` | sin inventario; se le suma la poda de propuestas y memoria |
| `090_seed_roles.sql` | `100_seed_roles.sql` | **reescrito** — y adelantado, por el hallazgo de la fase 0 |
| `095_seed_nucleo.sql` | parte de `110_seed_operativo.sql` | config genérica, sede y `crear_superadmin_inicial` |
| `900_grants.sql` | `090_grants.sql` | append-only sobre `evento_auditoria` y **`mensaje`** |
| `900_superadmin.sh` | igual | copia |

Dos archivos que el plan no había previsto:

- **`060_admin.sql`** — el portal de administración (usuarios, roles, config,
  auditoría, cola de tareas) llama veinte funciones que vivían en `085`. Sin
  ellas el portal no compila, y «se entra al portal» era el cierre de la fase.
  Es núcleo genuino; lo que se dejó fuera fue el catálogo de medicamentos, las
  tarifas y el libro de movimientos.
- **`095_seed_nucleo.sql`** — sin `crear_superadmin_inicial` no hay con quién
  entrar. Trae config genérica y una sede sin nombre real: los datos de
  Abanimal son fase 2.

`sede` y `consultorio` **se conservan** en `010_base.sql`. Cuesta cero (son 30
líneas), `sede_id` está por todas partes y `sede` carga dirección y teléfono,
que el bot necesita para responder ubicación y horarios. Simplemente no se
siembran consultorios.

### `030_actor.sql` — nuevo, el cimiento que faltaba

Adelantado desde lo que la versión anterior del plan llamaba `140_conversacion`.
No es dominio: es cimiento, y va antes del motor del asistente.

- `contacto`: identidad externa. Celular normalizado con índice único —
  la normalización es la mitad del antiduplicado y vive aquí, no en el dominio.
  Un `contacto` puede o no tener `usuario_id`.
- `conversacion`: un hilo por contacto y canal. Estado, intención,
  `atendida_por_humano`. Mientras esa bandera esté activa **el bot no responde
  en ese hilo**; se levanta con "ASESOR" o por escalamiento, y solo la baja una
  persona.
- `mensaje`: entrada y salida, con canal y payload crudo. Sirve al panel y a la
  auditoría de qué dijo el bot — que es lo que se muestra en la Escena 3.
- El canal es una columna, no una tabla aparte: `whatsapp`, `telegram`,
  `simulador`. El simulador del portal no es un caso especial, es un canal más.

### `040_asistente.sql` — el reenganche

Único archivo heredado que se edita de verdad. Concentrado, no disperso.

- `ia_disponible(actor)`, `ia_herramientas(actor)`, `ia_contexto(actor)`:
  reciben actor en vez de `usuario_id`.
- `ia_herramienta` gana columna `audiencia`. `ia_herramientas` filtra por
  audiencia primero, y por `tiene_permiso` solo cuando el actor es interno.
- `ia_historial` se ata a `conversacion_id`, no a `chat_id bigint`.
- **No se copia ninguna herramienta del catálogo.** `ia_leer` e `ia_escribir`
  quedan con el `CASE` vacío; el dominio los llena en Fase 2. Así se elimina de
  raíz toda referencia a `ver_cola`, `dashboard`, inventario, caja y compras.
- Se conserva intacta la regla: **leer se hace solo, escribir se confirma con un
  botón.**

### Worker

Quedan cuatro manejadores: `chasqui_responder`, `notificar_superadmin`,
`notificar_inicio_sesion` y **`alertar_personal`**, este último nuevo — lo
encola `escalar_a_humano` y avisa por Telegram a quien tenga
`conversaciones.atender`. Los otros ocho se borraron. De `index.js` se quitó
`marcarAviso` / `aviso_turno_enviado`.

`chasqui_responder.js` se reescribió sobre el eje actor/conversación: recibe
`{conversacion_id, contacto_id}`, comprueba `bot_responde` antes de gastar una
llamada al modelo, y su prompt es de atención al público —con el bloque de
urgencias y la prohibición de diagnosticar— en vez del de personal interno.

**`src/canal.js`** es nuevo: la salida por canal. Quien responde no sabe por
dónde está hablando. `telegram` funciona, `simulador` no necesita transporte
(el registro en `mensaje` ES el envío) y `whatsapp` queda declarado para la
fase 3.

### Web

Quedan `entrar/`, `(portal)/layout`, `(portal)/admin/*`, `lib/db.ts`,
`lib/sesion.ts` y `lib/formato.ts`. Se borraron consultas, pacientes,
inventario, compras, reportes y la pantalla de sala de espera, con sus libs.
`esUuid` se mudó de `lib/clinico.ts` a `lib/formato.ts`: lo usan las rutas de
ingreso, que no tienen nada de clínico.

El panel muestra el pulso del canal —hilos abiertos, hilos esperando a una
persona, atraso de la cola— en vez del dashboard de turnos y caja. La agenda y
las conversaciones llegan en la fase 4.

### n8n

`01-telegram-webhook.json` y `04-job-mantenimiento.json` se conservan; el
primero, **solo como patrón** para el webhook de WhatsApp. Los jobs de turnos e
inventario se borraron.

**Cierre de fase ✔:** volumen `chasqui_assistant_pgdata` borrado, el sistema
levanta desde cero sin un solo error, el portal responde. Verificado además, en
la base y contra el worker real:

- normalización de celular: `315 418 4245`, `+57 315 418 4245` y
  `573154184245` colisionan contra el mismo contacto;
- idempotencia: el mismo `id_externo` dos veces deja un mensaje y una tarea;
- audiencia: el público ve dos herramientas, el superadmin ve cuatro, y un
  contacto público que pide una interna es rechazado en `ia_llamar`;
- confirmación: un contacto del público que invoca una herramienta que escribe
  recibe propuesta, no ejecución;
- escalamiento: tras `escalar_a_humano` el bot se calla y el mensaje se sigue
  registrando;
- append-only: `chasqui_assistant_app` inserta en `evento_auditoria` y no puede
  borrar.

---

## Fase 2 — El dominio

Migraciones nuevas a partir de `100`. Solo `100_pacientes.sql` viene de copia.

**Hecho ya:** `130_triaje.sql` y `810_seed_operativo.sql` — se adelantaron
porque el triaje es el límite que sostiene la venta y no tenía sentido
demostrarlo a medias. Falta el resto: pacientes, estudios, agenda,
antiduplicado y el catálogo completo de herramientas.

### `100_pacientes.sql` — desde `050_pacientes.sql`

Se copia y se le quitan los acoples a lo que no existe: `turno_id` en `cita` y
`consulta`, los `ALTER TABLE turno` / `ALTER TABLE movimiento_inventario` del
final, las columnas de inventario en el resumen de consulta, y
`vincular_turno_paciente`. Se conservan `dueno`, `paciente`, `consulta`,
`consulta_adenda`, `disponibilidad` y `cita`.

Es una edición quirúrgica, sí — pero **una sola**, y su modo de falla es
ruidoso: en un esquema nuevo, referenciar `turno` aborta la migración al primer
arranque.

### `110_estudios.sql` — catálogo y tarifas ✔

Hecho. **20 estudios** con descripción en lenguaje de cliente, tarifas por tipo
de día, preparación por estudio y los **35 festivos** de 2026 y 2027 con los
lunes ya trasladados.

`cotizar_estudio(codigo, fecha)` devuelve precio, si ese día tiene recargo y
por qué (nombra el festivo), la preparación, el ayuno y un campo
`como_decirlo` que le dice al modelo si la cifra está confirmada o es de
referencia. El modelo no calcula nada: repite.

⚠️ **Solo un precio está confirmado**: la ecografía abdominal ($172.000 L–S /
$187.000 domingos y festivos), que sale de la conversación real. Los otros 19
son estimaciones derivadas de las tarifas públicas de la Clínica Veterinaria de
la Universidad de La Salle (ecografía $150.000, radiografía $74.000), escaladas
por la proporción que separa esa ecografía de la de Abanimal.

Van marcadas con `estimado = true`, el asistente lo dice al cotizar, y
`SELECT * FROM v_tarifa_por_confirmar;` lista las 38 filas pendientes. Con la
lista real de Abanimal son quince `UPDATE`.

También se corrigió `pesos()`: el `G` de `to_char` toma el separador del locale
del contenedor y devolvía «$172,000». A un cliente colombiano eso le lee como
ciento setenta y dos.

### `120_agenda.sql` — disponibilidad y citas

`100_pacientes.sql` ya trae `cita` y `disponibilidad`; aquí se activan.

- Bloques por modalidad y por equipo. **El TAC es uno solo: no se puede
  sobreagendar**, y esa restricción va en la base, no en el prompt.
- `horarios_disponibles(estudio, desde, hasta)` → cupos libres.
- `agendar_cita`, `reagendar_cita`, `cancelar_cita`.
- `lista_espera`: al liberarse un cupo se ofrece al siguiente. Este es el
  argumento económico del demo (§ PROPUESTA 4).

### `130_triaje.sql` — urgencias ✔

Hecho. **14 cuadros y 117 términos**, con instrucciones de traslado literales
tomadas de AVMA, VCA, RSPCA, Royal Veterinary College y el manual Merck/MSD.

La frontera quedó donde tenía que quedar: decir *qué tiene* o *qué darle* es
acto médico y no ocurre nunca; decir *cómo moverlo sin empeorarlo mientras
llega* no lo es, y es lo que ahora entrega. Las instrucciones son texto en una
tabla que el bot recita sin reescribir — el modelo no las redacta, porque a un
atropellado hay que moverlo rígido y a un convulsivo hay que no meterle la mano
en la boca, y esas diferencias no se improvisan.

**Ninguna está aprobada todavía por un veterinario de Abanimal.** La vista
`v_urgencia_sin_aprobar` las lista, y las 14 están ahí. Antes de producción las
firma el Dr. Sánchez; esa media hora de su tiempo es parte de la venta.

Hay **tres rejas**, y el orden importa:

1. `termino_urgencia` — un `SELECT` en `asistente_recibir`, antes de que el
   modelo vea el mensaje. Si hay urgencia, la tarea al modelo **no se encola**.
2. `urgencia_general` — el cuadro atrapatodo, con instrucciones de traslado
   universales. Existe porque la lista nunca estará completa: en la primera
   prueba «se cayó **del** octavo piso» no coincidió con `se cayo de un` por
   una preposición.
3. `pedir_asesor` — herramienta pública para lo que las dos anteriores no
   vieron. **No pide confirmación por botón**, y es la única excepción a esa
   regla en todo el proyecto: la confirmación protege de acciones no queridas,
   y llamar a un humano nunca hace daño mientras que demorarlo sí.

«ASESOR» se resuelve en el mismo punto y por la misma razón: pedir una persona
no puede depender de que el modelo entienda que se la están pidiendo.

Lo probado contra el sistema real:

| Mensaje | Resultado |
|---|---|
| «mi perro convulsiona, qué le doy?» | cartilla de convulsión, escalado, sin pasar por el modelo |
| «se cayó del octavo piso, respira raro, no se mueve» | trauma (gana a respiratoria: mover mal causa daño nuevo) |
| «tiene la barriga hinchada y hace como para vomitar» | torsión gástrica |
| «mi gato no puede orinar» | obstrucción urinaria |
| «ASESOR» | escalado directo |
| «masa en la mama, ¿será cáncer?» | no diagnostica, escala con motivo útil |
| «quiero agendar una ecografía» · «cuánto vale un TAC» · «a qué hora abren» | **no** escala |

Lo que quedó construido, en detalle:

- `termino_urgencia`: convulsión, atropellado, no respira, sangra, intoxicación,
  parto, torsión, y variantes. **Datos, no constantes en código.**
- Al detectar: cortar el flujo, entregar instrucciones de traslado y dirección,
  marcar `atendida_por_humano`, encolar alerta al personal.
- **El bot nunca diagnostica ni aconseja tratamiento.** Se prueba en vivo en la
  Escena 3.

**La detección va en `asistente_recibir`, antes de encolar la tarea — no en una
herramienta que el modelo decida llamar.** Probado al cerrar la fase 1: ante
«mi perro convulsiona, qué le doy?» el modelo se portó impecable —no
diagnosticó, no sugirió medicamento, dijo que lo trajeran ya y anunció que
pasaba el chat a una persona— pero `atendida_por_humano` seguía en `false`.
Dijo que escalaba y no escaló.

Un límite clínico que depende de que el modelo se acuerde de invocar una
herramienta es un límite que se pierde el día que se distrae. El `SELECT`
contra `termino_urgencia` cuesta un milisegundo y ocurre siempre; el modelo
después redacta, pero la decisión ya está tomada en la base.

### `140_registro.sql` — antiduplicado

El problema que Abanimal declara por escrito en su propio formulario. Buscar por
celular normalizado (ya en `contacto`) y por documento antes de crear un `dueno`;
si hay coincidencia, ofrecer confirmar el paciente existente en vez de pedir los
11 campos.

### `150_herramientas.sql` — el catálogo del dominio

Reemplaza con `CREATE OR REPLACE` las `ia_leer`, `ia_escribir` e
`ia_resumen_accion` que la fase 1 dejó vacías, y siembra `ia_herramienta`.
Va después de `090_seed_roles.sql` a propósito: los permisos que referencia ya
existen (ver fase 0).

⚠️ **`130_triaje.sql` ya reemplazó `ia_leer` con la rama de `pedir_asesor`.**
Cuando `150` la vuelva a reemplazar tiene que conservar esa rama, o el
asistente pierde su tercera reja sin que nada falle en voz alta.

| Herramienta | Audiencia | Escribe |
|---|---|---|
| `pedir_asesor` ✔ | pública | no (excepción justificada) |
| `listar_estudios` ✔ | pública | no |
| `cotizar_estudio` ✔ | pública | no |
| `informacion_clinica` ✔ | pública | no |
| `preparacion_estudio` ✔ | pública | no |
| `horarios_disponibles` | pública | no |
| `consultar_cita` | pública | no |
| `registrar_tutor_paciente` | pública | sí |
| `agendar_cita` | pública | sí |
| `reagendar_cita` | pública | sí |
| `cancelar_cita` | pública | sí |
| `agenda_del_dia` | interna | no |

Las de audiencia pública que escriben confirman con botón igual que las
internas. La regla no se relaja porque el interlocutor sea un cliente.

### `810_seed_operativo.sql` ✔

Hecho. Los datos reales de Abanimal, tomados de sus páginas públicas en agosto
de 2026: sede completa (Cra 69 #17-24 Sur, Villa Claudia, Kennedy), los cinco
teléfonos con su función, el correo de informes, horario 24/7, el equipo
médico, los servicios y las cifras que ellos publican.

Todo eso vive en `config.ia_sobre_el_negocio`, que se edita desde
`/admin/config` sin desplegar nada. **Los precios NO están ahí a propósito**:
van en `tarifa`, donde una función los calcula según el día. Un precio en el
prompt es un precio que el modelo puede redondear.

El texto cierra con una sección «LO QUE NO SABES TODAVÍA» —precios, tiempos de
entrega, convenios con aseguradoras— para que el asistente lo diga en vez de
deducirlo. Es la aplicación directa de la lección de la primera respuesta real.

**Pendiente de confirmar con la clínica antes de producción.** Son datos de
fuentes públicas para un demo; un horario desactualizado en boca del bot es
peor que no tenerlo.

`090_seed_roles.sql` y `900_grants.sql` ya están hechos (fase 1).

---

## El protocolo conversacional

Vive en `instrucciones()`, dentro de `worker/src/tareas/chasqui_responder.js`.
Está en código y no en la base a propósito: es *comportamiento*, y cambiarlo es
un cambio de producto que merece pasar por git.

### LAER

**Escuchar · Reconocer · Explorar · Responder**, de Carew International. Se
escogió sobre AIDA porque AIDA es un embudo de marketing y LAER es la mecánica
de un turno de conversación — que es lo que aquí hace falta.

Cada mensaje del asistente pasa por los cuatro pasos, y el orden es lo que
importa: **reconocer antes de informar** es lo que separa a un recepcionista de
un contestador. De ahí sale también la regla que más cambia el tono: escuchar
ocupa más que hablar, así que se pregunta **una** cosa por mensaje y nunca dos.

Sobre la evidencia, para no exagerarla: las cifras que circulan (+58 %
satisfacción, +46 % conversión) vienen de material comercial de quienes venden
la metodología, no de estudios revisados. Lo que sí sostiene la elección es que
el método es viejo, específico y describe una mecánica, no una aspiración.

### El cierre

Cada mensaje termina proponiendo el siguiente paso concreto —agendar, venir,
traer los estudios previos—. La persona que hoy atiende ese WhatsApp no está
ahí para informar: está para que el paciente llegue. La diferencia entre
proponer y presionar es que **se propone una vez y se acepta el no**.

### Sonar como persona

Prohibido: encabezados, «¿En qué más puedo ayudarte?», anunciar capacidades,
viñetas salvo para opciones reales entre las que hay que escoger, saludar dos
veces en el mismo hilo, repetir el nombre en cada mensaje, más de un emoji.

`/start` no existe en WhatsApp: Telegram obliga a tocar un botón que lo manda,
así que el enrutador lo **traduce a «Hola»** y el asistente contesta como
contestaría cualquier saludo. Nadie entra a un mostrador y le leen la lista de
servicios.

### La presentación, garantizada en código

El primer mensaje del hilo identifica a la clínica: *«Buenas tardes, habla
Chasqui, de Abanimal Clínica Veterinaria»*. Quien escribe a un número que no
tiene guardado necesita saber quién le contesta.

Se intentó pedírselo al modelo de tres formas —al final del prompt, en
mayúsculas y de primero— y **seguía fallando una de cada dos veces**: cuando la
persona entraba directa con su consulta, el modelo se concentraba en
resolverla y se saltaba la presentación.

Así que dejó de pedirse. `conPresentacion()` en `chasqui_responder.js` mira si
el texto ya menciona «Chasqui» o el nombre de la clínica; si no, antepone la
línea. Nunca duplica, y el saludo de la franja horaria (`franjaHoraria()`)
también se calcula en código: «buenos días» a las nueve de la noche delata a un
programa más que cualquier otra cosa.

Es el mismo criterio que en el triaje: **lo que no puede fallar, no se le pide
al modelo.**

### Nunca anunciar lo que no se hizo

Regla dura del prompt, y viene de dos fallos observados: el modelo decía «ya le
avisé a una persona» o «te paso con un asesor» **sin llamar la herramienta**.
La persona queda esperando a alguien a quien nadie avisó. Hasta un «no puedo
ayudarte con eso» es mejor que una promesa incumplida.

Mientras no exista `agendar_cita`, cómo cerrar una cita vive en
`ia_sobre_el_negocio` (dato, no código): usar `pedir_asesor` con el motivo y
decirlo. Cuando la herramienta exista, se quita con un `UPDATE`.

### El límite que no se cruza

Suena natural, escribe como una persona y no anuncia que es un programa. **Pero
si le preguntan de frente si es un bot, lo dice.** Sostener la mentira ante una
pregunta directa es lo único que destruye la confianza de golpe, y frente a un
director médico la confianza es el producto.

Probado: *«¿eres una persona real o un bot?»* → *«Soy un asistente virtual, no
una persona. Pero estoy aquí para ayudarte… Si prefieres hablar con alguien del
equipo, te paso el chat sin problema.»*

Esa misma prueba destapó un falso positivo: `palabras_asesor` incluía «persona
real», así que la pregunta escalaba el chat en vez de responderse. Las frases
ahora son inequívocas — un falso positivo aquí interrumpe a alguien del equipo
y deja al cliente esperando a un humano que no pidió.

---

## Fase 3 — Canal de WhatsApp

- Workflow n8n `01-whatsapp-webhook.json`, calcado del de Telegram:
  verificación (GET `hub.challenge`), recepción, **respuesta en menos de un
  segundo**, todo lo lento a `tarea_async`.
- `worker/src/whatsapp.js`, equivalente de `telegram.js`: texto, botones
  interactivos y plantillas.
- Transcripción de notas de voz. La gente manda audio.
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

**Construir el simulador primero.** No depende de nadie externo, y como el canal
es una columna en `conversacion`, es una vista sobre el mismo motor: no código
paralelo que después haya que mantener en sincronía.

---

## Fase 4 — Panel y datos del demo

- Agenda del día.
- Conversaciones activas, con urgencias en rojo y botón de devolver el hilo al
  bot.
- Cupos liberados y lista de espera.
- `db/demo/`: catálogo real de estudios de Abanimal, agenda de una semana
  parcialmente ocupada, y algunos tutores con paciente e historia previa — sin
  eso el antiduplicado no se puede demostrar en vivo.

El `db/demo/` heredado (caja, compras) no se copia.

---

## Fase 5 — Ensayo

Cronometrar la Escena 2: el objetivo es **90 segundos** de principio a fin.
Ensayar con la red caída, para verificar que el simulador cubre de verdad.

---

## Esfuerzo

| Fase | | |
|---|---|---|
| 0 — verificar | medio día | ✔ |
| 1 — núcleo | 1 día | ✔ |
| 2 — dominio | 2 días | |
| 3 — WhatsApp | 1 día | |
| 4 — panel y datos | 1 día | |
| 5 — ensayo | medio día | |

Frente a la poda, la diferencia no está en el total sino en lo que queda: un
núcleo genérico separado del dominio, listo para el segundo cliente.

---

## Pendientes de información

Bloquean parte del alcance, no el demo:

1. Software de historia clínica que usa Abanimal (¿tiene API?).
2. Tabla de precios completa — solo se conoce ecografía abdominal.
3. Volumen real de mensajes por día y cuántas personas atienden el chat.
4. Si los tres números de WhatsApp se pueden unificar en uno.

## Credenciales ✔

`DEEPSEEK_API_KEY` (tomada de Chasqui Pet), `TELEGRAM_BOT_TOKEN` y
`SUPERADMIN_TELEGRAM_USER_ID` están puestas. El bot es
**`chasqui_abanimalBot`**, verificado contra `getMe`. El asistente responde de
verdad: primera conversación completa el 5 de agosto de 2026.

### Lo que enseñó la primera respuesta real

El modelo, preguntado por dirección y horario, **se los inventó** —una carrera
y un horario de lunes a sábado, dichos con total naturalidad—. La causa: la
sede del núcleo nace sin datos, `ia_contexto` devolvía `direccion: null`, y el
prompt callaba el hueco en vez de declararlo.

Se corrigió en `chasqui_responder.js`: un dato ausente se le dice ausente al
modelo, con instrucción explícita de no deducirlo. Reprobado con la misma
pregunta, ahora contesta *«no tengo a mano la dirección ni los horarios, pero
puedo pasarte con un asesor»*.

La lección vale para todo el dominio: **un campo vacío en el contexto es una
invitación a alucinar.** Cada dato que se agregue al prompt necesita su rama de
«no lo tengo», no solo su rama de «aquí está».

Ver [`PROPUESTA.md`](PROPUESTA.md) § 6.
