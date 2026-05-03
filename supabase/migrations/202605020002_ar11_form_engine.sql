-- AR-11 production form engine seed.
-- Official sources verified from USCIS on 2026-05-02.

insert into public.official_sources (agency, authority, title, url, source_kind, jurisdiction, notes)
values
  ('USCIS', 'official', 'USCIS Form AR-11 PDF', 'https://www.uscis.gov/sites/default/files/document/forms/ar-11.pdf', 'form_pdf', 'US', 'Official fillable PDF template for AR-11. Store a reviewed copy in official-templates before PDF generation.'),
  ('USCIS', 'official', 'USCIS How to Change Your Address', 'https://www.uscis.gov/addresschange', 'filing_guidance', 'US', 'Official address change guidance and special population instructions.'),
  ('USCIS', 'official', 'USCIS Change of Address Online Account', 'https://my.uscis.gov/file-a-form', 'online_submission', 'US', 'Official USCIS online account tool for user-directed address changes.')
on conflict (url) do update
set title = excluded.title,
    source_kind = excluded.source_kind,
    checked_at = now(),
    notes = excluded.notes;

with ar11 as (
  select id
  from public.form_definitions
  where agency = 'USCIS' and form_code = 'AR-11'
),
pdf_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/sites/default/files/document/forms/ar-11.pdf'
),
page_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/ar-11'
)
insert into public.form_editions (
  form_definition_id,
  edition_label,
  effective_from,
  pdf_template_path,
  official_pdf_source_id,
  instructions_source_id,
  field_map,
  validation_schema,
  status,
  verified_by,
  verified_at
)
select
  ar11.id,
  '11/02/22',
  date '2022-11-02',
  'AR-11/ar-11-11-02-22.pdf',
  pdf_source.id,
  page_source.id,
  '{
    "strategy": "acroform_or_overlay",
    "requires_template_verification": true,
    "fields": {
      "alien_registration_number": {"type": "text", "pdf_field": null},
      "family_name": {"type": "text", "pdf_field": null},
      "given_name": {"type": "text", "pdf_field": null},
      "middle_name": {"type": "text", "pdf_field": null},
      "date_of_birth": {"type": "date", "pdf_field": null},
      "country_of_birth": {"type": "text", "pdf_field": null},
      "country_of_citizenship": {"type": "text", "pdf_field": null},
      "current_street": {"type": "text", "pdf_field": null},
      "current_apt_ste_flr": {"type": "text", "pdf_field": null},
      "current_city": {"type": "text", "pdf_field": null},
      "current_state": {"type": "text", "pdf_field": null},
      "current_zip": {"type": "text", "pdf_field": null},
      "previous_street": {"type": "text", "pdf_field": null},
      "previous_apt_ste_flr": {"type": "text", "pdf_field": null},
      "previous_city": {"type": "text", "pdf_field": null},
      "previous_state": {"type": "text", "pdf_field": null},
      "previous_zip": {"type": "text", "pdf_field": null},
      "uscis_online_account_number": {"type": "text", "pdf_field": null},
      "last_form_filed": {"type": "text", "pdf_field": null},
      "receipt_number": {"type": "text", "pdf_field": null}
    }
  }'::jsonb,
  '{
    "required": [
      "family_name",
      "given_name",
      "date_of_birth",
      "country_of_birth",
      "country_of_citizenship",
      "current_street",
      "current_city",
      "current_state",
      "current_zip",
      "previous_street",
      "previous_city",
      "previous_state",
      "previous_zip"
    ],
    "patterns": {
      "alien_registration_number": "^A?[0-9]{7,9}$",
      "current_state": "^[A-Z]{2}$",
      "previous_state": "^[A-Z]{2}$",
      "current_zip": "^[0-9]{5}(-[0-9]{4})?$",
      "previous_zip": "^[0-9]{5}(-[0-9]{4})?$"
    }
  }'::jsonb,
  'active',
  'official-source-import',
  now()
from ar11, pdf_source, page_source
on conflict (form_definition_id, edition_label) do update
set effective_from = excluded.effective_from,
    pdf_template_path = excluded.pdf_template_path,
    official_pdf_source_id = excluded.official_pdf_source_id,
    instructions_source_id = excluded.instructions_source_id,
    field_map = excluded.field_map,
    validation_schema = excluded.validation_schema,
    status = excluded.status,
    verified_by = excluded.verified_by,
    verified_at = excluded.verified_at;

