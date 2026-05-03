# Supabase Production Plan

Target project: `AppUsalatino` (`bzedgcxopndnvnescoky`).

## Part 1: Production Data Foundation

Local migration updated:

- `supabase/migrations/202605020001_production_core.sql`

It adds:

- Auth-linked `profiles`.
- Official source registry.
- Form catalog, editions, questions, field maps, rules, fees, evidence, filing destinations.
- Secure document metadata and OCR job tracking.
- Case tracker and critical dates.
- Form sessions, answers, generated packets.
- Legal review queue.
- Premium services including annuality payments.
- DMV and local resource modules.
- Audit events.
- Private storage buckets.
- Row Level Security policies.
- Private role helpers in the non-exposed `private` schema.
- `citext` installed in the `extensions` schema.
- Foreign-key helper indexes for high-volume joins and deletes.

## Applied to Supabase

Project `AppUsalatino` has the production foundation applied in Supabase:

- `production_foundation_core`
- `production_rls_policies`
- `production_replace_rls_with_private_helpers`
- `production_fk_indexes`
- `production_move_citext_extension`
- `ar11_form_engine`

Verification as of May 2, 2026:

- 26 public application tables.
- 3 private storage buckets: `user-documents`, `generated-packets`, `official-templates`.
- 4 initial form definitions: AR-11, I-765, EOIR-33, Change of Venue.
- 19 official source registry records.
- AR-11 active edition `11/02/22` with 29 questions, 29 verified PDF field mappings, 4 rules, 3 evidence requirements, 1 filing destination rule, and 1 fee schedule reference.
- Supabase security advisors: 0 active lints.
- Performance advisors only report unused indexes because the database has no production traffic yet.

## PWA Connection

The web app now includes:

- Supabase browser client using `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
- Passwordless email login with Supabase Auth.
- Live dashboard data loader for `profiles`, `critical_dates`, `user_documents`, `immigration_cases`, `form_definitions`, and `premium_services`.
- RLS-compatible profile bootstrap after first login.
- Local preview fallback when Supabase environment variables are missing.
- Web env template at `apps/web/.env.example`; local development uses ignored `apps/web/.env.local`.
- Automation action wiring for form-session creation and answer saving through Edge Functions.
- PDF packet generation from the AR-11 wizard, including signed private Storage download links.
- Free testing service request wiring for annualities and expert review. Stripe is intentionally paused until the core flow is validated.

## Edge Functions

Supabase Edge Functions deployed to `AppUsalatino`:

- `create-form-session`: creates a user-owned session for the active official form edition and returns questions.
- `save-form-answer`: saves one answer, recalculates missing fields, and triggers required review for protected AR-11 cases.
- `generate-pdf-packet`: fills a reviewed official PDF template, fetches/caches the official PDF source when Storage does not have it yet, and writes the generated packet.
- `classify-document`: rules-based first-pass classification for USCIS, EOIR, and CBP documents.
- `uscis-case-status`: calls the official USCIS API only when production credentials are configured.
- `create-checkout-session`: temporary compatibility endpoint that creates free testing service requests; it does not call Stripe in this phase.
- `stripe-webhook`: deployed but not used while paid flows are paused.

All user-facing functions require JWT verification. `stripe-webhook` disables JWT by design because Stripe does not send Supabase user JWTs; it will matter again when paid flows are re-enabled.

Important: AR-11 is now activated only for audited AcroForm fields from the official USCIS PDF. Apt/suite/floor selectors are mapped to real PDF checkboxes. Signature fields remain manual; the app does not prefill a typed signature.

## Supabase Security Model

- User-owned rows use `user_id = auth.uid()`.
- Staff/admin access is controlled through `profiles.role`.
- Storage paths use the first folder segment as the owner id:
  - `user-documents/{user_id}/...`
  - `generated-packets/{user_id}/...`
- Official templates are private and staff-managed.
- Generated packets are written by Edge Functions/service role, then read by the owning user.

## Next Parts

1. Configure production secrets after the free flow is validated:
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `USCIS_CLIENT_ID`
   - `USCIS_CLIENT_SECRET`
2. Re-enable Stripe only after the free AR-11/document/case flow is stable.
3. Add final review checklist for AR-11.
4. Add EOIR-33, I-765, and Change of Venue in that order.
5. Add push notifications for critical dates.

## Non-Negotiable Controls

- Every production rule must reference an official source.
- Current form editions must be reviewed before activation.
- Change of Venue and complex cases require human review.
- USCIS and future Stripe secrets live only in Supabase secrets or deployment vaults.
- No USCIS/EOIR passwords are collected.
