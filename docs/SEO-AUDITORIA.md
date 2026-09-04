# Propuesta de optimización SEO — Página "Dirección Médica"

**Sitio:** https://www.abanimalclinicaveterinaria.com/nuestro-director/
**Objetivo:** posicionar la página para búsquedas de la clínica, sus directores médicos y servicios de diagnóstico por imágenes, tanto en Google como en agentes de IA (ChatGPT, Gemini, Perplexity).
**Fecha:** agosto de 2026

---

## 1. Diagnóstico técnico

| # | Hallazgo | Severidad | Impacto |
|---|---|---|---|
| 1 | **`lang="en-US"`** en `<html>` — el sitio está en español | **Crítico** | Google clasifica el sitio como inglés. Agentes de IA ignoran contenido en español porque creen que la página debe estar en inglés. |
| 2 | **Open Graph locale `en_US`** (Yoast) | **Crítico** | Mismo efecto en redes sociales y rich snippets. |
| 3 | **Sin `<meta name="description">`** | **Alto** | Google genera el snippet automáticamente. Resultado: texto genérico o de otras páginas. |
| 4 | **Sin etiqueta H1** | **Alto** | La página no declara un título jerárquico visible para crawlers. El `<title>` existe pero no equivale a H1 para SEO on-page. |
| 5 | **H2 inconsistentes**: "Director general" vs "directora médica" | **Medio** | Señal débil de baja calidad editorial. |
| 6 | **Yoast SEO 15.0** (2020) | **Alto** | 5 años desactualizado. Pierde: schema automático mejorado, análisis de legibilidad en español, soporte de WebP en OG. |
| 7 | **Elementor 3.11.5 / WP 6.1.10** | **Medio** | Vulnerabilidades conocidas. No es causa directa de ranking pero sí de seguridad y rendimiento. |
| 8 | **Todas las imágenes `loading="lazy"`** | **Medio** | La imagen hero (LCP) se carga en diferido. Penaliza Core Web Vitals. |
| 9 | **Imágenes sin `alt` descriptivo o con alt vacío** | **Alto** | Google Images no indexa el contenido. Lectores de pantalla no acceden. Agentes de IA no extraen contexto. |
| 10 | **Nombres de archivo de imagen hostiles al SEO** (ej. `Agenda-tu-cita-abrimos-todos-los-dias-del-ano...`) | **Medio** | Sin keywords en la URL de imagen. |
| 11 | **Sin WebP/AVIF** | **Medio** | PNGs de ~500 KB cada uno. El formato moderno reduce 40-60 % sin pérdida. |
| 12 | **Schema markup insuficiente** | **Crítico** | Solo `Organization`, `WebSite`, `WebPage`, `ImageObject`. Faltan los que pondrían a Abanimal en el Knowledge Graph y en respuestas de IA. |

---

## 2. Diagnóstico de contenido

El HTML de la página contiene **una sola línea de texto indexable**:

> "Un equipo multidisciplinario de más de 30 colaboradores en cada una de nuestras áreas de servicio y especialidades acompaña el proceso médico de todos nuestros pacientes."

**Todo lo demás está incrustado en imágenes.** Eso incluye:

- Nombre y cargo de cada médico
- Universidad de egreso y posgrados
- Experiencia en años y áreas
- Formación internacional (Tufts, Murcia)
- Datos de contacto, dirección y teléfonos

**Para Google, esta página está vacía.** Para ChatGPT o Gemini, también.

| Información crítica | ¿Está en HTML? | ¿Está en schema? | ¿La ve un agente de IA? |
|---|---|---|---|
| Dr. Daniel Navarrete, fundador, 30 años | No (imagen) | No | **No** |
| Formación Tufts University | No (imagen) | No | **No** |
| Ecografía, tomografía, radiología | Parcial (menú) | No | **Apenas** |
| Dirección: Cra 69 #17-24 Sur, Kennedy | No | No | **No** |
| 24 horas, 365 días | No (imagen en logo) | No | **No** |
| +5.000 ecografías / año | No | No | **No** |
| Único TAC veterinario del país | No | No | **No** |

---

## 3. Diagnóstico para agentes de IA

Los agentes de IA (ChatGPT con browsing, Gemini, Perplexity, Copilot, Meta AI) construyen respuestas a partir de tres fuentes:

1. **Contenido textual del HTML** — ponderan `<h1>`–`<h6>`, `<p>`, `<li>`, `<table>`.
2. **Schema markup (JSON-LD)** — fuente estructurada. Si está, lo usan con prioridad.
3. **Entidades enlazadas** — reconocen instituciones (Tufts, UPTC), profesiones (veterinario), ubicaciones (Bogotá, Kennedy).