with edition as (
  select fe.id
  from public.form_editions fe
  join public.form_definitions fd on fd.id = fe.form_definition_id
  where fd.agency = 'USCIS'
    and fd.form_code = 'AR-11'
    and fe.edition_label = '11/02/22'
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
select edition.id, question_key, label_es, label_en, help_text_es, data_type, required, display_order, source_field_refs, validation_rule
from edition
cross join (
  values
    ('alien_registration_number', 'Numero A', 'A-Number', 'Si no lo tiene, puede dejarlo en blanco.', 'text', false, 10, array['AR-11 identity']::text[], '{"pattern":"^A?[0-9]{7,9}$"}'::jsonb),
    ('family_name', 'Apellido legal', 'Family Name', null, 'text', true, 20, array['AR-11 identity']::text[], '{}'::jsonb),
    ('given_name', 'Nombre legal', 'Given Name', null, 'text', true, 30, array['AR-11 identity']::text[], '{}'::jsonb),
    ('middle_name', 'Segundo nombre', 'Middle Name', null, 'text', false, 40, array['AR-11 identity']::text[], '{}'::jsonb),
    ('date_of_birth', 'Fecha de nacimiento', 'Date of Birth', 'Usa formato mes/dia/ano para el PDF oficial.', 'date', true, 50, array['AR-11 identity']::text[], '{}'::jsonb),
    ('country_of_birth', 'Pais de nacimiento', 'Country of Birth', null, 'text', true, 60, array['AR-11 identity']::text[], '{}'::jsonb),
    ('country_of_citizenship', 'Pais de ciudadania', 'Country of Citizenship', null, 'text', true, 70, array['AR-11 identity']::text[], '{}'::jsonb),
    ('current_street', 'Nueva direccion: calle y numero', 'Current Physical Address - Street Number and Name', null, 'text', true, 100, array['AR-11 current address']::text[], '{}'::jsonb),
    ('current_apt_ste_flr', 'Nueva direccion: apto, suite o piso', 'Current Physical Address - Apt./Ste./Flr.', null, 'text', false, 110, array['AR-11 current address']::text[], '{}'::jsonb),
    ('current_city', 'Nueva direccion: ciudad', 'Current Physical Address - City', null, 'text', true, 120, array['AR-11 current address']::text[], '{}'::jsonb),
    ('current_state', 'Nueva direccion: estado', 'Current Physical Address - State', 'Usa abreviatura de dos letras.', 'state_code', true, 130, array['AR-11 current address']::text[], '{"pattern":"^[A-Z]{2}$"}'::jsonb),
    ('current_zip', 'Nueva direccion: codigo postal', 'Current Physical Address - ZIP Code', null, 'text', true, 140, array['AR-11 current address']::text[], '{"pattern":"^[0-9]{5}(-[0-9]{4})?$"}'::jsonb),
    ('previous_street', 'Direccion anterior: calle y numero', 'Previous Physical Address - Street Number and Name', null, 'text', true, 200, array['AR-11 previous address']::text[], '{}'::jsonb),
    ('previous_apt_ste_flr', 'Direccion anterior: apto, suite o piso', 'Previous Physical Address - Apt./Ste./Flr.', null, 'text', false, 210, array['AR-11 previous address']::text[], '{}'::jsonb),
    ('previous_city', 'Direccion anterior: ciudad', 'Previous Physical Address - City', null, 'text', true, 220, array['AR-11 previous address']::text[], '{}'::jsonb),
    ('previous_state', 'Direccion anterior: estado', 'Previous Physical Address - State', 'Usa abreviatura de dos letras.', 'state_code', true, 230, array['AR-11 previous address']::text[], '{"pattern":"^[A-Z]{2}$"}'::jsonb),
    ('previous_zip', 'Direccion anterior: codigo postal', 'Previous Physical Address - ZIP Code', null, 'text', true, 240, array['AR-11 previous address']::text[], '{"pattern":"^[0-9]{5}(-[0-9]{4})?$"}'::jsonb),
    ('uscis_online_account_number', 'Numero de cuenta USCIS en linea', 'USCIS Online Account Number', 'Opcional si no tiene uno.', 'text', false, 300, array['AR-11 account/case']::text[], '{}'::jsonb),
    ('last_form_filed', 'Ultimo formulario presentado ante USCIS', 'Form Last Filed', 'Ejemplo: I-765, I-130, I-485.', 'text', false, 310, array['AR-11 account/case']::text[], '{}'::jsonb),
    ('receipt_number', 'Numero de recibo relacionado', 'Receipt Number', 'Opcional, util para conectar el cambio con un caso.', 'text', false, 320, array['AR-11 account/case']::text[], '{}'::jsonb),
    ('protected_case_flag', 'Tengo un caso VAWA, T, U o I-751 por abuso', 'VAWA/T/U/I-751 abuse waiver flag', 'USCIS indica instrucciones especiales para estas poblaciones. Si marcas si, el sistema exige revision humana.', 'boolean', false, 900, array['USCIS special population guidance']::text[], '{}'::jsonb)
) as q(question_key, label_es, label_en, help_text_es, data_type, required, display_order, source_field_refs, validation_rule)
on conflict (form_edition_id, question_key) do update
set label_es = excluded.label_es,
    label_en = excluded.label_en,
    help_text_es = excluded.help_text_es,
    data_type = excluded.data_type,
    required = excluded.required,
    display_order = excluded.display_order,
    source_field_refs = excluded.source_field_refs,
    validation_rule = excluded.validation_rule;

with ar11 as (
  select id
  from public.form_definitions
  where agency = 'USCIS' and form_code = 'AR-11'
),
ar11_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/ar-11'
),
address_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/addresschange'
),
online_source as (
  select id from public.official_sources
  where url = 'https://my.uscis.gov/file-a-form'
)
insert into public.form_rules (
  form_definition_id,
  rule_key,
  jurisdiction,
  rule_type,
  condition,
  result,
  source_id,
  effective_from,
  review_requirement,
  active
)
select ar11.id, rule_key, 'US', rule_type, condition, result, source_id, date '2022-11-02', review_requirement::public.review_requirement, true
from ar11
cross join (
  values
    ('ar11_submit_within_10_days', 'deadline', '{}'::jsonb, '{"days_after_move":10,"severity":"red","message_es":"USCIS indica que los extranjeros en Estados Unidos deben reportar un cambio de direccion dentro de 10 dias de mudarse."}'::jsonb, (select id from ar11_source), 'none'),
    ('ar11_online_account_encouraged', 'submission_guidance', '{}'::jsonb, '{"preferred_method":"uscis_online_account","message_es":"USCIS recomienda usar la cuenta USCIS en linea porque actualiza los sistemas casi de inmediato y elimina la necesidad de presentar AR-11 en papel."}'::jsonb, (select id from online_source), 'none'),
    ('ar11_paper_is_user_signed', 'signature', '{}'::jsonb, '{"signature_required":true,"app_must_not_submit":true,"message_es":"La aplicacion prepara el PDF y checklist; el usuario debe revisar, firmar y presentar por el canal oficial."}'::jsonb, (select id from ar11_source), 'none'),
    ('ar11_vawa_t_u_requires_review', 'human_review_trigger', '{"answers.protected_case_flag":true}'::jsonb, '{"legal_review_required":"required","message_es":"Casos VAWA/T/U/I-751 por abuso siguen instrucciones especiales de USCIS y requieren revision humana."}'::jsonb, (select id from address_source), 'required')
) as r(rule_key, rule_type, condition, result, source_id, review_requirement)
on conflict (form_definition_id, rule_key) do update
set rule_type = excluded.rule_type,
    condition = excluded.condition,
    result = excluded.result,
    source_id = excluded.source_id,
    effective_from = excluded.effective_from,
    review_requirement = excluded.review_requirement,
    active = excluded.active;

