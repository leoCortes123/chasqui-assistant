// ---------------------------------------------------------------------------
// chasqui_responder — payload {conversacion_id, contacto_id, canal}
//
// El lado lento del asistente: llama a la API de DeepSeek, ejecuta las
// herramientas que pida y manda la respuesta por el canal de la conversación.
//
// Este archivo es deliberadamente tonto. No sabe qué es una ecografía, ni
// cuánto cuesta, ni quién puede agendar. Solo sabe tres cosas:
//
//   1. pedirle a la base el catálogo de herramientas y el historial,
//   2. reenviar cada llamada de herramienta a `ia_llamar`,
//   3. parar en seco cuando `ia_llamar` responde que algo necesita
//      confirmación, y mostrar la tarjeta que armó la base.
//
// Todo el criterio —qué se puede hacer, con qué audiencia, con qué permisos,
// qué texto ve la persona— vive en 040_asistente.sql y en el catálogo del
// dominio. Si mañana hay que agregar una herramienta, se agrega allá y aquí
// no se toca nada.
//
// El punto 3 es el que sostiene «las acciones las confirma la persona»: en
// cuanto una herramienta devuelve `requiere_confirmacion`, se abandona el
// turno del modelo. Lo que dijera después daría igual, porque no va a
// ejecutarse nada hasta que alguien toque el botón.
//
// Sobre el cliente: DeepSeek expone una API compatible con la de OpenAI, así
// que se usa el SDK de OpenAI apuntado a su servidor. Es el camino que la
// propia DeepSeek documenta, y evita reescribir reintentos y timeouts.
// ---------------------------------------------------------------------------

import OpenAI from 'openai';
import { responder, formatear } from '../canal.js';

export const tipo = 'chasqui_responder';

// Tope de vueltas del bucle consultar → responder. Con 8 le alcanza de sobra
// para cotizar un estudio, mirar los cupos y responder; si se pasa de ahí es
// que se enredó, y es mejor cortar que dejarlo girando contra la API cobrando
// por vuelta.
const MAX_VUELTAS = 8;

const BASE_URL = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com';

// Se construye una sola vez y se reutiliza: abre menos conexiones y el SDK ya
// trae reintentos con espera creciente para 429 y 5xx.
const cliente = process.env.DEEPSEEK_API_KEY
  ? new OpenAI({
      apiKey: process.env.DEEPSEEK_API_KEY,
      baseURL: BASE_URL,
      timeout: Number(process.env.IA_TIMEOUT_MS || 90_000),
      maxRetries: 2,
    })
  : null;

/**
 * Instrucciones del asistente. Se arman aquí y no en la base porque son sobre
 * CÓMO conversar; lo que puede hacer ya se lo dice el catálogo de
 * herramientas, que sí viene de la base.
 *
 * El protocolo: LAER
 * ------------------
 * Escuchar · Reconocer · Explorar · Responder. Lo desarrolló Carew
 * International como método de conversación comercial y es el que mejor
 * encaja aquí por una razón concreta: no es un embudo de marketing, es la
 * mecánica de un turno de conversación. Cada mensaje que escribe el asistente
 * pasa por los cuatro pasos, y el orden importa — reconocer antes de
 * informar es lo que separa a un recepcionista bueno de un contestador.
 *
 * De ese método sale también la regla que más cambia el tono: escuchar ocupa
 * más que hablar. Un asistente que suelta todo lo que sabe en el primer
 * mensaje no está atendiendo, está recitando.
 *
 * Sobre el objetivo comercial
 * ---------------------------
 * La persona que hoy atiende ese WhatsApp no está ahí para informar: está
 * para que el paciente llegue a la clínica. El asistente hace lo mismo, y por
 * eso cada mensaje cierra proponiendo el siguiente paso. La diferencia entre
 * proponer y presionar es que se propone UNA vez y se acepta el no.
 *
 * El límite que no se cruza
 * -------------------------
 * Suena natural, escribe como una persona y no anuncia que es un programa.
 * Pero si le preguntan de frente si es un bot, lo dice. Sostener la mentira
 * ante una pregunta directa es lo único que destruye la confianza de golpe —y
 * frente a un director médico, la confianza es el producto.
 */
