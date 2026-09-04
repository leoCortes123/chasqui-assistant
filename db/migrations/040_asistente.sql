-- =====================================================================
-- Chasqui Assistant — 040_asistente.sql
-- El motor conversacional. Heredado de `078_chasqui_ia.sql` de Chasqui Pet,
-- reenganchado al eje `actor` en vez de al eje `usuario`.
--
-- Qué es y qué NO es
-- ------------------
-- Es una puerta más al mismo sistema, no un sistema paralelo. El asistente
-- no tiene acceso a la base: tiene una lista cerrada de herramientas y cada
-- una llama a las MISMAS funciones que ya usan los botones y el portal. Por
-- eso hereda gratis lo que ya está probado: permisos, auditoría, append-only
-- y los mensajes de error en español que ya escribimos.
--
-- Las tres reglas que ordenan el diseño, intactas:
--
--   1. NADA de SQL libre. El modelo no escribe consultas; escoge una
--      herramienta de un catálogo y le pasa argumentos tipados. Lo que no
--      esté en `ia_herramienta` sencillamente no existe para él.
--
--   2. Los permisos son los del ACTOR, no los del asistente. Aquí está el
--      único cambio de fondo frente a Chasqui Pet: el catálogo se filtra
--      primero por AUDIENCIA —pública o interna— y solo después, y solo
--      para el actor interno, por `tiene_permiso`. Un desconocido que
--      escribe a WhatsApp no tiene rol ni permisos; tiene audiencia.
--
--   3. Leer se hace solo; ESCRIBIR se confirma con un botón. Cualquier
--      herramienta con `escribe = true` no se ejecuta al invocarla: deja
--      una propuesta en `ia_accion_pendiente` y se le muestra a la persona
--      exactamente qué va a pasar. La acción la dispara la persona, no el
--      modelo. **La regla no se relaja porque el interlocutor sea un
--      cliente en vez de un empleado.**
--
-- Este archivo NO trae ni una sola herramienta. `ia_leer` e `ia_escribir`
-- quedan vacías a propósito: el dominio las llena en `150_herramientas.sql`.
-- Así no sobrevive ni una referencia a turnos, inventario, caja o compras.
--
-- Reparto con el resto del sistema: la base decide QUÉ se puede hacer y
-- arma los textos; el worker solo habla con la API del modelo, que es I/O
-- lento y no cabe en el segundo que el webhook tiene para responder.
-- =====================================================================

SET client_min_messages = warning;

-- ---------------------------------------------------------------------
-- 1. Configuración
-- ---------------------------------------------------------------------
INSERT INTO config (clave, valor, tipo, descripcion, editable_ui) VALUES
  ('ia_activa', 'true', 'booleano',
   'Habilita el asistente conversacional', true),
  ('ia_modelo', 'deepseek-v4-pro', 'texto',
   'Modelo de DeepSeek que responde: deepseek-v4-pro (mejor) o deepseek-v4-flash (más barato)', true),
  ('ia_temperatura', '0.3', 'texto',
   'Qué tan suelto responde el modelo, de 0 a 1. Bajo = más literal y predecible', true),
  ('ia_turnos_memoria', '20', 'entero',
   'Cuántos mensajes recuerda la conversación antes de olvidar los viejos', true),
  ('ia_limite_hora', '60', 'entero',
   'Máximo de mensajes por contacto y por hora', true),
  ('ia_sobre_el_negocio', '', 'texto',
   'Notas libres sobre la clínica que el asistente puede usar para responder dudas del negocio', true)
ON CONFLICT (clave) DO NOTHING;


