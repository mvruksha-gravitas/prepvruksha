-- Signup flow: profile completion, terms, parental consent (parent OTP) and
-- consent withdrawal.
--
-- The public.* functions below are called only by services/api with the
-- service role (PostgREST RPC), after it has verified the user's JWT; they
-- take the user id as an argument. They are not executable by app clients.
-- Errors are raised with SQLSTATE P0001 and a machine-readable message
-- (e.g. 'dob_already_set') that the API maps to a response.

-- Signup status -------------------------------------------------------------
-- Derived at the time of checking (p_as_of), never stored: parental consent
-- stops being required on the student's 18th birthday, and withdrawing a
-- consent sends the student back to the matching step.
--   needs_profile   name, date of birth or target exam year missing
--   needs_terms     no active consent to the current terms version
--   needs_parental  under 18 with no active parental consent
--   complete
-- Null when the profile does not exist.
-- Security invoker: callers see only the rows their grants and RLS allow.
create or replace function private.signup_status(p_user_id uuid, p_as_of date default current_date)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p.full_name is null or p.date_of_birth is null or p.target_exam_year is null
      then 'needs_profile'
    when not exists (
      select 1
      from public.consents c
      join public.policy_versions pv
        on pv.type = 'terms' and pv.is_current and pv.version = c.policy_version
      where c.user_id = p.id and c.type = 'terms' and c.withdrawn_at is null
    ) then 'needs_terms'
    when p.date_of_birth > (p_as_of - interval '18 years')::date
      and not exists (
        select 1 from public.consents c
        where c.user_id = p.id and c.type = 'parental' and c.withdrawn_at is null
      ) then 'needs_parental'
    else 'complete'
  end
  from public.profiles p
  where p.id = p_user_id;
$$;

