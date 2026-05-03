-- Production automation catalog coverage for every visible workflow.
-- Sources are official USCIS, EOIR, Federal Register, or official portals.

insert into public.official_sources (agency, authority, title, url, source_kind, jurisdiction, notes)
values
  ('USCIS', 'official', 'USCIS Asylum', 'https://www.uscis.gov/humanitarian/refugees-and-asylum/asylum', 'form_page', 'US', 'Official USCIS asylum page including Annual Asylum Fee payment notice guidance.'),
  ('USCIS', 'official', 'USCIS H.R. 1 Fee Alert', 'https://www.uscis.gov/newsroom/alerts/uscis-updates-fees-based-on-hr-1', 'fees', 'US', 'Official USCIS alert announcing H.R. 1 immigration fees.'),
  ('USCIS', 'official', 'USCIS Annual Asylum Fee Portal', 'https://my.uscis.gov/accounts/annual-asylum-fee/start/overview', 'payment_portal', 'US', 'Official USCIS online payment portal for the Annual Asylum Fee.'),
  ('USCIS', 'official', 'Federal Register H.R.1 Fee Rule 2026', 'https://www.federalregister.gov/documents/2026/04/29/2026-08333/uscis-immigration-fees-and-related-procedures-required-by-hr1-reconciliation-bill', 'rule', 'US', 'Federal Register interim final rule effective 2026-05-29 for H.R.1 fee procedures.'),
  ('EOIR', 'official', 'EOIR Respondent EOIR-33/IC', 'https://respondentaccess.eoir.justice.gov/en/forms/eoir33ic/', 'form_page', 'US', 'Official EOIR Respondent Access workflow for EOIR-33/IC.'),
  ('EOIR', 'official', 'EOIR Learn About Immigration Court', 'https://www.justice.gov/eoir/learn-about-immigration-court', 'practice_manual', 'US', 'Official EOIR page describing motion to change venue basics.')
on conflict (url) do update
set agency = excluded.agency,
    authority = excluded.authority,
    title = excluded.title,
    source_kind = excluded.source_kind,
    jurisdiction = excluded.jurisdiction,
    checked_at = now(),
    notes = excluded.notes;

insert into public.form_definitions (
  agency,
  form_code,
  title,
  description,
  federal,
  review_requirement,
  official_page_source_id,
  enabled
)
select 'USCIS', 'ANNUAL_ASYLUM_FEE', 'Pago Tarifa Anual de Asilo', 'Prepara datos, alerta y comprobante interno para pagar la Annual Asylum Fee en el portal oficial USCIS.', true, 'none', s.id, true
from public.official_sources s
where s.url = 'https://www.uscis.gov/humanitarian/refugees-and-asylum/asylum'
on conflict (agency, form_code) do update
set title = excluded.title,
    description = excluded.description,
    review_requirement = excluded.review_requirement,
    official_page_source_id = excluded.official_page_source_id,
    enabled = true;

update public.form_definitions
set enabled = true,
    updated_at = now()
where (agency, form_code) in (
  ('USCIS'::public.agency_code, 'I-765'),
  ('EOIR'::public.agency_code, 'EOIR-33'),
  ('EOIR'::public.agency_code, 'CHANGE_OF_VENUE')
);