-- ---------------------------------------------------------------------
-- 2. Memoria de la conversación
--
-- Se guarda solo lo que se dijeron: la pregunta y la respuesta final, como
-- texto. Las llamadas a herramientas que el modelo haya hecho para llegar a
-- esa respuesta viven únicamente durante esa tarea y no se persisten —los
-- datos que sacó ya están dentro de lo que contestó, y guardar llamadas a
-- herramientas a medias es la forma más fácil de mandarle a la API un
-- historial que ella misma rechaza.
--
-- `ia_mensaje` no es `mensaje`, y la diferencia importa: `mensaje` (030) es
-- lo que de verdad viajó por el canal, para el panel y la auditoría;
-- `ia_mensaje` es lo que el modelo recuerda. Uno se conserva, el otro se
-- poda.
--
-- La poda la hace `ia_historial` al leer, no un job.
-- ---------------------------------------------------------------------
CREATE TABLE ia_mensaje (
  id              bigserial PRIMARY KEY,
  conversacion_id uuid NOT NULL REFERENCES conversacion(id) ON DELETE CASCADE,
  rol             text NOT NULL CHECK (rol IN ('user', 'assistant')),
  contenido       jsonb NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_ia_mensaje_conversacion ON ia_mensaje (conversacion_id, id DESC);


-- Propuestas de escritura a la espera del botón de confirmación.
--
-- Viven 10 minutos: una propuesta vieja se hizo sobre una agenda que ya
-- cambió, y confirmarla a ciegas media hora después es justamente lo que la
-- confirmación pretende evitar.
CREATE TABLE ia_accion_pendiente (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversacion_id uuid NOT NULL REFERENCES conversacion(id) ON DELETE CASCADE,
  contacto_id     uuid NOT NULL REFERENCES contacto(id) ON DELETE CASCADE,
  sede_id         uuid REFERENCES sede(id),
  herramienta     text NOT NULL,
  argumentos      jsonb NOT NULL DEFAULT '{}'::jsonb,
  resumen         text NOT NULL,
  estado          text NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente', 'confirmada', 'cancelada', 'expirada')),
  resultado       jsonb,
  created_at      timestamptz NOT NULL DEFAULT now(),
  expira_at       timestamptz NOT NULL DEFAULT now() + interval '10 minutes',
  resuelta_at     timestamptz
);

CREATE INDEX idx_ia_pendiente_conversacion
  ON ia_accion_pendiente (conversacion_id) WHERE estado = 'pendiente';


-- ---------------------------------------------------------------------
-- 3. Catálogo de herramientas
--
-- Una tabla y no un CASE gigante: el catálogo se consulta para armar lo que
-- se le manda al modelo, y se consulta otra vez para decidir si algo
-- escribe. Con dos listas separadas acabarían desincronizadas, y la que se
-- desincronizaría es la que dice «esto escribe» — la que importa.
--
--   audiencia 'publica' = la ve cualquiera que escriba al canal.
--             'interna' = solo el personal, y además sujeta a `permiso`.
--   permiso   NULL = cualquier miembro del personal. Solo aplica a las
--             internas: una herramienta pública con permiso sería una
--             contradicción, y el CHECK lo impide.
--   escribe   true = no se ejecuta sola, deja propuesta y espera el botón.
--   critica   true = la confirmación muestra los datos exactos (fecha, hora,
--             precio, paciente). Todo lo que agenda o cobra lo es.
--   esquema   JSON Schema de los argumentos, tal cual lo pide la API.
-- ---------------------------------------------------------------------
CREATE TABLE ia_herramienta (
  nombre      text PRIMARY KEY,
  audiencia   text NOT NULL DEFAULT 'interna'
                CHECK (audiencia IN ('publica', 'interna')),
  permiso     text REFERENCES permiso(codigo),
  escribe     boolean NOT NULL DEFAULT false,
  critica     boolean NOT NULL DEFAULT false,
  descripcion text NOT NULL,
  esquema     jsonb NOT NULL DEFAULT '{"type":"object","properties":{}}'::jsonb,
  orden       int NOT NULL DEFAULT 100,
  activa      boolean NOT NULL DEFAULT true,
  CONSTRAINT ia_herramienta_publica_sin_permiso
    CHECK (audiencia = 'interna' OR permiso IS NULL)
);

-- Sin seeds. El catálogo lo siembra el dominio, después de que existan los
-- permisos que referencia.


-- ---------------------------------------------------------------------
-- 4. Lo que el worker le manda al modelo
-- ---------------------------------------------------------------------

-- ¿Está disponible el asistente para este actor?
--
-- A diferencia de Chasqui Pet, no se exige fila en `usuario`: basta con ser
-- un contacto no bloqueado. Eso es todo el cambio de «personal interno» a
-- «público», y es el que hace que el resto del archivo sirva.
CREATE OR REPLACE FUNCTION ia_disponible(p_contacto_id uuid)
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT config_bool('ia_activa', true) AND p_contacto_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM contacto WHERE id = p_contacto_id AND NOT bloqueado);
$$;

