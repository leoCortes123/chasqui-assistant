# Abanimal es invisible en Google y en la IA — y la puerta de entrada está cerrada

**Cliente:** Abanimal Clínica Veterinaria S.A.S.
**Páginas analizadas:** https://www.abanimalclinicaveterinaria.com/ y `/nuestro-director/`
**Fecha:** agosto de 2026

---

## Resumen ejecutivo

Abanimal tiene el único TAC veterinario del país, hace más de 5.000 ecografías
al año y está dirigida por un médico con 30 años de trayectoria y formación en
Tufts y Murcia. Nada de eso existe para Google. Nada de eso existe para
ChatGPT. Literalmente: la página de Dirección Médica contiene **una sola frase
de texto legible por un buscador**; todo lo demás está incrustado dentro de
imágenes, que un buscador no puede leer.

Y cuando el cliente sí logra encontrarlos, se topa con el segundo cuello de
botella: el WhatsApp. Sus propias reseñas de Google lo dicen — lo clínico se
califica excelente, y las quejas se concentran casi todas en lo mismo: **"no
responden los mensajes"**.

Son dos fallas de la misma cadena:

> **Nadie los encuentra** (SEO) → **y el que los encuentra se cansa de esperar**
> (WhatsApp sin atender).

Este documento explica cada falla técnica en términos de negocio: qué está
roto, cuánto cuesta, y qué se hace para arreglarlo.

---

# PARTE 1 — LA PÁGINA WEB

## Cómo funciona realmente Google (y por qué esto importa)

Google no "mira" una página como una persona. Envía un programa —un *crawler*—
que lee **el código de texto** de la página y guarda las palabras que
encuentra. Si una información está escrita como texto, Google la guarda y puede
mostrarla a quien la busque. Si esa misma información está dentro de una imagen
—un JPG con la hoja de vida escrita encima— para Google **no existe**. No hay
matiz: no es que valga menos, es que no está.

ChatGPT, Gemini y Perplexity funcionan igual, pero son todavía más estrictos:
solo pueden responder con lo que pueden leer, y prefieren datos estructurados
(un formato estándar llamado *schema*) por encima de todo lo demás.

La página de Dirección Médica de Abanimal está construida casi por completo con
imágenes. Es el equivalente digital de tener toda la información de la clínica
impresa en un afiche colgado en la sala de espera: la ve quien ya entró; quien
está afuera buscando, no.

---

## Falla 1 — El sitio le dice a Google que está escrito en inglés

### Qué pasa técnicamente

La primera línea del código del sitio declara `lang="en-US"`. Esa etiqueta es
la forma en que una página le informa a Google, a los navegadores y a los
lectores de pantalla en qué idioma está escrita. El sitio de Abanimal está
íntegramente en español, pero está declarado como inglés de Estados Unidos. La
misma etiqueta equivocada se repite en los datos que se envían a redes sociales
(`og:locale = en_US`).

Esto no es un detalle de programador. Es una contradicción activa: el sitio
declara una cosa y contiene otra.

### Cómo afecta al negocio

Google usa esa etiqueta como una de sus señales para decidir **a quién le
muestra la página**. Un sitio declarado en inglés de EE. UU. compite en peores
condiciones frente a búsquedas hechas en español desde Colombia. Cuando un
tutor en Bogotá busca *"veterinaria 24 horas Kennedy"* o *"ecografía
veterinaria Bogotá"*, Abanimal parte con una desventaja que no se ganó: la
autoevaluó ella misma en su propio código.

Peor con la IA: un agente que rastrea la página ve una declaración de idioma
que no coincide con el contenido, y eso reduce la confianza con la que lo cita.

**Traducción:** están pagando un impuesto de posicionamiento por un error de
una sola línea que nunca decidieron cometer.

### Cómo se soluciona

Cambiar el idioma del sitio a **español de Colombia (`es-CO`)** desde el panel
de WordPress y corregir la configuración de idioma social en Yoast. **15
minutos.** Es la corrección con mejor relación esfuerzo/beneficio de todo el
diagnóstico.

---

## Falla 2 — Las hojas de vida de los médicos no existen para internet

### Qué pasa técnicamente

Todo el contenido de la página `/nuestro-director/` —nombres, cargos,
universidades, posgrados, años de experiencia, formación en el exterior— está
dentro de archivos de imagen. El único texto real que un buscador recupera de
esa página es:

