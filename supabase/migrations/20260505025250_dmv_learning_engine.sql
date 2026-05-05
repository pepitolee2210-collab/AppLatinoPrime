-- DMV learning engine.
-- Official source research performed 2026-05-05 from state .gov/.us pages:
-- USAGov state motor vehicle services, Utah DLD, California DMV, Florida FLHSMV,
-- New York DMV, and Texas DPS.

create table if not exists public.dmv_handbook_versions (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null references public.us_states(code) on delete cascade,
  language text not null default 'en',
  source_id uuid not null references public.official_sources(id),
  version_label text not null,
  published_at date,
  storage_bucket text,
  storage_path text,
  content_sha256 text,
  active boolean not null default true,
  verified_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (state_code, language, version_label)
);

create index if not exists dmv_handbook_versions_state_active_idx
on public.dmv_handbook_versions(state_code, language, active, verified_at desc);

create trigger dmv_handbook_versions_set_updated_at
before update on public.dmv_handbook_versions
for each row execute function public.set_updated_at();

create table if not exists public.dmv_exam_configs (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null references public.us_states(code) on delete cascade,
  license_type text not null default 'standard_operator',
  language text not null default 'es',
  exam_name text not null,
  question_count int check (question_count is null or question_count > 0),
  passing_score int check (passing_score is null or passing_score >= 0),
  passing_score_percent numeric(5,2)
    check (passing_score_percent is null or (passing_score_percent >= 0 and passing_score_percent <= 100)),
  time_limit_minutes int check (time_limit_minutes is null or time_limit_minutes > 0),
  open_book boolean,
  delivery_modes text[] not null default array[]::text[],
  available_languages text[] not null default array[]::text[],
  must_correct_rules jsonb not null default '{}'::jsonb,
  official_source_id uuid not null references public.official_sources(id),
  active boolean not null default true,
  verified_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (state_code, license_type, language, exam_name),
  check (passing_score is null or question_count is null or passing_score <= question_count)
);

create index if not exists dmv_exam_configs_state_active_idx
on public.dmv_exam_configs(state_code, language, active, verified_at desc);

create trigger dmv_exam_configs_set_updated_at
before update on public.dmv_exam_configs
for each row execute function public.set_updated_at();

create table if not exists public.dmv_learning_modules (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null references public.us_states(code) on delete cascade,
  language text not null default 'es',
  module_key text not null,
  title_es text not null,
  title_en text,
  summary_es text not null,
  source_id uuid not null references public.official_sources(id),
  display_order int not null default 0,
  active boolean not null default true,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (state_code, language, module_key)
);

create index if not exists dmv_learning_modules_state_order_idx
on public.dmv_learning_modules(state_code, language, active, display_order);

create trigger dmv_learning_modules_set_updated_at
before update on public.dmv_learning_modules
for each row execute function public.set_updated_at();

alter table public.dmv_questions
  add column if not exists module_key text,
  add column if not exists difficulty text not null default 'standard'
    check (difficulty in ('intro', 'standard', 'hard')),
  add column if not exists source_ref text,
  add column if not exists display_order int not null default 0,
  add column if not exists active boolean not null default true;

create index if not exists dmv_questions_active_order_idx
on public.dmv_questions(question_set_id, active, display_order);

create table if not exists public.dmv_practice_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  state_code char(2) not null references public.us_states(code),
  question_set_id uuid references public.dmv_question_sets(id) on delete set null,
  exam_config_id uuid references public.dmv_exam_configs(id) on delete set null,
  mode text not null default 'practice' check (mode in ('practice', 'simulation')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  total_questions int not null default 0 check (total_questions >= 0),
  score_correct int not null default 0 check (score_correct >= 0),
  passed boolean,
  duration_seconds int check (duration_seconds is null or duration_seconds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (score_correct <= total_questions)
);

create index if not exists dmv_practice_attempts_user_created_idx
on public.dmv_practice_attempts(user_id, created_at desc);

create index if not exists dmv_practice_attempts_state_idx
on public.dmv_practice_attempts(state_code, completed_at desc);

create trigger dmv_practice_attempts_set_updated_at
before update on public.dmv_practice_attempts
for each row execute function public.set_updated_at();

create table if not exists public.dmv_practice_attempt_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.dmv_practice_attempts(id) on delete cascade,
  question_id uuid not null references public.dmv_questions(id) on delete cascade,
  selected_option_key text not null,
  correct boolean not null default false,
  answered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (attempt_id, question_id)
);