with definition as (
  select id from public.form_definitions where agency = 'USCIS' and form_code = 'ANNUAL_ASYLUM_FEE'
),
source as (
  select id from public.official_sources where url = 'https://www.uscis.gov/humanitarian/refugees-and-asylum/asylum'
),
edition as (
  insert into public.form_editions (
    form_definition_id,
    edition_label,
    effective_from,
    instructions_source_id,
    field_map,
    validation_schema,
    status,
    verified_by,
    verified_at
  )
  select
    definition.id,
    'aaf-production-2026',
    '2026-05-03'::date,
    source.id,
    '{"packet_kind":"uscis_online_payment_prep","requires_template_verification":true,"fields":{}}'::jsonb,
    '{"official_channel":"https://my.uscis.gov/accounts/annual-asylum-fee/start/overview","notice_controls_amount":true}'::jsonb,
    'active',
    'official_source_research',
    now()
  from definition
  cross join source
  on conflict (form_definition_id, edition_label) do update
  set effective_from = excluded.effective_from,
      instructions_source_id = excluded.instructions_source_id,
      field_map = excluded.field_map,
      validation_schema = excluded.validation_schema,
      status = 'active',
      verified_by = excluded.verified_by,
      verified_at = now()
  returning id
)
insert into public.form_questions (
  form_edition_id,
  question_key,
  label_es,
  label_en,
  help_text_es,
  data_type,
  required,
  display_order,
  source_field_refs,
  validation_rule
)
select edition.id, q.question_key, q.label_es, q.label_en, q.help_text_es, q.data_type, q.required, q.display_order, q.source_field_refs, q.validation_rule
from edition
cross join (
  values
    ('full_name', 'Nombre completo del solicitante', 'Applicant full name', 'Como aparece en la notificacion o recibo I-589.', 'text', true, 10, array['USCIS AAF notice']::text[], '{}'::jsonb),
    ('a_number', 'A-Number', 'Alien Registration Number', 'Ejemplo: A012345678.', 'text', true, 20, array['USCIS AAF notice']::text[], '{}'::jsonb),
    ('i589_receipt_number', 'Numero de recibo I-589', 'I-589 receipt number', 'El recibo indicado en la notificacion USCIS.', 'text', true, 30, array['USCIS AAF notice']::text[], '{}'::jsonb),
    ('i589_filing_date', 'Fecha de presentacion I-589', 'I-589 filing date', 'Usala para calcular aniversarios y alertas.', 'date', false, 40, array['I-589 receipt']::text[], '{}'::jsonb),
    ('aaf_notice_received', 'Recibiste notificacion oficial USCIS', 'Official USCIS notice received', 'USCIS indica que el aviso incluye monto, fecha y forma de pago.', 'select', true, 50, array['USCIS AAF notice']::text[], '{"options":[{"value":"yes","label_es":"Si"},{"value":"no","label_es":"No"}]}'::jsonb),
    ('aaf_notice_date', 'Fecha de la notificacion', 'Notice date', 'La tarifa debe atenderse segun el aviso oficial.', 'date', false, 60, array['USCIS AAF notice']::text[], '{}'::jsonb),
    ('aaf_due_date', 'Fecha limite indicada por USCIS', 'USCIS due date', 'Si el aviso da una fecha, registrala aqui.', 'date', true, 70, array['USCIS AAF notice']::text[], '{}'::jsonb),
    ('fee_amount_usd', 'Monto indicado en el aviso', 'Fee amount shown on notice', 'El monto oficial lo controla el aviso y el portal USCIS.', 'text', true, 80, array['USCIS AAF notice']::text[], '{}'::jsonb),
    ('uscis_online_account_number', 'Numero de cuenta USCIS online', 'USCIS online account number', 'Opcional si lo tienes.', 'text', false, 90, array['USCIS account']::text[], '{}'::jsonb),
    ('payer_email', 'Correo para comprobante', 'Payer email', 'Correo donde guardaras el comprobante de pago.', 'text', true, 100, array['payment receipt']::text[], '{}'::jsonb),
    ('payment_status', 'Estado del pago', 'Payment status', 'Actualiza esto despues de entrar al portal oficial.', 'select', true, 110, array['payment receipt']::text[], '{"options":[{"value":"pending","label_es":"Pendiente"},{"value":"paid","label_es":"Pagado"},{"value":"not_applicable","label_es":"No aplica todavia"}]}'::jsonb),
    ('payment_confirmation_number', 'Numero de confirmacion', 'Payment confirmation number', 'Pegalo despues de pagar en USCIS.', 'text', false, 120, array['payment receipt']::text[], '{}'::jsonb),
    ('confirm_official_portal', 'Entiendo que el pago se hace solo en USCIS', 'Official portal confirmation', 'La app prepara el paquete; el pago real se hace en my.uscis.gov.', 'boolean', true, 130, array['USCIS AAF portal']::text[], '{}'::jsonb),
    ('confirm_no_waiver', 'Entiendo que USCIS indica que no hay exencion para AAF', 'No waiver confirmation', 'Confirmacion basada en la pagina oficial USCIS.', 'boolean', true, 140, array['USCIS AAF notice']::text[], '{}'::jsonb)
) as q(question_key, label_es, label_en, help_text_es, data_type, required, display_order, source_field_refs, validation_rule)
on conflict (form_edition_id, question_key) do update
set label_es = excluded.label_es,
    label_en = excluded.label_en,
    help_text_es = excluded.help_text_es,
    data_type = excluded.data_type,
    required = excluded.required,
    display_order = excluded.display_order,
    source_field_refs = excluded.source_field_refs,
    validation_rule = excluded.validation_rule,
    updated_at = now();

