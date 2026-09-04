# Chasqui Assistant

Asistente conversacional de WhatsApp para clínicas veterinarias: agenda citas,
cotiza estudios, registra tutor y paciente sin duplicar historia clínica, manda
los recordatorios de preparación y escala las urgencias a una persona.

**Primer caso:** demo comercial para
[Abanimal Clínica Veterinaria](https://www.abanimalclinicaveterinaria.com/)
(Bogotá), centro de referencia nacional en imágenes diagnósticas.
La propuesta completa está en [`docs/PROPUESTA.md`](docs/PROPUESTA.md).

---

## De dónde viene este proyecto

Nació como **copia de trabajo de Chasqui Pet** (`../chasquiPet`), renombrada y
repuerteada. Se copió el sistema completo y funcionando en vez de armar un
esqueleto a mano, porque las migraciones de Chasqui Pet se referencian entre sí
de forma cruzada y extraer "solo lo reutilizable" produce una base que no
arranca.

De esa copia ya no queda el esqueleto: `db/migrations/` se vació y se repobló
archivo por archivo, con numeración nueva. Lo que no se copió, no existe — y una
referencia a una tabla que no se copió revienta al primer arranque, en voz alta,
en vez de quedar viva y muda.

---

## Estado

**El núcleo y el dominio están construidos, y el sistema levanta desde cero sin
errores.** El asistente cotiza, agenda, mueve y cancela citas, y escala las
urgencias sin pasar por el modelo. Falta WhatsApp real y el panel. Ver
[`docs/PLAN.md`](docs/PLAN.md).

### Qué hay hoy

| Migración | Qué aporta |
|---|---|
| `010_base.sql` | Extensiones, `config`, sedes, auditoría, cola `tarea_async`, rate limit, fechas en `America/Bogota` |
| `020_identidad.sql` | Usuarios, roles y permisos **como datos**, no como constantes |
| `030_actor.sql` | **Contacto, conversación y mensaje.** El eje que Chasqui Pet no tenía: atender a un desconocido, no solo a personal con sesión |
| `040_asistente.sql` | Catálogo cerrado de herramientas filtrado por **audiencia**, y confirmación obligatoria para escribir. El motor conversacional |
| `050_auth_web.sql` | Ingreso al portal sin contraseñas, con enlace de un solo uso |
| `060_admin.sql` | Usuarios, config, auditoría, cola de tareas y salud del sistema |
| `070_mantenimiento.sql` | La poda diaria de lo que crece para siempre |
| `090_seed_roles.sql` | Roles y permisos del negocio |
| `100_pacientes.sql` | Tutores y pacientes, con el **antiduplicado** de historia clínica |
| `110_estudios.sql` | Catálogo de estudios y tarifas que cambian domingos y festivos |
| `120_agenda.sql` | **La agenda.** Recursos, horarios, citas y recordatorios de ayuno |
| `130_triaje.sql` | Urgencias detectadas por SQL, antes del modelo |
| `140_canal_telegram.sql` | El canal de Telegram |
| `150_herramientas.sql` | El catálogo de herramientas del asistente |
| `900_grants.sql` | Roles de BD con **append-only real** sobre auditoría y mensajes |

`worker/` procesa la cola con backoff, rescate de tareas colgadas y apagado
limpio; `web/` es el portal Next.js con sesión, permisos y administración.

### Qué falta construir

Canal de WhatsApp (Meta Cloud API), lista de espera, flujo para veterinarios
remitentes y el panel de la clínica.

---

## Puertos

Tres sistemas conviven en la misma máquina. Este usa los suyos:

| | Chasqui (n8n) | Chasqui Pet | **Chasqui Assistant** |
|---|---|---|---|
| Postgres | 5432 | 5433 | **5434** |
| n8n | 5678 | 5679 | **5680** |
| Portal web | — | 3100 | **3200** |
| Proxy | — | 8081 | **8082** |

---

## Arrancar

```bash
cp .env.example .env      # y editar: claves, token del bot, superadmin
docker compose --profile local up -d
```

La base solo corre `db/migrations/` la **primera** vez, con el volumen
`chasqui_assistant_pgdata` vacío. Para rehacer el esquema durante el desarrollo
hay que borrar ese volumen — no el de Chasqui Pet.

Detalle de cada variable: comentarios en `.env.example`.

Para probar un cambio de esquema sin tocar el volumen ni recrear contenedores,
un Postgres desechable con las migraciones montadas alcanza:

```bash
docker run --rm -d --name prueba-esquema \
  -e POSTGRES_USER=chasqui_assistant -e POSTGRES_PASSWORD=prueba \
  -e POSTGRES_DB=chasqui_assistant -e APP_DB_PASSWORD=x \
  -e N8N_DB_NAME=n8n -e N8N_DB_USER=n8n -e N8N_DB_PASSWORD=x \
  -v "$PWD/db/migrations:/docker-entrypoint-initdb.d:ro" postgres:16-alpine
docker logs prueba-esquema 2>&1 | grep ERROR
```

**Sin `DEEPSEEK_API_KEY` el asistente no responde**: escala la conversación a
una persona y lo dice. Es el comportamiento correcto, no un error, pero explica
por qué el bot contesta que ya avisó a alguien en vez de cotizar.

---

## Probar el asistente

```bash
bash scripts/probar-chat.sh "hola, a que hora abren?"
bash scripts/probar-chat.sh "mi perro convulsiona, que le doy?"
bash scripts/probar-chat.sh "y cuanto vale una ecografia?" 3001234567
```

Entra por la misma puerta que el canal real (`asistente_recibir`), así que lo
que se ve es lo que vería un cliente. El segundo argumento es el celular: con
el mismo número la conversación continúa, con uno distinto empieza de cero.

Se invoca con `bash` porque el repositorio vive en NTFS y no admite el bit de
ejecución.

La línea del final dice por dónde salió la respuesta:

| ruta | significa |
|---|---|
| `urgencia` | la armó la base y no pasó por el modelo |
| `pidio_asesor` | dijo «ASESOR» |
| `al modelo` | respondió DeepSeek |
| `rate_limit` | superó el tope de mensajes por hora |

Para empezar de cero con todos los hilos:

```sql
DELETE FROM ia_mensaje; DELETE FROM mensaje;
DELETE FROM conversacion; DELETE FROM contacto; DELETE FROM tarea_async;
```

### Lo que ya se puede probar

Ubicación, horarios, servicios, equipo médico, tomógrafo, remisión de colegas,
**precios de los 20 estudios** con su preparación y su ayuno, las 14 urgencias,
«ASESOR», y que el bot diga «no lo sé» en vez de inventar.

Y la conversación completa de una cita: cotizar, ofrecer horas reales,
**agendar**, mover y cancelar, con botón de confirmar y con los recordatorios
de ayuno programados. El tutor que vuelve es reconocido y no le vuelven a
preguntar cómo se llama su perro.

```sql
SELECT * FROM v_agenda_hoy;                   -- la agenda del día
SELECT horarios_disponibles('tac_simple');    -- las horas libres de verdad
```

Tres cosas que decide la base y no el modelo, y que vale la pena mirar:

- **El tomógrafo no se sobreagenda.** Es un `EXCLUDE` sobre la tabla `cita`,
  no una consulta previa: dos conversaciones simultáneas no pueden tomar el
  mismo cupo.
- **El precio sigue a la fecha.** Mover una cita del viernes festivo al sábado
  la baja de $187.000 a $172.000, en la fila y en lo que se dice.
- **El ayuno se dice a una hora humana.** Ocho horas antes de una cita de las
  9 am es la 1:00 am; el bot dice «desde las 9:00 pm del día anterior», que es
  la hora en que uno realmente deja de dar comida.

También se puede hablar con él desde Telegram, en **@chasqui_abanimalBot**.

### Lo que todavía no

WhatsApp real (falta el transporte de Meta), la lista de espera (la tabla está,
el flujo no) y el panel de la clínica. Eso es la fase 3 y la 4.

### ⚠️ Los precios son estimados, menos uno

Solo la ecografía abdominal está confirmada. Los otros 19 estudios llevan
cifras derivadas de tarifas públicas de otras clínicas de Bogotá, marcadas con
`estimado = true`; el asistente las da como referencia y lo aclara. Antes de
mostrar esto a Abanimal como algo definitivo:

```sql
SELECT * FROM v_tarifa_por_confirmar;
```

Lo mismo pasa con la agenda: los horarios de cada equipo son un supuesto
nuestro (lunes a sábado de 8 a 18, domingo de 9 a 13). La clínica atiende
urgencias 24/7, que es otra cosa y no pasa por la agenda.

```sql
SELECT * FROM v_horario_por_confirmar;
```

---

## Estructura

```
db/migrations/   esquema, funciones, permisos y seeds (se ejecutan en orden)
db/demo/         datos de demostración
n8n/workflows/   webhooks y jobs versionados
worker/          cola de tareas asíncronas (Node)
web/             portal (Next.js)
proxy/           Caddyfile
scripts/         respaldo, restauración, importación de n8n, registro de webhook
docs/            propuesta, plan y documentación propia de este proyecto
referencia/      Chasqui Pet original, SIN renombrar: especificación y docs
```

`referencia/` no se compila ni se ejecuta. Está para consultar cómo se resolvió
algo en Chasqui Pet.

---

## Documentos

- [`docs/PROPUESTA.md`](docs/PROPUESTA.md) — investigación de Abanimal, diagnóstico del canal actual, alcance y guion del demo
- [`docs/conversacion-real-abanimal.md`](docs/conversacion-real-abanimal.md) — el chat real que originó la propuesta
- [`docs/PLAN.md`](docs/PLAN.md) — qué podar, qué construir y en qué orden
- [`referencia/chasquipet-especificacion.md`](referencia/chasquipet-especificacion.md) — especificación completa de Chasqui Pet
- [`referencia/chasquipet-docs/modelo-datos.md`](referencia/chasquipet-docs/modelo-datos.md) — modelo de datos heredado, tabla por tabla