create index if not exists dmv_practice_attempt_answers_attempt_idx
on public.dmv_practice_attempt_answers(attempt_id);

alter table public.dmv_handbook_versions enable row level security;
alter table public.dmv_exam_configs enable row level security;
alter table public.dmv_learning_modules enable row level security;
alter table public.dmv_practice_attempts enable row level security;
alter table public.dmv_practice_attempt_answers enable row level security;

drop policy if exists "dmv_handbook_versions_read_authenticated" on public.dmv_handbook_versions;
create policy "dmv_handbook_versions_read_authenticated"
on public.dmv_handbook_versions for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "dmv_handbook_versions_staff_write" on public.dmv_handbook_versions;
create policy "dmv_handbook_versions_staff_write"
on public.dmv_handbook_versions for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "dmv_exam_configs_read_authenticated" on public.dmv_exam_configs;
create policy "dmv_exam_configs_read_authenticated"
on public.dmv_exam_configs for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "dmv_exam_configs_staff_write" on public.dmv_exam_configs;
create policy "dmv_exam_configs_staff_write"
on public.dmv_exam_configs for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "dmv_learning_modules_read_authenticated" on public.dmv_learning_modules;
create policy "dmv_learning_modules_read_authenticated"
on public.dmv_learning_modules for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "dmv_learning_modules_staff_write" on public.dmv_learning_modules;
create policy "dmv_learning_modules_staff_write"
on public.dmv_learning_modules for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "dmv_questions_read_authenticated" on public.dmv_questions;
create policy "dmv_questions_read_authenticated"
on public.dmv_questions for select
to authenticated
using (
  (dmv_questions.active = true or private.is_staff())
  and exists (
    select 1 from public.dmv_question_sets qs
    where qs.id = dmv_questions.question_set_id
      and (qs.active = true or private.is_staff())
  )
);

