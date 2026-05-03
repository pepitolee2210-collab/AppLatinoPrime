-- USA Latino Prime production core for Supabase.
-- Project target: AppUsalatino (bzedgcxopndnvnescoky).
-- This migration creates the official-source registry, form engine,
-- document vault metadata, case tracking, premium services, and RLS.

create schema if not exists extensions;
create schema if not exists private;

grant usage on schema extensions to anon, authenticated, service_role;
grant usage on schema private to authenticated, service_role;

create extension if not exists pgcrypto;
create extension if not exists citext with schema extensions;

do $$ begin
  create type public.app_role as enum ('user', 'staff', 'admin');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.agency_code as enum ('USCIS', 'EOIR', 'CBP', 'DMV', 'STATE', 'LOCAL', 'OTHER');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.source_authority as enum ('official', 'official_api', 'manual_verified', 'internal');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.review_requirement as enum ('none', 'recommended', 'required');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.workflow_status as enum (
    'draft',
    'in_progress',
    'needs_user_review',
    'needs_expert_review',
    'ready_to_sign',
    'exported',
    'submitted_by_user',
    'cancelled'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.document_status as enum ('uploaded', 'processing', 'classified', 'needs_review', 'rejected', 'archived');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.severity as enum ('green', 'yellow', 'red');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.premium_service_type as enum ('ANNUALITY_PAYMENT', 'EXPERT_REVIEW', 'SPECIAL_CASE_TRACKING');
exception when duplicate_object then null;
end $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email extensions.citext,
  full_name text,
  phone text,
  preferred_language text not null default 'es',
  state_code char(2),
  timezone text not null default 'America/New_York',
  role public.app_role not null default 'user',
  onboarding_completed_at timestamptz,
  legal_disclaimer_ack_at timestamptz,
  privacy_consent_version text,
  privacy_consented_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('staff', 'admin')
  );
$$;

grant execute on function private.is_staff() to authenticated, service_role;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

grant execute on function private.is_admin() to authenticated, service_role;

create table if not exists public.official_sources (
  id uuid primary key default gen_random_uuid(),
  agency public.agency_code not null,
  authority public.source_authority not null default 'official',
  title text not null,
  url text not null unique,
  source_kind text not null,
  jurisdiction text not null default 'US',
  checked_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger official_sources_set_updated_at
before update on public.official_sources
for each row execute function public.set_updated_at();

create table if not exists public.us_states (
  code char(2) primary key,
  name text not null,
  enabled boolean not null default true,
  dmv_supported boolean not null default false,
  resources_supported boolean not null default false,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger us_states_set_updated_at
before update on public.us_states
for each row execute function public.set_updated_at();

create table if not exists public.form_definitions (
  id uuid primary key default gen_random_uuid(),
  agency public.agency_code not null,
  form_code text not null,
  title text not null,
  description text not null,
  federal boolean not null default true,
  review_requirement public.review_requirement not null default 'none',
  official_page_source_id uuid references public.official_sources(id),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency, form_code)
);

create trigger form_definitions_set_updated_at
before update on public.form_definitions
for each row execute function public.set_updated_at();

create table if not exists public.form_editions (
  id uuid primary key default gen_random_uuid(),
  form_definition_id uuid not null references public.form_definitions(id) on delete cascade,
  edition_label text not null,
  effective_from date,
  effective_to date,
  pdf_template_path text,
  official_pdf_source_id uuid references public.official_sources(id),
  instructions_source_id uuid references public.official_sources(id),
  field_map jsonb not null default '{}'::jsonb,
  validation_schema jsonb not null default '{}'::jsonb,
  status text not null default 'draft',
  verified_by text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_definition_id, edition_label)
);

create index if not exists form_editions_definition_status_idx
on public.form_editions(form_definition_id, status, effective_from desc);

create trigger form_editions_set_updated_at
before update on public.form_editions
for each row execute function public.set_updated_at();

create table if not exists public.form_questions (
  id uuid primary key default gen_random_uuid(),
  form_edition_id uuid not null references public.form_editions(id) on delete cascade,
  question_key text not null,
  label_es text not null,
  label_en text,
  help_text_es text,
  data_type text not null,
  required boolean not null default false,
  display_order int not null default 0,
  source_field_refs text[] not null default array[]::text[],
  validation_rule jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_edition_id, question_key)
);