-- Everything the app needs to route a signed-in user.
create or replace function public.get_signup_state(p_user_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_status text := private.signup_status(p_user_id);
  v_request public.parental_consent_requests;
begin
  if v_status is null then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;

  select * into v_request
  from public.parental_consent_requests
  where user_id = p_user_id and status = 'pending' and expires_at > now();

  return jsonb_build_object(
    'status', v_status,
    'is_minor', private.is_minor(p_user_id),
    'terms_version', (select version from public.policy_versions where type = 'terms' and is_current),
    'parental_version', (select version from public.policy_versions where type = 'parental' and is_current),
    'pending_request', case when v_request.id is null then null else jsonb_build_object(
      'id', v_request.id,
      'parent_name', v_request.parent_name,
      'parent_phone', v_request.parent_phone,
      'expires_at', v_request.expires_at,
      'attempts_left', v_request.max_attempts - v_request.attempts,
      'resend_available_at', v_request.created_at + interval '60 seconds'
    ) end
  );
end;
$$;

-- Profile completion ---------------------------------------------------------
-- Date of birth is set once (see private.guard_date_of_birth); sending the
-- same value again is allowed so the form can be resubmitted.
create or replace function public.complete_profile(
  p_user_id uuid,
  p_full_name text,
  p_date_of_birth date,
  p_target_exam_year smallint,
  p_category text default null,
  p_preferred_language text default null)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_name text := btrim(p_full_name);
  v_this_year int := extract(year from current_date)::int;
  v_old_dob date;
begin
  select date_of_birth into v_old_dob from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 120 then
    raise exception 'full_name_invalid' using errcode = 'P0001';
  end if;
  if p_date_of_birth is null then
    raise exception 'dob_required' using errcode = 'P0001';
  end if;
  if v_old_dob is not null and v_old_dob <> p_date_of_birth then
    raise exception 'dob_already_set' using errcode = 'P0001';
  end if;
  if p_target_exam_year is null or p_target_exam_year not between v_this_year and v_this_year + 3 then
    raise exception 'target_exam_year_invalid' using errcode = 'P0001';
  end if;
  if p_category is not null and p_category not in ('general', 'ews', 'obc_ncl', 'sc', 'st') then
    raise exception 'category_invalid' using errcode = 'P0001';
  end if;
  if p_preferred_language is not null and p_preferred_language not in ('en', 'kn') then
    raise exception 'language_invalid' using errcode = 'P0001';
  end if;

  -- The DOB trigger enforces the 13-30 age range on first set.
  update public.profiles
  set full_name = v_name,
      date_of_birth = p_date_of_birth,
      target_exam_year = p_target_exam_year,
      category = p_category,
      preferred_language = coalesce(p_preferred_language, preferred_language)
  where id = p_user_id;

  return private.signup_status(p_user_id);
end;
$$;

-- Terms ------------------------------------------------------------------------
create or replace function public.accept_terms(p_user_id uuid, p_policy_version text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_policy public.policy_versions;
begin
  select * into v_policy from public.policy_versions where type = 'terms' and is_current;
  if not found then
    raise exception 'policy_missing' using errcode = 'P0001';
  end if;
  if p_policy_version is distinct from v_policy.version then
    raise exception 'policy_version_outdated' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;

  insert into public.consents (user_id, type, policy_version, scope, method)
  values (p_user_id, 'terms', v_policy.version, v_policy.scope, 'in_app')
  on conflict (user_id, type, policy_version) where withdrawn_at is null do nothing;

  return private.signup_status(p_user_id);
end;
$$;

-- Parental consent: send a code to the parent ------------------------------------
-- The API generates the code, sends it by SMS after this returns, and passes
-- only its keyed hash here. Limits (each SMS costs money):
--   60 s between codes for a user; 5 codes per user and 5 per parent number
--   in any 24 hours (a parent may consent for siblings); codes expire after
--   10 minutes; 5 attempts per code.
-- A new code supersedes the user's pending one (resend or changed number).
create or replace function public.start_parental_consent(
  p_user_id uuid, p_parent_name text, p_parent_phone text, p_code_hash text)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  c_cooldown constant interval := interval '60 seconds';
  c_per_user_per_day constant int := 5;
  c_per_phone_per_day constant int := 5;
  c_expiry constant interval := interval '10 minutes';
  c_max_attempts constant smallint := 5;
  v_name text := btrim(p_parent_name);
  v_student_phone text;
  v_policy public.policy_versions;
  v_request public.parental_consent_requests;
begin
  -- Serialise per user and per parent number so the limits hold under
  -- concurrent requests. Always user first, then phone: no lock cycles.
  perform pg_advisory_xact_lock(hashtextextended('parental_consent_user:' || p_user_id::text, 0));

  if private.signup_status(p_user_id) is distinct from 'needs_parental' then
    raise exception 'parental_consent_not_required' using errcode = 'P0001';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 120 then
    raise exception 'parent_name_invalid' using errcode = 'P0001';
  end if;
  if p_parent_phone is null or p_parent_phone !~ '^91[6-9][0-9]{9}$' then
    raise exception 'parent_phone_invalid' using errcode = 'P0001';
  end if;
  if coalesce(p_code_hash, '') = '' then
    raise exception 'code_hash_required' using errcode = 'P0001';
  end if;

  select phone into v_student_phone from public.profiles where id = p_user_id;
  if v_student_phone = p_parent_phone then
    raise exception 'parent_phone_is_student_phone' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('parental_consent_phone:' || p_parent_phone, 0));

  if exists (
    select 1 from public.parental_consent_requests
    where user_id = p_user_id and created_at > now() - c_cooldown
  ) then
    raise exception 'resend_too_soon' using errcode = 'P0001';
  end if;
  if (select count(*) from public.parental_consent_requests
      where user_id = p_user_id and created_at > now() - interval '24 hours') >= c_per_user_per_day then
    raise exception 'daily_limit_reached' using errcode = 'P0001';
  end if;
  if (select count(*) from public.parental_consent_requests
      where parent_phone = p_parent_phone and created_at > now() - interval '24 hours') >= c_per_phone_per_day then
    raise exception 'parent_phone_daily_limit_reached' using errcode = 'P0001';
  end if;

  select * into v_policy from public.policy_versions where type = 'parental' and is_current;
  if not found then
    raise exception 'policy_missing' using errcode = 'P0001';
  end if;

  update public.parental_consent_requests
  set status = 'superseded', code_hash = null
  where user_id = p_user_id and status = 'pending';

  insert into public.parental_consent_requests
    (user_id, parent_name, parent_phone, policy_version, scope, code_hash, max_attempts, expires_at)
  values
    (p_user_id, v_name, p_parent_phone, v_policy.version, v_policy.scope, p_code_hash,
     c_max_attempts, now() + c_expiry)
  returning * into v_request;

  return jsonb_build_object(
    'request_id', v_request.id,
    'expires_at', v_request.expires_at,
    'resend_available_at', v_request.created_at + c_cooldown);
end;
$$;

-- Parental consent: check the code -------------------------------------------------
-- Returns a result instead of raising for a wrong code, so the attempt count
-- is saved:
--   {"result": "verified", "consent_id": ...}
--   {"result": "invalid", "attempts_left": n}
--   {"result": "locked" | "expired" | "no_pending_request" | "not_required"}
create or replace function public.verify_parental_consent(p_user_id uuid, p_code_hash text)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_request public.parental_consent_requests;
  v_consent_id uuid;
begin
  select * into v_request
  from public.parental_consent_requests
  where user_id = p_user_id and status = 'pending'
  for update;
  if not found then
    return jsonb_build_object('result', 'no_pending_request');
  end if;

  if v_request.expires_at <= now() then
    update public.parental_consent_requests set status = 'expired', code_hash = null
    where id = v_request.id;
    return jsonb_build_object('result', 'expired');
  end if;

  update public.parental_consent_requests set attempts = attempts + 1
  where id = v_request.id
  returning * into v_request;

  if p_code_hash is null or v_request.code_hash <> p_code_hash then
    if v_request.attempts >= v_request.max_attempts then
      update public.parental_consent_requests set status = 'locked', code_hash = null
      where id = v_request.id;
      return jsonb_build_object('result', 'locked');
    end if;
    return jsonb_build_object('result', 'invalid',
      'attempts_left', v_request.max_attempts - v_request.attempts);
  end if;

  -- Correct code, but consent may no longer be needed (turned 18, or already given).
  if private.signup_status(p_user_id) is distinct from 'needs_parental' then
    update public.parental_consent_requests set status = 'cancelled', code_hash = null
    where id = v_request.id;
    return jsonb_build_object('result', 'not_required');
  end if;

  insert into public.consents
    (user_id, type, policy_version, scope, granted_by_name, granted_by_phone, method, request_id)
  values
    (p_user_id, 'parental', v_request.policy_version, v_request.scope,
     v_request.parent_name, v_request.parent_phone, 'parent_otp', v_request.id)
  returning id into v_consent_id;

  update public.parental_consent_requests
  set status = 'verified', verified_at = now(), code_hash = null
  where id = v_request.id;

  return jsonb_build_object('result', 'verified', 'consent_id', v_consent_id);
end;
$$;

-- Withdrawal ------------------------------------------------------------------------
-- Marks the user's active consents of this type as withdrawn (the records are
-- kept). The signup status then blocks access until consent is given again.
create or replace function public.withdraw_consent(p_user_id uuid, p_type text)
returns text
language plpgsql
set search_path = ''
as $$
begin
  if p_type is null or p_type not in ('terms', 'parental') then
    raise exception 'consent_type_invalid' using errcode = 'P0001';
  end if;

  update public.consents set withdrawn_at = now()
  where user_id = p_user_id and type = p_type and withdrawn_at is null;
  if not found then
    raise exception 'no_active_consent' using errcode = 'P0001';
  end if;

  if p_type = 'parental' then
    update public.parental_consent_requests set status = 'cancelled', code_hash = null
    where user_id = p_user_id and status = 'pending';
  end if;

  return private.signup_status(p_user_id);
end;
$$;

-- Privileges -------------------------------------------------------------------------
revoke all on function private.signup_status(uuid, date) from public, anon, authenticated;
grant execute on function private.signup_status(uuid, date) to service_role;

revoke all on function
  public.get_signup_state(uuid),
  public.complete_profile(uuid, text, date, smallint, text, text),
  public.accept_terms(uuid, text),
  public.start_parental_consent(uuid, text, text, text),
  public.verify_parental_consent(uuid, text),
  public.withdraw_consent(uuid, text)
from public, anon, authenticated;

grant execute on function
  public.get_signup_state(uuid),
  public.complete_profile(uuid, text, date, smallint, text, text),
  public.accept_terms(uuid, text),
  public.start_parental_consent(uuid, text, text, text),
  public.verify_parental_consent(uuid, text),
  public.withdraw_consent(uuid, text)
to service_role;