with ar11 as (
  select id
  from public.form_definitions
  where agency = 'USCIS' and form_code = 'AR-11'
),
ar11_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/ar-11'
)
insert into public.evidence_requirements (
  form_definition_id,
  requirement_key,
  title_es,
  description_es,
  category_code,
  source_id,
  required,
  active
)
select ar11.id, requirement_key, title_es, description_es, category_code, ar11_source.id, required, true
from ar11, ar11_source
cross join (
  values
    ('identity_basics', 'Identidad basica', 'Nombre legal, fecha y pais de nacimiento, pais de ciudadania y Numero A si aplica.', 'identity', true),
    ('previous_and_current_address', 'Direccion anterior y nueva', 'Direccion fisica anterior y nueva para preparar el formulario.', 'address', true),
    ('case_reference_optional', 'Referencia de caso', 'Ultimo formulario presentado y numero de recibo si el usuario desea relacionarlo con un caso.', 'case', false)
) as e(requirement_key, title_es, description_es, category_code, required)
on conflict (form_definition_id, requirement_key) do update
set title_es = excluded.title_es,
    description_es = excluded.description_es,
    category_code = excluded.category_code,
    source_id = excluded.source_id,
    required = excluded.required,
    active = excluded.active;

with ar11 as (
  select id
  from public.form_definitions
  where agency = 'USCIS' and form_code = 'AR-11'
),
ar11_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/ar-11'
),
fee_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/g-1055'
)
insert into public.filing_destinations (
  form_definition_id,
  destination_key,
  filing_method,
  address,
  source_id,
  effective_from,
  active
)
select ar11.id, 'ar11_paper_refer_to_current_form', 'mail', '{"instruction_es":"USCIS indica consultar el Formulario AR-11 para la direccion postal actual. No enviar otros formularios ni tarifas a esa direccion.","template_path":"AR-11/ar-11-11-02-22.pdf"}'::jsonb, ar11_source.id, date '2022-11-02', true
from ar11, ar11_source
on conflict (form_definition_id, destination_key) do update
set filing_method = excluded.filing_method,
    address = excluded.address,
    source_id = excluded.source_id,
    effective_from = excluded.effective_from,
    active = excluded.active;

with ar11 as (
  select id
  from public.form_definitions
  where agency = 'USCIS' and form_code = 'AR-11'
),
fee_source as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/g-1055'
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
select ar11.id, 'ar11_fee_schedule_reference', 'general', null, 'USD', '{"message_es":"Verificar tarifa vigente en el desglose oficial G-1055 antes de presentar."}'::jsonb, fee_source.id, date '2022-11-02', true
from ar11, fee_source
on conflict (form_definition_id, fee_key) do update
set amount_cents = excluded.amount_cents,
    condition = excluded.condition,
    source_id = excluded.source_id,
    effective_from = excluded.effective_from,
    active = excluded.active;