-- Catálogo filtrado para este actor. Lo que no puede hacer, no lo ve.
--
--   · Las públicas las ve todo el mundo.
--   · Las internas solo el personal, y solo las que sus permisos habilitan.
--
-- Sale ya en el formato de «funciones» que espera la API de DeepSeek —el
-- mismo de OpenAI—, porque es el único que lo consume. Si algún día se
-- cambia de proveedor se cambia este jsonb_build_object y nada más: el
-- worker solo reenvía lo que salga de aquí.
CREATE OR REPLACE FUNCTION ia_herramientas(p_contacto_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'type', 'function',
           'function', jsonb_build_object(
             'name', h.nombre,
             'description', h.descripcion,
             'parameters', h.esquema)) ORDER BY h.orden), '[]'::jsonb)
    FROM ia_herramienta h
   WHERE h.activa
     AND (h.audiencia = 'publica'
          OR (actor_usuario(p_contacto_id) IS NOT NULL
              AND (h.permiso IS NULL
                   OR tiene_permiso(actor_usuario(p_contacto_id), h.permiso))));
$$;

-- Contexto que va en el prompt de sistema: quién habla, dónde y qué día es.
-- Sin esto el modelo responde en abstracto y pregunta cosas que ya sabemos.
--
-- La dirección y el teléfono de la sede van aquí a propósito: son la
-- respuesta a «¿dónde quedan?» y a «¿cómo llego?», que en una urgencia es
-- lo único que hay que contestar bien.
CREATE OR REPLACE FUNCTION ia_contexto(p_contacto_id uuid, p_sede_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
  a      jsonb := actor(p_contacto_id);
  v_sede record;
BEGIN
  SELECT nombre, direccion, telefono, ciudad INTO v_sede
    FROM sede
   WHERE (p_sede_id IS NULL AND activa) OR id = p_sede_id
   ORDER BY created_at
   LIMIT 1;

  RETURN jsonb_build_object(
    'clinica',        config_txt('nombre_clinica', 'la clínica'),
    'interlocutor',   COALESCE(a->>'nombre', 'alguien que escribe por primera vez'),
    'es_personal',    COALESCE((a->>'es_interno')::boolean, false),
    'roles',          COALESCE((SELECT jsonb_agg(rol_codigo)
                                  FROM usuario_rol
                                 WHERE usuario_id = actor_usuario(p_contacto_id)), '[]'::jsonb),
    'sede',           v_sede.nombre,
    'direccion',      v_sede.direccion,
    'telefono',       v_sede.telefono,
    'ciudad',         v_sede.ciudad,
    'fecha_hoy',      hoy_bogota(),
    'hora_local',     to_char(ahora_bogota(), 'HH24:MI'),
    'moneda',         'peso colombiano (COP)',
    'sobre_el_negocio', NULLIF(config_txt('ia_sobre_el_negocio', ''), ''));
END;
$$;

-- Historial reciente, del más viejo al más nuevo, podado al tamaño
-- configurado. Se corta por número de mensajes y no por tokens a propósito:
-- es un número que una persona de la clínica puede entender y ajustar desde
-- el portal sin saber qué es un token.
CREATE OR REPLACE FUNCTION ia_historial(p_conversacion_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('role', rol, 'content', contenido)
                            ORDER BY id), '[]'::jsonb)
    FROM (SELECT id, rol, contenido
            FROM ia_mensaje
           WHERE conversacion_id = p_conversacion_id
           ORDER BY id DESC
           LIMIT GREATEST(config_int('ia_turnos_memoria', 20), 2)) m;