create index if not exists form_questions_edition_order_idx
on public.form_questions(form_edition_id, display_order);

create trigger form_questions_set_updated_at
before update on public.form_questions
for each row execute function public.set_updated_at();

create table if not exists public.form_rules (
  id uuid primary key default gen_random_uuid(),
  form_definition_id uuid not null references public.form_definitions(id) on delete cascade,
  rule_key text not null,
  jurisdiction text not null default 'US',
  state_code char(2) references public.us_states(code),
  category_code text,
  rule_type text not null,
  condition jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  source_id uuid references public.official_sources(id),
  effective_from date,
  effective_to date,
  review_requirement public.review_requirement not null default 'none',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_definition_id, rule_key)
);

create index if not exists form_rules_lookup_idx
on public.form_rules(form_definition_id, state_code, category_code, rule_type)
where active = true;

create index if not exists form_rules_condition_gin_idx
on public.form_rules using gin(condition);

create trigger form_rules_set_updated_at
before update on public.form_rules
for each row execute function public.set_updated_at();

create table if not exists public.evidence_requirements (
  id uuid primary key default gen_random_uuid(),
  form_definition_id uuid not null references public.form_definitions(id) on delete cascade,
  requirement_key text not null,
  title_es text not null,
  description_es text not null,
  category_code text,
  source_id uuid references public.official_sources(id),
  required boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_definition_id, requirement_key)
);

create trigger evidence_requirements_set_updated_at
before update on public.evidence_requirements
for each row execute function public.set_updated_at();

create table if not exists public.filing_destinations (
  id uuid primary key default gen_random_uuid(),
  form_definition_id uuid not null references public.form_definitions(id) on delete cascade,
  destination_key text not null,
  state_code char(2) references public.us_states(code),
  category_code text,
  filing_method text not null,
  address jsonb not null default '{}'::jsonb,
  source_id uuid references public.official_sources(id),
  effective_from date,
  effective_to date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_definition_id, destination_key)
);

create index if not exists filing_destinations_lookup_idx
on public.filing_destinations(form_definition_id, state_code, category_code, filing_method)
where active = true;

create trigger filing_destinations_set_updated_at
before update on public.filing_destinations
for each row execute function public.set_updated_at();

create table if not exists public.fee_rules (
  id uuid primary key default gen_random_uuid(),
  form_definition_id uuid not null references public.form_definitions(id) on delete cascade,
  fee_key text not null,
  category_code text,
  amount_cents int,
  currency char(3) not null default 'USD',
  condition jsonb not null default '{}'::jsonb,
  source_id uuid references public.official_sources(id),
  effective_from date,
  effective_to date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (form_definition_id, fee_key)
);

create index if not exists fee_rules_lookup_idx
on public.fee_rules(form_definition_id, category_code)
where active = true;

create trigger fee_rules_set_updated_at
before update on public.fee_rules
for each row execute function public.set_updated_at();

create table if not exists public.user_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  agency public.agency_code not null default 'OTHER',
  doc_type text not null,
  title text not null,
  storage_bucket text not null default 'user-documents',
  storage_path text not null,
  mime_type text not null,
  sha256 text,
  size_bytes bigint not null default 0,
  status public.document_status not null default 'uploaded',
  offline_allowed boolean not null default false,
  extracted_fields jsonb not null default '{}'::jsonb,
  source_confidence numeric(4,3),
  issued_at date,
  expires_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

create index if not exists user_documents_user_created_idx
on public.user_documents(user_id, created_at desc);

create index if not exists user_documents_user_agency_idx
on public.user_documents(user_id, agency);

create index if not exists user_documents_expires_idx
on public.user_documents(user_id, expires_at)
where expires_at is not null;

create index if not exists user_documents_extracted_fields_gin_idx
on public.user_documents using gin(extracted_fields);

create trigger user_documents_set_updated_at
before update on public.user_documents
for each row execute function public.set_updated_at();

create table if not exists public.document_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.user_documents(id) on delete cascade,
  job_type text not null,
  status text not null default 'queued',
  provider text,
  provider_job_id text,
  result jsonb not null default '{}'::jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists document_processing_jobs_document_idx
on public.document_processing_jobs(document_id, created_at desc);

create index if not exists document_processing_jobs_status_idx
on public.document_processing_jobs(status, created_at)
where status in ('queued', 'processing');

