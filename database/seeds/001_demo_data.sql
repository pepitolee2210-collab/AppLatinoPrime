insert into users (id, email, full_name, state_code, timezone)
values (
  '11111111-1111-4111-8111-111111111111',
  'demo@usalatinoprime.com',
  'Marisol Rivera',
  'UT',
  'America/Denver'
)
on conflict (email) do nothing;

insert into user_subscriptions (user_id, tier, status)
values ('11111111-1111-4111-8111-111111111111', 'base', 'active')
on conflict (user_id) do update set tier = excluded.tier, status = excluded.status;

insert into immigration_profiles (user_id, country_of_birth, current_address, consent_version, legal_disclaimer_ack_at)
values (
  '11111111-1111-4111-8111-111111111111',
  'Mexico',
  '{"line1":"120 W Main St","city":"Salt Lake City","state":"UT","postalCode":"84101"}',
  '2026-05-01',
  now()
)
on conflict (user_id) do nothing;

insert into documents (
  id,
  user_id,
  agency,
  doc_type,
  title,
  storage_key,
  sha256,
  size_bytes,
  status,
  offline_allowed,
  ocr_status,
  extracted_fields,
  expires_at
)
values
  (
    '22222222-2222-4222-8222-222222222221',
    '11111111-1111-4111-8111-111111111111',
    'EOIR',
    'NOTICE_OF_HEARING',
    'Notice of Hearing EOIR-31',
    'demo/users/1111/documents/eoir-hearing.pdf',
    repeat('a', 64),
    834211,
    'classified',
    true,
    'completed',
    '{"hearingDate":"2025-06-12","court":"Salt Lake City Immigration Court"}',
    null
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'USCIS',
    'EAD_CARD',
    'EAD I-766 Card',
    'demo/users/1111/documents/ead-card.pdf',
    repeat('b', 64),
    412900,
    'classified',
    true,
    'completed',
    '{"category":"C09","cardNumber":"demo"}',
    '2025-07-30'
  )
on conflict (id) do nothing;

insert into cases (id, user_id, agency, receipt_number, form_type, status, status_source, last_checked_at)
values (
  '33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  'USCIS',
  'IOE1234567890',
  'I-765',
  'Case Was Received',
  'uscis_api',
  now()
)
on conflict (id) do nothing;

insert into critical_dates (id, user_id, case_id, source_document_id, kind, title, details, due_at, severity, source)
values
  (
    '44444444-4444-4444-8444-444444444441',
    '11111111-1111-4111-8111-111111111111',
    null,
    '22222222-2222-4222-8222-222222222221',
    'court_hearing',
    'Audiencia en corte',
    'EOIR: 12 de junio de 2025. Confirmar dirección y asistencia.',
    '2025-06-12 09:00:00-06',
    'red',
    'document_ocr'
  ),
  (
    '44444444-4444-4444-8444-444444444442',
    '11111111-1111-4111-8111-111111111111',
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    'ead_expiration',
    'Expira tu EAD',
    'I-765 categoria C09. Preparar renovacion con margen.',
    '2025-07-30 17:00:00-06',
    'yellow',
    'document_ocr'
  )
on conflict (id) do nothing;

insert into automated_filings (
  id,
  user_id,
  case_id,
  filing_type,
  status,
  input_snapshot,
  generated_pdf_key,
  legal_review_required,
  legal_review_status
)
values
  (
    '55555555-5555-4555-8555-555555555551',
    '11111111-1111-4111-8111-111111111111',
    null,
    'AR11',
    'ready_to_sign',
    '{"fromProfile":true,"addressState":"UT"}',
    'demo/users/1111/filings/ar11.pdf',
    false,
    'not_required'
  ),
  (
    '55555555-5555-4555-8555-555555555552',
    '11111111-1111-4111-8111-111111111111',
    null,
    'CHANGE_OF_VENUE',
    'draft',
    '{"reason":"Moved to Utah","destinationCourt":"Salt Lake City"}',
    null,
    true,
    'not_requested'
  )
on conflict (id) do nothing;

insert into dmv_question_sets (id, state_code, language, source_name, source_url, version_label, active)
values (
  '66666666-6666-4666-8666-666666666666',
  'UT',
  'es',
  'Utah Driver License Division Handbook',
  'https://dld.utah.gov/handbooks/',
  '2026-demo',
  true
)
on conflict (state_code, language, version_label) do nothing;

insert into premium_services (id, service_type, title, description, price_mode, enabled)
values
  (
    '77777777-7777-4777-8777-777777777771',
    'ANNUALITY_PAYMENT',
    'Pago de anualidades',
    'Gestiona pagos anuales, comprobantes y recordatorios de renovacion del servicio.',
    'annual',
    true
  ),
  (
    '77777777-7777-4777-8777-777777777772',
    'EXPERT_REVIEW',
    'Revision experta',
    'Solicita acompanamiento humano para casos de mayor complejidad.',
    'manual_quote',
    true
  )
on conflict (service_type) do update
set title = excluded.title,
    description = excluded.description,
    price_mode = excluded.price_mode,
    enabled = excluded.enabled;
