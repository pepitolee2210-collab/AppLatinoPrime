-- Official form hardening and state source registry.
-- Sources verified from official USCIS, EOIR, and USAGov pages on 2026-05-04.

create table if not exists public.official_source_snapshots (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.official_sources(id) on delete cascade,
  fetched_at timestamptz not null default now(),
  http_status int,
  content_type text,
  content_sha256 text,
  byte_size bigint,
  storage_bucket text,
  storage_path text,
  snapshot_status text not null default 'fetched'
    check (snapshot_status in ('fetched', 'skipped', 'failed')),
  error_message text,
  extracted_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (source_id, content_sha256)
);

create index if not exists official_source_snapshots_source_fetched_idx
on public.official_source_snapshots(source_id, fetched_at desc);

alter table public.official_source_snapshots enable row level security;

drop policy if exists "official_source_snapshots_read_authenticated" on public.official_source_snapshots;
create policy "official_source_snapshots_read_authenticated"
on public.official_source_snapshots for select
to authenticated
using (true);

drop policy if exists "official_source_snapshots_staff_write" on public.official_source_snapshots;
create policy "official_source_snapshots_staff_write"
on public.official_source_snapshots for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

create table if not exists public.state_service_catalog (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null references public.us_states(code) on delete cascade,
  service_area text not null check (service_area in ('dmv', 'resources', 'state_forms')),
  verification_status text not null default 'source_verified'
    check (verification_status in ('source_verified', 'content_imported', 'questions_ready', 'needs_review', 'unsupported')),
  primary_source_id uuid not null references public.official_sources(id),
  secondary_source_id uuid references public.official_sources(id),
  verification_source_id uuid references public.official_sources(id),
  extracted_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (state_code, service_area)
);

create index if not exists state_service_catalog_source_idx
on public.state_service_catalog(primary_source_id);

create trigger state_service_catalog_set_updated_at
before update on public.state_service_catalog
for each row execute function public.set_updated_at();

alter table public.state_service_catalog enable row level security;

drop policy if exists "state_service_catalog_read_authenticated" on public.state_service_catalog;
create policy "state_service_catalog_read_authenticated"
on public.state_service_catalog for select
to authenticated
using (true);

