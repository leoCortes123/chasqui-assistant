# Propuesta Abanimal — cómo publicar `propuesta-web/`

Este archivo **no** va dentro de la carpeta que se sube: contiene notas
internas y quedaría accesible en `/PROPUESTA-WEB-publicar.md`.

Todo lo que hay en `propuesta-web/` es lo que se sube, y nada más. No hay build,
no hay dependencias: son archivos estáticos.

```
index.html    la propuesta completa (única página; CSS y JS van dentro)
favicon.svg   ícono de la pestaña, con los colores de Abanimal
robots.txt    bloquea a los buscadores
_headers      refuerza el noindex desde el servidor (Netlify y Cloudflare)
```

Las tipografías (Anton y Roboto) se cargan desde Google Fonts, así que la
página necesita internet para verse con la tipografía correcta. Sin conexión
cae a las fuentes del sistema y sigue siendo legible.

---

## Publicar en Netlify (lo más rápido)

1. Entrar a <https://app.netlify.com/drop>
2. Arrastrar **esta carpeta completa** (`propuesta-web`), no los archivos sueltos.
3. Queda en línea en segundos, con una URL tipo
   `https://algo-aleatorio.netlify.app`.
4. Opcional, con cuenta gratuita: *Site configuration → Change site name* para
   dejarla como `abanimal-diagnostico.netlify.app`.

Para actualizarla después: mismo sitio → *Deploys* → arrastrar la carpeta otra
vez. La URL no cambia.

## Alternativa: Cloudflare Pages

<https://dash.cloudflare.com> → **Workers & Pages** → *Create* → *Pages* →
*Upload assets* → arrastrar la carpeta. URL `https://proyecto.pages.dev`.
Requiere cuenta gratuita; responde más rápido en Colombia y admite dominio
propio sin costo.

## Alternativa: GitHub Pages

Repositorio nuevo (público) con estos archivos en la raíz → *Settings* →
*Pages* → *Deploy from branch* `main` → `/ (root)`. URL
`https://usuario.github.io/repositorio/`. Tarda un par de minutos.

## Ver en local, antes de publicar

```bash
python3 -m http.server 8000 --directory .
# luego abrir http://localhost:8000
```

---

## Antes de mandarle el enlace al cliente

- [ ] **Reemplazar las tres reseñas parafraseadas** por citas textuales del
      perfil real de Google (buscar el comentario `REEMPLAZAR` en `index.html`).
- [ ] **Poner el enlace del botón final**: hoy es `href="#"`. Debe apuntar a un
      `https://wa.me/57...` o a una agenda tipo Calendly.
- [ ] **Verificar que `@chasqui_abanimalBot` esté arriba y respondiendo**: la
      sección «Pruébelo» invita a escribirle sin acompañamiento.
- [ ] Revisar que las tarifas estimadas sigan marcadas como referencia.

## Nota sobre privacidad

El HTML trae `noindex, nofollow` y `robots.txt` bloquea a los buscadores, así
que no va a aparecer en Google. Pero la URL **es pública para quien la tenga**:
no hay contraseña. Si eso importa, dejar el nombre aleatorio que asigna Netlify
en vez de uno adivinable.