drop policy if exists "dmv_practice_attempts_own_or_staff" on public.dmv_practice_attempts;
create policy "dmv_practice_attempts_own_or_staff"
on public.dmv_practice_attempts for all
to authenticated
using (user_id = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "dmv_practice_attempt_answers_own_or_staff" on public.dmv_practice_attempt_answers;
create policy "dmv_practice_attempt_answers_own_or_staff"
on public.dmv_practice_attempt_answers for all
to authenticated
using (
  exists (
    select 1
    from public.dmv_practice_attempts attempt
    where attempt.id = dmv_practice_attempt_answers.attempt_id
      and (attempt.user_id = (select auth.uid()) or private.is_staff())
  )
)
with check (
  exists (
    select 1
    from public.dmv_practice_attempts attempt
    where attempt.id = dmv_practice_attempt_answers.attempt_id
      and (attempt.user_id = (select auth.uid()) or private.is_staff())
  )
);

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
values
  ('DMV', 'official', 'Utah Driver License Division resources', 'https://dld.utah.gov/resources/', 'dmv_resources', 'UT', 'Official Utah DLD resources page listing current driver handbooks.', now()),
  ('DMV', 'official', 'Utah Driver Handbook English 2025-2026', 'https://dld.utah.gov/wp-content/uploads/Driver-Handbook-REV-3.2026.pdf', 'dmv_handbook', 'UT', 'Official Utah DLD Driver Handbook current English PDF linked from DLD resources.', now()),
  ('DMV', 'official', 'Manual del Conductor de Utah 2024', 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf', 'dmv_handbook', 'UT', 'Official Utah DLD Spanish driver handbook PDF linked from DLD resources.', now()),
  ('DMV', 'official', 'Utah Written Knowledge Test', 'https://dld.utah.gov/written-knowledge-test/', 'dmv_exam_info', 'UT', 'Official Utah DLD written knowledge test page.', now()),
  ('DMV', 'official', 'Utah Written Knowledge Practice Test', 'https://dld.utah.gov/practice-test/', 'dmv_practice_info', 'UT', 'Official Utah DLD timed practice test page.', now()),
  ('DMV', 'official', 'California Knowledge and Drive Tests Preparation', 'https://www.dmv.ca.gov/portal/driver-licenses-identification-cards/preparing-for-knowledge-and-drive-tests/', 'dmv_exam_info', 'CA', 'Official California DMV knowledge and drive tests preparation page.', now()),
  ('DMV', 'official', 'California Driver Handbook Testing Process', 'https://www.dmv.ca.gov/portal/handbook/california-driver-handbook/the-testing-process/', 'dmv_handbook_section', 'CA', 'Official California DMV handbook section for testing process.', now()),
  ('DMV', 'official', 'Florida Class E Knowledge Exam and Driving Skills Test', 'https://www.flhsmv.gov/driver-licenses-id-cards/licensing-requirements-teens-graduated-driver-license-laws-driving-curfews/class-e-knowledge-exam-driving-skills-test/', 'dmv_exam_info', 'FL', 'Official FLHSMV Class E knowledge exam and driving skills test page.', now()),
  ('DMV', 'official', 'Florida Handbooks and Manuals', 'https://www.flhsmv.gov/resources/handbooks-manuals/', 'dmv_handbook', 'FL', 'Official FLHSMV handbooks and manuals page.', now()),
  ('DMV', 'official', 'New York State Driver Manual and Practice Tests', 'https://dmv.ny.gov/new-york-state-drivers-manual-practice-tests', 'dmv_handbook', 'NY', 'Official NY DMV driver manual and practice tests page.', now()),
  ('DMV', 'official', 'New York Driver Manual Chapter 1 Driver Licenses', 'https://dmv.ny.gov/book/export/html/1556', 'dmv_exam_info', 'NY', 'Official NY DMV manual chapter containing written test passing rule.', now()),
  ('DMV', 'official', 'Texas Driver Handbook DL-7', 'https://www.dps.texas.gov/Internetforms/Forms/DL-7.pdf', 'dmv_handbook', 'TX', 'Official Texas DPS Driver Handbook PDF.', now()),
  ('DMV', 'official', 'Apply for a Texas Driver License', 'https://www.dps.texas.gov/section/driver-license/apply-texas-driver-license', 'dmv_exam_info', 'TX', 'Official Texas DPS driver license application page.', now())
on conflict (url) do update
set
  agency = excluded.agency,
  authority = excluded.authority,
  title = excluded.title,
  source_kind = excluded.source_kind,
  jurisdiction = excluded.jurisdiction,
  notes = excluded.notes,
  checked_at = now(),
  updated_at = now();

with handbook_rows as (
  select *
  from (
    values
      ('UT'::char(2), 'en', 'Utah Driver Handbook 2025-2026', 'https://dld.utah.gov/wp-content/uploads/Driver-Handbook-REV-3.2026.pdf', null::date, 'Current English handbook linked by Utah DLD.'),
      ('UT'::char(2), 'es', 'Manual del Conductor de Utah 2024', 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf', null::date, 'Spanish handbook linked by Utah DLD.'),
      ('CA'::char(2), 'en', 'California Driver Handbook online', 'https://www.dmv.ca.gov/portal/handbook/california-driver-handbook/the-testing-process/', null::date, 'California DMV online handbook section used for test process.'),
      ('FL'::char(2), 'multi', 'Florida Driver License Handbook portal', 'https://www.flhsmv.gov/resources/handbooks-manuals/', null::date, 'FLHSMV handbook portal includes English, Spanish and Kreol options.'),
      ('NY'::char(2), 'en', 'New York Driver Manual online', 'https://dmv.ny.gov/new-york-state-drivers-manual-practice-tests', null::date, 'NY DMV online manual includes practice quizzes.'),
      ('TX'::char(2), 'en', 'Texas Driver Handbook DL-7', 'https://www.dps.texas.gov/Internetforms/Forms/DL-7.pdf', null::date, 'Texas DPS Driver Handbook PDF.')
  ) as row_data(state_code, language, version_label, source_url, published_at, notes)
)
insert into public.dmv_handbook_versions (
  state_code,
  language,
  source_id,
  version_label,
  published_at,
  active,
  verified_at,
  notes
)
select
  handbook_rows.state_code,
  handbook_rows.language,
  official_sources.id,
  handbook_rows.version_label,
  handbook_rows.published_at,
  true,
  now(),
  handbook_rows.notes
from handbook_rows
join public.official_sources on official_sources.url = handbook_rows.source_url
on conflict (state_code, language, version_label) do update
set
  source_id = excluded.source_id,
  published_at = excluded.published_at,
  active = true,
  verified_at = excluded.verified_at,
  notes = excluded.notes,
  updated_at = now();

with exam_rows as (
  select *
  from (
    values
      ('UT'::char(2), 'standard_operator_never_licensed', 'es', 'Utah escrito - primera licencia', 50, null::int, null::numeric, null::int, false, array['in_person'], array['Spanish', 'English', 'Arabic', 'French', 'Korean', 'Mandarin Chinese', 'Portuguese', 'Somali', 'Tagalog', 'Vietnamese'], '{}'::jsonb, 'https://dld.utah.gov/written-knowledge-test/', 'Utah DLD states first-time applicants take a closed-book 50-question written knowledge test.'),
      ('UT'::char(2), 'standard_operator_previously_licensed', 'es', 'Utah escrito - licencia previa', 25, null::int, null::numeric, null::int, true, array['in_person'], array['Spanish', 'English', 'Arabic', 'French', 'Korean', 'Mandarin Chinese', 'Portuguese', 'Somali', 'Tagalog', 'Vietnamese'], '{}'::jsonb, 'https://dld.utah.gov/written-knowledge-test/', 'Utah DLD states previously licensed applicants take an open-book 25-question written knowledge test.'),
      ('UT'::char(2), 'practice', 'es', 'Utah practica oficial', 30, null::int, null::numeric, 30, null::boolean, array['online_practice'], array['Spanish', 'English'], '{}'::jsonb, 'https://dld.utah.gov/practice-test/', 'Utah DLD practice test is a 30-question, 30-minute timed online practice test.'),
      ('FL'::char(2), 'class_e_learner', 'es', 'Florida Class E Knowledge Exam', 50, 40, 80.00::numeric, null::int, null::boolean, array['in_person', 'online_under_18', 'delap'], array['Arabic', 'Chinese', 'English', 'Haitian Creole', 'Russian', 'Spanish'], '{}'::jsonb, 'https://www.flhsmv.gov/driver-licenses-id-cards/licensing-requirements-teens-graduated-driver-license-laws-driving-curfews/class-e-knowledge-exam-driving-skills-test/', 'FLHSMV states Class E has 50 multiple-choice questions and requires 40 correct, or 80 percent.'),
      ('NY'::char(2), 'class_d_learner_permit', 'es', 'New York Class D learner permit written test', 20, 14, null::numeric, null::int, null::boolean, array['touch_screen', 'paper', 'school_okta'], array['multiple_languages'], '{"road_sign_questions":4,"road_sign_min_correct":2}'::jsonb, 'https://dmv.ny.gov/book/export/html/1556', 'NY DMV states the written test requires 14 of 20 correct and 2 of 4 road sign questions correct.'),
      ('CA'::char(2), 'noncommercial_original_dl', 'es', 'California original driver license knowledge test', null::int, null::int, null::numeric, null::int, false, array['in_person', 'online_after_application'], array['English', 'Spanish', 'Traditional Chinese'], '{}'::jsonb, 'https://www.dmv.ca.gov/portal/driver-licenses-identification-cards/preparing-for-knowledge-and-drive-tests/', 'California DMV states original DL applicants must pass a multiple-choice knowledge test; exact count is left null until confirmed from the current official exam rules page.'),
      ('TX'::char(2), 'class_c_noncommercial', 'es', 'Texas Class C knowledge exam', null::int, null::int, 70.00::numeric, null::int, null::boolean, array['in_person', 'driver_education_school'], array['English', 'Spanish'], '{}'::jsonb, 'https://www.dps.texas.gov/Internetforms/Forms/DL-7.pdf', 'Texas DPS Driver Handbook states a 70 percent or better grade is required for knowledge exams; exact public question count is left null.')
  ) as row_data(
    state_code,
    license_type,
    language,
    exam_name,
    question_count,
    passing_score,
    passing_score_percent,
    time_limit_minutes,
    open_book,
    delivery_modes,
    available_languages,
    must_correct_rules,
    source_url,
    notes
  )
)
insert into public.dmv_exam_configs (
  state_code,
  license_type,
  language,
  exam_name,
  question_count,
  passing_score,
  passing_score_percent,
  time_limit_minutes,
  open_book,
  delivery_modes,
  available_languages,
  must_correct_rules,
  official_source_id,
  active,
  verified_at,
  notes
)
select
  exam_rows.state_code,
  exam_rows.license_type,
  exam_rows.language,
  exam_rows.exam_name,
  exam_rows.question_count,
  exam_rows.passing_score,
  exam_rows.passing_score_percent,
  exam_rows.time_limit_minutes,
  exam_rows.open_book,
  exam_rows.delivery_modes,
  exam_rows.available_languages,
  exam_rows.must_correct_rules,
  official_sources.id,
  true,
  now(),
  exam_rows.notes
from exam_rows
join public.official_sources on official_sources.url = exam_rows.source_url
on conflict (state_code, license_type, language, exam_name) do update
set
  question_count = excluded.question_count,
  passing_score = excluded.passing_score,
  passing_score_percent = excluded.passing_score_percent,
  time_limit_minutes = excluded.time_limit_minutes,
  open_book = excluded.open_book,
  delivery_modes = excluded.delivery_modes,
  available_languages = excluded.available_languages,
  must_correct_rules = excluded.must_correct_rules,
  official_source_id = excluded.official_source_id,
  active = true,
  verified_at = excluded.verified_at,
  notes = excluded.notes,
  updated_at = now();

with module_rows as (
  select *
  from (
    values
      ('UT'::char(2), 'es', 'test-process', 'Formato del examen', 'Exam format', 'Preguntas, modalidad, idiomas y practica oficial de Utah DLD.', 10, 'https://dld.utah.gov/written-knowledge-test/'),
      ('UT'::char(2), 'es', 'speed', 'Velocidad y zonas escolares', 'Speed', 'Limites sin senal, escuelas y velocidad segura para condiciones reales.', 20, 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf'),
      ('UT'::char(2), 'es', 'signals', 'Semaforos y senales', 'Signals', 'Luces rojas, amarillas, flechas, cruces ferroviarios y obediencia a oficiales.', 30, 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf'),
      ('UT'::char(2), 'es', 'right-of-way', 'Derecho de paso', 'Right of way', 'Emergencias, intersecciones, ceder el paso y ley move over.', 40, 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf'),
      ('UT'::char(2), 'es', 'night-driving', 'Manejo nocturno', 'Night driving', 'Luces altas, visibilidad, fatiga y conduccion en condiciones dificiles.', 50, 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf'),
      ('UT'::char(2), 'es', 'alcohol-drugs', 'Alcohol, drogas y seguridad', 'Alcohol and drugs', 'Efectos de alcohol y drogas, DUI, interlock y decisiones seguras.', 60, 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf'),
      ('CA'::char(2), 'es', 'knowledge-test', 'Examen de conocimiento', 'Knowledge test', 'Preparacion oficial, manual del conductor y reglas de ayudas prohibidas.', 10, 'https://www.dmv.ca.gov/portal/driver-licenses-identification-cards/preparing-for-knowledge-and-drive-tests/'),
      ('CA'::char(2), 'es', 'testing-process', 'Proceso de prueba', 'Testing process', 'Vision, conocimiento, intentos, eLearning de renovacion y prueba practica.', 20, 'https://www.dmv.ca.gov/portal/handbook/california-driver-handbook/the-testing-process/'),
      ('FL'::char(2), 'es', 'class-e-exam', 'Examen Class E', 'Class E exam', '50 preguntas, 40 correctas para aprobar, idiomas y opciones de prueba.', 10, 'https://www.flhsmv.gov/driver-licenses-id-cards/licensing-requirements-teens-graduated-driver-license-laws-driving-curfews/class-e-knowledge-exam-driving-skills-test/'),
      ('FL'::char(2), 'es', 'tlsae', 'Curso TLSAE', 'TLSAE course', 'Curso obligatorio para quienes nunca tuvieron licencia en ningun estado o pais.', 20, 'https://www.flhsmv.gov/driver-licenses-id-cards/licensing-requirements-teens-graduated-driver-license-laws-driving-curfews/class-e-knowledge-exam-driving-skills-test/'),
      ('FL'::char(2), 'es', 'skills-test', 'Prueba practica Class E', 'Driving skills test', 'Maniobras, vehiculo, inspeccion y opciones de prueba oficial.', 30, 'https://www.flhsmv.gov/driver-licenses-id-cards/licensing-requirements-teens-graduated-driver-license-laws-driving-curfews/class-e-knowledge-exam-driving-skills-test/'),
      ('NY'::char(2), 'es', 'traffic-control', 'Control de trafico', 'Traffic control', 'Capitulos y quizzes oficiales que cubren senales, semaforos y reglas.', 10, 'https://dmv.ny.gov/new-york-state-drivers-manual-practice-tests'),
      ('NY'::char(2), 'es', 'intersections-turns', 'Intersecciones y giros', 'Intersections and turns', 'Material oficial de capitulos 4 a 11 para aprobar el permiso.', 20, 'https://dmv.ny.gov/new-york-state-drivers-manual-practice-tests'),
      ('NY'::char(2), 'es', 'road-signs', 'Senales de transito', 'Road signs', 'Regla especial: responder correctamente al menos 2 de 4 preguntas de senales.', 30, 'https://dmv.ny.gov/book/export/html/1556'),
      ('TX'::char(2), 'es', 'handbook', 'Manual de Texas', 'Texas handbook', 'Manual DPS DL-7 y regla de 70 por ciento o mas para aprobar examenes de conocimiento.', 10, 'https://www.dps.texas.gov/Internetforms/Forms/DL-7.pdf'),
      ('TX'::char(2), 'es', 'application', 'Solicitud de licencia', 'License application', 'Documentos, presencia legal, residencia, ITD y pasos oficiales DPS.', 20, 'https://www.dps.texas.gov/section/driver-license/apply-texas-driver-license')
  ) as row_data(state_code, language, module_key, title_es, title_en, summary_es, display_order, source_url)
)
insert into public.dmv_learning_modules (
  state_code,
  language,
  module_key,
  title_es,
  title_en,
  summary_es,
  source_id,
  display_order,
  active,
  verified_at
)
select
  module_rows.state_code,
  module_rows.language,
  module_rows.module_key,
  module_rows.title_es,
  module_rows.title_en,
  module_rows.summary_es,
  official_sources.id,
  module_rows.display_order,
  true,
  now()
from module_rows
join public.official_sources on official_sources.url = module_rows.source_url
on conflict (state_code, language, module_key) do update
set
  title_es = excluded.title_es,
  title_en = excluded.title_en,
  summary_es = excluded.summary_es,
  source_id = excluded.source_id,
  display_order = excluded.display_order,
  active = true,
  verified_at = excluded.verified_at,
  updated_at = now();

update public.dmv_question_sets
set active = false,
    updated_at = now()
where state_code = 'UT'
  and language = 'es'
  and version_label <> 'Utah Driver Handbook 2025-2026 ES practice';

with source as (
  select id
  from public.official_sources
  where url = 'https://dld.utah.gov/wp-content/uploads/MANUAL-DEL-CONDUCTOR-DE-UTAH-2024.pdf'
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
    'Utah Driver Handbook 2025-2026 ES practice',
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
  topic,
  module_key,
  difficulty,
  source_ref,
  display_order,
  active
)
select
  question_set.id,
  item.prompt,
  item.options::jsonb,
  item.correct_option_key,
  item.explanation,
  item.topic,
  item.module_key,
  item.difficulty,
  item.source_ref,
  item.display_order,
  true
from question_set
cross join (
  values
    (
      'Si no hay senal, cual es el limite en una zona residencial o comercial de Utah?',
      '[{"key":"a","label":"35 mph"},{"key":"b","label":"25 mph"},{"key":"c","label":"45 mph"}]',
      'b',
      'En Utah, el limite basico sin senal para zona residencial o comercial es 25 mph.',
      'speed',
      'speed',
      'standard',
      'Manual del Conductor de Utah, seccion Velocidad.',
      10
    ),
    (
      'Cual es la velocidad indicada al pasar una escuela durante entrada, salida, recreo o luces intermitentes?',
      '[{"key":"a","label":"20 mph"},{"key":"b","label":"30 mph"},{"key":"c","label":"55 mph"}]',
      'a',
      'La zona escolar indicada requiere reducir a 20 mph en los periodos senalados.',
      'speed',
      'speed',
      'standard',
      'Manual del Conductor de Utah, seccion Velocidad.',
      20
    ),
    (
      'Que exige una luz roja antes de entrar a una interseccion?',
      '[{"key":"a","label":"Seguir si no viene nadie"},{"key":"b","label":"Tocar bocina y avanzar"},{"key":"c","label":"Detenerse antes de entrar y esperar hasta que sea permitido"}]',
      'c',
      'Ante luz roja debes detenerte antes de entrar a la interseccion, linea de pare o cruce peatonal.',
      'signals',
      'signals',
      'intro',
      'Manual del Conductor de Utah, seccion Semaforos.',
      30
    ),
    (
      'Que debe hacer ante una luz amarilla intermitente?',
      '[{"key":"a","label":"Acelerar para no bloquear"},{"key":"b","label":"Reducir velocidad y proceder con cautela"},{"key":"c","label":"Detenerse siempre 10 segundos"}]',
      'b',
      'Una luz amarilla intermitente exige reducir velocidad, avanzar con cautela y estar preparado para detenerse.',
      'signals',
      'signals',
      'intro',
      'Manual del Conductor de Utah, seccion Semaforos.',
      40
    ),
    (
      'Si llevas luces altas y viene un vehiculo de frente, a que distancia debes bajarlas?',
      '[{"key":"a","label":"500 pies antes del vehiculo"},{"key":"b","label":"100 pies antes del vehiculo"},{"key":"c","label":"Solo cuando el otro conductor lo pida"}]',
      'a',
      'El manual indica bajar las luces altas antes de estar a 500 pies del vehiculo que viene de frente.',
      'night-driving',
      'night-driving',
      'standard',
      'Utah Driver Handbook 2025-2026, Night Driving.',
      50
    ),
    (
      'Cuando se acerca una patrulla, ambulancia o camion de bomberos con sirena o luces, que debes hacer?',
      '[{"key":"a","label":"Seguir en tu carril a la misma velocidad"},{"key":"b","label":"Moverte a la derecha y detenerte hasta que pase"},{"key":"c","label":"Frenar en medio del carril izquierdo"}]',
      'b',
      'Utah exige ceder el paso, moverse de inmediato al lado derecho de la via y detenerse hasta que el vehiculo de emergencia pase.',
      'right-of-way',
      'right-of-way',
      'standard',
      'Utah Driver Handbook 2025-2026, Emergency Vehicles.',
      60
    ),
    (
      'Que resume mejor la ley move over al acercarte a un vehiculo detenido con luces de emergencia?',
      '[{"key":"a","label":"Reducir velocidad y dar espacio; cambiar de carril si es seguro"},{"key":"b","label":"Mantener velocidad porque el vehiculo esta detenido"},{"key":"c","label":"Usar la bocina para avisar que pasaras"}]',
      'a',
      'La regla busca dar mas espacio y bajar la velocidad al pasar vehiculos detenidos con luces de emergencia.',
      'right-of-way',
      'right-of-way',
      'hard',
      'Utah Driver Handbook 2025-2026, Move Over Law.',
      70
    ),
    (
      'Que factor aparece entre las principales causas de choques en carreteras de Utah?',
      '[{"key":"a","label":"Fallar en mantenerse en el carril correcto"},{"key":"b","label":"Usar luces bajas de dia"},{"key":"c","label":"Estacionar en una pendiente"}]',
      'a',
      'El manual lista fallar en mantenerse en el carril correcto entre las principales causas de choques en Utah.',
      'safe-driving',
      'right-of-way',
      'standard',
      'Utah Driver Handbook 2025-2026, Utah crash statistics.',
      80
    ),
    (
      'Que efecto pueden tener el alcohol y otras drogas al manejar?',
      '[{"key":"a","label":"Mejoran el tiempo de reaccion"},{"key":"b","label":"Reducen juicio, vision y tiempo de reaccion"},{"key":"c","label":"Solo afectan si el viaje es largo"}]',
      'b',
      'El manual explica que alcohol y drogas reducen juicio, vision y respuesta ante el manejo.',
      'alcohol-drugs',
      'alcohol-drugs',
      'standard',
      'Utah Driver Handbook 2025-2026, Alcohol/Drugs and Driving.',
      90
    ),
    (
      'Que advertencia oficial da Utah DLD sobre sitios imitadores?',
      '[{"key":"a","label":"Usar solo sitios que terminen en .gov para informacion DLD"},{"key":"b","label":"Cualquier pagina con logo sirve"},{"key":"c","label":"Los sitios privados reemplazan al manual oficial"}]',
      'a',
      'El manual advierte tener cuidado con sitios imitadores que no terminan en .gov.',
      'test-process',
      'test-process',
      'intro',
      'Utah Driver Handbook 2025-2026, DLD services notice.',
      100
    )
) as item(prompt, options, correct_option_key, explanation, topic, module_key, difficulty, source_ref, display_order);

update public.state_service_catalog
set verification_status = case
      when state_code = 'UT' then 'questions_ready'
      when state_code in ('CA', 'FL', 'NY', 'TX') then 'content_imported'
      else verification_status
    end,
    notes = case
      when state_code = 'UT' then 'Official Utah DLD handbook, test rules, learning modules and Spanish practice questions are loaded.'
      when state_code = 'FL' then 'Official FLHSMV Class E exam rules and learning modules are loaded; question bank import remains pending.'
      when state_code = 'NY' then 'Official NY DMV written test rules and learning modules are loaded; question bank import remains pending.'
      when state_code = 'CA' then 'Official California DMV knowledge test sources and modules are loaded; exact current question count and question bank import remain pending.'
      when state_code = 'TX' then 'Official Texas DPS handbook and 70 percent pass rule are loaded; exact public question count and question bank import remain pending.'
      else notes
    end,
    extracted_at = now(),
    updated_at = now()
where service_area = 'dmv'
  and state_code in ('UT', 'CA', 'FL', 'NY', 'TX');

create or replace view public.dmv_state_learning_catalog
with (security_invoker = true)
as
select
  s.code as state_code,
  s.name as state_name,
  c.verification_status,
  c.notes,
  source.title as source_title,
  source.url as source_url,
  (
    select count(*)::int
    from public.dmv_question_sets qs
    join public.dmv_questions q on q.question_set_id = qs.id
    where qs.state_code = s.code
      and qs.language = 'es'
      and qs.active = true
      and q.active = true
  ) as active_question_count,
  coalesce(
    (
      select jsonb_agg(to_jsonb(module_rows) order by module_rows.display_order)
      from (
        select
          m.id,
          m.module_key,
          m.title_es,
          m.title_en,
          m.summary_es,
          m.display_order
        from public.dmv_learning_modules m
        where m.state_code = s.code
          and m.language = 'es'
          and m.active = true
        order by m.display_order
      ) as module_rows
    ),
    '[]'::jsonb
  ) as modules,
  coalesce(
    (
      select jsonb_agg(to_jsonb(exam_rows) order by exam_rows.exam_name)
      from (
        select
          e.id,
          e.license_type,
          e.exam_name,
          e.question_count,
          e.passing_score,
          e.passing_score_percent,
          e.time_limit_minutes,
          e.open_book,
          e.delivery_modes,
          e.available_languages,
          e.must_correct_rules,
          e.notes
        from public.dmv_exam_configs e
        where e.state_code = s.code
          and e.language = 'es'
          and e.active = true
        order by e.exam_name
      ) as exam_rows
    ),
    '[]'::jsonb
  ) as exam_configs
from public.us_states s
join public.state_service_catalog c on c.state_code = s.code and c.service_area = 'dmv'
join public.official_sources source on source.id = c.primary_source_id;

grant select on public.dmv_state_learning_catalog to authenticated;