drop policy if exists "state_service_catalog_staff_write" on public.state_service_catalog;
create policy "state_service_catalog_staff_write"
on public.state_service_catalog for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('official-source-snapshots', 'official-source-snapshots', false, 104857600, array['application/pdf', 'text/html', 'application/json', 'text/plain'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "official_source_snapshots_storage_staff" on storage.objects;
create policy "official_source_snapshots_storage_staff"
on storage.objects for all
to authenticated
using (bucket_id = 'official-source-snapshots' and private.is_staff())
with check (bucket_id = 'official-source-snapshots' and private.is_staff());

insert into public.official_sources (agency, authority, title, url, source_kind, jurisdiction, notes, checked_at)
values
  ('USCIS', 'official', 'USCIS Form I-765 PDF', 'https://www.uscis.gov/sites/default/files/document/forms/i-765.pdf?download=1', 'form_pdf', 'US', 'Official fillable PDF template for Form I-765. AcroForm fields audited locally before mapping.', now()),
  ('USCIS', 'official', 'USCIS Form I-765 Instructions PDF', 'https://www.uscis.gov/sites/default/files/document/forms/i-765instr.pdf', 'instructions_pdf', 'US', 'Official USCIS instructions for Form I-765.', now()),
  ('EOIR', 'official', 'EOIR Downloadable Forms', 'https://www.justice.gov/eoir/eoir-forms', 'forms_index', 'US', 'Official EOIR downloadable forms and filing guidance.', now()),
  ('EOIR', 'official', 'EOIR-33/IC PDF', 'https://icor.eoir.justice.gov/eoir-33ic_change_of_address_and_contact_information_form.pdf', 'form_pdf', 'US', 'Official EOIR-33/IC PDF referenced by EOIR forms listing; portal remains the preferred guided workflow.', now()),
  ('STATE', 'official', 'USAGov State Motor Vehicle Services', 'https://www.usa.gov/state-motor-vehicle-services', 'state_directory', 'US', 'Official GSA/USAGov directory used to seed state motor vehicle portal URLs.', now())
on conflict (url) do update
set agency = excluded.agency,
    authority = excluded.authority,
    title = excluded.title,
    source_kind = excluded.source_kind,
    jurisdiction = excluded.jurisdiction,
    notes = excluded.notes,
    checked_at = now();

with usagov as (
  select id from public.official_sources
  where url = 'https://www.usa.gov/state-motor-vehicle-services'
),
state_portals(agency, authority, title, url, source_kind, jurisdiction, notes) as (
  values
    ('DMV'::public.agency_code, 'official'::public.source_authority, 'Alabama State Motor Vehicle Services', 'https://www.revenue.alabama.gov/', 'dmv_portal', 'AL', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Alaska State Motor Vehicle Services', 'https://dmv.alaska.gov/', 'dmv_portal', 'AK', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Arizona State Motor Vehicle Services', 'https://azdot.gov/', 'dmv_portal', 'AZ', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Arkansas State Motor Vehicle Services', 'https://www.dfa.arkansas.gov/', 'dmv_portal', 'AR', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'California State Motor Vehicle Services', 'https://www.dmv.ca.gov/', 'dmv_portal', 'CA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Colorado State Motor Vehicle Services', 'https://dmv.colorado.gov/', 'dmv_portal', 'CO', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Connecticut State Motor Vehicle Services', 'https://portal.ct.gov/', 'dmv_portal', 'CT', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Delaware State Motor Vehicle Services', 'https://www.dmv.de.gov/', 'dmv_portal', 'DE', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Florida State Motor Vehicle Services', 'https://www.flhsmv.gov/', 'dmv_portal', 'FL', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Georgia State Motor Vehicle Services', 'https://dds.georgia.gov/', 'dmv_portal', 'GA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Hawaii State Motor Vehicle Services', 'https://hidot.hawaii.gov/', 'dmv_portal', 'HI', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Idaho State Motor Vehicle Services', 'https://itd.idaho.gov/', 'dmv_portal', 'ID', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Illinois State Motor Vehicle Services', 'https://www.ilsos.gov/', 'dmv_portal', 'IL', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Indiana State Motor Vehicle Services', 'https://www.in.gov/', 'dmv_portal', 'IN', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Iowa State Motor Vehicle Services', 'https://iowadot.gov/', 'dmv_portal', 'IA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Kansas State Motor Vehicle Services', 'https://www.ksrevenue.gov/', 'dmv_portal', 'KS', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Kentucky State Motor Vehicle Services', 'https://drive.ky.gov/', 'dmv_portal', 'KY', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Louisiana State Motor Vehicle Services', 'https://www.expresslane.org/', 'dmv_portal', 'LA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Maine State Motor Vehicle Services', 'https://www.maine.gov/', 'dmv_portal', 'ME', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Maryland State Motor Vehicle Services', 'https://mva.maryland.gov/', 'dmv_portal', 'MD', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Massachusetts State Motor Vehicle Services', 'https://www.mass.gov/', 'dmv_portal', 'MA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Michigan State Motor Vehicle Services', 'https://www.michigan.gov/', 'dmv_portal', 'MI', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Minnesota State Motor Vehicle Services', 'https://onlineservices.dps.mn.gov/', 'dmv_portal', 'MN', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Mississippi State Motor Vehicle Services', 'https://www.mmvc.ms.gov/', 'dmv_portal', 'MS', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Missouri State Motor Vehicle Services', 'https://dor.mo.gov/', 'dmv_portal', 'MO', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Montana State Motor Vehicle Services', 'https://mvdmt.gov/', 'dmv_portal', 'MT', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Nebraska State Motor Vehicle Services', 'https://dmv.nebraska.gov/', 'dmv_portal', 'NE', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Nevada State Motor Vehicle Services', 'https://dmv.nv.gov/', 'dmv_portal', 'NV', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'New Hampshire State Motor Vehicle Services', 'https://www.dmv.nh.gov/', 'dmv_portal', 'NH', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'New Jersey State Motor Vehicle Services', 'https://www.nj.gov/', 'dmv_portal', 'NJ', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'New Mexico State Motor Vehicle Services', 'https://www.mvd.newmexico.gov/', 'dmv_portal', 'NM', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'New York State Motor Vehicle Services', 'https://dmv.ny.gov/', 'dmv_portal', 'NY', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'North Carolina State Motor Vehicle Services', 'https://www.ncdot.gov/', 'dmv_portal', 'NC', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'North Dakota State Motor Vehicle Services', 'https://www.dot.nd.gov/', 'dmv_portal', 'ND', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Ohio State Motor Vehicle Services', 'https://www.bmv.ohio.gov/', 'dmv_portal', 'OH', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Oklahoma State Motor Vehicle Services', 'https://oklahoma.gov/', 'dmv_portal', 'OK', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Oregon State Motor Vehicle Services', 'https://www.oregon.gov/', 'dmv_portal', 'OR', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Pennsylvania State Motor Vehicle Services', 'https://www.dmv.pa.gov/', 'dmv_portal', 'PA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Rhode Island State Motor Vehicle Services', 'https://dmv.ri.gov/', 'dmv_portal', 'RI', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'South Carolina State Motor Vehicle Services', 'https://scdmvonline.com/', 'dmv_portal', 'SC', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'South Dakota State Motor Vehicle Services', 'https://dor.sd.gov/', 'dmv_portal', 'SD', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Tennessee State Motor Vehicle Services', 'https://www.tn.gov/', 'dmv_portal', 'TN', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Texas State Motor Vehicle Services', 'https://www.txdmv.gov/', 'dmv_portal', 'TX', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Utah State Motor Vehicle Services', 'https://dmv.utah.gov/', 'dmv_portal', 'UT', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Vermont State Motor Vehicle Services', 'https://dmv.vermont.gov/', 'dmv_portal', 'VT', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Virginia State Motor Vehicle Services', 'https://www.dmv.virginia.gov/', 'dmv_portal', 'VA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Washington State Motor Vehicle Services', 'https://www.dol.wa.gov/', 'dmv_portal', 'WA', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'West Virginia State Motor Vehicle Services', 'https://transportation.wv.gov/', 'dmv_portal', 'WV', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Wisconsin State Motor Vehicle Services', 'https://wisconsindot.gov/', 'dmv_portal', 'WI', 'State motor vehicle portal listed by USAGov official directory.'),
    ('DMV', 'official', 'Wyoming State Motor Vehicle Services', 'https://www.dot.state.wy.us/', 'dmv_portal', 'WY', 'State motor vehicle portal listed by USAGov official directory.')
)
insert into public.official_sources (agency, authority, title, url, source_kind, jurisdiction, notes, checked_at)
select agency, authority, title, url, source_kind, jurisdiction, notes || ' Verification directory source: https://www.usa.gov/state-motor-vehicle-services', now()
from state_portals
on conflict (url) do update
set agency = excluded.agency,
    authority = excluded.authority,
    title = excluded.title,
    source_kind = excluded.source_kind,
    jurisdiction = excluded.jurisdiction,
    notes = excluded.notes,
    checked_at = now();

with usagov as (
  select id from public.official_sources
  where url = 'https://www.usa.gov/state-motor-vehicle-services'
),
portal_sources as (
  select id, jurisdiction
  from public.official_sources
  where source_kind = 'dmv_portal'
    and jurisdiction in (
      'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY'
    )
)
insert into public.state_service_catalog (
  state_code,
  service_area,
  verification_status,
  primary_source_id,
  verification_source_id,
  extracted_at,
  notes
)
select
  portal_sources.jurisdiction,
  'dmv',
  case when portal_sources.jurisdiction = 'UT' then 'questions_ready' else 'source_verified' end,
  portal_sources.id,
  usagov.id,
  now(),
  case
    when portal_sources.jurisdiction = 'UT' then 'Official portal verified; Utah practice questions are already seeded from the Utah Driver Handbook.'
    else 'Official state motor vehicle portal verified from USAGov. Handbook/question import must be completed before enabling a state-specific simulator.'
  end
from portal_sources
cross join usagov
on conflict (state_code, service_area) do update
set verification_status = excluded.verification_status,
    primary_source_id = excluded.primary_source_id,
    verification_source_id = excluded.verification_source_id,
    extracted_at = excluded.extracted_at,
    notes = excluded.notes,
    updated_at = now();

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
select edition.id, q.question_key, q.label_es, q.label_en, q.help_text_es, q.data_type, q.required, q.display_order, q.source_field_refs, q.validation_rule
from edition
cross join (
  values
    ('current_unit_type', 'Tipo de unidad en direccion nueva', 'Current address unit type', 'Selecciona solo si aplica.', 'select', false, 112, array['AR-11 present address unit']::text[], '{"options":[{"value":"apt","label_es":"Apartamento"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('previous_unit_type', 'Tipo de unidad en direccion anterior', 'Previous address unit type', 'Selecciona solo si aplica.', 'select', false, 212, array['AR-11 previous address unit']::text[], '{"options":[{"value":"apt","label_es":"Apartamento"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('mailing_street', 'Direccion postal opcional: calle y numero', 'Optional mailing address - Street Number and Name', 'Solo si quieres recibir correo en una direccion distinta.', 'text', false, 400, array['AR-11 mailing address']::text[], '{}'::jsonb),
    ('mailing_unit_type', 'Tipo de unidad postal', 'Mailing address unit type', 'Selecciona solo si aplica.', 'select', false, 410, array['AR-11 mailing address unit']::text[], '{"options":[{"value":"apt","label_es":"Apartamento"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('mailing_apt_ste_flr', 'Direccion postal opcional: apto, suite o piso', 'Optional mailing address - Apt./Ste./Flr.', null, 'text', false, 420, array['AR-11 mailing address']::text[], '{}'::jsonb),
    ('mailing_city', 'Direccion postal opcional: ciudad', 'Optional mailing address - City', null, 'text', false, 430, array['AR-11 mailing address']::text[], '{}'::jsonb),
    ('mailing_state', 'Direccion postal opcional: estado', 'Optional mailing address - State', 'Usa abreviatura de dos letras.', 'state_code', false, 440, array['AR-11 mailing address']::text[], '{"pattern":"^[A-Z]{2}$"}'::jsonb),
    ('mailing_zip', 'Direccion postal opcional: codigo postal', 'Optional mailing address - ZIP Code', null, 'text', false, 450, array['AR-11 mailing address']::text[], '{"pattern":"^[0-9]{5}(-[0-9]{4})?$"}'::jsonb)
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

with ar11 as (
  select fe.id
  from public.form_editions fe
  join public.form_definitions fd on fd.id = fe.form_definition_id
  where fd.agency = 'USCIS'
    and fd.form_code = 'AR-11'
    and fe.edition_label = '11/02/22'
),
pdf as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/sites/default/files/document/forms/ar-11.pdf'
),
instructions as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/ar-11'
)
update public.form_editions fe
set pdf_template_path = 'AR-11/ar-11-11-02-22.pdf',
    official_pdf_source_id = pdf.id,
    instructions_source_id = instructions.id,
    field_map = '{
      "strategy": "acroform",
      "requires_template_verification": false,
      "fields": {
        "alien_registration_number": {"type": "text", "pdf_field": "AlienNumber[0]"},
        "family_name": {"type": "text", "pdf_field": "S1_FamilyName[0]"},
        "given_name": {"type": "text", "pdf_field": "S1_GivenName[0]"},
        "middle_name": {"type": "text", "pdf_field": "S1_MiddleName[0]"},
        "date_of_birth": {"type": "date", "pdf_field": "S1_DateOfBirth[0]"},
        "previous_street": {"type": "text", "pdf_field": "S2A_StreetNumberName[0]"},
        "previous_unit_apt": {"type": "checkbox", "answer_key": "previous_unit_type", "checked_value": "apt", "pdf_field": "S2A_Unit[0]"},
        "previous_unit_floor": {"type": "checkbox", "answer_key": "previous_unit_type", "checked_value": "floor", "pdf_field": "S2A_Unit[1]"},
        "previous_unit_suite": {"type": "checkbox", "answer_key": "previous_unit_type", "checked_value": "suite", "pdf_field": "S2A_Unit[2]"},
        "previous_apt_ste_flr": {"type": "text", "pdf_field": "S2A_AptSteFlrNumber[0]"},
        "previous_city": {"type": "text", "pdf_field": "S2A_CityOrTown[0]"},
        "previous_state": {"type": "choice", "pdf_field": "S2A_State[0]"},
        "previous_zip": {"type": "text", "pdf_field": "S2A_ZipCode[0]"},
        "current_street": {"type": "text", "pdf_field": "S2B_StreetNumberName[0]"},
        "current_unit_apt": {"type": "checkbox", "answer_key": "current_unit_type", "checked_value": "apt", "pdf_field": "S2B__Unit[0]"},
        "current_unit_floor": {"type": "checkbox", "answer_key": "current_unit_type", "checked_value": "floor", "pdf_field": "S2B__Unit[1]"},
        "current_unit_suite": {"type": "checkbox", "answer_key": "current_unit_type", "checked_value": "suite", "pdf_field": "S2B__Unit[2]"},
        "current_apt_ste_flr": {"type": "text", "pdf_field": "S2B_AptSteFlrNumber[0]"},
        "current_city": {"type": "text", "pdf_field": "S2B_CityOrTown[0]"},
        "current_state": {"type": "choice", "pdf_field": "S2B_State[0]"},
        "current_zip": {"type": "text", "pdf_field": "S2B_ZipCode[0]"},
        "mailing_street": {"type": "text", "pdf_field": "S2C_StreetNumberName[0]"},
        "mailing_unit_apt": {"type": "checkbox", "answer_key": "mailing_unit_type", "checked_value": "apt", "pdf_field": "S2C_Unit[0]"},
        "mailing_unit_floor": {"type": "checkbox", "answer_key": "mailing_unit_type", "checked_value": "floor", "pdf_field": "S2C_Unit[1]"},
        "mailing_unit_suite": {"type": "checkbox", "answer_key": "mailing_unit_type", "checked_value": "suite", "pdf_field": "S2C_Unit[2]"},
        "mailing_apt_ste_flr": {"type": "text", "pdf_field": "S2C_AptSteFlrNumber[0]"},
        "mailing_city": {"type": "text", "pdf_field": "S2C_CityOrTown[0]"},
        "mailing_state": {"type": "choice", "pdf_field": "S2C_State[0]"},
        "mailing_zip": {"type": "text", "pdf_field": "S2C_ZipCode[0]"}
      }
    }'::jsonb,
    validation_schema = jsonb_set(coalesce(fe.validation_schema, '{}'::jsonb), '{official_pdf_field_count}', '33'::jsonb, true),
    status = 'active',
    verified_by = 'official_pdf_field_audit',
    verified_at = now(),
    updated_at = now()
from ar11, pdf, instructions
where fe.id = ar11.id;

with i765_definition as (
  select id from public.form_definitions
  where agency = 'USCIS'
    and form_code = 'I-765'
),
disabled_old as (
  update public.form_editions fe
  set status = 'draft',
      updated_at = now()
  from i765_definition
  where fe.form_definition_id = i765_definition.id
    and fe.edition_label <> '08/21/25'
  returning fe.id
),
pdf as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/sites/default/files/document/forms/i-765.pdf?download=1'
),
instructions as (
  select id from public.official_sources
  where url = 'https://www.uscis.gov/sites/default/files/document/forms/i-765instr.pdf'
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
  i765_definition.id,
  '08/21/25',
  date '2025-08-21',
  'I-765/i-765-08-21-25.pdf',
  pdf.id,
  instructions.id,
  '{
    "strategy": "acroform",
    "requires_template_verification": false,
    "official_pdf_field_count": 169,
    "fields": {
      "application_initial": {"type": "checkbox", "answer_key": "application_reason", "checked_value": "initial", "pdf_field": "Part1_Checkbox[0]"},
      "application_replacement": {"type": "checkbox", "answer_key": "application_reason", "checked_value": "replacement", "pdf_field": "Part1_Checkbox[1]"},
      "application_renewal": {"type": "checkbox", "answer_key": "application_reason", "checked_value": "renewal", "pdf_field": "Part1_Checkbox[2]"},
      "family_name": {"type": "text", "pdf_field": "Line1a_FamilyName[0]"},
      "given_name": {"type": "text", "pdf_field": "Line1b_GivenName[0]"},
      "middle_name": {"type": "text", "pdf_field": "Line1c_MiddleName[0]"},
      "mailing_in_care_of": {"type": "text", "pdf_field": "Line4a_InCareofName[0]"},
      "mailing_street": {"type": "text", "pdf_field": "Line4b_StreetNumberName[0]"},
      "mailing_unit_suite": {"type": "checkbox", "answer_key": "mailing_unit_type", "checked_value": "suite", "pdf_field": "Pt2Line5_Unit[0]"},
      "mailing_unit_floor": {"type": "checkbox", "answer_key": "mailing_unit_type", "checked_value": "floor", "pdf_field": "Pt2Line5_Unit[1]"},
      "mailing_unit_apt": {"type": "checkbox", "answer_key": "mailing_unit_type", "checked_value": "apt", "pdf_field": "Pt2Line5_Unit[2]"},
      "mailing_apt_ste_flr": {"type": "text", "pdf_field": "Pt2Line5_AptSteFlrNumber[0]"},
      "mailing_city": {"type": "text", "pdf_field": "Pt2Line5_CityOrTown[0]"},
      "mailing_state": {"type": "choice", "pdf_field": "Pt2Line5_State[0]"},
      "mailing_zip": {"type": "text", "pdf_field": "Pt2Line5_ZipCode[0]"},
      "physical_street": {"type": "text", "pdf_field": "Pt2Line7_StreetNumberName[0]"},
      "physical_unit_suite": {"type": "checkbox", "answer_key": "physical_unit_type", "checked_value": "suite", "pdf_field": "Pt2Line7_Unit[0]"},
      "physical_unit_floor": {"type": "checkbox", "answer_key": "physical_unit_type", "checked_value": "floor", "pdf_field": "Pt2Line7_Unit[1]"},
      "physical_unit_apt": {"type": "checkbox", "answer_key": "physical_unit_type", "checked_value": "apt", "pdf_field": "Pt2Line7_Unit[2]"},
      "physical_apt_ste_flr": {"type": "text", "pdf_field": "Pt2Line7_AptSteFlrNumber[0]"},
      "physical_city": {"type": "text", "pdf_field": "Pt2Line7_CityOrTown[0]"},
      "physical_state": {"type": "choice", "pdf_field": "Pt2Line7_State[0]"},
      "physical_zip": {"type": "text", "pdf_field": "Pt2Line7_ZipCode[0]"},
      "a_number": {"type": "text", "pdf_field": "Line7_AlienNumber[0]"},
      "uscis_online_account_number": {"type": "text", "pdf_field": "Line8_ElisAccountNumber[0]"},
      "ssn": {"type": "text", "pdf_field": "Line12b_SSN[0]"},
      "citizenship_country_1": {"type": "text", "pdf_field": "Line17a_CountryOfBirth[0]"},
      "citizenship_country_2": {"type": "text", "pdf_field": "Line17b_CountryOfBirth[0]"},
      "birth_city": {"type": "text", "pdf_field": "Line18a_CityTownOfBirth[0]"},
      "birth_state_province": {"type": "text", "pdf_field": "Line18b_CityTownOfBirth[0]"},
      "country_of_birth": {"type": "text", "pdf_field": "Line18c_CountryOfBirth[0]"},
      "date_of_birth": {"type": "date", "pdf_field": "Line19_DOB[0]"},
      "i94_number": {"type": "text", "pdf_field": "Line20a_I94Number[0]"},
      "passport_number": {"type": "text", "pdf_field": "Line20b_Passport[0]"},
      "travel_document_number": {"type": "text", "pdf_field": "Line20c_TravelDoc[0]"},
      "passport_country_of_issuance": {"type": "text", "pdf_field": "Line20d_CountryOfIssuance[0]"},
      "passport_expiration": {"type": "date", "pdf_field": "Line20e_ExpDate[0]"},
      "last_arrival_date": {"type": "date", "pdf_field": "Line21_DateOfLastEntry[0]"},
      "place_of_last_arrival": {"type": "text", "pdf_field": "place_entry[0]"},
      "status_last_entry": {"type": "text", "pdf_field": "Line23_StatusLastEntry[0]"},
      "current_status": {"type": "text", "pdf_field": "Line24_CurrentStatus[0]"},
      "eligibility_category_letter": {"type": "text", "pdf_field": "section_1[0]"},
      "eligibility_category_number": {"type": "text", "pdf_field": "section_2[0]"},
      "eligibility_category_suffix": {"type": "text", "pdf_field": "section_3[0]"},
      "related_receipt_number": {"type": "text", "pdf_field": "Line30a_ReceiptNumber[0]"},
      "statement_can_read_english": {"type": "checkbox", "answer_key": "applicant_statement", "checked_value": "can_read_english", "pdf_field": "Pt3Line1Checkbox[0]"},
      "statement_used_interpreter": {"type": "checkbox", "answer_key": "applicant_statement", "checked_value": "used_interpreter", "pdf_field": "Pt3Line1Checkbox[1]"},
      "interpreter_language": {"type": "text", "pdf_field": "Pt3Line1b_Language[0]"},
      "signature_phone": {"type": "text", "pdf_field": "Pt3Line3_DaytimePhoneNumber1[0]"},
      "signature_mobile": {"type": "text", "pdf_field": "Pt3Line4_MobileNumber1[0]"},
      "signature_email": {"type": "text", "pdf_field": "Pt3Line5_Email[0]"}
    }
  }'::jsonb,
  '{
    "required": [
      "application_reason",
      "family_name",
      "given_name",
      "mailing_street",
      "mailing_city",
      "mailing_state",
      "mailing_zip",
      "citizenship_country_1",
      "birth_city",
      "country_of_birth",
      "date_of_birth",
      "current_status",
      "eligibility_category_letter",
      "eligibility_category_number",
      "signature_phone",
      "signature_email",
      "applicant_statement"
    ],
    "official_pdf_field_count": 169,
    "edition_notice": "Downloaded from official USCIS PDF source; verify current acceptable edition and filing address on USCIS before mailing or online filing.",
    "barcode_note": "The official PDF contains USCIS barcode fields; users must review the completed PDF before signing or submitting."
  }'::jsonb,
  'active',
  'official_pdf_field_audit',
  now()
from i765_definition, pdf, instructions
on conflict (form_definition_id, edition_label) do update
set effective_from = excluded.effective_from,
    pdf_template_path = excluded.pdf_template_path,
    official_pdf_source_id = excluded.official_pdf_source_id,
    instructions_source_id = excluded.instructions_source_id,
    field_map = excluded.field_map,
    validation_schema = excluded.validation_schema,
    status = 'active',
    verified_by = excluded.verified_by,
    verified_at = now(),
    updated_at = now();

with edition as (
  select fe.id
  from public.form_editions fe
  join public.form_definitions fd on fd.id = fe.form_definition_id
  where fd.agency = 'USCIS'
    and fd.form_code = 'I-765'
    and fe.edition_label = '08/21/25'
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
    ('family_name', 'Apellido legal', 'Family name', null, 'text', true, 20, array['I-765 Part 2 Item 1.a']::text[], '{}'::jsonb),
    ('given_name', 'Nombre legal', 'Given name', null, 'text', true, 30, array['I-765 Part 2 Item 1.b']::text[], '{}'::jsonb),
    ('middle_name', 'Segundo nombre', 'Middle name', null, 'text', false, 40, array['I-765 Part 2 Item 1.c']::text[], '{}'::jsonb),
    ('mailing_in_care_of', 'Direccion postal: a cargo de', 'Mailing address in care of', 'Opcional.', 'text', false, 100, array['I-765 Part 2 Item 5.a']::text[], '{}'::jsonb),
    ('mailing_street', 'Direccion postal: calle y numero', 'Mailing street number and name', null, 'text', true, 110, array['I-765 Part 2 Item 5.b']::text[], '{}'::jsonb),
    ('mailing_unit_type', 'Direccion postal: tipo de unidad', 'Mailing unit type', 'Selecciona solo si aplica.', 'select', false, 120, array['I-765 Part 2 Item 5.c']::text[], '{"options":[{"value":"apt","label_es":"Apartamento"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('mailing_apt_ste_flr', 'Direccion postal: apto, suite o piso', 'Mailing Apt./Ste./Flr.', null, 'text', false, 130, array['I-765 Part 2 Item 5.c']::text[], '{}'::jsonb),
    ('mailing_city', 'Direccion postal: ciudad', 'Mailing city or town', null, 'text', true, 140, array['I-765 Part 2 Item 5.d']::text[], '{}'::jsonb),
    ('mailing_state', 'Direccion postal: estado', 'Mailing state', 'Usa abreviatura de dos letras.', 'state_code', true, 150, array['I-765 Part 2 Item 5.e']::text[], '{"pattern":"^[A-Z]{2}$"}'::jsonb),
    ('mailing_zip', 'Direccion postal: codigo postal', 'Mailing ZIP code', null, 'text', true, 160, array['I-765 Part 2 Item 5.f']::text[], '{"pattern":"^[0-9]{5}(-[0-9]{4})?$"}'::jsonb),
    ('physical_street', 'Direccion fisica: calle y numero', 'Physical street number and name', 'Si es distinta de la postal.', 'text', false, 200, array['I-765 Part 2 Item 7.a']::text[], '{}'::jsonb),
    ('physical_unit_type', 'Direccion fisica: tipo de unidad', 'Physical unit type', 'Selecciona solo si aplica.', 'select', false, 210, array['I-765 Part 2 Item 7.b']::text[], '{"options":[{"value":"apt","label_es":"Apartamento"},{"value":"floor","label_es":"Piso"},{"value":"suite","label_es":"Suite"}]}'::jsonb),
    ('physical_apt_ste_flr', 'Direccion fisica: apto, suite o piso', 'Physical Apt./Ste./Flr.', null, 'text', false, 220, array['I-765 Part 2 Item 7.b']::text[], '{}'::jsonb),
    ('physical_city', 'Direccion fisica: ciudad', 'Physical city or town', null, 'text', false, 230, array['I-765 Part 2 Item 7.c']::text[], '{}'::jsonb),
    ('physical_state', 'Direccion fisica: estado', 'Physical state', 'Usa abreviatura de dos letras.', 'state_code', false, 240, array['I-765 Part 2 Item 7.d']::text[], '{"pattern":"^[A-Z]{2}$"}'::jsonb),
    ('physical_zip', 'Direccion fisica: codigo postal', 'Physical ZIP code', null, 'text', false, 250, array['I-765 Part 2 Item 7.e']::text[], '{"pattern":"^[0-9]{5}(-[0-9]{4})?$"}'::jsonb),
    ('a_number', 'A-Number', 'Alien Registration Number', 'Si aplica.', 'text', false, 300, array['I-765 Part 2 Item 8']::text[], '{"pattern":"^A?[0-9]{7,9}$"}'::jsonb),
    ('uscis_online_account_number', 'Numero de cuenta USCIS online', 'USCIS online account number', 'Opcional.', 'text', false, 310, array['I-765 Part 2 Item 9']::text[], '{}'::jsonb),
    ('ssn', 'Seguro Social', 'U.S. Social Security Number', 'Si aplica.', 'text', false, 320, array['I-765 Part 2 Item 13.b']::text[], '{}'::jsonb),
    ('citizenship_country_1', 'Pais de ciudadania o nacionalidad 1', 'Country of citizenship or nationality 1', null, 'text', true, 400, array['I-765 Part 2 Item 14.a']::text[], '{}'::jsonb),
    ('citizenship_country_2', 'Pais de ciudadania o nacionalidad 2', 'Country of citizenship or nationality 2', 'Opcional si tienes doble nacionalidad.', 'text', false, 410, array['I-765 Part 2 Item 14.b']::text[], '{}'::jsonb),
    ('birth_city', 'Ciudad de nacimiento', 'City/town/village of birth', null, 'text', true, 420, array['I-765 Part 2 Item 15.a']::text[], '{}'::jsonb),
    ('birth_state_province', 'Estado o provincia de nacimiento', 'State/province of birth', null, 'text', false, 430, array['I-765 Part 2 Item 15.b']::text[], '{}'::jsonb),
    ('country_of_birth', 'Pais de nacimiento', 'Country of birth', null, 'text', true, 440, array['I-765 Part 2 Item 15.c']::text[], '{}'::jsonb),
    ('date_of_birth', 'Fecha de nacimiento', 'Date of birth', 'Usa formato mes/dia/ano en el PDF generado.', 'date', true, 450, array['I-765 Part 2 Item 16']::text[], '{}'::jsonb),
    ('i94_number', 'Numero I-94', 'I-94 number', 'Si aplica.', 'text', false, 500, array['I-765 Part 2 Item 17']::text[], '{}'::jsonb),
    ('passport_number', 'Numero de pasaporte', 'Passport number', 'Si aplica.', 'text', false, 510, array['I-765 Part 2 Item 18']::text[], '{}'::jsonb),
    ('travel_document_number', 'Numero de documento de viaje', 'Travel document number', 'Si aplica.', 'text', false, 520, array['I-765 Part 2 Item 19']::text[], '{}'::jsonb),
    ('passport_country_of_issuance', 'Pais emisor del pasaporte', 'Passport country of issuance', null, 'text', false, 530, array['I-765 Part 2 Item 20']::text[], '{}'::jsonb),
    ('passport_expiration', 'Fecha de vencimiento del pasaporte', 'Passport expiration date', null, 'date', false, 540, array['I-765 Part 2 Item 21']::text[], '{}'::jsonb),
    ('last_arrival_date', 'Fecha de ultima entrada a EE.UU.', 'Date of last arrival', null, 'date', false, 550, array['I-765 Part 2 Item 22']::text[], '{}'::jsonb),
    ('place_of_last_arrival', 'Lugar de ultima entrada', 'Place of last arrival', null, 'text', false, 560, array['I-765 Part 2 Item 23']::text[], '{}'::jsonb),
    ('status_last_entry', 'Estatus en ultima entrada', 'Immigration status at last arrival', null, 'text', false, 570, array['I-765 Part 2 Item 24']::text[], '{}'::jsonb),
    ('current_status', 'Estatus migratorio actual', 'Current immigration status or category', null, 'text', true, 580, array['I-765 Part 2 Item 25']::text[], '{}'::jsonb),
    ('eligibility_category_letter', 'Categoria: letra', 'Eligibility category letter', 'Ejemplo: c para (c)(8).', 'text', true, 600, array['I-765 Part 2 Item 27']::text[], '{}'::jsonb),
    ('eligibility_category_number', 'Categoria: numero', 'Eligibility category number', 'Ejemplo: 8 para (c)(8).', 'text', true, 610, array['I-765 Part 2 Item 27']::text[], '{}'::jsonb),
    ('eligibility_category_suffix', 'Categoria: subcategoria opcional', 'Eligibility category suffix', 'Solo si las instrucciones lo requieren.', 'text', false, 620, array['I-765 Part 2 Item 27']::text[], '{}'::jsonb),
    ('related_receipt_number', 'Numero de recibo relacionado', 'Related receipt number', 'I-589, I-485 u otro recibo que soporte la categoria.', 'text', false, 630, array['I-765 supporting receipt']::text[], '{}'::jsonb),
    ('applicant_statement', 'Declaracion del solicitante', 'Applicant statement', 'Selecciona si puedes leer ingles o usaste interprete.', 'select', true, 700, array['I-765 Part 3 Item 1']::text[], '{"options":[{"value":"can_read_english","label_es":"Puedo leer y entender ingles"},{"value":"used_interpreter","label_es":"Use interprete"}]}'::jsonb),
    ('interpreter_language', 'Idioma del interprete', 'Interpreter language', 'Solo si usaste interprete.', 'text', false, 710, array['I-765 Part 3 Item 1.b']::text[], '{}'::jsonb),
    ('signature_phone', 'Telefono de contacto', 'Contact phone', null, 'text', true, 720, array['I-765 Part 3 Item 3']::text[], '{}'::jsonb),
    ('signature_mobile', 'Telefono movil', 'Mobile phone', 'Opcional.', 'text', false, 730, array['I-765 Part 3 Item 4']::text[], '{}'::jsonb),
    ('signature_email', 'Correo de contacto', 'Contact email', null, 'text', true, 740, array['I-765 Part 3 Item 5']::text[], '{}'::jsonb),
    ('protected_case_flag', 'Mi caso requiere revision experta antes de enviar', 'Expert review flag', 'Marca si tienes antecedentes, orden previa, detencion, apelacion o dudas legales.', 'boolean', false, 900, array['risk triage']::text[], '{}'::jsonb)
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
  select id from public.form_definitions
  where agency = 'EOIR'
    and form_code = 'EOIR-33'
),
source as (
  select id from public.official_sources
  where url = 'https://respondentaccess.eoir.justice.gov/en/forms/eoir33ic/'
),
pdf as (
  select id from public.official_sources
  where url = 'https://icor.eoir.justice.gov/eoir-33ic_change_of_address_and_contact_information_form.pdf'
)
update public.form_editions fe
set official_pdf_source_id = pdf.id,
    instructions_source_id = source.id,
    validation_schema = jsonb_set(coalesce(fe.validation_schema, '{}'::jsonb), '{official_pdf_note}', '"EOIR provides a downloadable PDF and Respondent Access workflow; this app generates a preparation packet and directs the user to the official EOIR channel."'::jsonb, true),
    verified_by = 'official_source_research',
    verified_at = now(),
    updated_at = now()
from definition, source, pdf
where fe.form_definition_id = definition.id
  and fe.edition_label = 'eoir33ic-intake-2026';

create or replace view public.production_ready_form_catalog
with (security_invoker = true)
as
select
  fd.id,
  fd.agency,
  fd.form_code,
  fd.title,
  fd.description,
  fd.federal,
  fd.review_requirement,
  fd.official_page_source_id,
  page_source.url as official_page_url,
  fe.id as active_edition_id,
  fe.edition_label,
  fe.effective_from,
  fe.pdf_template_path,
  pdf_source.url as official_pdf_url,
  instructions_source.url as instructions_url,
  fe.status as edition_status,
  fe.verified_at,
  case
    when jsonb_typeof(fe.field_map -> 'fields') = 'object' then (
      select count(*)::int
      from jsonb_object_keys(fe.field_map -> 'fields')
    )
    else 0
  end as mapped_pdf_field_count,
  fd.enabled
from public.form_definitions fd
join public.official_sources page_source on page_source.id = fd.official_page_source_id
join public.form_editions fe on fe.form_definition_id = fd.id
left join public.official_sources pdf_source on pdf_source.id = fe.official_pdf_source_id
left join public.official_sources instructions_source on instructions_source.id = fe.instructions_source_id
where fd.enabled = true
  and fe.status = 'active'
  and fe.verified_at is not null
  and fe.instructions_source_id is not null
  and page_source.authority in ('official', 'official_api');

grant select on public.production_ready_form_catalog to authenticated;

create or replace view public.state_official_source_catalog
with (security_invoker = true)
as
select
  s.code as state_code,
  s.name as state_name,
  c.service_area,
  c.verification_status,
  source.title as source_title,
  source.url as source_url,
  verifier.url as verification_url,
  c.extracted_at,
  c.notes
from public.us_states s
join public.state_service_catalog c on c.state_code = s.code
join public.official_sources source on source.id = c.primary_source_id
left join public.official_sources verifier on verifier.id = c.verification_source_id;

grant select on public.state_official_source_catalog to authenticated;

do $$
begin
  alter table public.official_sources
    add constraint official_sources_official_https_check
    check (authority <> 'official' or url ~* '^https://')
    not valid;
exception when duplicate_object then null;
end $$;

alter table public.official_sources
validate constraint official_sources_official_https_check;

do $$
begin
  alter table public.form_definitions
    add constraint form_definitions_enabled_source_check
    check (enabled = false or official_page_source_id is not null)
    not valid;
exception when duplicate_object then null;
end $$;

alter table public.form_definitions
validate constraint form_definitions_enabled_source_check;

do $$
begin
  alter table public.form_editions
    add constraint form_editions_active_verified_source_check
    check (status <> 'active' or (verified_at is not null and instructions_source_id is not null))
    not valid;
exception when duplicate_object then null;
end $$;

alter table public.form_editions
validate constraint form_editions_active_verified_source_check;