/**
 * «buenos días» / «buenas tardes» / «buenas noches» según la hora de Bogotá.
 *
 * Se calcula aquí y no se le deja al modelo: sabe la hora, pero derivar la
 * franja es justo el tipo de detalle que falla una de cada veinte veces, y
 * «buenos días» a las nueve de la noche delata a un programa más que
 * cualquier otra cosa.
 */
function franjaHoraria(horaLocal) {
  const hora = Number(String(horaLocal ?? '').slice(0, 2));
  if (!Number.isFinite(hora)) return 'buen día';
  if (hora < 12) return 'buenos días';
  if (hora < 19) return 'buenas tardes';
  return 'buenas noches';
}

/**
 * Garantiza que el primer mensaje del hilo identifique a la clínica.
 *
 * El prompt lo pide, y aun así el modelo lo omite cuando la persona entra
 * directa con su consulta: se concentra en resolverla. Se le pidió de tres
 * formas distintas —al final del prompt, en mayúsculas, y de primero— y siguió
 * fallando una de cada dos veces.
 *
 * Así que deja de pedirse. Quien escribe a un número que no tiene guardado
 * tiene que saber quién le contesta, y eso no puede quedar sujeto a que el
 * modelo se acuerde. Si el texto ya se presenta —porque el prompt sí funcionó—
 * no se toca; si no, se antepone la línea. Nunca queda duplicado.
 */
function conPresentacion(texto, ctx, primerMensaje) {
  if (!primerMensaje || ctx.es_personal) return texto;

  const yaSePresenta =
    /chasqui/i.test(texto) ||
    (ctx.clinica && texto.toLowerCase().includes(String(ctx.clinica).toLowerCase()));

  if (yaSePresenta) return texto;

  const saludo = franjaHoraria(ctx.hora_local);
  const cabeza = `${saludo[0].toUpperCase()}${saludo.slice(1)}, habla Chasqui, de ${ctx.clinica}.`;

  return `${cabeza}\n\n${texto}`;
}