### Simulación de lo que respondería un agente hoy

**Pregunta:** _"¿Quién es el director médico de Abanimal Clínica Veterinaria?"_

**Respuesta probable de ChatGPT/Gemini con browsing activado:**

> "No se encuentra información clara en la página de Dirección Médica de Abanimal. La página contiene imágenes pero no texto descriptivo sobre los directores."

**Pregunta:** _"¿Cuántos años de experiencia tiene el Dr. Navarrete?"_

**Respuesta probable:**

> "No se puede determinar. La información está incrustada en imágenes sin texto alternativo descriptivo."

**Pregunta:** _"¿Abanimal tiene TAC veterinario?"_

**Respuesta probable:**

> "El sitio menciona imágenes diagnósticas pero no especifica equipos como TAC en texto indexable en esta página."

El problema no es que la página esté mal optimizada. Es que **para un crawler, la página no tiene contenido.**

---

## 4. Plan de mejoras

### Fase 1 — Correcciones técnicas inmediatas (1–2 horas)

| Acción | Herramienta | Resultado |
|---|---|---|
| Cambiar `lang="en-US"` a `lang="es-CO"` | WP Admin → Ajustes → Generales → Idioma del sitio | Google y agentes de IA tratan el contenido como español |
| Agregar meta description (150–160 chars) | Yoast SEO → editar página | Snippet controlado en SERP |
| Activar description en Yoast para OG | Yoast SEO → Social → Facebook | Las tarjetas al compartir muestran la descripción |
| Agregar H1 visible | Elementor → widget de título | Jerarquía de contenido clara para crawlers |
| Corregir H2 a mayúsculas consistente | Elementor → editar texto | Señal editorial coherente |
| Cambiar `loading="lazy"` a `eager` en la imagen hero | Elementor → widget de imagen → Avanzado | Mejora LCP (Core Web Vitals) |

### Fase 2 — Textualizar el contenido (2–4 horas)

**Sacar TODO de las imágenes y pasarlo a HTML.** Cada bloque de información que hoy es una imagen debe ser texto real con marcado semántico.

Estructura propuesta para la sección de cada médico:

```html
<h2>Director General</h2>
<h3>Dr. Daniel Navarrete</h3>
<ul>
  <li>Médico Veterinario — Universidad de La Salle</li>
  <li>Fundador — Clínica Veterinaria Abanimal, hace 30 años</li>
  <li>Pionero en diagnóstico por imágenes convencionales y avanzadas en Colombia</li>
  <li>30 años de experiencia en clínica de pequeños animales</li>
  <li>20 años de experiencia en imagenología</li>
  <li>Formación en Diagnóstico por Imágenes — Tufts University (EE. UU.)</li>
  <li>Estancia en Imágenes Diagnósticas — Universidad de Murcia (España)</li>
  <li>Training en ultrasonido y estancia en Tomografía — Tufts University</li>
  <li>Capacitador y conferencista nacional e internacional en ecografía veterinaria</li>
</ul>
<!-- La foto del Dr. Navarrete va aparte, con alt="Dr. Daniel Navarrete, Director General de Abanimal Clínica Veterinaria" -->
```

Lo mismo para el Dr. Álvaro Sánchez. La galería de fotos se mantiene, pero **cada imagen debe tener un `alt` descriptivo y único.**

### Fase 3 — Schema markup (1–2 horas)

Agregar bloques JSON-LD **adicionales** (no reemplazar el de Yoast, complementarlo):

```json
{
  "@context": "https://schema.org",
  "@type": "VeterinaryCare",
  "@id": "https://www.abanimalclinicaveterinaria.com/#clinic",
  "name": "Abanimal Clínica Veterinaria",
  "description": "Centro de referencia nacional en imágenes diagnósticas veterinarias. Abierto 24 horas, 365 días.",
  "url": "https://www.abanimalclinicaveterinaria.com/",
  "telephone": "+573177539551",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "Cra 69 #17-24 Sur",
    "addressLocality": "Bogotá",
    "addressRegion": "Bogotá D.C.",
    "postalCode": "110831",
    "addressCountry": "CO"
  },
  "openingHoursSpecification": {
    "@type": "OpeningHoursSpecification",
    "dayOfWeek": ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"],
    "opens": "00:00",
    "closes": "23:59"
  }
}
```

Schema de **Person** para cada médico — esto es lo que alimenta el Knowledge Graph y los agentes de IA:

