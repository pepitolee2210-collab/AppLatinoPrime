-- Activates AR-11 PDF generation only after auditing the AcroForm field names
-- in the official USCIS PDF template for edition 11/02/22.

with edition as (
  select fe.id
  from public.form_editions fe
  join public.form_definitions fd on fd.id = fe.form_definition_id
  where fd.agency = 'USCIS'
    and fd.form_code = 'AR-11'
    and fe.edition_label = '11/02/22'
)
update public.form_editions fe
set field_map = '{
      "strategy": "acroform",
      "requires_template_verification": false,
      "verified_with": "PyPDF2 get_fields audit of official USCIS AR-11 PDF",
      "manual_fields": [
        "S3_SignatureApplicant[0]",
        "S3_DateofSignature[0]",
        "S2A_Unit[0..2]",
        "S2B__Unit[0..2]",
        "S2C_Unit[0..2]"
      ],
      "notes_es": "La firma y los selectores apt/suite/piso quedan para revision manual antes de enviar. No se prellena firma mecanografiada.",
      "fields": {
        "alien_registration_number": {"type": "text", "pdf_field": "AlienNumber[0]"},
        "family_name": {"type": "text", "pdf_field": "S1_FamilyName[0]"},
        "given_name": {"type": "text", "pdf_field": "S1_GivenName[0]"},
        "middle_name": {"type": "text", "pdf_field": "S1_MiddleName[0]"},
        "date_of_birth": {"type": "date", "pdf_field": "S1_DateOfBirth[0]"},
        "previous_street": {"type": "text", "pdf_field": "S2A_StreetNumberName[0]"},
        "previous_apt_ste_flr": {"type": "text", "pdf_field": "S2A_AptSteFlrNumber[0]"},
        "previous_city": {"type": "text", "pdf_field": "S2A_CityOrTown[0]"},
        "previous_state": {"type": "choice", "pdf_field": "S2A_State[0]"},
        "previous_zip": {"type": "text", "pdf_field": "S2A_ZipCode[0]"},
        "current_street": {"type": "text", "pdf_field": "S2B_StreetNumberName[0]"},
        "current_apt_ste_flr": {"type": "text", "pdf_field": "S2B_AptSteFlrNumber[0]"},
        "current_city": {"type": "text", "pdf_field": "S2B_CityOrTown[0]"},
        "current_state": {"type": "choice", "pdf_field": "S2B_State[0]"},
        "current_zip": {"type": "text", "pdf_field": "S2B_ZipCode[0]"},
        "mailing_street": {"type": "text", "pdf_field": "S2C_StreetNumberName[0]"},
        "mailing_apt_ste_flr": {"type": "text", "pdf_field": "S2C_AptSteFlrNumber[0]"},
        "mailing_city": {"type": "text", "pdf_field": "S2C_CityOrTown[0]"},
        "mailing_state": {"type": "choice", "pdf_field": "S2C_State[0]"},
        "mailing_zip": {"type": "text", "pdf_field": "S2C_ZipCode[0]"}
      }
    }'::jsonb,
    validation_schema = '{
      "required": [
        "family_name",
        "given_name",
        "date_of_birth",
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
        "mailing_state": "^[A-Z]{2}$",
        "current_zip": "^[0-9]{5}(-[0-9]{4})?$",
        "previous_zip": "^[0-9]{5}(-[0-9]{4})?$",
        "mailing_zip": "^[0-9]{5}(-[0-9]{4})?$"
      }
    }'::jsonb,
    status = 'active',
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
update public.form_questions fq
set required = false,
    help_text_es = 'Este dato puede guardarse en el perfil, pero no existe como campo prellenado en el PDF oficial AR-11 11/02/22.',
    updated_at = now()
from edition
where fq.form_edition_id = edition.id
  and fq.question_key in ('country_of_birth', 'country_of_citizenship', 'uscis_online_account_number', 'last_form_filed', 'receipt_number');

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
    ('mailing_street', 'Direccion postal: calle y numero', 'Mailing Address - Street Number and Name', 'Solo si tu direccion postal es distinta a tu direccion fisica nueva.', 'text', false, 150, array['AR-11 mailing address']::text[], '{}'::jsonb),
    ('mailing_apt_ste_flr', 'Direccion postal: apto, suite o piso', 'Mailing Address - Apt./Ste./Flr.', 'Solo si aplica.', 'text', false, 160, array['AR-11 mailing address']::text[], '{}'::jsonb),
    ('mailing_city', 'Direccion postal: ciudad', 'Mailing Address - City', 'Solo si tu direccion postal es distinta.', 'text', false, 170, array['AR-11 mailing address']::text[], '{}'::jsonb),
    ('mailing_state', 'Direccion postal: estado', 'Mailing Address - State', 'Usa abreviatura de dos letras.', 'state_code', false, 180, array['AR-11 mailing address']::text[], '{"pattern":"^[A-Z]{2}$"}'::jsonb),
    ('mailing_zip', 'Direccion postal: codigo postal', 'Mailing Address - ZIP Code', 'Solo si tu direccion postal es distinta.', 'text', false, 190, array['AR-11 mailing address']::text[], '{"pattern":"^[0-9]{5}(-[0-9]{4})?$"}'::jsonb)
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
