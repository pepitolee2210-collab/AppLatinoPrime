-- Map AR-11 Apt./Ste./Flr. unit-type checkboxes to explicit wizard answers.

with edition as (
  select fe.id
  from public.form_editions fe
  join public.form_definitions fd on fd.id = fe.form_definition_id
  where fd.agency = 'USCIS'
    and fd.form_code = 'AR-11'
    and fe.edition_label = '11/02/22'
)
update public.form_editions fe
set field_map =
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(
      jsonb_set(fe.field_map, '{manual_fields}', '["S3_SignatureApplicant[0]", "S3_DateofSignature[0]"]'::jsonb, true),
        '{fields,previous_unit_apt}', '{"type":"checkbox","pdf_field":"S2A_Unit[0]","answer_key":"previous_unit_type","checked_value":"apt"}'::jsonb, true),
        '{fields,previous_unit_floor}', '{"type":"checkbox","pdf_field":"S2A_Unit[1]","answer_key":"previous_unit_type","checked_value":"floor"}'::jsonb, true),
        '{fields,previous_unit_suite}', '{"type":"checkbox","pdf_field":"S2A_Unit[2]","answer_key":"previous_unit_type","checked_value":"suite"}'::jsonb, true),
        '{fields,current_unit_apt}', '{"type":"checkbox","pdf_field":"S2B__Unit[0]","answer_key":"current_unit_type","checked_value":"apt"}'::jsonb, true),
        '{fields,current_unit_floor}', '{"type":"checkbox","pdf_field":"S2B__Unit[1]","answer_key":"current_unit_type","checked_value":"floor"}'::jsonb, true),
        '{fields,current_unit_suite}', '{"type":"checkbox","pdf_field":"S2B__Unit[2]","answer_key":"current_unit_type","checked_value":"suite"}'::jsonb, true),
        '{fields,mailing_unit_apt}', '{"type":"checkbox","pdf_field":"S2C_Unit[0]","answer_key":"mailing_unit_type","checked_value":"apt"}'::jsonb, true),
        '{fields,mailing_unit_floor}', '{"type":"checkbox","pdf_field":"S2C_Unit[1]","answer_key":"mailing_unit_type","checked_value":"floor"}'::jsonb, true),
        '{fields,mailing_unit_suite}', '{"type":"checkbox","pdf_field":"S2C_Unit[2]","answer_key":"mailing_unit_type","checked_value":"suite"}'::jsonb, true),
    verified_by = 'codex_pdf_field_audit',
    verified_at = now(),
    updated_at = now()
from edition
where fe.id = edition.id;

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
    ('current_unit_type', 'Nueva direccion: tipo de unidad', 'Current Physical Address - Unit Type', 'Selecciona si el numero corresponde a apartamento, suite o piso.', 'select', false, 105, array['AR-11 current address unit type']::text[], '{"options":[{"value":"apt","label_es":"Apto"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('mailing_unit_type', 'Direccion postal: tipo de unidad', 'Mailing Address - Unit Type', 'Solo si tu direccion postal tiene apartamento, suite o piso.', 'select', false, 155, array['AR-11 mailing address unit type']::text[], '{"options":[{"value":"apt","label_es":"Apto"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('previous_unit_type', 'Direccion anterior: tipo de unidad', 'Previous Physical Address - Unit Type', 'Selecciona si el numero corresponde a apartamento, suite o piso.', 'select', false, 205, array['AR-11 previous address unit type']::text[], '{"options":[{"value":"apt","label_es":"Apto"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb)
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
