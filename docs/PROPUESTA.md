# Propuesta — Chatbot de WhatsApp para Abanimal Clínica Veterinaria

**Estado:** propuesta comercial, pendiente de presentar
**Prospecto:** Abanimal Clínica Veterinaria S.A.S. — Bogotá
**Fecha:** agosto de 2026

---

## 1. El negocio

**Abanimal** — Cra 69 #17-24 Sur, Villa Claudia, Kennedy, Bogotá.
Fundada hace 30 años por el **Dr. Daniel Navarrete** (Universidad de La Salle;
formación en imágenes diagnósticas en Tufts University y Universidad de Murcia).
Director médico: **Dr. Álvaro Sánchez** (MSc Medicina Interna y Cirugía de
Pequeños Animales, UPTC; cursando oncología). Más de 30 colaboradores.
Abierta 24 horas, los 365 días del año.

No es una veterinaria de barrio: es un **centro de referencia en imágenes
diagnósticas**. Esto define todo lo demás.

### Servicios

| Área | Detalle |
|---|---|
| Imágenes diagnósticas | Ecografía (convencional, Doppler vascular, ecocardiografía), tomografía, radiología (convencional y de contraste), intervencionismo guiado por eco/TAC |
| Especializados | Endoscopia diagnóstica y terapéutica, radiología dental, estudio de asimetría facial, diagnóstico de enfermedad articular |
| Base | Consulta con equipo multidisciplinario, hospitalización 24 h, cirugía, urgencias 24 h, laboratorio clínico |

### Cifras que ellos mismos publican

- **+5.000 ecografías al año**
- **+2.000 radiografías al año**
- **Único TAC veterinario del país** (según su web), con 80 % menos radiación ionizante
- 20 años como referente nacional en imágenes
- **Reciben remisiones de otros veterinarios** — "recibimos colegas con convenios especiales"

### Canales actuales

| Canal | Número | Uso declarado |
|---|---|---|
| WhatsApp | 317 753 9551 | Consulta médica |
| WhatsApp | 319 707 763 | Hospitalización |
| WhatsApp | 315 418 4245 | Imágenes diagnósticas |
| Fijo | 601 414 4930 / 601 420 7765 | Call center |

Marca secundaria con sitio y redes propias: *Abanimal Imágenes Diagnósticas*.

### Reputación

Reseñas muy buenas en lo clínico y en imágenes. **Las negativas apuntan casi
todas a comunicación**: "no responden los mensajes". Ese es exactamente el
hueco que llena el bot.

---

## 2. Diagnóstico del canal actual

Basado en una conversación real de agendamiento con la línea 315 418 4245
(1 – 4 de agosto de 2026), archivada en `docs/conversacion-real-abanimal.md`.

| # | Falla | Evidencia |
|---|---|---|
| 1 | **6 minutos de espera** para el primer contacto humano | 11:56 → 12:02, viernes en horario laboral |
| 2 | **Formulario de texto plano** copiado y pegado, 11 campos, sin validación | El cliente omitió el nombre del tutor; hubo que pedirlo aparte ("Tu nombre ?") |
| 3 | **Nunca se confirmó la cita** | "¿osea que ya está confirmada para el lunes a las 9 am?" → sin respuesta |
| 4 | **Nunca se recordó el ayuno de 8 horas** | Se mencionó una sola vez, enterrado en un párrafo largo |
| 5 | **Reagendamiento manual y a ciegas** | "mañana a la misma hora" → "sería 9:30", negociado a mano sobre una agenda que nadie puede consultar |
| 6 | **Cancelación el mismo día a las 7:45 am** de la primera hora | El cupo quedó vacío y nadie lo ofreció a otro paciente |
| 7 | **Los datos se quedan en el chat** | Alguien debe transcribirlos a la historia clínica |
| 8 | **Historias clínicas duplicadas — declarado por ellos** | *"SI YA ESTÁ REGISTRADO INDÍQUENOS EL TELÉFONO PARA NO DUPLICAR EL HISTORIAL CLÍNICO"*: el problema existe y se le traslada al cliente |
| 9 | **El correo del remitente se pide a mano, tres días después** | "tu me puedes escribir correo del doc", para enviar un informe que ya debería estar ruteado |

**Traducción comercial:** cada estudio consume ~15 mensajes de una persona, y
aun así el cliente termina sin confirmación, sin recordatorio y con riesgo de
historia duplicada.

---

## 3. Alcance del demo

Un solo número. El bot atiende y el humano entra solo donde aporta.

### 3.1 Recepción y triaje instantáneo (24/7)
Clasifica el mensaje en: urgencia · cita de imágenes · consulta general ·
hospitalizado · remisión de colega · precios · ubicación y horarios.

### 3.2 Triaje de urgencias — la regla de oro
Palabras como *convulsión, atropellado, no respira, sangra, intoxicación,
parto, torsión* → el bot **deja de conversar**, da instrucciones de traslado,
entrega dirección con enlace de mapa y **escala a humano de inmediato** con
alerta en el panel.

**Nunca da diagnóstico ni consejo médico.** Este límite se muestra
explícitamente en el demo: es lo que le da confianza a un director médico.

### 3.3 Toma de datos estructurada
Reemplaza el formulario copiado y pegado por preguntas de a una, con validación:

- Detecta si el celular **ya está registrado** → "Saria, criolla, 8 años,
  ¿confirmas?" → **cero historias duplicadas**, sin pedirle nada al cliente.
- CC numérica, correo con formato válido, especie/sexo/estado reproductivo por
  botones, no texto libre.
- Acepta audio y lo transcribe (la gente manda notas de voz).