create trigger document_processing_jobs_set_updated_at
before update on public.document_processing_jobs
for each row execute function public.set_updated_at();

create table if not exists public.immigration_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  agency public.agency_code not null,
  receipt_number text,
  eoir_case_identifier_ciphertext bytea,
  form_code text,
  status text not null default 'unknown',
  status_source text not null default 'manual',
  last_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint immigration_cases_identifier_check
    check (receipt_number is not null or eoir_case_identifier_ciphertext is not null)
);

create index if not exists immigration_cases_user_agency_idx
on public.immigration_cases(user_id, agency);

create index if not exists immigration_cases_receipt_idx
on public.immigration_cases(receipt_number)
where receipt_number is not null;

create trigger immigration_cases_set_updated_at
before update on public.immigration_cases
for each row execute function public.set_updated_at();

create table if not exists public.case_status_snapshots (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.immigration_cases(id) on delete cascade,
  status text not null,
  source text not null,
  raw_payload jsonb not null default '{}'::jsonb,
  checked_at timestamptz not null default now()
);

create index if not exists case_status_snapshots_case_checked_idx
on public.case_status_snapshots(case_id, checked_at desc);

create table if not exists public.critical_dates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  case_id uuid references public.immigration_cases(id) on delete set null,
  document_id uuid references public.user_documents(id) on delete set null,
  kind text not null,
  title text not null,
  details text,
  due_at timestamptz not null,
  severity public.severity not null default 'yellow',
  source text not null default 'user',
  acknowledged_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists critical_dates_user_due_idx
on public.critical_dates(user_id, due_at asc);

create index if not exists critical_dates_unacked_idx
on public.critical_dates(user_id, severity, due_at)
where acknowledged_at is null;

create trigger critical_dates_set_updated_at
before update on public.critical_dates
for each row execute function public.set_updated_at();

create table if not exists public.form_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  case_id uuid references public.immigration_cases(id) on delete set null,
  form_edition_id uuid not null references public.form_editions(id),
  status public.workflow_status not null default 'draft',
  language text not null default 'es',
  current_step text,
  profile_snapshot jsonb not null default '{}'::jsonb,
  source_document_ids uuid[] not null default array[]::uuid[],
  missing_fields text[] not null default array[]::text[],
  validation_result jsonb not null default '{}'::jsonb,
  legal_review_required public.review_requirement not null default 'none',
  user_confirmed_truthful_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists form_sessions_user_status_idx
on public.form_sessions(user_id, status, updated_at desc);

create index if not exists form_sessions_form_edition_idx
on public.form_sessions(form_edition_id);

create trigger form_sessions_set_updated_at
before update on public.form_sessions
for each row execute function public.set_updated_at();

create table if not exists public.form_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.form_sessions(id) on delete cascade,
  question_key text not null,
  answer jsonb not null,
  source text not null default 'user',
  confidence numeric(4,3),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, question_key)
);

create index if not exists form_answers_session_idx
on public.form_answers(session_id);

create trigger form_answers_set_updated_at
before update on public.form_answers
for each row execute function public.set_updated_at();

create table if not exists public.generated_packets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null references public.form_sessions(id) on delete cascade,
  storage_bucket text not null default 'generated-packets',
  storage_path text not null,
  packet_type text not null default 'pdf',
  checksum_sha256 text,
  page_count int,
  signature_required boolean not null default true,
  generated_by text not null default 'system',
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

create index if not exists generated_packets_user_created_idx
on public.generated_packets(user_id, created_at desc);

create index if not exists generated_packets_session_idx
on public.generated_packets(session_id);

create table if not exists public.legal_review_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid references public.form_sessions(id) on delete set null,
  case_id uuid references public.immigration_cases(id) on delete set null,
  topic text not null,
  urgency public.severity not null default 'yellow',
  status text not null default 'new',
  assigned_to uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_review_requests_user_created_idx
on public.legal_review_requests(user_id, created_at desc);

create index if not exists legal_review_requests_status_idx
on public.legal_review_requests(status, created_at desc);

create trigger legal_review_requests_set_updated_at
before update on public.legal_review_requests
for each row execute function public.set_updated_at();