function instrucciones(ctx, primerMensaje) {
  const interno = ctx.es_personal;
  const saludo = franjaHoraria(ctx.hora_local);

  return [
    // --- Quién eres --------------------------------------------------
    `Eres quien atiende el WhatsApp de ${ctx.clinica}, una clínica veterinaria en ${ctx.ciudad}.`,
    interno
      ? `Hablas con ${ctx.interlocutor}, que trabaja aquí.`
      : `Escribes con ${ctx.interlocutor}. Es un cliente.`,
    '',
    'Escribe como escribe una persona del equipo: cercano, directo, sin',
    'formalidad de oficina y sin entusiasmo de vendedor. Tu trabajo es que la',
    'persona se sienta atendida y termine trayendo a su mascota.',
    '',

    // --- Presentación -------------------------------------------------
    //
    // Si es el primer mensaje o no, lo sabe el worker mirando el historial —
    // no se le pide al modelo que lo deduzca. Cuando la instrucción decía «si
    // es lo primero que escribes», el modelo se presentaba al recibir un
    // «hola» pero NO cuando la persona entraba directa con su consulta:
    // interpretaba que ahí ya estaba en medio de una conversación. Con la
    // rama decidida afuera, no hay nada que interpretar.
    primerMensaje
      ? [
          'ESTE ES TU PRIMER MENSAJE EN ESTA CONVERSACIÓN',
          '',
          'La persona le está escribiendo a un número que no tiene guardado. Si',
          'no le dices quién le contesta, no sabe si le respondió la clínica,',
          'otra veterinaria o un equivocado. Así que este mensaje —y solo este—',
          'empieza identificándote:',
          '',
          `- Saluda con "${saludo}". Es la franja horaria correcta ahora mismo:`,
          '  no la cambies.',
          '- Di tu nombre y el de la clínica: eres Chasqui, de ' + ctx.clinica + '.',
          '- Y sigue de una con lo que la persona necesita.',
          '',
          `Si te escribieron solo para saludar: "${saludo}, habla Chasqui, de`,
          `${ctx.clinica}. ¿En qué te ayudo?" y esperas.`,
          '',
          'Si te escribieron ya con su consulta, NO le hagas esperar un mensaje',
          'entero de presentación: júntalo con la respuesta, en la misma línea.',
          `Por ejemplo: "${saludo}, habla Chasqui de ${ctx.clinica}. Claro,`,
          'esa es la ecografía gestacional…" y sigues respondiendo normal.',
          '',
          'No copies las frases palabra por palabra: es el tono y la',
          'información que deben llevar, no una fórmula.',
          '',
          'Todo de "tú", incluida la presentación. "Le habla… ¿en qué TE ayudo?"',
          'mezcla los dos tratos y suena mal.',
          '',
          'Dos o tres líneas. Nada de listas de servicios ni de explicar lo que',
          'puedes hacer: la persona ya va a decirte lo que necesita.',
        ].join('\n')
      : 'YA TE PRESENTASTE EN ESTE CHAT. No vuelvas a saludar ni a decir quién\n' +
        'eres: repetir el saludo en cada mensaje es la marca más clara de un\n' +
        'robot. Sigue la conversación donde iba.',
    '',

    // --- Contexto ----------------------------------------------------
    'CONTEXTO DE AHORA',
    `- Hoy es ${ctx.fecha_hoy}, son las ${ctx.hora_local} en ${ctx.ciudad}.`,
    // Un dato ausente se declara ausente, y no se calla. Callarlo deja un
    // hueco, y el modelo rellena los huecos: con la sede sin sembrar inventó
    // una dirección y un horario completos, dichos con total naturalidad.
    // Un cliente que llega a una dirección falsa es peor que uno sin respuesta.
    ctx.direccion
      ? `- Quedamos en ${ctx.direccion}.`
      : '- NO TIENES la dirección. Si te la piden, dilo y ofrece pasar con un asesor. No la inventes.',
    ctx.telefono ? `- Teléfono: ${ctx.telefono}.` : null,
    interno ? `- Roles: ${(ctx.roles ?? []).join(', ') || 'sin rol asignado'}.` : null,
    '- El dinero es en pesos colombianos.',

    // Pacientes y citas van en el prompt de cada turno, y no en una
    // herramienta que el modelo tenga que acordarse de llamar.
    //
    // Las citas además arreglan un agujero real: la confirmación la dispara
    // un botón, no un mensaje, así que en la memoria del modelo lo último
    // que quedó fue "¿lo confirmo?" y nunca el "sí". Sin esta línea creía
    // que ninguna cita se había cerrado, y a alguien que pedía cancelar le
    // contestaba que no tenía nada agendado.
    (ctx.pacientes ?? []).length
      ? `- Ya conoces a: ${ctx.pacientes
          .map((p) => `${p.nombre} (${p.especie}${p.raza ? `, ${p.raza}` : ''})`)
          .join('; ')}. No vuelvas a preguntar lo que ya sabes.`
      : null,
    (ctx.citas ?? []).length
      ? `- Citas ya agendadas y confirmadas: ${ctx.citas
          .map((c) => `${c.paciente} — ${c.estudio}, ${c.cuando}, ${c.valor} (cita_id ${c.cita_id})`)
          .join(' | ')}. Están confirmadas: si preguntan, existen.`
      : '- No tiene ninguna cita agendada.',
    ctx.sobre_el_negocio
      ? `\nLO QUE SABES DEL NEGOCIO\n${ctx.sobre_el_negocio}`
      : '- NO TIENES los horarios ni los datos del negocio. Dilo y ofrece pasar con un asesor.',
    '',

    // --- Urgencias ---------------------------------------------------
    'URGENCIAS — antes que todo lo demás',
    '- NUNCA des un diagnóstico, ni sugieras un medicamento, una dosis o un',
    '  tratamiento, ni digas si algo "parece" grave o leve. No eres',
    '  veterinario, y decirlo no te resta autoridad: te la da.',
    '- Si el caso suena grave y el sistema no lo atajó antes que tú, usa',
    '  pedir_asesor de una vez y dile que traiga al paciente ya.',
    '- Si insisten en que opines clínicamente, di que eso lo define el médico',
    '  viendo al paciente, y ofrece la cita.',
    '',

    // --- El protocolo ------------------------------------------------
    'CÓMO RESPONDES — los cuatro pasos, en este orden',
    '',
    '1. ESCUCHA. Lee lo que te dijeron y lo que no. Si de verdad falta un dato',
    '   para poder ayudar, pregúntalo; si no falta, no preguntes por preguntar.',
    '',
    '2. RECONOCE. Antes de informar, una frase corta que muestre que',
    '   entendiste. «Claro», «uf, entiendo», «sí, eso preocupa». UNA frase, no',
    '   un párrafo de empatía: si te pasas suena a manual.',
    '',
    '3. EXPLORA. Cuando falte contexto que cambie tu respuesta —qué mascota,',
    '   qué edad, desde cuándo, si ya la vio un veterinario— pregunta UNA cosa,',
    '   la que más cambie lo que vas a decir. Nunca dos preguntas en el mismo',
    '   mensaje. Nunca un formulario: es exactamente lo que vinimos a',
    '   reemplazar.',
    '',
    '4. RESPONDE Y PROPÓN. Da la información concreta, y cierra proponiendo el',
    '   siguiente paso: agendar, venir, que traiga los estudios previos. Un',
    '   mensaje que informa y no propone nada deja a la persona sola decidiendo.',
    '   Propón una vez. Si dicen que no, no insistas: deja la puerta abierta y',
    '   ya.',
    '',

    // --- Voz ---------------------------------------------------------
    'CÓMO SUENAS',
    '- Español de Colombia, de "tú". Nunca "vos" ni "tenés" ni "ustedes" para',
    '  una sola persona.',
    '- Corto. Dos, tres, cuatro líneas. Estás en WhatsApp, no escribiendo un',
    '  correo. Si tienes que decir mucho, di lo importante y ofrece el resto.',
    '- Nada de listas con viñetas salvo que enumeres opciones reales entre las',
    '  que hay que escoger (horarios, estudios). Una persona no habla con',
    '  viñetas.',
    '- Nada de encabezados, negritas decorativas ni "¡Hola! 😊 ¿En qué puedo',
    '  ayudarte hoy?". Eso grita robot.',
    '- No anuncies lo que puedes hacer. Nadie llega a un mostrador y le leen el',
    '  menú de servicios: uno pregunta y le responden.',
    '- No cierres cada mensaje con "¿en qué más te puedo ayudar?". Cierra con',
    '  algo específico de lo que están hablando, o no cierres con nada.',
    '- Varía. No empieces siempre igual ni repitas las mismas frases.',
    '- Un emoji suelto está bien cuando cae natural. Dos en el mismo mensaje,',
    '  no.',
    '',

    // --- Honestidad --------------------------------------------------
    'LO QUE NO HACES',
    '- No inventas. Un dato que no esté arriba ni salga de una herramienta, NO',
    '  LO TIENES. Decir "déjame confirmártelo con un asesor" siempre es mejor',
    '  que acertar de casualidad: un precio o una dirección inventados llegan a',
    '  alguien que actúa sobre ellos.',
    '- No dices un precio de memoria. SIEMPRE cotizar_estudio, porque la tarifa',
    '  cambia domingos y festivos y el calendario está en el sistema.',
    '- Cuando el precio sea de referencia, dilo en la misma frase en que lo',
    '  das, no después: el valor final lo confirma el profesional según el',
    '  caso. Nunca lo presentes como cerrado si el sistema te dice que no lo',
    '  está.',
    '- No te haces pasar por humano si te preguntan de frente. Si te preguntan',
    '  si eres un bot, una persona o una máquina: dilo, sin drama, y sigue',
    '  atendiendo igual de bien. Ofrécele hablar con alguien del equipo si lo',
    '  prefiere.',
    '- No repites el nombre de la persona en cada mensaje. Una vez basta.',
    '- NUNCA anuncias algo que no hiciste. Si escribes "te paso con un asesor",',
    '  "ya le avisé al equipo" o "te agendo", tienes que haber llamado la',
    '  herramienta correspondiente EN ESTE MISMO TURNO. Decirlo sin hacerlo',
    '  deja a la persona esperando a alguien que nunca fue avisado, y es el',
    '  peor error que puedes cometer: hasta un "no puedo ayudarte con eso" es',
    '  mejor que una promesa que no se cumple.',
    '',

    // --- Acciones ----------------------------------------------------
    'ACCIONES QUE CAMBIAN DATOS (agendar, reagendar, cancelar, registrar)',
    'Tú no las ejecutas. Al usarlas, el sistema le muestra a la persona un',
    'resumen con un botón de confirmar, y solo ella decide. Úsalas cuando te lo',
    'pidan, sin pedir permiso antes por chat: el botón ES el permiso. Después',
    'de invocarla no digas nada más, el sistema se encarga de mostrarla.',
  ]
    .filter((l) => l !== null)
    .join('\n');
}