$$;

CREATE OR REPLACE FUNCTION ia_registrar(
  p_conversacion_id uuid, p_rol text, p_contenido jsonb)
RETURNS void
LANGUAGE sql AS $$
  INSERT INTO ia_mensaje (conversacion_id, rol, contenido)
  VALUES (p_conversacion_id, p_rol, p_contenido);
$$;

CREATE OR REPLACE FUNCTION ia_olvidar(p_conversacion_id uuid)
RETURNS void
LANGUAGE sql AS $$
  DELETE FROM ia_mensaje WHERE conversacion_id = p_conversacion_id;
$$;


-- ---------------------------------------------------------------------
-- 5. Ejecución de herramientas de LECTURA
--
-- Vacía en el núcleo. El dominio la reemplaza con CREATE OR REPLACE y le
-- pone el CASE con sus herramientas.
--
-- Todo lo que devuelva debe ser jsonb: va derecho al modelo como resultado
-- de la herramienta. Devolver los identificadores (paciente_id, cita_id) no
-- es opcional — son los que después necesita para proponer una escritura, y
-- adivinar un UUID es exactamente lo que no queremos que intente.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ia_leer(
  p_contacto_id uuid, p_sede_id uuid, p_nombre text, p_args jsonb)
RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
  RETURN jsonb_build_object('ok', false,
    'error', format('La herramienta %s no existe.', p_nombre));
END;
$$;


-- ---------------------------------------------------------------------
-- 6. Ejecución de herramientas de ESCRITURA
--
-- Esta función NO la llama el modelo: la llama `ia_confirmar` después de
-- que la persona tocó el botón. Es el único camino por el que una
-- conversación puede cambiar algo en la base.
--
-- Vacía en el núcleo, igual que `ia_leer`.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ia_escribir(
  p_contacto_id uuid, p_sede_id uuid, p_nombre text, p_args jsonb)
RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
  RETURN jsonb_build_object('ok', false,
    'mensaje', format('La herramienta %s no existe.', p_nombre));
END;
$$;


-- ---------------------------------------------------------------------
-- 7. La tarjeta de confirmación
--
-- Se arma en SQL, con los datos frescos de la base y no con lo que el
-- modelo crea recordar. Es la diferencia entre «confirma la cita» y
-- «confirma la ecografía abdominal de Saria el lunes 4 a las 9:00 am,
-- $172.000, con ayuno desde las 9:00 pm». Lo segundo se puede revisar; lo
-- primero se aprueba sin leer.
--
-- El dominio la reemplaza. El texto genérico de aquí es el que se ve si
-- alguien agrega una herramienta y olvida escribirle su resumen: dice poco,
-- pero no miente.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ia_resumen_accion(
  p_contacto_id uuid, p_sede_id uuid, p_nombre text, p_args jsonb)
RETURNS text
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN 'Acción: ' || esc(p_nombre);
END;
$$;


-- ---------------------------------------------------------------------
-- 7 bis. El filtro de la tarjeta
--
-- Devuelve NULL si los argumentos sirven, o el texto del error si no. Ese
-- texto lo lee el modelo, no la persona: se escribe diciéndole qué hacer
-- para corregir, igual que los errores de las funciones de negocio.
--
-- Aquí no se valida todo lo que valida la función de negocio —el cupo, el
-- horario, el bloqueo—: eso depende del instante en que se confirma y su
-- lugar es la confirmación. Lo que se ataja aquí es lo que dejaría armar una
-- tarjeta sobre algo que no existe.
--
-- El dominio la reemplaza, igual que a `ia_resumen_accion`. Sin dominio no
-- valida nada, que es el comportamiento que había.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ia_validar_accion(p_nombre text, p_args jsonb)
RETURNS text
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN NULL;
END;
$$;