> "Un equipo multidisciplinario de más de 30 colaboradores en cada una de
> nuestras áreas de servicio y especialidades acompaña el proceso médico de
> todos nuestros pacientes."

Treinta palabras. Eso es todo lo que Google conoce de la página que presenta a
la dirección médica de un centro de referencia nacional.

Esto es lo que un agente de IA responde hoy si se le pregunta por el director
médico de Abanimal:

> *"No se encuentra información clara. La página contiene imágenes pero no
> texto descriptivo sobre los directores."*

Y esto es lo que Google **no** puede saber:

| Dato | ¿Google lo ve? |
|---|---|
| Dr. Daniel Navarrete, fundador, 30 años de ejercicio | **No** |
| Formación en Tufts University y Universidad de Murcia | **No** |
| Dr. Álvaro Sánchez, MSc Medicina Interna y Cirugía (UPTC) | **No** |
| Único TAC veterinario del país | **No** |
| +5.000 ecografías al año | **No** |
| Dirección: Cra 69 #17-24 Sur, Kennedy | **No** |
| Atención 24 horas, 365 días | **No** |

### Cómo afecta al negocio

Hay dos pérdidas y una es mucho más cara que la otra.

**La pérdida obvia** es el tutor que busca *"veterinario especialista en
ecografía Bogotá"* y encuentra una clínica genérica, sin TAC y sin veinte años
de imagenología. Ese cliente se va con la competencia sin haber sabido nunca
que Abanimal existía.

**La pérdida cara es la remisión.** Abanimal vive de ser centro de referencia:
recibe pacientes remitidos por otros veterinarios. Cuando un colega en Tunja,
Villavicencio o el norte de Bogotá tiene un caso que necesita tomografía y
busca *"a quién remito este paciente para TAC"*, no encuentra al Dr. Navarrete
ni a Abanimal. Remite a donde siempre ha remitido. Cada remisión perdida no es
un estudio: es un veterinario que queda enganchado con otro centro y le manda
todos sus casos durante años.

**Y la pérdida de confianza.** Una página de dirección médica sin credenciales
legibles, que ni siquiera aparece bien en una búsqueda del propio nombre del
doctor, transmite menos autoridad de la que Abanimal realmente tiene. Están
compitiendo por debajo de su categoría.

### Cómo se soluciona

Sacar todo de las imágenes y escribirlo como texto real, con estructura
semántica (títulos, subtítulos, listas) para que Google entienda la jerarquía:
quién es, qué cargo tiene, dónde estudió, en qué es experto. Las fotos se
mantienen —pero como fotos, acompañando al texto, no reemplazándolo.

La página pasa de **~30 palabras indexables a más de 500**. **3–4 horas.**

---

## Falla 3 — Los datos no están en el formato que la IA sabe leer

### Qué pasa técnicamente

Existe un estándar internacional llamado **schema.org / JSON-LD**: un bloque de
datos invisible para el visitante, que le entrega a Google y a los asistentes
de IA la ficha del negocio ya ordenada — tipo de establecimiento, dirección,
teléfono, horarios, y la ficha de cada profesional con sus universidades y
especialidades.

Es la diferencia entre que un robot tenga que *adivinar* leyendo un párrafo y
que reciba **el dato afirmado, sin ambigüedad**.

Hoy el sitio de Abanimal solo tiene los bloques genéricos que WordPress pone
solo (`Organization`, `WebSite`, `WebPage`). No tiene `VeterinaryCare` —el tipo
específico de clínica veterinaria—, no tiene `Person` para ningún médico, no
tiene horarios declarados ni especialidades médicas.

### Cómo afecta al negocio

Esto es lo que decide si Abanimal aparece o no en tres lugares que hoy pesan
más cada mes:

1. **El panel lateral de Google** (el recuadro con foto, horario, teléfono y
   botón "Cómo llegar"). Sin datos estructurados, Google lo arma con lo que
   pueda o no lo arma.
2. **Las respuestas de ChatGPT, Gemini, Perplexity y Copilot.** Cuando alguien
   pregunta *"¿qué clínica en Bogotá tiene ecógrafo Doppler?"*, la IA responde
   con lo que puede verificar. Abanimal no le da nada que verificar.
3. **Los asistentes de voz del celular**, que sacan la respuesta directamente
   de datos estructurados.

Las consultas de salud hechas a asistentes de IA vienen creciendo a un ritmo
que ya las vuelve un canal, no una curiosidad. La ventaja real es que **casi
ninguna veterinaria en Colombia está haciendo esto todavía**. Es un espacio que
hoy está vacío y que en dos años va a estar tomado. Ocuparlo cuesta un par de
horas ahora; recuperarlo después cuesta muchísimo más.