export async function manejar({ payload }, { db, log }) {
  const conversacionId = payload?.conversacion_id;
  const contactoId = payload?.contacto_id;

  if (!conversacionId || !contactoId) {
    throw new Error('payload sin conversacion_id o contacto_id');
  }

  // El hilo pudo pasar a manos de una persona entre que se encoló la tarea y
  // que el worker la tomó. Es el caso normal en una urgencia: se escala en el
  // webhook y esta tarea llega un segundo tarde.
  const { rows: cRows } = await db.query(
    `SELECT c.id, c.canal, c.chat_externo_id, bot_responde(c.id) AS responde,
            u.sede_id
       FROM conversacion c
       JOIN contacto ct ON ct.id = c.contacto_id
       LEFT JOIN usuario u ON u.id = ct.usuario_id
      WHERE c.id = $1`,
    [conversacionId],
  );
  const conversacion = cRows[0];

  if (!conversacion) throw new Error(`la conversación ${conversacionId} no existe`);
  if (!conversacion.responde) {
    log.info(`conversación ${conversacionId}: la atiende una persona, el bot se calla`);
    return { respondido: false, motivo: 'atendida_por_humano' };
  }

  if (!cliente) {
    // Falta la llave: no es recuperable reintentando, así que se avisa y se
    // completa la tarea en vez de quemar los intentos.
    await responder(
      db,
      conversacion,
      'En este momento no puedo responder automáticamente. Ya le avisé a una ' +
        'persona del equipo para que te atienda.',
    );
    await db.query('SELECT escalar_a_humano($1, $2)', [
      conversacionId,
      'asistente sin configurar (falta DEEPSEEK_API_KEY)',
    ]);
    log.aviso('DEEPSEEK_API_KEY no está configurada: el asistente no puede responder');
    return { respondido: false, motivo: 'sin_api_key' };
  }

  const sedeId = conversacion.sede_id ?? null;

  // Todo el estado viene de la base en una sola consulta: catálogo, historial,
  // contexto y parámetros. El worker no guarda nada entre tareas, así que dos
  // workers en paralelo no se pisan.
  const { rows } = await db.query(
    `SELECT ia_herramientas($1)          AS herramientas,
            ia_historial($2)             AS historial,
            ia_contexto($1, $3)          AS contexto,
            config_txt('ia_modelo', 'deepseek-v4-pro')  AS modelo,
            config_txt('ia_temperatura', '0.3')         AS temperatura`,
    [contactoId, conversacionId, sedeId],
  );
  const { herramientas, historial, contexto, modelo, temperatura } = rows[0];

  if (!historial.length) {
    log.aviso(`conversación ${conversacionId}: no hay nada que responder`);
    return { respondido: false, motivo: 'sin_historial' };
  }

  const mensajes = [
    { role: 'system', content: instrucciones(contexto, historial.length <= 1) },
    ...historial.map((m) => ({ role: m.role, content: m.content })),
  ];

  let pendiente = null; // primera acción que pidió confirmación
  let mensajeFinal = null;
  let vueltas = 0;
  const tokens = { entrada: 0, salida: 0 };

  while (vueltas < MAX_VUELTAS && !pendiente) {
    vueltas += 1;

    const respuesta = await cliente.chat.completions.create({
      model: modelo,
      messages: mensajes,
      // Sin catálogo (el dominio todavía no lo sembró) se omite el parámetro:
      // la API rechaza `tools: []`.
      ...(herramientas.length ? { tools: herramientas } : {}),
      temperature: Number(temperatura) || 0.3,
      max_tokens: 2048,
    });

    if (respuesta.usage) {
      tokens.entrada += respuesta.usage.prompt_tokens ?? 0;
      tokens.salida += respuesta.usage.completion_tokens ?? 0;
    }

    mensajeFinal = respuesta.choices?.[0]?.message;
    if (!mensajeFinal) break;

    // El turno del asistente entra al historial de esta vuelta con sus
    // tool_calls: la API exige que cada resultado que se mande después
    // corresponda a una llamada que ella misma pidió.
    //
    // `reasoning_content` se deja fuera a propósito: DeepSeek lo devuelve pero
    // no lo acepta de vuelta, y reenviarlo hace fallar la petición.
    mensajes.push({
      role: 'assistant',
      content: mensajeFinal.content ?? '',
      ...(mensajeFinal.tool_calls?.length ? { tool_calls: mensajeFinal.tool_calls } : {}),
    });

    const llamadas = mensajeFinal.tool_calls ?? [];
    if (llamadas.length === 0) break;

    for (const llamada of llamadas) {
      const nombre = llamada.function?.name;
      let argumentos = {};
      try {
        argumentos = JSON.parse(llamada.function?.arguments || '{}');
      } catch {
        // El modelo mandó JSON roto. Se le dice y que reintente.
        mensajes.push({
          role: 'tool',
          tool_call_id: llamada.id,
          content: JSON.stringify({ ok: false, error: 'Los argumentos no son JSON válido.' }),
        });
        continue;
      }

      let datos;
      try {
        const r = await db.query('SELECT ia_llamar($1, $2, $3, $4, $5) AS r', [
          contactoId,
          conversacionId,
          sedeId,
          nombre,
          JSON.stringify(argumentos),
        ]);
        datos = r.rows[0].r;
      } catch (err) {
        // Un error de base se le devuelve al modelo como resultado para que lo
        // cuente o corrija; no se cae la tarea por una consulta mala.
        datos = { ok: false, error: err.message };
      }

      log.info(
        `conversación ${conversacionId} · herramienta ${nombre} → ` +
          (datos?.requiere_confirmacion ? 'propuesta' : datos?.ok ? 'ok' : 'error'),
      );

      if (datos?.requiere_confirmacion && !pendiente) {
        pendiente = { ...datos, herramienta: nombre };
      }

      // Un resultado por cada llamada, sin saltarse ninguna: si falta uno, la
      // siguiente petición se rechaza entera.
      mensajes.push({
        role: 'tool',
        tool_call_id: llamada.id,
        content: JSON.stringify(datos),
      });
    }
  }

  // --- Caso 1: hay algo que confirmar --------------------------------------
  //
  // Los DATOS de la confirmación salen de la base, nunca de la redacción del
  // modelo: la tarjeta manda y va completa.
  //
  // Lo que sí se conserva es lo que el modelo haya escrito antes de llamar a
  // la herramienta, como preámbulo. Sin eso, alguien que escribe «cancelemos,
  // se me murió el gato» recibe de vuelta un formulario y nada más — y ese es
  // justo el momento en que la clínica no puede sonar a máquina.
  //
  // El preámbulo se descarta si trae cifras o fechas: eso es competencia de
  // la tarjeta, y dos versiones del precio en el mismo mensaje es peor que
  // una sola seca.
  if (pendiente) {
    const { rows: t } = await db.query('SELECT ia_tarjeta_confirmacion($1) AS t', [
      pendiente.accion_id,
    ]);
    const tarjeta = t[0].t;

    const preambulo = (mensajeFinal?.content ?? '').trim();
    const traeDatos = /\$|\d{1,2}:\d{2}|\b\d{1,2}\s+de\s+[a-záéíóú]+/i.test(preambulo);
    const texto =
      preambulo && !traeDatos
        ? `${formatear(preambulo)}\n\n${tarjeta.texto}`
        : tarjeta.texto;

    const r = await responder(db, conversacion, texto, tarjeta.botones ?? []);

    return {
      respondido: r.ok,
      confirmacion: pendiente.accion_id,
      herramienta: pendiente.herramienta,
      vueltas,
      tokens,
      envio: r.ok ? 'enviado' : `no enviado (${r.motivo})`,
    };
  }

  // --- Caso 2: respuesta de texto ------------------------------------------
  const texto = (mensajeFinal?.content ?? '').trim();

  if (!texto) {
    // Se quedó sin vueltas o contestó vacío. Pasa poco, pero un chat mudo es
    // peor que un aviso honesto.
    await responder(
      db,
      conversacion,
      'Me enredé con eso y no logré armar la respuesta. Vuelve a escribírmelo de ' +
        'otra forma, o escribe ASESOR y te atiende una persona.',
    );
    return { respondido: false, motivo: 'sin_texto', vueltas, tokens };
  }

  // `responder` registra el texto en `mensaje` y en la memoria del modelo. Solo
  // se guarda la respuesta final, no las llamadas a herramientas: los datos que
  // consultó ya están dentro del texto.
  const r = await responder(
    db,
    conversacion,
    conPresentacion(texto, contexto, historial.length <= 1),
    [],
    { markdown: true },
  );

  return {
    respondido: r.ok,
    vueltas,
    caracteres: texto.length,
    tokens,
    envio: r.ok ? 'enviado' : `no enviado (${r.motivo})`,
  };
}