### 3.4 Agenda con disponibilidad real
"Tengo lunes 9:00, 9:30 y 11:00 para ecografía abdominal" → el cliente elige
por botón. Reagendar y cancelar son autoservicio. Al liberarse un cupo, el bot
lo **ofrece automáticamente a la lista de espera** — ese es el dinero recuperado.

### 3.5 Cotización automática
Conoce la tabla de precios y la regla de tarifa: ecografía abdominal
**$172.000 L–S / $187.000 domingos y festivos**, con calendario de festivos
colombianos incorporado. Responde en segundos, siempre igual, sin errores de
cotización.

### 3.6 Confirmación y preparación — el punto que hoy falla
- **Inmediata:** "✅ Confirmado. Saria, ecografía abdominal, lunes 4 de agosto,
  9:00 am. Cra 69 #17-24 Sur."
- **La noche anterior, 8 pm:** "Recuerda: Saria no puede comer ni beber desde
  las 9:00 pm. El ayuno de 8 horas es obligatorio o el estudio debe
  reprogramarse."
- **2 horas antes:** confirmar asistencia con un botón. Si dice que no, el cupo
  se libera solo.

### 3.7 Post-estudio
Correo capturado desde el registro; informe e imágenes se envían al tutor **y al
veterinario remitente** sin que nadie lo pida.

### 3.8 Canal para colegas remitentes
Flujo aparte: el veterinario remite paciente, adjunta orden, agenda y recibe el
informe. Siendo centro de remisiones, esto es diferencial y ninguna veterinaria
en Bogotá lo tiene.

### 3.9 Traspaso a humano, siempre
"ASESOR" en cualquier momento. El bot se calla en ese hilo hasta que el humano
lo devuelva. El cliente nunca queda atrapado.

### 3.10 Panel web
Agenda del día, conversaciones activas, urgencias en rojo, cupos liberados,
historial completo por paciente. La operadora deja de vivir en WhatsApp Web.

---

## 4. Guion de la presentación

**No** una presentación de diapositivas. Un demo que se toca. Tres escenas de
3 minutos.

**Escena 1 — El espejo.**
Se proyecta la conversación real, con los 9 puntos marcados. No es teoría, es
su cliente. Cierra en "¿ya está confirmada?" sin respuesta.

**Escena 2 — Lo mismo, con el bot.**
Ellos escriben desde su propio celular al número del demo. Piden ecografía para
su perro. En **90 segundos**: cotizado, registrado, agendado, confirmado por
escrito. Sin humano. Luego reagendan y cancelan solos.

**Escena 3 — Lo que no se ve.**
Panel en pantalla: la cita apareció sola, los datos están estructurados, el
recordatorio de ayuno está programado. Remate: se manda "mi perro convulsiona"
y el bot escala en un segundo, con alerta.

**El número, al final y en una sola diapositiva:**
5.000 ecografías/año × $172.000 ≈ **$860 millones/año** solo en ecografía.
Recuperar un 5 % de no-shows y cupos muertos ≈ **$43 millones/año**, más la
operadora liberada para vender en vez de transcribir.

---

## 5. Implementación

Se reutiliza la arquitectura de **Chasqui Pet** (ver `README.md`): Postgres como
fuente única de verdad, n8n para webhooks y jobs, worker de tareas asíncronas,
portal Next.js, Caddy + cloudflared. Lo nuevo es el dominio: catálogo de
estudios, agenda, reglas de preparación y triaje clínico.

| | |
|---|---|
| Esfuerzo demo | ~1 semana |
| Canal del demo | Número sandbox de Meta Cloud API + simulador de chat en el portal como respaldo si falla la red en la reunión |
| Datos | Precios y estudios reales tomados de su web y de la conversación; agenda simulada en bloques de 30 min |
| Producción | 3–5 semanas, según con qué se integre la agenda |

### Lo que el demo NO hace
Decirlo en la reunión, no esperar a que lo pregunten:

- No se conecta a su historia clínica.
- No cobra anticipos.
- No interpreta imágenes.
- No da diagnósticos.

Es un demo de flujo, no un sistema instalado.

---

## 6. Preguntas abiertas antes de presentar

1. **¿Qué software de historia clínica usan?** Único riesgo real de la
   propuesta. Con API, la integración es directa; si es Excel o un sistema
   cerrado, la agenda vive en nuestra base y se sincroniza a mano al principio.
2. **¿Quién decide?** El Dr. Navarrete es dueño y perfil técnico-diagnóstico:
   le va a importar el triaje de urgencias y la trazabilidad, no el ahorro en
   personal.
3. **Tabla de precios completa** de los estudios (solo se conoce ecografía
   abdominal).
4. **¿Los tres números se pueden unificar?** Consolidar en uno es media
   propuesta.
5. **Volumen real de mensajes/día** y cuánta gente atiende el chat. Sin eso el
   ROI es estimado.

---

## 7. Ángulo de venta

El gancho **no** es "ahorra una persona". Es:

> **Cero historias clínicas duplicadas y cero estudios perdidos por ayuno roto.**

Son problemas *clínicos* que ellos ya reconocen por escrito. Ahí el que decide
es el director médico, no el administrativo.

---

## Fuentes

- https://www.abanimalclinicaveterinaria.com/
- https://www.abanimalclinicaveterinaria.com/servicios/
- https://www.abanimalclinicaveterinaria.com/imagenes-diagnosticas/
- https://www.abanimalclinicaveterinaria.com/contacto/
- https://www.abanimalclinicaveterinaria.com/nuestro-director/
- https://www.abanimalimagenesdiagnosticas.com/
- Conversación de WhatsApp con la línea 315 418 4245, 1–4 de agosto de 2026