with definition as (
  select id from public.form_definitions where agency = 'USCIS' and form_code = 'I-765'
),
source as (
  select id from public.official_sources where url = 'https://www.uscis.gov/i-765'
),
edition as (
  insert into public.form_editions (
    form_definition_id,
    edition_label,
    effective_from,
    instructions_source_id,
    field_map,
    validation_schema,
    status,
    verified_by,
    verified_at
  )
  select
    definition.id,
    'i765-intake-2026',
    '2025-01-20'::date,
    source.id,
    '{"packet_kind":"employment_authorization_prep","requires_template_verification":true,"fields":{}}'::jsonb,
    '{"edition_notice":"Verify current acceptable edition and filing address on USCIS before mailing or online filing."}'::jsonb,
    'active',
    'official_source_research',
    now()
  from definition
  cross join source
  on conflict (form_definition_id, edition_label) do update
  set effective_from = excluded.effective_from,
      instructions_source_id = excluded.instructions_source_id,
      field_map = excluded.field_map,
      validation_schema = excluded.validation_schema,
      status = 'active',
      verified_by = excluded.verified_by,
      verified_at = now()
  returning id
)
insert into public.form_questions (
  form_edition_id,
  question_key,
  label_es,
  label_en,
  help_text_es,
  data_type,
  required,
  display_order,
  source_field_refs,
  validation_rule
)
select edition.id, q.question_key, q.label_es, q.label_en, q.help_text_es, q.data_type, q.required, q.display_order, q.source_field_refs, q.validation_rule
from edition
cross join (
  values
    ('application_reason', 'Tipo de solicitud', 'Reason for applying', 'USCIS pide elegir inicial, renovacion o reemplazo.', 'select', true, 10, array['I-765 Part 1']::text[], '{"options":[{"value":"initial","label_es":"Inicial"},{"value":"renewal","label_es":"Renovacion"},{"value":"replacement","label_es":"Reemplazo/correccion"}]}'::jsonb),
    ('eligibility_category', 'Categoria de elegibilidad', 'Eligibility category', 'Ejemplo comun: (c)(8) asilo pendiente. Verifica instrucciones USCIS.', 'select', true, 20, array['I-765 Question 27']::text[], '{"options":[{"value":"c8","label_es":"(c)(8) Asilo pendiente"},{"value":"c9","label_es":"(c)(9) Ajuste pendiente"},{"value":"c11","label_es":"(c)(11) Parole"},{"value":"c19","label_es":"(c)(19) TPS pendiente"},{"value":"c34","label_es":"(c)(34) Otro HR1"},{"value":"a12","label_es":"(a)(12) TPS otorgado"},{"value":"other","label_es":"Otra categoria"}]}'::jsonb),
    ('full_name', 'Nombre legal completo', 'Full legal name', 'Como aparece en documentos oficiales.', 'text', true, 30, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('a_number', 'A-Number', 'Alien Registration Number', 'Si aplica.', 'text', false, 40, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('uscis_online_account_number', 'Numero de cuenta USCIS online', 'USCIS online account number', 'Opcional.', 'text', false, 50, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('date_of_birth', 'Fecha de nacimiento', 'Date of birth', null, 'date', true, 60, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('country_of_birth', 'Pais de nacimiento', 'Country of birth', null, 'text', true, 70, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('mailing_address', 'Direccion postal actual', 'Mailing address', 'Incluye apartamento, ciudad, estado y ZIP.', 'text', true, 80, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('physical_address', 'Direccion fisica actual', 'Physical address', 'Si es distinta de la postal.', 'text', false, 90, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('last_arrival_date', 'Fecha de ultima entrada a EE.UU.', 'Date of last arrival', null, 'date', false, 100, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('i94_number', 'Numero I-94', 'I-94 number', 'Si aplica.', 'text', false, 110, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('passport_number', 'Numero de pasaporte', 'Passport number', 'Si aplica.', 'text', false, 120, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('current_status', 'Estatus migratorio actual', 'Current immigration status', 'Ejemplo: asilo pendiente, parole, TPS.', 'text', true, 130, array['I-765 Part 2']::text[], '{}'::jsonb),
    ('previous_ead_expiration', 'Vencimiento del EAD actual', 'Current EAD expiration', 'Relevante para renovaciones.', 'date', false, 140, array['current EAD']::text[], '{}'::jsonb),
    ('related_receipt_number', 'Recibo del caso relacionado', 'Related receipt number', 'I-589, I-485 u otro recibo que soporte la categoria.', 'text', false, 150, array['supporting receipt']::text[], '{}'::jsonb),
    ('signature_phone', 'Telefono de contacto', 'Contact phone', null, 'text', true, 160, array['I-765 applicant statement']::text[], '{}'::jsonb),
    ('signature_email', 'Correo de contacto', 'Contact email', null, 'text', true, 170, array['I-765 applicant statement']::text[], '{}'::jsonb),
    ('protected_case_flag', 'Mi caso requiere revision experta antes de enviar', 'Expert review flag', 'Marca si tienes antecedentes, orden previa, detencion, apelacion o dudas legales.', 'boolean', false, 180, array['risk triage']::text[], '{}'::jsonb)
) as q(question_key, label_es, label_en, help_text_es, data_type, required, display_order, source_field_refs, validation_rule)
on conflict (form_edition_id, question_key) do update
set label_es = excluded.label_es,
    label_en = excluded.label_en,
    help_text_es = excluded.help_text_es,
    data_type = excluded.data_type,
    required = excluded.required,
    display_order = excluded.display_order,
    source_field_refs = excluded.source_field_refs,
    validation_rule = excluded.validation_rule,
    updated_at = now();

with definition as (
  select id from public.form_definitions where agency = 'EOIR' and form_code = 'EOIR-33'
),
source as (
  select id from public.official_sources where url = 'https://respondentaccess.eoir.justice.gov/en/forms/eoir33ic/'
),
edition as (
  insert into public.form_editions (
    form_definition_id,
    edition_label,
    effective_from,
    instructions_source_id,
    field_map,
    validation_schema,
    status,
    verified_by,
    verified_at
  )
  select
    definition.id,
    'eoir33ic-intake-2026',
    '2026-05-03'::date,
    source.id,
    '{"packet_kind":"eoir33ic_prep","requires_template_verification":true,"fields":{}}'::jsonb,
    '{"service_required":"copy_to_dhs","deadline":"within_five_working_days_of_change"}'::jsonb,
    'active',
    'official_source_research',
    now()
  from definition
  cross join source
  on conflict (form_definition_id, edition_label) do update
  set effective_from = excluded.effective_from,
      instructions_source_id = excluded.instructions_source_id,
      field_map = excluded.field_map,
      validation_schema = excluded.validation_schema,
      status = 'active',
      verified_by = excluded.verified_by,
      verified_at = now()
  returning id
)
insert into public.form_questions (
  form_edition_id,
  question_key,
  label_es,
  label_en,
  help_text_es,
  data_type,
  required,
  display_order,
  source_field_refs,
  validation_rule
)
select edition.id, q.question_key, q.label_es, q.label_en, q.help_text_es, q.data_type, q.required, q.display_order, q.source_field_refs, q.validation_rule
from edition
cross join (
  values
    ('full_name', 'Nombre completo', 'Full name', 'Debe coincidir con el caso de corte.', 'text', true, 10, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('a_number', 'A-Number', 'Alien Registration Number', 'Ejemplo: A012345678.', 'text', true, 20, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('eoir_case_identifier', 'Numero de caso EOIR', 'EOIR case identifier', 'Si lo tienes.', 'text', false, 30, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('immigration_court', 'Corte de inmigracion actual', 'Immigration court', 'Corte donde esta pendiente el caso.', 'text', true, 40, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('former_address', 'Direccion anterior', 'Former address', 'Direccion o contacto anterior.', 'text', true, 50, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('current_address', 'Direccion actual', 'Current address', 'Incluye calle fija, ciudad, estado y ZIP.', 'text', true, 60, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('phone', 'Telefono actual', 'Current phone', null, 'text', false, 70, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('email', 'Correo actual', 'Current email', null, 'text', false, 80, array['EOIR-33/IC']::text[], '{}'::jsonb),
    ('change_date', 'Fecha del cambio', 'Change date', 'EOIR indica actualizar dentro de cinco dias laborables.', 'date', true, 90, array['EOIR-33/IC instructions']::text[], '{}'::jsonb),
    ('served_dhs_copy', 'Entiendo que debo entregar copia a DHS', 'DHS service confirmation', 'EOIR-33 incluye prueba de servicio a DHS.', 'boolean', true, 100, array['EOIR-33/IC proof of service']::text[], '{}'::jsonb),
    ('separate_person_confirmed', 'Entiendo que cada persona requiere su propio EOIR-33', 'Separate copy confirmation', 'EOIR indica enviar copia separada por cada persona afectada.', 'boolean', true, 110, array['EOIR-33/IC instructions']::text[], '{}'::jsonb)
) as q(question_key, label_es, label_en, help_text_es, data_type, required, display_order, source_field_refs, validation_rule)
on conflict (form_edition_id, question_key) do update
set label_es = excluded.label_es,
    label_en = excluded.label_en,
    help_text_es = excluded.help_text_es,
    data_type = excluded.data_type,
    required = excluded.required,
    display_order = excluded.display_order,
    source_field_refs = excluded.source_field_refs,
    validation_rule = excluded.validation_rule,
    updated_at = now();

with definition as (
  select id from public.form_definitions where agency = 'EOIR' and form_code = 'CHANGE_OF_VENUE'
),
source as (
  select id from public.official_sources where url = 'https://www.justice.gov/eoir/learn-about-immigration-court'
),
edition as (
  insert into public.form_editions (
    form_definition_id,
    edition_label,
    effective_from,
    instructions_source_id,
    field_map,
    validation_schema,
    status,
    verified_by,
    verified_at
  )
  select
    definition.id,
    'change-venue-draft-2026',
    '2026-05-03'::date,
    source.id,
    '{"packet_kind":"motion_draft","requires_template_verification":true,"fields":{}}'::jsonb,
    '{"requires_human_review":true,"must_continue_attending_scheduled_hearings":true}'::jsonb,
    'active',
    'official_source_research',
    now()
  from definition
  cross join source
  on conflict (form_definition_id, edition_label) do update
  set effective_from = excluded.effective_from,
      instructions_source_id = excluded.instructions_source_id,
      field_map = excluded.field_map,
      validation_schema = excluded.validation_schema,
      status = 'active',
      verified_by = excluded.verified_by,
      verified_at = now()
  returning id
)
insert into public.form_questions (
  form_edition_id,
  question_key,
  label_es,
  label_en,
  help_text_es,
  data_type,
  required,
  display_order,
  source_field_refs,
  validation_rule
)
select edition.id, q.question_key, q.label_es, q.label_en, q.help_text_es, q.data_type, q.required, q.display_order, q.source_field_refs, q.validation_rule
from edition
cross join (
  values
    ('full_name', 'Nombre completo', 'Full name', 'Como aparece en corte.', 'text', true, 10, array['motion caption']::text[], '{}'::jsonb),
    ('a_number', 'A-Number', 'Alien Registration Number', null, 'text', true, 20, array['motion caption']::text[], '{}'::jsonb),
    ('current_court', 'Corte actual', 'Current immigration court', 'Donde esta programada la audiencia.', 'text', true, 30, array['EOIR venue']::text[], '{}'::jsonb),
    ('requested_court', 'Corte solicitada', 'Requested immigration court', 'Corte a la que quieres mover el caso.', 'text', true, 40, array['EOIR venue']::text[], '{}'::jsonb),
    ('next_hearing_date', 'Fecha y hora de proxima audiencia', 'Next hearing date and time', 'La mocion no excusa asistir si no ha sido concedida.', 'date', true, 50, array['EOIR notice of hearing']::text[], '{}'::jsonb),
    ('fixed_street_address', 'Direccion fija donde recibiras avisos', 'Fixed street address', 'EOIR requiere direccion fija para notificaciones.', 'text', true, 60, array['ICPM change venue']::text[], '{}'::jsonb),
    ('reason_for_move', 'Explicacion detallada del cambio', 'Detailed explanation', 'Describe mudanza, distancia, trabajo, familia u otras razones.', 'text', true, 70, array['ICPM change venue']::text[], '{}'::jsonb),
    ('supporting_evidence_summary', 'Evidencia de soporte', 'Supporting evidence summary', 'Ejemplo: contrato, recibo, empleo, escuela, pruebas de domicilio.', 'text', true, 80, array['ICPM evidence']::text[], '{}'::jsonb),
    ('has_filed_eoir33', 'Ya prepare o presentare EOIR-33/IC', 'EOIR-33 prepared or filed', 'EOIR indica que el cambio de direccion debe acompanar la mocion si cambio la direccion.', 'boolean', true, 90, array['ICPM change venue']::text[], '{}'::jsonb),
    ('served_dhs_copy', 'Entiendo que debo entregar copia a DHS/OPLA', 'DHS service confirmation', 'La mocion necesita prueba de servicio.', 'boolean', true, 100, array['EOIR service']::text[], '{}'::jsonb),
    ('understands_hearing_remains_active', 'Entiendo que debo asistir hasta que la mocion sea concedida', 'Hearing remains active confirmation', 'EOIR indica que presentar la mocion no excusa asistir a audiencias programadas.', 'boolean', true, 110, array['EOIR change venue guidance']::text[], '{}'::jsonb),
    ('protected_case_flag', 'Este caso requiere revision legal humana', 'Human legal review flag', 'Siempre recomendamos revision humana para este paquete.', 'boolean', true, 120, array['risk triage']::text[], '{}'::jsonb)
) as q(question_key, label_es, label_en, help_text_es, data_type, required, display_order, source_field_refs, validation_rule)
on conflict (form_edition_id, question_key) do update
set label_es = excluded.label_es,
    label_en = excluded.label_en,
    help_text_es = excluded.help_text_es,
    data_type = excluded.data_type,
    required = excluded.required,
    display_order = excluded.display_order,
    source_field_refs = excluded.source_field_refs,
    validation_rule = excluded.validation_rule,
    updated_at = now();

with annual as (
  select id from public.form_definitions where agency = 'USCIS' and form_code = 'ANNUAL_ASYLUM_FEE'
),
fr as (
  select id from public.official_sources where url = 'https://www.federalregister.gov/documents/2026/04/29/2026-08333/uscis-immigration-fees-and-related-procedures-required-by-hr1-reconciliation-bill'
)
insert into public.fee_rules (
  form_definition_id,
  fee_key,
  category_code,
  amount_cents,
  currency,
  condition,
  source_id,
  effective_from,
  active
)
select annual.id, 'aaf_notice_driven_fy2026', null, 10200, 'USD', '{"notice_controls_amount":true,"payment_channel":"uscis_online","no_waiver":true}'::jsonb, fr.id, '2026-01-01'::date, true
from annual
cross join fr
on conflict (form_definition_id, fee_key) do update
set amount_cents = excluded.amount_cents,
    condition = excluded.condition,
    source_id = excluded.source_id,
    effective_from = excluded.effective_from,
    active = true,
    updated_at = now();

with annual as (
  select id from public.form_definitions where agency = 'USCIS' and form_code = 'ANNUAL_ASYLUM_FEE'
),
portal as (
  select id from public.official_sources where url = 'https://my.uscis.gov/accounts/annual-asylum-fee/start/overview'
)
insert into public.filing_destinations (
  form_definition_id,
  destination_key,
  filing_method,
  address,
  source_id,
  active
)
select annual.id, 'uscis_online_aaf_portal', 'online', '{"url":"https://my.uscis.gov/accounts/annual-asylum-fee/start/overview","requires":["A-Number","I-589 receipt number"]}'::jsonb, portal.id, true
from annual
cross join portal
on conflict (form_definition_id, destination_key) do update
set filing_method = excluded.filing_method,
    address = excluded.address,
    source_id = excluded.source_id,
    active = true,
    updated_at = now();

with eoir33 as (
  select id from public.form_definitions where agency = 'EOIR' and form_code = 'EOIR-33'
),
portal as (
  select id from public.official_sources where url = 'https://respondentaccess.eoir.justice.gov/en/forms/eoir33ic/'
)
insert into public.filing_destinations (
  form_definition_id,
  destination_key,
  filing_method,
  address,
  source_id,
  active
)
select eoir33.id, 'eoir_respondent_access_eoir33ic', 'online_or_court', '{"url":"https://respondentaccess.eoir.justice.gov/en/forms/eoir33ic/","requires":"copy_to_dhs"}'::jsonb, portal.id, true
from eoir33
cross join portal
on conflict (form_definition_id, destination_key) do update
set filing_method = excluded.filing_method,
    address = excluded.address,
    source_id = excluded.source_id,
    active = true,
    updated_at = now();

with forms as (
  select fd.id, fd.form_code, os.id as source_id
  from public.form_definitions fd
  left join public.official_sources os on os.id = fd.official_page_source_id
  where fd.form_code in ('ANNUAL_ASYLUM_FEE', 'I-765', 'EOIR-33', 'CHANGE_OF_VENUE')
),
requirements as (
  select * from (
    values
      ('ANNUAL_ASYLUM_FEE', 'aaf_notice', 'Notificacion USCIS AAF', 'Aviso oficial con A-Number, recibo, monto y fecha limite.', true),
      ('ANNUAL_ASYLUM_FEE', 'payment_receipt', 'Comprobante de pago USCIS', 'Recibo o numero de confirmacion generado por el portal oficial despues del pago.', false),
      ('I-765', 'identity_document', 'Identificacion y documentos base', 'Documento de identidad, I-94 si aplica y recibo del caso que soporta la categoria.', true),
      ('I-765', 'previous_ead', 'EAD anterior para renovacion', 'Copia del permiso anterior si se solicita renovacion.', false),
      ('EOIR-33', 'proof_of_service', 'Prueba de servicio a DHS', 'Confirmacion de que se entregara copia a DHS/OPLA.', true),
      ('CHANGE_OF_VENUE', 'new_address_evidence', 'Prueba de nueva direccion', 'Contrato, recibo, correo oficial u otra evidencia de domicilio.', true),
      ('CHANGE_OF_VENUE', 'eoir33ic', 'EOIR-33/IC', 'Cambio de direccion si la direccion de correspondencia cambio.', true)
  ) as r(form_code, requirement_key, title_es, description_es, required)
)
insert into public.evidence_requirements (
  form_definition_id,
  requirement_key,
  title_es,
  description_es,
  source_id,
  required,
  active
)
select forms.id, requirements.requirement_key, requirements.title_es, requirements.description_es, forms.source_id, requirements.required, true
from requirements
join forms on forms.form_code = requirements.form_code
on conflict (form_definition_id, requirement_key) do update
set title_es = excluded.title_es,
    description_es = excluded.description_es,
    source_id = excluded.source_id,
    required = excluded.required,
    active = true,
    updated_at = now();

update public.premium_services
set title = 'Pago de anualidades',
    description = 'Gratis por ahora: prepara alertas, datos y comprobante interno para la Tarifa Anual de Asilo de USCIS.',
    price_mode = 'free',
    enabled = true,
    updated_at = now()
where service_type = 'ANNUALITY_PAYMENT';
