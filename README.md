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

Es una **copia de trabajo de Chasqui Pet** (`../chasquiPet`), renombrada y
repuerteada para correr en paralelo. Se copió el sistema completo y funcionando
en vez de armar un esqueleto a mano: las migraciones de Chasqui Pet se
referencian entre sí de forma cruzada (`080_reportes` toca turnos, caja e
inventario; `090_grants` toca `movimiento_inventario`; `078_chasqui_ia` las toca
casi todas), así que extraer "solo lo reutilizable" produce una base que no
arranca.

**Consecuencia práctica:** este repositorio arranca hoy como un Chasqui Pet
renombrado. Podar lo que no aplica y construir el dominio de citas es el trabajo
de la primera sesión — ver [`docs/PLAN.md`](docs/PLAN.md).

---

## Qué se hereda

### Se aprovecha tal cual

| Módulo | Por qué sirve |
|---|---|
| `db/migrations/010_base.sql` | Extensiones, `config`, sedes, auditoría, fechas en `America/Bogota` |
| `db/migrations/020_identidad.sql` | Usuarios, roles y permisos **como datos**, no como constantes |
| `db/migrations/050_pacientes.sql` | Dueño, paciente, consulta, adendas — y ya trae las tablas `cita` y `disponibilidad` |
| `db/migrations/058_auth_web.sql` + `077_portal_enlace.sql` | Ingreso al portal sin contraseñas, con enlace de un solo uso |
| `db/migrations/078_chasqui_ia.sql` | Asistente con catálogo cerrado de herramientas, permisos del usuario y confirmación obligatoria para escribir. **Es la base del bot conversacional.** |
| `db/migrations/085_admin.sql`, `088_mantenimiento.sql`, `090_grants.sql` | Administración, poda y roles de BD con append-only real |
| `worker/` | Cola `tarea_async` con backoff, rescate de tareas colgadas y apagado limpio. Los recordatorios de ayuno y confirmación son tareas de esta cola. |
| `web/` | Portal Next.js: sesión, permisos, layout, admin, pacientes |
| `scripts/`, `proxy/`, `docker-compose.yml` | Respaldo, restauración, importación de n8n, túnel público y registro de webhook |

### Se poda

Turnos y pantalla de sala de espera, inventario, caja y cobro, compras y
proveedores. Abanimal ya tiene sistema para eso; el demo es del canal de
WhatsApp.

### Se construye

Catálogo de estudios con reglas de tarifa (L–S vs. domingos y festivos), agenda
por modalidad con disponibilidad real, canal de WhatsApp (Meta Cloud API),
triaje de urgencias, reglas de preparación (ayuno) con recordatorios
programados, lista de espera y flujo para veterinarios remitentes.

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
