create extension if not exists pgcrypto;
create extension if not exists citext;

do $$ begin
  create type agency_type as enum ('USCIS', 'EOIR', 'CBP', 'DMV', 'OTHER');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type status_severity as enum ('green', 'yellow', 'red');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type subscription_tier as enum ('free', 'base', 'premium', 'expert');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type filing_type as enum ('AR11', 'EOIR33', 'CHANGE_OF_VENUE', 'I765_RENEWAL');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type filing_status as enum ('draft', 'needs_review', 'ready_to_sign', 'exported', 'submitted_by_user', 'cancelled');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type document_status as enum ('classified', 'needs_review', 'expired', 'processing', 'rejected');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type premium_service_type as enum ('ANNUALITY_PAYMENT', 'EXPERT_REVIEW', 'SPECIAL_CASE_TRACKING');
exception when duplicate_object then null;
end $$;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email citext unique not null,
  phone text,
  full_name text not null,
  preferred_language text not null default 'es',
  state_code char(2),
  timezone text not null default 'America/New_York',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  tier subscription_tier not null default 'free',
  stripe_customer_id text,
  stripe_subscription_id text,
  status text not null default 'inactive',
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists immigration_profiles (
  user_id uuid primary key references users(id) on delete cascade,
  a_number_ciphertext bytea,
  birth_date_ciphertext bytea,
  country_of_birth text,
  current_address jsonb not null default '{}'::jsonb,
  mailing_address jsonb not null default '{}'::jsonb,
  consent_version text not null,
  consented_at timestamptz not null default now(),
  legal_disclaimer_ack_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  agency agency_type not null default 'OTHER',
  doc_type text not null,
  title text not null,
  storage_provider text not null default 's3',
  storage_key text not null,
  mime_type text not null default 'application/pdf',
  sha256 text not null,
  size_bytes bigint not null default 0,
  status document_status not null default 'processing',
  offline_allowed boolean not null default false,
  ocr_status text not null default 'pending',
  extracted_fields jsonb not null default '{}'::jsonb,
  issued_at date,
  expires_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists documents_user_created_idx on documents(user_id, created_at desc);
create index if not exists documents_user_agency_idx on documents(user_id, agency);
create index if not exists documents_user_expires_idx on documents(user_id, expires_at) where expires_at is not null;
create index if not exists documents_fields_gin_idx on documents using gin(extracted_fields);

create table if not exists document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  version_no int not null,
  storage_key text not null,
  sha256 text not null,
  created_at timestamptz not null default now(),
  unique (document_id, version_no)
);

create table if not exists cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  agency agency_type not null,
  receipt_number text,
  eoir_case_id_ciphertext bytea,
  form_type text,
  status text not null default 'unknown',
  status_source text not null default 'manual',
  last_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cases_receipt_or_eoir check (receipt_number is not null or eoir_case_id_ciphertext is not null)
);

create index if not exists cases_user_agency_idx on cases(user_id, agency);
create index if not exists cases_receipt_idx on cases(receipt_number) where receipt_number is not null;

create table if not exists case_status_snapshots (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references cases(id) on delete cascade,
  status text not null,
  raw_payload jsonb not null default '{}'::jsonb,
  source text not null,
  checked_at timestamptz not null default now()
);

create index if not exists case_status_snapshots_case_checked_idx on case_status_snapshots(case_id, checked_at desc);

create table if not exists critical_dates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  case_id uuid references cases(id) on delete set null,
  source_document_id uuid references documents(id) on delete set null,
  kind text not null,
  title text not null,
  details text,
  due_at timestamptz not null,
  severity status_severity not null default 'yellow',
  source text not null default 'user',
  acknowledged_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists critical_dates_user_due_idx on critical_dates(user_id, due_at asc);
create index if not exists critical_dates_unacked_idx on critical_dates(user_id, severity, due_at)
  where acknowledged_at is null;

create table if not exists notification_preferences (
  user_id uuid primary key references users(id) on delete cascade,
  push_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  email_enabled boolean not null default true,
  quiet_hours jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (endpoint)
);

create table if not exists automated_filings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  case_id uuid references cases(id) on delete set null,
  filing_type filing_type not null,
  status filing_status not null default 'draft',
  input_snapshot jsonb not null,
  generated_pdf_key text,
  legal_review_required boolean not null default true,
  legal_review_status text not null default 'not_requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists automated_filings_user_created_idx on automated_filings(user_id, created_at desc);
create index if not exists automated_filings_user_type_idx on automated_filings(user_id, filing_type);

create table if not exists filing_events (
  id uuid primary key default gen_random_uuid(),
  filing_id uuid not null references automated_filings(id) on delete cascade,
  actor_user_id uuid references users(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists dmv_question_sets (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null,
  language text not null default 'es',
  source_name text not null,
  source_url text not null,
  version_label text not null,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  unique (state_code, language, version_label)
);

create table if not exists dmv_questions (
  id uuid primary key default gen_random_uuid(),
  question_set_id uuid not null references dmv_question_sets(id) on delete cascade,
  prompt text not null,
  options jsonb not null,
  correct_option_key text not null,
  explanation text,
  topic text,
  created_at timestamptz not null default now()
);

create index if not exists dmv_questions_set_topic_idx on dmv_questions(question_set_id, topic);

create table if not exists local_resources (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null,
  city text,
  category text not null,
  name text not null,
  phone text,
  website text,
  address jsonb not null default '{}'::jsonb,
  languages text[] not null default array['es'],
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists local_resources_state_category_idx on local_resources(state_code, category);

create table if not exists expert_support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  case_id uuid references cases(id) on delete set null,
  topic text not null,
  urgency status_severity not null default 'yellow',
  description text not null,
  status text not null default 'new',
  assigned_to text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists premium_services (
  id uuid primary key default gen_random_uuid(),
  service_type premium_service_type not null unique,
  title text not null,
  description text not null,
  price_mode text not null check (price_mode in ('one_time', 'annual', 'manual_quote')),
  stripe_price_id text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists premium_service_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  service_id uuid not null references premium_services(id),
  case_id uuid references cases(id) on delete set null,
  status text not null default 'requested',
  amount_cents integer,
  currency char(3) not null default 'USD',
  stripe_checkout_session_id text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists premium_service_requests_user_created_idx on premium_service_requests(user_id, created_at desc);
create index if not exists premium_service_requests_status_idx on premium_service_requests(status, created_at desc);

create table if not exists audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete set null,
  actor_id uuid references users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  ip_address inet,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_log_user_created_idx on audit_log(user_id, created_at desc);
create index if not exists audit_log_entity_idx on audit_log(entity_type, entity_id);