### Cómo se soluciona

Agregar los bloques JSON-LD de `VeterinaryCare` (con dirección, teléfonos y
horario 24/7) y de `Person` para cada médico, enlazando las universidades a sus
entidades reconocidas (La Salle, Tufts, Murcia, UPTC). Google y los agentes de
IA las reconocen automáticamente y esa asociación transfiere autoridad.
**1–2 horas.**

---

## Falla 4 — Las 19 fotos de la galería no aportan nada

### Qué pasa técnicamente

Cada imagen en una web puede llevar un texto alternativo (`alt`) que describe
lo que muestra. Es el único modo en que un buscador sabe qué hay en una foto,
y también es lo que lee un lector de pantalla para una persona con discapacidad
visual. En la página de Abanimal, las imágenes no tienen descripción útil o la
tienen vacía. Además, los archivos pesan alrededor de 500 KB cada uno en
formato PNG, un formato antiguo para web.

### Cómo afecta al negocio

**Google Imágenes es un canal entero que hoy no trae un solo paciente.** Fotos
reales del tomógrafo, del ecógrafo Doppler, de la sala de imágenes —el activo
visual que diferencia a Abanimal de cualquier veterinaria de barrio— son
invisibles para quien busca "tomógrafo veterinario Colombia".

Y el peso de las imágenes tiene un costo adicional: la página carga lento en
celular, y Google penaliza explícitamente los sitios lentos en su
posicionamiento. La mayoría de las búsquedas de urgencia veterinaria se hacen
desde un celular, con afán y con datos móviles.

### Cómo se soluciona

Escribir un `alt` descriptivo y único para las 19 imágenes, convertir los PNG a
formato WebP (mismo aspecto, 40–60 % menos peso) y priorizar la carga de la
imagen principal. **2–3 horas.** Efecto colateral: el sitio se vuelve accesible
para personas con discapacidad visual, que hoy no pueden usarlo.

---

## Falla 5 — Faltan las piezas básicas de una página indexable

### Qué pasa técnicamente

- **Sin meta descripción**: es el párrafo que Google muestra debajo del título
  en los resultados. Al no existir, Google inventa uno con cualquier fragmento
  suelto de la página.
- **Sin etiqueta H1**: el título principal que le dice al buscador de qué trata
  la página. No existe.
- **Yoast SEO en versión de 2020**, cinco años desactualizado, sin las mejoras
  de datos estructurados ni el análisis de contenido en español.

### Cómo afecta al negocio

La meta descripción es el **texto de venta** en el resultado de Google: es lo
que decide si alguien hace clic en Abanimal o en el resultado de abajo. Hoy
Abanimal no controla ese mensaje; se lo escribe Google con retazos. Es como
dejar que un desconocido redacte el aviso de la clínica.

### Cómo se soluciona

Redactar la meta descripción, agregar el H1 y actualizar el plugin.
**1–2 horas.**

---

## Lo que cambia el día que se corrige

| | Hoy | Después |
|---|---|---|
| Un tutor busca "ecografía veterinaria Bogotá" | Encuentra una clínica genérica | Encuentra Abanimal, ve TAC, Doppler y 30 años de trayectoria |
| Un colega busca dónde remitir un TAC | No halla nada; remite donde siempre | Encuentra a Abanimal como referente nacional |
| Alguien le pregunta a ChatGPT por ecografía en Bogotá | Abanimal no se menciona | "Abanimal, en Kennedy: ecógrafo Doppler, TAC, dirigida por el Dr. Navarrete (Tufts)" |
| Palabras que Google puede leer | ~30 | 500+ |
| Idioma declarado | Inglés de EE. UU. | Español de Colombia |
| Fichas estructuradas para IA | 0 médicos | Todos, con universidades enlazadas |

**Esfuerzo total: 7–12 horas, una semana calendario.** Sin tocar el hosting ni
el panel de la clínica: se entrega el contenido listo para publicar.

---

# PARTE 2 — EL CHATBOT DE WHATSAPP

## El problema que el SEO no resuelve

Arreglar la web hace que la gente llegue. No garantiza que la atiendan.

Y ahí está el segundo hueco, y es el que Abanimal ya tiene documentado
públicamente: **sus reseñas negativas en Google no hablan de medicina, hablan
de comunicación.** Lo clínico y lo diagnóstico se califican muy bien. Lo que
aparece una y otra vez en las malas es lo mismo: *no responden los mensajes*,
no confirman, toca insistir.

