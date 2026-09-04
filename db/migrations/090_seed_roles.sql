-- =====================================================================
-- Chasqui Assistant — 090_seed_roles.sql
-- Roles y permisos como datos. Cambiar quién puede hacer qué es un UPDATE,
-- no un despliegue.
--
-- Por qué va aquí y no al final
-- -----------------------------
-- Chasqui Pet sembraba los permisos en `100_seed_roles.sql`, DESPUÉS de
-- `078_chasqui_ia.sql`, que inserta el catálogo de herramientas con una FK
-- a `permiso`. Desde un volumen vacío eso aborta la inicialización en la
-- primera herramienta con permiso, y todo lo que viene después —grants,
-- superadmin, seeds— no llega a correr.
--
-- La regla que sale de ahí: **los permisos se siembran antes que cualquier
-- catálogo que los referencie.** Por eso este archivo es 090 y el catálogo
-- del dominio es 150.
--
-- Los permisos son datos, así que no dependen de que exista la tabla que
-- protegen: `citas.gestionar` se puede sembrar aquí aunque `cita` nazca en
-- `120_agenda.sql`.
-- =====================================================================

SET client_min_messages = warning;

INSERT INTO rol (codigo, nombre, descripcion, nivel, sistema) VALUES
  ('superadmin',  'Superadministrador',
   'Acceso técnico total, configuración del sistema, auditoría y tareas fallidas.', 100, true),
  ('admin',       'Administrador',
   'Administra la clínica: usuarios, catálogo de estudios, tarifas, agenda y reportes.', 80, true),
  ('veterinario', 'Veterinario',
   'Ve la agenda y la historia clínica, atiende conversaciones escaladas y registra consultas.', 60, true),
  ('recepcion',   'Recepción',
   'Atiende el chat, agenda y reagenda estudios, registra tutores y pacientes.', 40, true)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO permiso (codigo, modulo, descripcion) VALUES
  -- Conversaciones: el canal de atención
  ('conversaciones.ver',      'canal',    'Ver las conversaciones activas y su historial'),
  ('conversaciones.atender',  'canal',    'Escribir en un hilo y devolvérselo al bot'),
  -- Clínico
  ('pacientes.ver',           'clinico',  'Ver tutores, pacientes e historia clínica'),
  ('pacientes.editar',        'clinico',  'Crear y editar tutores y pacientes'),
  ('consulta.crear',          'clinico',  'Crear y editar consultas en borrador'),
  ('consulta.firmar',         'clinico',  'Firmar una consulta y volverla registro clínico válido'),
  -- Agenda y estudios
  ('agenda.ver',              'agenda',   'Ver la agenda, los cupos y la lista de espera'),
  ('agenda.gestionar',        'agenda',   'Agendar, reagendar y cancelar citas'),
  ('agenda.disponibilidad',   'agenda',   'Definir bloques de disponibilidad por equipo y modalidad'),
  ('estudios.catalogo',       'agenda',   'Crear y editar estudios, preparaciones y tarifas'),
  -- Reportes y administración
  ('reportes.operativos',     'reportes', 'Reportes de agenda, estudios, no-shows y conversaciones'),
  ('reportes.financieros',    'reportes', 'Reportes de facturación estimada y cupos recuperados'),
  ('usuarios.gestionar',      'admin',    'Crear usuarios, asignar roles y permisos'),
  ('config.editar',           'admin',    'Editar configuración operativa, sedes y parámetros del asistente'),
  ('auditoria.ver',           'admin',    'Consultar la auditoría'),
  ('sistema.operar',          'admin',    'Bandeja de tareas fallidas, backups y salud del sistema')
ON CONFLICT (codigo) DO NOTHING;

-- superadmin: todo.
INSERT INTO rol_permiso (rol_codigo, permiso_codigo)
SELECT 'superadmin', codigo FROM permiso
ON CONFLICT DO NOTHING;

-- admin: todo excepto la operación técnica del sistema.
INSERT INTO rol_permiso (rol_codigo, permiso_codigo)
SELECT 'admin', codigo FROM permiso WHERE codigo <> 'sistema.operar'
ON CONFLICT DO NOTHING;

-- veterinario: lee la agenda y la historia, firma consultas y puede tomar
-- una conversación escalada. No define disponibilidad ni toca tarifas.
INSERT INTO rol_permiso (rol_codigo, permiso_codigo) VALUES
  ('veterinario', 'conversaciones.ver'),
  ('veterinario', 'conversaciones.atender'),
  ('veterinario', 'pacientes.ver'),
  ('veterinario', 'pacientes.editar'),
  ('veterinario', 'consulta.crear'),
  ('veterinario', 'consulta.firmar'),
  ('veterinario', 'agenda.ver'),
  ('veterinario', 'agenda.gestionar'),
  ('veterinario', 'reportes.operativos')
ON CONFLICT DO NOTHING;

-- recepción: es quien vive en el chat. Agenda y registra, pero no firma
-- nada clínico ni cambia el catálogo de estudios.
INSERT INTO rol_permiso (rol_codigo, permiso_codigo) VALUES
  ('recepcion', 'conversaciones.ver'),
  ('recepcion', 'conversaciones.atender'),
  ('recepcion', 'pacientes.ver'),
  ('recepcion', 'pacientes.editar'),
  ('recepcion', 'agenda.ver'),
  ('recepcion', 'agenda.gestionar'),
  ('recepcion', 'reportes.operativos')
ON CONFLICT DO NOTHING;