create table if not exists public.premium_services (
  id uuid primary key default gen_random_uuid(),
  service_type public.premium_service_type not null unique,
  title text not null,
  description text not null,
  price_mode text not null check (price_mode in ('free', 'one_time', 'annual', 'manual_quote')),
  stripe_price_id text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger premium_services_set_updated_at
before update on public.premium_services
for each row execute function public.set_updated_at();

create table if not exists public.premium_service_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  service_id uuid not null references public.premium_services(id),
  case_id uuid references public.immigration_cases(id) on delete set null,
  status text not null default 'requested',
  amount_cents int,
  currency char(3) not null default 'USD',
  stripe_checkout_session_id text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists premium_service_requests_user_created_idx
on public.premium_service_requests(user_id, created_at desc);

create index if not exists premium_service_requests_status_idx
on public.premium_service_requests(status, created_at desc);

create trigger premium_service_requests_set_updated_at
before update on public.premium_service_requests
for each row execute function public.set_updated_at();

create table if not exists public.dmv_question_sets (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null references public.us_states(code),
  language text not null default 'es',
  source_id uuid references public.official_sources(id),
  version_label text not null,
  active boolean not null default false,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (state_code, language, version_label)
);

create trigger dmv_question_sets_set_updated_at
before update on public.dmv_question_sets
for each row execute function public.set_updated_at();

create table if not exists public.dmv_questions (
  id uuid primary key default gen_random_uuid(),
  question_set_id uuid not null references public.dmv_question_sets(id) on delete cascade,
  prompt text not null,
  options jsonb not null,
  correct_option_key text not null,
  explanation text,
  topic text,
  created_at timestamptz not null default now()
);

create index if not exists dmv_questions_set_topic_idx
on public.dmv_questions(question_set_id, topic);

create table if not exists public.local_resources (
  id uuid primary key default gen_random_uuid(),
  state_code char(2) not null references public.us_states(code),
  city text,
  category text not null,
  name text not null,
  phone text,
  website text,
  address jsonb not null default '{}'::jsonb,
  languages text[] not null default array['es'],
  source_id uuid references public.official_sources(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists local_resources_state_category_idx
on public.local_resources(state_code, category);

create trigger local_resources_set_updated_at
before update on public.local_resources
for each row execute function public.set_updated_at();

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists push_subscriptions_user_active_idx
on public.push_subscriptions(user_id, created_at desc)
where revoked_at is null;

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  ip_address inet,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_events_user_created_idx
on public.audit_events(user_id, created_at desc);

create index if not exists audit_events_entity_idx
on public.audit_events(entity_type, entity_id);

-- Foreign-key helper indexes for planner health at scale.
create index if not exists audit_events_actor_id_idx
on public.audit_events(actor_id);

create index if not exists critical_dates_case_id_idx
on public.critical_dates(case_id);

create index if not exists critical_dates_document_id_idx
on public.critical_dates(document_id);

create index if not exists dmv_question_sets_source_id_idx
on public.dmv_question_sets(source_id);

create index if not exists evidence_requirements_source_id_idx
on public.evidence_requirements(source_id);

create index if not exists fee_rules_source_id_idx
on public.fee_rules(source_id);

create index if not exists filing_destinations_source_id_idx
on public.filing_destinations(source_id);

create index if not exists filing_destinations_state_code_idx
on public.filing_destinations(state_code);

create index if not exists form_definitions_official_page_source_id_idx
on public.form_definitions(official_page_source_id);

create index if not exists form_editions_instructions_source_id_idx
on public.form_editions(instructions_source_id);

create index if not exists form_editions_official_pdf_source_id_idx
on public.form_editions(official_pdf_source_id);

create index if not exists form_rules_source_id_idx
on public.form_rules(source_id);

create index if not exists form_rules_state_code_idx
on public.form_rules(state_code);

create index if not exists form_sessions_case_id_idx
on public.form_sessions(case_id);

create index if not exists legal_review_requests_assigned_to_idx
on public.legal_review_requests(assigned_to);

create index if not exists legal_review_requests_case_id_idx
on public.legal_review_requests(case_id);

create index if not exists legal_review_requests_session_id_idx
on public.legal_review_requests(session_id);

create index if not exists local_resources_source_id_idx
on public.local_resources(source_id);

create index if not exists premium_service_requests_case_id_idx
on public.premium_service_requests(case_id);

create index if not exists premium_service_requests_service_id_idx
on public.premium_service_requests(service_id);

-- Storage buckets are private. Files are stored under a user-id first path segment:
-- user-documents/{user_id}/...
-- generated-packets/{user_id}/...
-- official-templates/{form_code}/...
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('user-documents', 'user-documents', false, 52428800, array['application/pdf', 'image/png', 'image/jpeg']),
  ('generated-packets', 'generated-packets', false, 52428800, array['application/pdf']),
  ('official-templates', 'official-templates', false, 52428800, array['application/pdf'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Enable RLS.
alter table public.profiles enable row level security;
alter table public.official_sources enable row level security;
alter table public.us_states enable row level security;
alter table public.form_definitions enable row level security;
alter table public.form_editions enable row level security;
alter table public.form_questions enable row level security;
alter table public.form_rules enable row level security;
alter table public.evidence_requirements enable row level security;
alter table public.filing_destinations enable row level security;
alter table public.fee_rules enable row level security;
alter table public.user_documents enable row level security;
alter table public.document_processing_jobs enable row level security;
alter table public.immigration_cases enable row level security;
alter table public.case_status_snapshots enable row level security;
alter table public.critical_dates enable row level security;
alter table public.form_sessions enable row level security;
alter table public.form_answers enable row level security;
alter table public.generated_packets enable row level security;
alter table public.legal_review_requests enable row level security;
alter table public.premium_services enable row level security;
alter table public.premium_service_requests enable row level security;
alter table public.dmv_question_sets enable row level security;
alter table public.dmv_questions enable row level security;
alter table public.local_resources enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.audit_events enable row level security;

-- Profiles.
drop policy if exists "profiles_select_own_or_staff" on public.profiles;
create policy "profiles_select_own_or_staff"
on public.profiles for select
using (id = (select auth.uid()) or private.is_staff());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (id = (select auth.uid()));

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin"
on public.profiles for update
using (id = (select auth.uid()) or private.is_admin())
with check (id = (select auth.uid()) or private.is_admin());

-- Public read catalogs; staff/admin maintain via authenticated tools or service role.
drop policy if exists "official_sources_read_authenticated" on public.official_sources;
create policy "official_sources_read_authenticated"
on public.official_sources for select
to authenticated
using (true);

drop policy if exists "official_sources_staff_write" on public.official_sources;
create policy "official_sources_staff_write"
on public.official_sources for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "us_states_read_authenticated" on public.us_states;
create policy "us_states_read_authenticated"
on public.us_states for select
to authenticated
using (true);

drop policy if exists "us_states_staff_write" on public.us_states;
create policy "us_states_staff_write"
on public.us_states for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "form_definitions_read_authenticated" on public.form_definitions;
create policy "form_definitions_read_authenticated"
on public.form_definitions for select
to authenticated
using (enabled = true or private.is_staff());

drop policy if exists "form_definitions_staff_write" on public.form_definitions;
create policy "form_definitions_staff_write"
on public.form_definitions for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "form_editions_read_authenticated" on public.form_editions;
create policy "form_editions_read_authenticated"
on public.form_editions for select
to authenticated
using (status = 'active' or private.is_staff());

drop policy if exists "form_editions_staff_write" on public.form_editions;
create policy "form_editions_staff_write"
on public.form_editions for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "form_questions_read_authenticated" on public.form_questions;
create policy "form_questions_read_authenticated"
on public.form_questions for select
to authenticated
using (
  exists (
    select 1
    from public.form_editions fe
    where fe.id = form_questions.form_edition_id
      and (fe.status = 'active' or private.is_staff())
  )
);

drop policy if exists "form_questions_staff_write" on public.form_questions;
create policy "form_questions_staff_write"
on public.form_questions for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "form_rules_read_authenticated" on public.form_rules;
create policy "form_rules_read_authenticated"
on public.form_rules for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "form_rules_staff_write" on public.form_rules;
create policy "form_rules_staff_write"
on public.form_rules for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "evidence_read_authenticated" on public.evidence_requirements;
create policy "evidence_read_authenticated"
on public.evidence_requirements for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "evidence_staff_write" on public.evidence_requirements;
create policy "evidence_staff_write"
on public.evidence_requirements for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "filing_destinations_read_authenticated" on public.filing_destinations;
create policy "filing_destinations_read_authenticated"
on public.filing_destinations for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "filing_destinations_staff_write" on public.filing_destinations;
create policy "filing_destinations_staff_write"
on public.filing_destinations for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "fee_rules_read_authenticated" on public.fee_rules;
create policy "fee_rules_read_authenticated"
on public.fee_rules for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "fee_rules_staff_write" on public.fee_rules;
create policy "fee_rules_staff_write"
on public.fee_rules for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

-- User-owned records.
drop policy if exists "user_documents_own_or_staff" on public.user_documents;
create policy "user_documents_own_or_staff"
on public.user_documents for all
to authenticated
using (user_id = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "document_processing_jobs_owner_or_staff" on public.document_processing_jobs;
create policy "document_processing_jobs_owner_or_staff"
on public.document_processing_jobs for select
to authenticated
using (
  private.is_staff()
  or exists (
    select 1 from public.user_documents d
    where d.id = document_processing_jobs.document_id
      and d.user_id = (select auth.uid())
  )
);

drop policy if exists "immigration_cases_own_or_staff" on public.immigration_cases;
create policy "immigration_cases_own_or_staff"
on public.immigration_cases for all
to authenticated
using (user_id = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "case_status_snapshots_owner_or_staff" on public.case_status_snapshots;
create policy "case_status_snapshots_owner_or_staff"
on public.case_status_snapshots for select
to authenticated
using (
  private.is_staff()
  or exists (
    select 1 from public.immigration_cases c
    where c.id = case_status_snapshots.case_id
      and c.user_id = (select auth.uid())
  )
);

drop policy if exists "critical_dates_own_or_staff" on public.critical_dates;
create policy "critical_dates_own_or_staff"
on public.critical_dates for all
to authenticated
using (user_id = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "form_sessions_own_or_staff" on public.form_sessions;
create policy "form_sessions_own_or_staff"
on public.form_sessions for all
to authenticated
using (user_id = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "form_answers_owner_or_staff" on public.form_answers;
create policy "form_answers_owner_or_staff"
on public.form_answers for all
to authenticated
using (
  private.is_staff()
  or exists (
    select 1 from public.form_sessions s
    where s.id = form_answers.session_id
      and s.user_id = (select auth.uid())
  )
)
with check (
  private.is_staff()
  or exists (
    select 1 from public.form_sessions s
    where s.id = form_answers.session_id
      and s.user_id = (select auth.uid())
  )
);

drop policy if exists "generated_packets_own_or_staff" on public.generated_packets;
create policy "generated_packets_own_or_staff"
on public.generated_packets for select
to authenticated
using (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "legal_review_requests_own_or_staff" on public.legal_review_requests;
create policy "legal_review_requests_own_or_staff"
on public.legal_review_requests for all
to authenticated
using (user_id = (select auth.uid()) or assigned_to = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "premium_services_read_authenticated" on public.premium_services;
create policy "premium_services_read_authenticated"
on public.premium_services for select
to authenticated
using (enabled = true or private.is_staff());

drop policy if exists "premium_services_staff_write" on public.premium_services;
create policy "premium_services_staff_write"
on public.premium_services for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "premium_service_requests_own_or_staff" on public.premium_service_requests;
create policy "premium_service_requests_own_or_staff"
on public.premium_service_requests for all
to authenticated
using (user_id = (select auth.uid()) or private.is_staff())
with check (user_id = (select auth.uid()) or private.is_staff());

drop policy if exists "dmv_question_sets_read_authenticated" on public.dmv_question_sets;
create policy "dmv_question_sets_read_authenticated"
on public.dmv_question_sets for select
to authenticated
using (active = true or private.is_staff());

drop policy if exists "dmv_question_sets_staff_write" on public.dmv_question_sets;
create policy "dmv_question_sets_staff_write"
on public.dmv_question_sets for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "dmv_questions_read_authenticated" on public.dmv_questions;
create policy "dmv_questions_read_authenticated"
on public.dmv_questions for select
to authenticated
using (
  exists (
    select 1 from public.dmv_question_sets qs
    where qs.id = dmv_questions.question_set_id
      and (qs.active = true or private.is_staff())
  )
);

drop policy if exists "dmv_questions_staff_write" on public.dmv_questions;
create policy "dmv_questions_staff_write"
on public.dmv_questions for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "local_resources_read_authenticated" on public.local_resources;
create policy "local_resources_read_authenticated"
on public.local_resources for select
to authenticated
using (true);

drop policy if exists "local_resources_staff_write" on public.local_resources;
create policy "local_resources_staff_write"
on public.local_resources for all
to authenticated
using (private.is_staff())
with check (private.is_staff());

drop policy if exists "push_subscriptions_own" on public.push_subscriptions;
create policy "push_subscriptions_own"
on public.push_subscriptions for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "audit_events_read_own_or_staff" on public.audit_events;
create policy "audit_events_read_own_or_staff"
on public.audit_events for select
to authenticated
using (user_id = (select auth.uid()) or actor_id = (select auth.uid()) or private.is_staff());

-- Storage RLS.
drop policy if exists "user_documents_storage_select_own" on storage.objects;
create policy "user_documents_storage_select_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'user-documents'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or private.is_staff())
);

drop policy if exists "user_documents_storage_insert_own" on storage.objects;
create policy "user_documents_storage_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'user-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "user_documents_storage_update_own" on storage.objects;
create policy "user_documents_storage_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'user-documents'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or private.is_staff())
)
with check (
  bucket_id = 'user-documents'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or private.is_staff())
);

drop policy if exists "generated_packets_storage_select_own" on storage.objects;
create policy "generated_packets_storage_select_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'generated-packets'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or private.is_staff())
);

drop policy if exists "official_templates_storage_staff" on storage.objects;
create policy "official_templates_storage_staff"
on storage.objects for all
to authenticated
using (bucket_id = 'official-templates' and private.is_staff())
with check (bucket_id = 'official-templates' and private.is_staff());

-- Initial official source registry. These are source pages, not copied legal content.
insert into public.official_sources (agency, authority, title, url, source_kind, jurisdiction, notes)
values
  ('USCIS', 'official', 'USCIS All Forms', 'https://www.uscis.gov/forms/forms', 'forms_index', 'US', 'Catalog entry for current USCIS form pages and editions.'),
  ('USCIS', 'official', 'USCIS Form AR-11', 'https://www.uscis.gov/ar-11', 'form_page', 'US', 'Official change of address form page.'),
  ('USCIS', 'official', 'USCIS Form I-765', 'https://www.uscis.gov/i-765', 'form_page', 'US', 'Official Application for Employment Authorization page.'),
  ('USCIS', 'official', 'Direct Filing Addresses for Form I-765', 'https://www.uscis.gov/i-765-addresses', 'filing_addresses', 'US', 'Official direct filing address source; rules vary by category and location.'),
  ('USCIS', 'official', 'USCIS Fee Schedule', 'https://www.uscis.gov/g-1055', 'fees', 'US', 'Official fee schedule source.'),
  ('USCIS', 'official_api', 'USCIS Developer Portal', 'https://developer.uscis.gov/', 'api_docs', 'US', 'Official USCIS API and production access documentation.'),
  ('EOIR', 'official', 'EOIR Forms', 'https://www.justice.gov/eoir/eoir-forms', 'forms_index', 'US', 'Official EOIR forms index.'),
  ('EOIR', 'official', 'EOIR Respondent Access', 'https://respondentaccess.eoir.justice.gov/en/', 'portal', 'US', 'Official respondent access portal.'),
  ('EOIR', 'official', 'EOIR Case Information', 'https://www.justice.gov/eoir/eoir-case-information', 'case_information', 'US', 'Official EOIR case information source.'),
  ('EOIR', 'official', 'Immigration Court Practice Manual', 'https://www.justice.gov/eoir/reference-materials/ic', 'practice_manual', 'US', 'Official EOIR reference materials for Immigration Court practice.'),
  ('CBP', 'official', 'CBP I-94', 'https://www.cbp.gov/I94', 'i94', 'US', 'Official CBP I-94 information page.'),
  ('CBP', 'official', 'I-94 Travel Records Portal', 'https://i94.cbp.dhs.gov/', 'portal', 'US', 'Official I-94 travel records portal.'),
  ('DMV', 'official', 'Utah Written Knowledge Test', 'https://dld.utah.gov/written-knowledge-test/', 'dmv_test', 'UT', 'Official Utah Driver License Division written knowledge test page.'),
  ('DMV', 'official', 'California Driver Handbook', 'https://www.dmv.ca.gov/portal/handbook/california-driver-handbook/', 'dmv_handbook', 'CA', 'Official California DMV handbook page.'),
  ('DMV', 'official', 'Texas Driver License Handbooks', 'https://www.dps.texas.gov/section/driver-license/driver-license-handbooks', 'dmv_handbook', 'TX', 'Official Texas DPS handbook page.'),
  ('DMV', 'official', 'Florida Driver Handbooks', 'https://www.flhsmv.gov/resources/handbooks-manuals/', 'dmv_handbook', 'FL', 'Official Florida FLHSMV handbook source.')
on conflict (url) do update
set agency = excluded.agency,
    authority = excluded.authority,
    title = excluded.title,
    source_kind = excluded.source_kind,
    jurisdiction = excluded.jurisdiction,
    checked_at = now(),
    notes = excluded.notes;

insert into public.us_states (code, name, dmv_supported, resources_supported, verified_at)
values
  ('UT', 'Utah', true, true, now()),
  ('CA', 'California', false, false, null),
  ('TX', 'Texas', false, false, null),
  ('FL', 'Florida', false, false, null),
  ('NY', 'New York', false, false, null)
on conflict (code) do update
set name = excluded.name,
    dmv_supported = excluded.dmv_supported,
    resources_supported = excluded.resources_supported,
    verified_at = excluded.verified_at;

insert into public.form_definitions (
  agency,
  form_code,
  title,
  description,
  federal,
  review_requirement,
  official_page_source_id
)
select 'USCIS', 'AR-11', 'Alien Change of Address Card', 'User-directed USCIS address change preparation and checklist.', true, 'none', s.id
from public.official_sources s
where s.url = 'https://www.uscis.gov/ar-11'
on conflict (agency, form_code) do update
set title = excluded.title,
    description = excluded.description,
    review_requirement = excluded.review_requirement,
    official_page_source_id = excluded.official_page_source_id;

insert into public.form_definitions (
  agency,
  form_code,
  title,
  description,
  federal,
  review_requirement,
  official_page_source_id
)
select 'USCIS', 'I-765', 'Application for Employment Authorization', 'User-directed employment authorization packet preparation.', true, 'recommended', s.id
from public.official_sources s
where s.url = 'https://www.uscis.gov/i-765'
on conflict (agency, form_code) do update
set title = excluded.title,
    description = excluded.description,
    review_requirement = excluded.review_requirement,
    official_page_source_id = excluded.official_page_source_id;

insert into public.form_definitions (
  agency,
  form_code,
  title,
  description,
  federal,
  review_requirement,
  official_page_source_id
)
select 'EOIR', 'EOIR-33', 'Change of Address or Contact Information', 'User-directed EOIR address/contact information preparation.', true, 'recommended', s.id
from public.official_sources s
where s.url = 'https://www.justice.gov/eoir/eoir-forms'
on conflict (agency, form_code) do update
set title = excluded.title,
    description = excluded.description,
    review_requirement = excluded.review_requirement,
    official_page_source_id = excluded.official_page_source_id;

insert into public.form_definitions (
  agency,
  form_code,
  title,
  description,
  federal,
  review_requirement,
  official_page_source_id
)
select 'EOIR', 'CHANGE_OF_VENUE', 'Motion to Change Venue Draft', 'Draft packet workflow for user review and required human review.', true, 'required', s.id
from public.official_sources s
where s.url = 'https://www.justice.gov/eoir/reference-materials/ic'
on conflict (agency, form_code) do update
set title = excluded.title,
    description = excluded.description,
    review_requirement = excluded.review_requirement,
    official_page_source_id = excluded.official_page_source_id;

insert into public.premium_services (service_type, title, description, price_mode, enabled)
values
  ('ANNUALITY_PAYMENT', 'Pago de anualidades', 'Prueba gratis: administra anualidades, comprobantes y recordatorios sin pago durante la etapa de validacion.', 'free', true),
  ('EXPERT_REVIEW', 'Revision experta', 'Prueba gratis: crea una solicitud de revision experta para validar el flujo operativo.', 'free', true),
  ('SPECIAL_CASE_TRACKING', 'Seguimiento especial', 'Prueba gratis: activa el seguimiento especial para probar el dashboard de casos contratados.', 'free', true)
on conflict (service_type) do update
set title = excluded.title,
    description = excluded.description,
    price_mode = excluded.price_mode,
    enabled = excluded.enabled;
