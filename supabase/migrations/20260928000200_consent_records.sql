-- Signup consent records (DPDP): policy versions, what each consent covers,
-- and the parent-OTP requests behind parental consent.

-- Policy versions ------------------------------------------------------------
-- The text a student (terms) or parent (parental) agrees to. One current
-- version per type; a new terms version makes students accept again.

create table public.policy_versions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('terms', 'parental')),
  version text not null check (char_length(version) between 1 and 40),
  -- Purpose of processing the consent covers; copied into each consent row.
  scope text not null check (char_length(scope) between 1 and 1000),
  document_url text,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (type, version)
);

create unique index policy_versions_one_current_idx
  on public.policy_versions (type) where is_current;

create trigger set_updated_at before update on public.policy_versions
  for each row execute function private.set_updated_at();

alter table public.policy_versions enable row level security;

create policy "policy_versions: everyone reads"
  on public.policy_versions for select
  to anon, authenticated
  using (true);

-- Managed by migrations/seed (later the console through the API).
grant select on public.policy_versions to anon, authenticated;
grant select, insert, update, delete on public.policy_versions to service_role;

-- Parental consent requests --------------------------------------------------
-- One row per code sent to a parent. Only a keyed hash of the code is stored,
-- never the code. Rows are kept after use as the evidence behind the consent
-- and to enforce the daily sending limits.

create table public.parental_consent_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  parent_name text not null check (char_length(parent_name) between 1 and 120),
  -- Digits with country code, no + (same format as profiles.phone).
  parent_phone text not null check (parent_phone ~ '^91[6-9][0-9]{9}$'),
  policy_version text not null,
  scope text not null,
  code_hash text,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'expired', 'locked', 'superseded', 'cancelled')),
  attempts smallint not null default 0 check (attempts >= 0),
  max_attempts smallint not null default 5 check (max_attempts > 0),
  expires_at timestamptz not null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pending_request_has_code check (status <> 'pending' or code_hash is not null)
);

comment on column public.parental_consent_requests.code_hash is
  'HMAC-SHA256 of the code, keyed with a secret held only by services/api. Cleared once the request is no longer pending.';

create index parental_consent_requests_user_idx
  on public.parental_consent_requests (user_id, created_at desc);
create index parental_consent_requests_phone_idx
  on public.parental_consent_requests (parent_phone, created_at desc);
create unique index parental_consent_requests_one_pending_idx
  on public.parental_consent_requests (user_id) where status = 'pending';

create trigger set_updated_at before update on public.parental_consent_requests
  for each row execute function private.set_updated_at();

-- No client access: only the API reads and writes these rows.
alter table public.parental_consent_requests enable row level security;
grant select, insert, update, delete on public.parental_consent_requests to service_role;

-- Consents: what was agreed to, and the evidence -----------------------------
-- No real consents exist yet (no real users before this slice); the
-- temporary default only fills NOT NULL for existing local test rows.

alter table public.consents
  add column scope text not null default 'unspecified' check (char_length(scope) between 1 and 1000),
  add column request_id uuid references public.parental_consent_requests (id) on delete restrict;
alter table public.consents alter column scope drop default;

alter table public.consents
  add constraint parent_otp_consent_has_request check (method <> 'parent_otp' or request_id is not null);

comment on column public.consents.scope is 'Purpose of processing consented to (from policy_versions.scope).';
comment on column public.consents.request_id is 'The parental_consent_requests row whose code was verified (parent_otp).';

-- At most one active consent per user, type and policy version.
create unique index consents_one_active_idx
  on public.consents (user_id, type, policy_version) where withdrawn_at is null;