-- ---------------------------------------------------------------------
-- 8. La puerta única: lo que el worker llama por cada herramienta
--
-- Devuelve o el dato (lectura) o una propuesta con su identificador
-- (escritura). El worker no decide nada de esto: pregunta y obedece.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ia_llamar(
  p_contacto_id uuid, p_conversacion_id uuid, p_sede_id uuid,
  p_nombre text, p_args jsonb)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  h         ia_herramienta%ROWTYPE;
  v_usuario uuid := actor_usuario(p_contacto_id);
  v_id      uuid;
  v_resumen text;
  v_error   text;
BEGIN
  SELECT * INTO h FROM ia_herramienta WHERE nombre = p_nombre AND activa;

  IF h.nombre IS NULL THEN
    RETURN jsonb_build_object('ok', false,
      'error', format('No existe una herramienta llamada %s.', p_nombre));
  END IF;

  -- Segunda reja. La primera fue no ponerla en el catálogo que se le mandó;
  -- la tercera es el `exigir_permiso` de la propia función de negocio.
  -- Tres, porque una sola se puede olvidar al agregar la herramienta número
  -- quince.
  --
  -- Aquí se revisa primero la audiencia: un contacto del público que le pida
  -- al modelo una herramienta interna —porque la vio en otra conversación o
  -- porque se la inventó— no pasa de esta línea.
  IF h.audiencia = 'interna' AND v_usuario IS NULL THEN
    RETURN jsonb_build_object('ok', false,
      'error', 'Esa herramienta es solo para el personal de la clínica. Sigue la '
               'conversación con normalidad y no la menciones.');
  END IF;

  IF h.permiso IS NOT NULL AND NOT tiene_permiso(v_usuario, h.permiso) THEN
    RETURN jsonb_build_object('ok', false,
      'error', 'El usuario no tiene permiso para esto. Díselo con naturalidad y ofrécele '
               'otra cosa; no lo intentes por otro camino.');
  END IF;

  IF NOT h.escribe THEN
    BEGIN
      RETURN ia_leer(p_contacto_id, p_sede_id, p_nombre, COALESCE(p_args, '{}'::jsonb));
    EXCEPTION WHEN others THEN
      -- Un argumento mal formado (un UUID inventado, una fecha rara) no
      -- puede tumbar la tarea: se le devuelve al modelo como resultado para
      -- que corrija y vuelva a intentar.
      RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
    END;
  END IF;

  -- Escritura: no se ejecuta, se propone. Vale igual para el público.
  --
  -- Antes de proponer, se revisan los argumentos. La función de negocio ya
  -- los valida —`agendar_cita` rechaza un estudio que no existe—, pero la
  -- valida al CONFIRMAR, y para entonces la tarjeta ya se mostró. El modelo
  -- inventó el código «ECO-ABD» (el real es `eco_abdominal`) y la tarjeta
  -- salió con el estudio en blanco y el precio en $0: un resumen construido
  -- sobre una fila que no existe no falla, sale vacío. Y una tarjeta vacía es
  -- peor que un error, porque tiene un botón debajo.
  --
  -- El error no se lanza: se le devuelve al modelo igual que en la rama de
  -- lectura, para que corrija con `listar_estudios` y vuelva a proponer.
  --
  -- Validar y resumir van en el mismo bloque protegido: los dos leen los
  -- argumentos crudos y a los dos los puede tumbar una fecha que no es una
  -- fecha. Es la misma razón por la que la rama de lectura tiene su EXCEPTION.
  BEGIN
    v_error := ia_validar_accion(p_nombre, COALESCE(p_args, '{}'::jsonb));
    IF v_error IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', v_error);
    END IF;

    -- El resumen se calcula ANTES de guardar y con los datos de este
    -- instante. Si entre la propuesta y el botón alguien más toma ese cupo,
    -- la tarjeta dirá lo que era cierto cuando se propuso y la función de
    -- negocio rechazará al confirmar: se falla, no se adivina.
    v_resumen := ia_resumen_accion(p_contacto_id, p_sede_id, p_nombre,
                                   COALESCE(p_args, '{}'::jsonb));
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
  END;

  INSERT INTO ia_accion_pendiente
    (conversacion_id, contacto_id, sede_id, herramienta, argumentos, resumen)
  VALUES
    (p_conversacion_id, p_contacto_id, p_sede_id, p_nombre,
     COALESCE(p_args, '{}'::jsonb), v_resumen)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'ok', true,
    'requiere_confirmacion', true,
    'accion_id', v_id,
    'critica', h.critica,
    'resumen', v_resumen);
