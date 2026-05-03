insert into public.official_sources (
  agency,
  authority,
  title,
  url,
  source_kind,
  jurisdiction,
  notes,
  checked_at
)
values (
  'DMV',
  'official',
  'Utah Driver Handbook',
  'https://dld.utah.gov/wp-content/uploads/Driver-Handbook.pdf',
  'dmv_handbook',
  'UT',
  'Official Utah Driver License Division handbook PDF used for initial Spanish practice questions.',
  now()
)
on conflict (url) do update
set
  agency = excluded.agency,
  authority = excluded.authority,
  title = excluded.title,
  source_kind = excluded.source_kind,
  jurisdiction = excluded.jurisdiction,
  notes = excluded.notes,
  checked_at = now();

with source as (
  select id
  from public.official_sources
  where url = 'https://dld.utah.gov/wp-content/uploads/Driver-Handbook.pdf'
),
question_set as (
  insert into public.dmv_question_sets (
    state_code,
    language,
    source_id,
    version_label,
    active,
    verified_at
  )
  select
    'UT',
    'es',
    source.id,
    'Utah Driver Handbook current',
    true,
    now()
  from source
  on conflict (state_code, language, version_label) do update
  set
    source_id = excluded.source_id,
    active = true,
    verified_at = excluded.verified_at,
    updated_at = now()
  returning id
),
cleared as (
  delete from public.dmv_questions
  where question_set_id in (select id from question_set)
)
insert into public.dmv_questions (
  question_set_id,
  prompt,
  options,
  correct_option_key,
  explanation,
  topic
)
select
  question_set.id,
  item.prompt,
  item.options::jsonb,
  item.correct_option_key,
  item.explanation,
  item.topic
from question_set
cross join (
  values
    (
      'Si no hay senal, cual es el limite en una zona residencial o comercial de Utah?',
      '[{"key":"a","label":"35 mph"},{"key":"b","label":"25 mph"},{"key":"c","label":"45 mph"}]',
      'b',
      'El manual de Utah indica 25 mph en areas residenciales o comerciales sin senal.',
      'speed'
    ),
    (
      'Cual es la velocidad indicada al pasar por una escuela durante entrada, salida o luces intermitentes?',
      '[{"key":"a","label":"20 mph"},{"key":"b","label":"30 mph"},{"key":"c","label":"55 mph"}]',
      'a',
      'El manual de Utah lista 20 mph al pasar una escuela durante recreo, entrada/salida o luces intermitentes.',
      'speed'
    ),
    (
      'Que exige una luz roja antes de entrar a una interseccion?',
      '[{"key":"a","label":"Seguir si no viene nadie"},{"key":"b","label":"Tocar bocina y avanzar"},{"key":"c","label":"Detenerse antes de entrar y esperar hasta que sea permitido"}]',
      'c',
      'Ante luz roja debes detenerte antes de entrar a la interseccion.',
      'signals'
    ),
    (
      'Que debe hacer ante una luz amarilla intermitente?',
      '[{"key":"a","label":"Acelerar para no bloquear"},{"key":"b","label":"Reducir velocidad y proceder con cautela"},{"key":"c","label":"Detenerse siempre 10 segundos"}]',
      'b',
      'Una luz amarilla intermitente requiere reducir velocidad y proceder con cautela.',
      'signals'
    ),
    (
      'Que regla aplica con luces altas cuando hay vehiculos aproximandose?',
      '[{"key":"a","label":"Usarlas siempre en ciudad"},{"key":"b","label":"Apagarlas solo si hay niebla"},{"key":"c","label":"Bajarlas ante trafico cercano"}]',
      'c',
      'El manual indica bajar luces altas ante trafico cercano para no encandilar.',
      'night-driving'
    )
) as item(prompt, options, correct_option_key, explanation, topic);