Eso es demoledor por tres razones:

1. **Es lo primero que ve un cliente nuevo.** Nadie lee la reseña de cinco
   estrellas sobre la ecografía; lee la de una estrella que dice "llevo dos
   días esperando respuesta". Esa reseña anula el trabajo de posicionamiento
   que se acaba de pagar.
2. **Las reseñas afectan el posicionamiento local.** Google usa la calificación
   y la frecuencia de reseñas para ordenar el mapa. Las quejas por atención
   bajan el promedio y bajan la posición.
3. **Es la única falla del listado que no es clínica.** Abanimal no tiene un
   problema de calidad médica. Tiene un problema de **tiempo de respuesta en
   WhatsApp** — y ese sí tiene solución técnica inmediata.

## Lo que muestra la conversación real

No es una hipótesis. Tenemos archivada una conversación real de agendamiento
con la línea de imágenes diagnósticas (315 418 4245, del 1 al 4 de agosto de
2026). En un solo caso, esto es lo que pasó:

| Lo que ocurrió | Consecuencia |
|---|---|
| 6 minutos de espera para el primer contacto, un viernes en horario laboral | El cliente ya está evaluando escribirle a otra clínica |
| Formulario de 11 campos copiado y pegado, sin validación | El cliente omitió un dato; hubo que pedírselo aparte |
| **Nunca se confirmó la cita** — "¿osea que ya está confirmada?" quedó sin respuesta | Cliente ansioso, y una reseña negativa en potencia |
| El ayuno de 8 horas se mencionó una sola vez, enterrado en un párrafo | Si el paciente come, se pierde el estudio **y el cupo** |
| Cancelación el mismo día a las 7:45 am de la primera hora | El cupo quedó vacío; nadie se lo ofreció a otro paciente |
| Se pidió el correo del veterinario remitente tres días después, a mano | Se retrasa el informe al colega que remitió |

Ese caso consumió cerca de **15 mensajes de una persona** y aun así terminó sin
confirmación, sin recordatorio y con riesgo de historia clínica duplicada
—problema que la propia clínica reconoce por escrito en su formulario:
*"SI YA ESTÁ REGISTRADO INDÍQUENOS EL TELÉFONO PARA NO DUPLICAR EL HISTORIAL
CLÍNICO"*.

## Qué hace el chatbot, punto por punto

| Queja de reseña | Qué hace el bot |
|---|---|
| "No responden los mensajes" | Responde en **segundos, 24/7**, incluso a las 3 am y en domingo |
| "Nunca me confirmaron" | Confirmación escrita automática: paciente, estudio, fecha, hora y dirección |
| "Toca insistir para que le den precio" | Cotiza al instante con la tarifa real, incluida la diferencia de domingos y festivos |
| "Me hicieron perder el viaje" | Recordatorio de ayuno la noche anterior a las 8 pm y confirmación de asistencia 2 horas antes |
| "Me pidieron los datos otra vez" | Reconoce el celular y recupera el paciente: cero historias duplicadas |
| "Nadie me dio razón de mi mascota" | Canal de hospitalización con estado y escalamiento a humano |

Y dos reglas que son parte de la venta, no una limitación:

- **El bot nunca diagnostica ni recomienda tratamiento.** Ante palabras como
  *convulsión, atropellado, no respira, intoxicación*, deja de conversar, da
  instrucciones de traslado con el mapa y **escala a un humano de inmediato**
  con alerta en el panel.
- **Siempre hay salida a humano.** Escribiendo "ASESOR" el bot se calla en ese
  hilo hasta que la persona lo devuelva. El cliente nunca queda atrapado.

## El número

Con las cifras que la propia clínica publica:

- 5.000 ecografías al año × $172.000 ≈ **$860 millones al año** solo en
  ecografía.
- Recuperar apenas un **5 %** de citas perdidas por no-show, cupos cancelados
  que nadie reasignó y clientes que se cansaron de esperar ≈ **$43 millones al
  año**.
- Más el tiempo de la operadora, que hoy se va en copiar y pegar formularios y
  transcribir datos al historial, y que pasa a usarse en atender a quien ya
  está en la clínica.

Y un beneficio que no aparece en esa cuenta: **las reseñas que hoy dicen "no
responden" dejan de escribirse.** Eso sube la calificación, sube la posición en
el mapa de Google y devuelve el efecto sobre el SEO. Los dos frentes se
alimentan mutuamente.