END;
$$;

-- Ejecuta la propuesta. Aquí es donde por fin cambia algo.
CREATE OR REPLACE FUNCTION ia_confirmar(p_id uuid, p_contacto_id uuid)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  a     ia_accion_pendiente%ROWTYPE;
  v     jsonb;
  v_canal text;
BEGIN
  -- FOR UPDATE y el filtro por estado: dos toques rápidos al mismo botón no
  -- pueden agendar dos veces.
  SELECT * INTO a FROM ia_accion_pendiente
   WHERE id = p_id AND estado = 'pendiente' FOR UPDATE;

  IF a.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mensaje', 'Esa confirmación ya no está disponible.');
  END IF;

  -- Que confirme el mismo que pidió. El botón viene autenticado por el
  -- canal, pero uno reenviado a otro chat no debe servir.
  IF a.contacto_id <> p_contacto_id THEN
    RETURN jsonb_build_object('ok', false, 'mensaje', 'Esa confirmación no es tuya.');
  END IF;

  IF a.expira_at < now() THEN
    UPDATE ia_accion_pendiente SET estado = 'expirada', resuelta_at = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', false,
      'mensaje', 'Pasaron más de 10 minutos y los datos pudieron cambiar. Pídemelo otra vez.');
  END IF;

  BEGIN
    v := ia_escribir(a.contacto_id, a.sede_id, a.herramienta, a.argumentos);
  EXCEPTION
    WHEN insufficient_privilege THEN
      v := jsonb_build_object('ok', false, 'mensaje', 'No tienes permiso para esa acción.');
    WHEN others THEN
      v := jsonb_build_object('ok', false, 'mensaje', SQLERRM);
  END;

  UPDATE ia_accion_pendiente
     SET estado = 'confirmada', resultado = v, resuelta_at = now()
   WHERE id = p_id;

  SELECT canal INTO v_canal FROM conversacion WHERE id = a.conversacion_id;

  PERFORM auditar('ia_accion_pendiente', p_id::text, 'confirmar',
                  actor_usuario(a.contacto_id), COALESCE(v_canal, 'sistema'),
                  NULL, jsonb_build_object('herramienta', a.herramienta,
                                           'argumentos', a.argumentos,
                                           'contacto_id', a.contacto_id,
                                           'ok', v->'ok'));

  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION ia_cancelar(p_id uuid, p_contacto_id uuid)
RETURNS void
LANGUAGE sql AS $$
  UPDATE ia_accion_pendiente
     SET estado = 'cancelada', resuelta_at = now()
   WHERE id = p_id AND contacto_id = p_contacto_id AND estado = 'pendiente';
$$;

