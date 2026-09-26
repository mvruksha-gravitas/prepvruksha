-- Profiles (one per auth user) and DPDP consents.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (char_length(full_name) between 1 and 120),
  phone text,
  preferred_language text not null default 'en' check (preferred_language in ('en', 'kn')),
  -- Minor status is derived from this (see private.is_minor); never stored.
  date_of_birth date check (date_of_birth >= date '1950-01-01'),
  target_exam_year smallint check (target_exam_year between 2025 and 2100),
  -- NEET reservation category; feeds the rank/college predictor later.
  category text check (category in ('general', 'ews', 'obc_ncl', 'sc', 'st')),
  home_state text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.profiles.phone is
  'Copied from auth.users.phone (digits, no +) by trigger. Not editable by the user.';
comment on column public.profiles.date_of_birth is
  'Set by the signup/consent flow through the API, not by the client.';

create trigger set_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- Create a profile for every new auth user, and keep the phone in sync.
create or replace function private.handle_auth_user_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.profiles (id, phone) values (new.id, new.phone)
    on conflict (id) do nothing;
  elsif new.phone is distinct from old.phone then
    update public.profiles set phone = new.phone where id = new.id;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_auth_user_change();

create trigger on_auth_user_phone_changed
  after update of phone on auth.users
  for each row execute function private.handle_auth_user_change();

-- Whether a user is under 18 today. Null when the date of birth is unknown;
-- callers must treat null as "ask for date of birth", never as "adult".
-- Security invoker: callers see only the profiles RLS allows them to see.
create or replace function private.is_minor(p_user_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p.date_of_birth > (current_date - interval '18 years')::date
  from public.profiles p
  where p.id = p_user_id;
$$;

alter table public.profiles enable row level security;

create policy "profiles: users read their own"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));

create policy "profiles: users update their own"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Rows are created by the trigger and removed with the auth user, so clients
-- get no insert/delete. Clients may update only these columns; id, phone and
-- date_of_birth are changed by triggers or the API.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name, preferred_language, target_exam_year, category, home_state)
  on public.profiles to authenticated;


create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null check (type in ('parental', 'terms', 'marketing')),
  -- Version of the policy text the consent was given against.
  policy_version text not null,
  granted_by_name text,
  granted_by_phone text,
  granted_at timestamptz not null default now(),
  method text not null check (method in ('parent_otp', 'in_app', 'offline_form')),
  -- DPDP: consent can be withdrawn; keep the record and mark it.
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint parental_consent_names_parent check (
    type <> 'parental' or (granted_by_name is not null and granted_by_phone is not null)
  ),
  constraint withdrawn_after_granted check (withdrawn_at is null or withdrawn_at >= granted_at)
);

create index consents_user_id_type_idx on public.consents (user_id, type);

create trigger set_updated_at before update on public.consents
  for each row execute function private.set_updated_at();

alter table public.consents enable row level security;

create policy "consents: users read their own, super admins read all"
  on public.consents for select
  to authenticated
  using (user_id = (select auth.uid()) or private.is_staff('super_admin'));

-- No client write policies: consents are recorded by the signup flow through
-- the API (service role).
revoke all on public.consents from anon, authenticated;
grant select on public.consents to authenticated;