---

# LOS DOS JUNTOS

```
SEO arreglado          →  la gente encuentra a Abanimal
Chatbot funcionando    →  la gente que la encuentra sí es atendida
Buena atención         →  mejores reseñas
Mejores reseñas        →  mejor posición en Google
```

Arreglar solo el SEO es abrirle la puerta a más gente para que espere seis
minutos y se vaya. Poner solo el chatbot es atender de maravilla a los pocos
que ya sabían de la clínica. Van juntos.

---

## Entrega

Por etapas, y la primera arranca ya. Cada etapa se entrega **funcionando y
midiéndose**. La etapa A no depende de nada ni de nadie: no toca el hosting, no
interrumpe la operación y se puede empezar esta semana.

| Etapa | Qué se entrega | Modalidad |
|---|---|---|
| **A · Corrección de la página** | Contenido textualizado, idioma corregido, imágenes descritas y fichas estructuradas para Google e IA | Remoto, sin acceso al hosting: se entrega el código listo para publicar |
| **B · Reestructuración del portal** | Arquitectura de todo el sitio para búsqueda e IA: una página por servicio y por equipo, contenido nuevo, rendimiento y accesibilidad | Sobre el WordPress actual o migrando, según convenga |
| **C · Levantamiento de sistemas** | Mapa de lo que hoy usan —historia clínica, agenda, tarifas, inventario— y qué se puede conectar | **Documento propio de la clínica**, que hoy no existe en ninguna parte |
| **D · Asistente en producción** | El asistente **ya construido**, cargado con su portafolio, tarifas, horarios y protocolos: agenda real, antiduplicado, cotización, triaje, recordatorios y panel web | En el canal que elijan: WhatsApp oficial, Telegram, web o contestador telefónico |
| **E · Módulos internos** | Inventario, turnos, cobro, compras, reportes o herramientas a la medida | De a un módulo, empezando por el que más horas les está costando |

Los plazos se fijan al cerrar cada etapa, con el alcance ya definido. Lo firme
es el orden: **la etapa A se empieza de inmediato** y no depende de nada.

### Inversión (COP, sin IVA)

| Ítem | Valor |
|---|---|
| A · Corrección de la página | **$2.400.000** (cerrado) |
| B · Reestructuración del portal (incluye A) | **$8.500.000** (cerrado) |
| C · Levantamiento de sistemas | **$1.800.000** — se descuenta íntegro de D |
| D · Asistente en producción, un canal | **$12.000.000 – $18.000.000** según integración |
| Canal adicional (Telegram, web, Instagram) | $2.500.000 c/u |
| Contestador telefónico con voz | $4.500.000 – $6.500.000 |
| E · Módulo interno (inventario, turnos, cobro, compras, reportes) | $3.500.000 – $6.000.000 c/u |
| Operación mensual | $950.000 – $1.500.000 / mes |
| Mensajes de WhatsApp oficial | Costo de Meta, a precio, sin recargo |

La etapa A cuesta menos que **catorce ecografías abdominales**; el portal
completo, menos de cincuenta. El asistente en su tope equivale a unas **ciento
cinco** —de las más de cinco mil que hacen al año— frente a los **$43 millones
anuales** que hoy se pierden recuperando apenas el 5 % de las citas que se caen.
**Se paga solo dentro del primer año**, y eso sin contar una sola remisión nueva.

El costo que no aparece en ninguna tabla es el de **no hacer nada**: cada mes que
pasa son remisiones que se enganchan con otro centro, reseñas de una estrella que
quedan escritas para siempre y un espacio en las respuestas de IA que alguien más
va a ocupar.

Condiciones y forma de pago se acuerdan en la reunión, con el alcance ya elegido.

---

## Esto no lo decide marketing

El Dr. Navarrete no construyó treinta años de trayectoria, con formación en
Tufts y en Murcia, para que Google no se la muestre a nadie. El único TAC
veterinario del país no se compró para que los colegas no lo encuentren cuando
buscan dónde remitir. Y una clínica que atiende 24 horas los 365 días del año
no debería tener reseñas que digan que no contesta.

El diagnóstico está hecho y las dos fallas se corrigen en semanas, no en meses.
La pregunta no es si conviene hacerlo. Es cuánto tiempo más van a seguir
regalándole ese mercado a clínicas que médicamente no les llegan a los talones.