-- La tarjeta, en la forma neutra que entiende cualquier canal. Quien la
-- traduce a botones de WhatsApp, a un teclado de Telegram o a HTML en el
-- simulador es el worker.
CREATE OR REPLACE FUNCTION ia_tarjeta_confirmacion(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE a ia_accion_pendiente%ROWTYPE;
BEGIN
  SELECT * INTO a FROM ia_accion_pendiente WHERE id = p_id;
  IF a.id IS NULL THEN
    RETURN jsonb_build_object('texto', 'Esa acción ya no está disponible.',
                              'botones', '[]'::jsonb);
  END IF;

  RETURN jsonb_build_object(
    'texto', a.resumen || E'\n\n' || '¿Lo confirmo?',
    'botones', jsonb_build_array(
      jsonb_build_object('t', '✅ Sí, confirmar', 'd', 'ia:ok:' || a.id),
      jsonb_build_object('t', '✖️ No', 'd', 'ia:no:' || a.id)));
END;
$$;


-- ---------------------------------------------------------------------
-- 9. La entrada del canal
--
-- Reemplaza a `bot_ia_texto` de Chasqui Pet, que estaba amarrado al menú de
-- botones de Telegram. Aquí no hay «entrar al modo conversación»: la
-- conversación ES el modo. Alguien que escribe a WhatsApp no toca un botón
-- primero.
--
-- Aquí no se llama a nadie por internet: el webhook tiene que devolverle
-- algo al canal en menos de un segundo. Todo lo lento va a la cola.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION asistente_recibir(
  p_conversacion_id uuid,
  p_texto text,
  p_id_externo text DEFAULT NULL,
  p_tipo text DEFAULT 'texto',
  p_payload jsonb DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  c        conversacion%ROWTYPE;
  v_msg_id bigint;
BEGIN
  SELECT * INTO c FROM conversacion WHERE id = p_conversacion_id;
  IF c.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mensaje', 'Esa conversación no existe.');
  END IF;

  -- Idempotencia: el canal reintenta. Si este mensaje ya se registró, se
  -- descarta entero — no se vuelve a encolar una respuesta.
  v_msg_id := mensaje_registrar(p_conversacion_id, 'entrante', p_texto,
                                p_tipo, p_payload, p_id_externo);
  IF v_msg_id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'duplicado', true, 'responde', false);
  END IF;

  -- El hilo está en manos de una persona: se guarda lo que dijo el cliente
  -- para que el panel lo muestre, y el bot se queda callado.
  IF NOT bot_responde(p_conversacion_id) THEN
    RETURN jsonb_build_object('ok', true, 'responde', false,
                              'motivo', 'atendida_por_humano');
  END IF;

  IF NOT ia_disponible(c.contacto_id) THEN
    RETURN jsonb_build_object('ok', true, 'responde', false, 'motivo', 'ia_apagada');
  END IF;

  -- Un chat secuestrado no puede quemar la cuenta del modelo en una noche.
  IF NOT consumir_rate_limit('ia:' || c.contacto_id::text,
                             config_int('ia_limite_hora', 60), 3600) THEN
    RETURN jsonb_build_object('ok', true, 'responde', false, 'motivo', 'rate_limit',
      'texto', 'Hemos hablado mucho en la última hora. Dame un momento, '
               'o escribe ASESOR si necesitas atención inmediata.');
  END IF;

  PERFORM ia_registrar(p_conversacion_id, 'user', to_jsonb(p_texto));

  PERFORM encolar_tarea('chasqui_responder',
    jsonb_build_object('conversacion_id', p_conversacion_id,
                       'contacto_id', c.contacto_id,
                       'canal', c.canal),
    5,          -- prioridad alta: hay alguien esperando frente al teléfono
    NULL, 0, 2  -- 2 intentos: si el modelo falla dos veces, mejor avisar que insistir
  );

  RETURN jsonb_build_object('ok', true, 'responde', true, 'mensaje_id', v_msg_id);
END;
$$;

-- Lo que el bot contestó. Se registra en los dos lados: en `mensaje` porque
-- viajó por el canal y el panel tiene que poder mostrarlo, y en `ia_mensaje`
-- porque el modelo tiene que recordar que ya lo dijo.
CREATE OR REPLACE FUNCTION asistente_responder(
  p_conversacion_id uuid,
  p_texto text,
  p_payload jsonb DEFAULT NULL)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
  v_id := mensaje_registrar(p_conversacion_id, 'saliente', p_texto, 'texto', p_payload);
  PERFORM ia_registrar(p_conversacion_id, 'assistant', to_jsonb(p_texto));
  RETURN v_id;
END;
$$;