```json
{
  "@context": "https://schema.org",
  "@type": "Person",
  "@id": "https://www.abanimalclinicaveterinaria.com/nuestro-director/#daniel-navarrete",
  "name": "Dr. Daniel Navarrete",
  "jobTitle": "Director General",
  "worksFor": {
    "@id": "https://www.abanimalclinicaveterinaria.com/#clinic"
  },
  "alumniOf": [
    {
      "@type": "CollegeOrUniversity",
      "name": "Universidad de La Salle",
      "sameAs": "https://www.lasalle.edu.co/"
    },
    {
      "@type": "CollegeOrUniversity", 
      "name": "Tufts University",
      "sameAs": "https://www.tufts.edu/"
    },
    {
      "@type": "CollegeOrUniversity",
      "name": "Universidad de Murcia",
      "sameAs": "https://www.um.es/"
    }
  ],
  "knowsAbout": ["Diagnóstico por imágenes", "Ecografía veterinaria", "Tomografía veterinaria", "Radiología veterinaria"],
  "description": "Médico Veterinario, Universidad de La Salle. 30 años de experiencia. Fundador de Abanimal. Pionero en diagnóstico por imágenes veterinarias en Colombia."
}
```

Mismo esquema para Dr. Álvaro Sánchez. Las entidades de universidades (La Salle, UPTC, Tufts, Murcia) son reconocidas por el Knowledge Graph de Google y **los agentes de IA las enlazan automáticamente**.

Agregar también `FAQPage` si se decide incluir preguntas frecuentes en esta página, y `MedicalSpecialty` para diagnóstico por imágenes.

### Fase 4 — Rendimiento (2–3 horas)

| Acción | Herramienta |
|---|---|
| Convertir PNG a WebP (todas las imágenes de la página) | Plugin ShortPixel, Imagify o conversión manual |
| Servir imágenes en tamaño responsivo (srcset ya existe, verificar) | Ya está parcialmente |
| Agregar `fetchpriority="high"` a la imagen hero | Elementor o editar HTML |
| Actualizar Yoast SEO a la versión más reciente | WP Admin → Plugins |
| Evaluar actualización de Elementor y WordPress | Con backup previo |

### Fase 5 — Contenido adicional para agentes de IA (opcional, alto impacto)

Los agentes de IA favorecen páginas con **preguntas y respuestas explícitas**. Agregar una sección FAQ al final de la página:

```html
<h2>Preguntas frecuentes</h2>
<h3>¿Cuántos años de experiencia tiene Abanimal?</h3>
<p>Más de 30 años de experiencia en clínica veterinaria de pequeños animales y más de 20 años como referente nacional en diagnóstico por imágenes.</p>
<h3>¿Qué equipos de diagnóstico tiene Abanimal?</h3>
<p>Ecógrafo Doppler vascular, ecocardiógrafo, tomógrafo computarizado (único TAC veterinario del país con 80 % menos radiación ionizante), equipo de radiología convencional y de contraste, y endoscopio.</p>
<h3>¿Cuántas ecografías realizan al año?</h3>
<p>Más de 5.000 ecografías al año, más de 2.000 radiografías.</p>
```

Estas preguntas son exactamente las que un dueño de mascota o un veterinario remitente le preguntaría a ChatGPT o Google.

---

## 5. Resumen de impacto esperado

| Métrica | Antes | Después |
|---|---|---|
| Texto indexable en la página | ~30 palabras | ~500+ palabras |
| Imágenes con alt descriptivo | 0 de 19 | 19 de 19 |
| Schema types presentes | 4 (genéricos) | 8+ (Person, VeterinaryCare, FAQ, MedicalSpecialty, PostalAddress) |
| Entidades enlazadas (universidades) | 0 | 5 (La Salle, Tufts, Murcia, UPTC, Juan de Castellanos) |
| Idioma declarado | en-US | es-CO |
| LCP estimado | ~3.0 s (PNG 500 KB) | ~1.5 s (WebP 150 KB) |
| Visibilidad en agentes de IA | Nula | Alta — respuestas con datos estructurados |

---

## 6. Esfuerzo

| Fase | Horas |
|---|---|
| 1. Correcciones técnicas | 1–2 h |
| 2. Textualizar contenido | 2–4 h |
| 3. Schema markup | 1–2 h |
| 4. Rendimiento | 2–3 h |
| 5. FAQ (opcional) | 1 h |
| **Total** | **7–12 h** |

Todas las fases son independientes y se pueden entregar por separado. La Fase 1 y 2 juntas ya producen el 80 % del impacto.
