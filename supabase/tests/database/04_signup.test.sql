-- Signup flow: profile completion, date-of-birth lock, terms, parental consent
-- (parent OTP), limits, withdrawal and turning 18.
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures (as postgres)
-- ---------------------------------------------------------------------------
-- a: minor, b: adult, c: minor sibling of a, d: minor for limits, s: super admin
insert into auth.users (id, aud, role, phone) values
  ('aaaaaaaa-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '919999900001'),
  ('bbbbbbbb-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '919999900002'),
  ('cccccccc-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '919999900003'),
  ('dddddddd-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '919999900004'),
  ('eeeeeeee-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '919999900005');
insert into public.staff_roles (user_id, role) values ('eeeeeeee-1111-1111-1111-111111111111', 'super_admin');

-- Everything below runs as the API does.
set local role service_role;

create temporary table t (k text primary key, v text) on commit drop;
insert into t values ('year', extract(year from current_date)::text);

-- ---------------------------------------------------------------------------
-- Profile completion
-- ---------------------------------------------------------------------------
select is(private.signup_status('aaaaaaaa-1111-1111-1111-111111111111'), 'needs_profile',
  'a new user needs to complete their profile');
select is(private.signup_status('00000000-0000-0000-0000-000000000000'), null::text,
  'status is null for an unknown user');

select throws_ok(
  format($$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', 'Asha',
            (current_date - interval '12 years')::date, %s::smallint) $$, (select v from t where k = 'year')),
  'P0001', 'age_out_of_range', 'age 12 is rejected');
select throws_ok(
  format($$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', 'Asha',
            (current_date - interval '31 years')::date, %s::smallint) $$, (select v from t where k = 'year')),
  'P0001', 'age_out_of_range', 'age 31 is rejected');
select throws_ok(
  $$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', 'Asha',
       (current_date - interval '16 years')::date, 2020::smallint) $$,
  'P0001', 'target_exam_year_invalid', 'a past target exam year is rejected');
select throws_ok(
  format($$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', '  ',
            (current_date - interval '16 years')::date, %s::smallint) $$, (select v from t where k = 'year')),
  'P0001', 'full_name_invalid', 'a blank name is rejected');
select throws_ok(
  format($$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', 'Asha',
            (current_date - interval '16 years')::date, %s::smallint, 'vip') $$, (select v from t where k = 'year')),
  'P0001', 'category_invalid', 'an unknown category is rejected');
select is(private.signup_status('aaaaaaaa-1111-1111-1111-111111111111'), 'needs_profile',
  'rejected profiles change nothing');

select is(
  public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', ' Asha ',
    (current_date - interval '16 years')::date, (select v from t where k = 'year')::smallint, null, 'kn'),
  'needs_terms', 'a complete profile moves on to terms (category optional)');
select is(
  (select full_name || '/' || preferred_language from public.profiles where id = 'aaaaaaaa-1111-1111-1111-111111111111'),
  'Asha/kn', 'profile fields are saved, name trimmed');

select is(
  public.complete_profile('bbbbbbbb-1111-1111-1111-111111111111', 'Bharat',
    (current_date - interval '20 years')::date, (select v from t where k = 'year')::smallint, 'obc_ncl'),
  'needs_terms', 'adult profile completed');
select is(
  public.complete_profile('cccccccc-1111-1111-1111-111111111111', 'Chitra',
    (current_date - interval '14 years')::date, ((select v from t where k = 'year')::int + 3)::smallint),
  'needs_terms', 'sibling profile completed');
select is(
  public.complete_profile('dddddddd-1111-1111-1111-111111111111', 'Deepa',
    (current_date - interval '17 years')::date, (select v from t where k = 'year')::smallint),
  'needs_terms', 'fourth profile completed');

-- ---------------------------------------------------------------------------
-- Date of birth is set once
-- ---------------------------------------------------------------------------
select lives_ok(
  format($$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', 'Asha K',
            (current_date - interval '16 years')::date, %s::smallint) $$, (select v from t where k = 'year')),
  'resubmitting the same date of birth is allowed');
select throws_ok(
  format($$ select public.complete_profile('aaaaaaaa-1111-1111-1111-111111111111', 'Asha',
            (current_date - interval '19 years')::date, %s::smallint) $$, (select v from t where k = 'year')),
  'P0001', 'dob_already_set', 'the date of birth cannot be changed through the profile');
select throws_ok(
  $$ update public.profiles set date_of_birth = current_date - interval '19 years'
     where id = 'aaaaaaaa-1111-1111-1111-111111111111' $$,
  'P0001', 'dob_already_set', 'not even the service role can change it directly');
select throws_ok(
  $$ update public.profiles set date_of_birth = null where id = 'aaaaaaaa-1111-1111-1111-111111111111' $$,
  'P0001', 'dob_already_set', 'nor clear it');

select throws_ok(
  $$ select public.correct_date_of_birth('bbbbbbbb-1111-1111-1111-111111111111',
       'aaaaaaaa-1111-1111-1111-111111111111', '2000-01-01', 'typo') $$,
  'P0001', 'not_authorised', 'only a super admin can correct a date of birth');
select throws_ok(
  $$ select public.correct_date_of_birth('eeeeeeee-1111-1111-1111-111111111111',
       'aaaaaaaa-1111-1111-1111-111111111111', '2000-01-01', ' ') $$,
  'P0001', 'reason_required', 'a correction needs a reason');
select lives_ok(
  $$ select public.correct_date_of_birth('eeeeeeee-1111-1111-1111-111111111111',
       'dddddddd-1111-1111-1111-111111111111', (current_date - interval '16 years')::date, 'Birth certificate') $$,
  'a super admin corrects a date of birth');
select is(
  (select date_of_birth from public.profiles where id = 'dddddddd-1111-1111-1111-111111111111'),
  (current_date - interval '16 years')::date, 'the correction is saved');
select is(
  (select count(*)::int from public.audit_log
   where action = 'profile.date_of_birth.corrected' and target_id = 'dddddddd-1111-1111-1111-111111111111'
     and actor_id = 'eeeeeeee-1111-1111-1111-111111111111' and details ->> 'reason' = 'Birth certificate'
     and details ? 'old' and details ? 'new'),
  1, 'the correction is audited with old value, new value and reason');
select throws_ok(
  $$ update public.profiles set date_of_birth = current_date - interval '15 years'
     where id = 'dddddddd-1111-1111-1111-111111111111' $$,
  'P0001', 'dob_already_set', 'the correction bypass does not outlive the correction');

-- ---------------------------------------------------------------------------
-- Terms
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select public.accept_terms('aaaaaaaa-1111-1111-1111-111111111111', '2000-old') $$,
  'P0001', 'policy_version_outdated', 'only the current terms version can be accepted');
select is(public.accept_terms('aaaaaaaa-1111-1111-1111-111111111111', '2026-10-draft'), 'needs_parental',
  'a minor who accepts terms needs parental consent');
select is(public.accept_terms('aaaaaaaa-1111-1111-1111-111111111111', '2026-10-draft'), 'needs_parental',
  'accepting again is a no-op');
select is(
  (select count(*)::int from public.consents
   where user_id = 'aaaaaaaa-1111-1111-1111-111111111111' and type = 'terms'
     and scope = (select scope from public.policy_versions where type = 'terms' and is_current)
     and method = 'in_app' and withdrawn_at is null),
  1, 'one terms consent with the policy scope');
select is(public.accept_terms('bbbbbbbb-1111-1111-1111-111111111111', '2026-10-draft'), 'complete',
  'an adult who accepts terms is complete');
select is(public.accept_terms('cccccccc-1111-1111-1111-111111111111', '2026-10-draft'), 'needs_parental',
  'sibling needs parental consent');
select is(public.accept_terms('dddddddd-1111-1111-1111-111111111111', '2026-10-draft'), 'needs_parental',
  'fourth user needs parental consent');

-- ---------------------------------------------------------------------------
-- Parental consent: start
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select public.start_parental_consent('bbbbbbbb-1111-1111-1111-111111111111', 'Parent', '919876500001', 'h') $$,
  'P0001', 'parental_consent_not_required', 'adults need no parental consent');
select throws_ok(
  $$ select public.start_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'Parent', '919999900001', 'h') $$,
  'P0001', 'parent_phone_is_student_phone', 'the student''s own number is rejected');
select throws_ok(
  $$ select public.start_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'Parent', '9876500001', 'h') $$,
  'P0001', 'parent_phone_invalid', 'numbers must be 91 + a 10-digit mobile number');
select throws_ok(
  $$ select public.start_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', '', '919876500001', 'h') $$,
  'P0001', 'parent_name_invalid', 'the parent''s name is required');

select ok(
  public.start_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'Ramesh', '919876500001', 'hash-1')
    ? 'request_id',
  'a code request is created');
select is(
  (select jsonb_build_object('name', r.parent_name, 'phone', r.parent_phone, 'left', r.attempts_left)
   from jsonb_to_record(public.get_signup_state('aaaaaaaa-1111-1111-1111-111111111111') -> 'pending_request')
     as r (parent_name text, parent_phone text, attempts_left int)),
  '{"name": "Ramesh", "phone": "919876500001", "left": 5}'::jsonb,
  'the signup state shows the pending request for the waiting screen');
select throws_ok(
  $$ select public.start_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'Ramesh', '919876500001', 'hash-2') $$,
  'P0001', 'resend_too_soon', 'a new code needs a 60 second wait');

-- ---------------------------------------------------------------------------
-- Parental consent: verify
-- ---------------------------------------------------------------------------
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'wrong'),
  '{"result": "invalid", "attempts_left": 4}'::jsonb, 'a wrong code uses an attempt');
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'wrong'),
  '{"result": "invalid", "attempts_left": 3}'::jsonb, 'attempts are saved');
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'wrong') ->> 'result', 'invalid', '3rd');
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'wrong') ->> 'result', 'invalid', '4th');
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'wrong'),
  '{"result": "locked"}'::jsonb, 'the 5th wrong attempt locks the code');
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'hash-1'),
  '{"result": "no_pending_request"}'::jsonb, 'a locked code cannot be used, even when right');
select is(
  (select code_hash from public.parental_consent_requests where user_id = 'aaaaaaaa-1111-1111-1111-111111111111'),
  null, 'the hash is cleared once the request is closed');

-- Pretend the 60 s wait has passed, then send a new code (to a changed number).
update public.parental_consent_requests set created_at = now() - interval '2 minutes'
where user_id = 'aaaaaaaa-1111-1111-1111-111111111111';
select lives_ok(
  $$ select public.start_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'Sunita', '919876500002', 'hash-3') $$,
  'a new code after the wait (changed number)');
select is(public.verify_parental_consent('aaaaaaaa-1111-1111-1111-111111111111', 'hash-3') ->> 'result',
  'verified', 'the right code records parental consent');
select is(private.signup_status('aaaaaaaa-1111-1111-1111-111111111111'), 'complete',
  'the minor is complete after parental consent');
select is(
  (select jsonb_build_object('name', c.granted_by_name, 'phone', c.granted_by_phone, 'method', c.method,
            'version', c.policy_version, 'scoped', c.scope = pv.scope, 'request', c.request_id = r.id,
            'hash_cleared', r.code_hash is null, 'status', r.status)
   from public.consents c
   join public.parental_consent_requests r on r.id = c.request_id
   join public.policy_versions pv on pv.type = 'parental' and pv.version = c.policy_version
   where c.user_id = 'aaaaaaaa-1111-1111-1111-111111111111' and c.type = 'parental'),
  '{"name": "Sunita", "phone": "919876500002", "method": "parent_otp", "version": "2026-10-draft",
    "scoped": true, "request": true, "hash_cleared": true, "status": "verified"}'::jsonb,
  'the consent records parent, method, version, scope and request; no code is kept');
select hasnt_column('public', 'parental_consent_requests', 'code', 'no column holds a raw code');

-- Siblings: the same parent number consents for a second child.
select lives_ok(
  $$ select public.start_parental_consent('cccccccc-1111-1111-1111-111111111111', 'Sunita', '919876500002', 'hash-4') $$,
  'one parent number may consent for more than one child');
select is(public.verify_parental_consent('cccccccc-1111-1111-1111-111111111111', 'hash-4') ->> 'result',
  'verified', 'sibling consent recorded');

-- Expiry
select lives_ok(
  $$ select public.start_parental_consent('dddddddd-1111-1111-1111-111111111111', 'Parent', '919876500003', 'hash-5') $$,
  'code sent for the fourth user');
update public.parental_consent_requests set expires_at = now() - interval '1 second'
where user_id = 'dddddddd-1111-1111-1111-111111111111' and status = 'pending';
select is(public.get_signup_state('dddddddd-1111-1111-1111-111111111111') -> 'pending_request', 'null'::jsonb,
  'an expired code is not shown as pending');
select is(public.verify_parental_consent('dddddddd-1111-1111-1111-111111111111', 'hash-5'),
  '{"result": "expired"}'::jsonb, 'an expired code is rejected');

-- ---------------------------------------------------------------------------
-- Daily limits
-- ---------------------------------------------------------------------------
-- Per user: 5 codes in 24 hours (1 real + 4 backdated past the wait).
update public.parental_consent_requests set created_at = now() - interval '2 hours'
where user_id = 'dddddddd-1111-1111-1111-111111111111';
insert into public.parental_consent_requests
  (user_id, parent_name, parent_phone, policy_version, scope, status, expires_at, created_at)
select 'dddddddd-1111-1111-1111-111111111111', 'Parent', '919876500003', '2026-10-draft', 'x', 'expired',
       now() - interval '1 hour', now() - make_interval(hours => 2 + g)
from generate_series(1, 4) g;
select throws_ok(
  $$ select public.start_parental_consent('dddddddd-1111-1111-1111-111111111111', 'Parent', '919876500004', 'h') $$,
  'P0001', 'daily_limit_reached', 'at most 5 codes per user per day');
update public.parental_consent_requests set created_at = now() - interval '25 hours'
where user_id = 'dddddddd-1111-1111-1111-111111111111';
select lives_ok(
  $$ select public.start_parental_consent('dddddddd-1111-1111-1111-111111111111', 'Parent', '919876500004', 'h') $$,
  'the user limit is a rolling 24 hours');

-- Per parent number: 5 codes in 24 hours, across children.
update public.parental_consent_requests set created_at = now() - interval '25 hours'
where user_id = 'dddddddd-1111-1111-1111-111111111111';
insert into public.parental_consent_requests
  (user_id, parent_name, parent_phone, policy_version, scope, status, expires_at, created_at)
select 'bbbbbbbb-1111-1111-1111-111111111111', 'Parent', '919876500005', '2026-10-draft', 'x', 'expired',
       now() - interval '1 hour', now() - make_interval(hours => g)
from generate_series(1, 5) g;
select throws_ok(
  $$ select public.start_parental_consent('dddddddd-1111-1111-1111-111111111111', 'Parent', '919876500005', 'h') $$,
  'P0001', 'parent_phone_daily_limit_reached', 'at most 5 codes per parent number per day');

-- ---------------------------------------------------------------------------
-- Turning 18: minor status is derived at the time of checking
-- ---------------------------------------------------------------------------
-- d has no parental consent; born exactly 16 years ago (see correction above).
select is(
  private.signup_status('dddddddd-1111-1111-1111-111111111111',
    ((current_date - interval '16 years') + interval '18 years' - interval '1 day')::date),
  'needs_parental', 'the day before the 18th birthday, parental consent is still required');
select is(
  private.signup_status('dddddddd-1111-1111-1111-111111111111',
    ((current_date - interval '16 years') + interval '18 years')::date),
  'complete', 'on the 18th birthday, parental consent is no longer required');

-- ---------------------------------------------------------------------------
-- Withdrawal
-- ---------------------------------------------------------------------------
select is(public.withdraw_consent('aaaaaaaa-1111-1111-1111-111111111111', 'parental'), 'needs_parental',
  'withdrawing parental consent blocks the minor again');
select is(
  (select count(*)::int from public.consents
   where user_id = 'aaaaaaaa-1111-1111-1111-111111111111' and type = 'parental' and withdrawn_at is not null),
  1, 'the withdrawn consent is kept and marked');
select throws_ok(
  $$ select public.withdraw_consent('aaaaaaaa-1111-1111-1111-111111111111', 'parental') $$,
  'P0001', 'no_active_consent', 'nothing left to withdraw');
select is(public.withdraw_consent('bbbbbbbb-1111-1111-1111-111111111111', 'terms'), 'needs_terms',
  'withdrawing terms blocks access');
select is(public.accept_terms('bbbbbbbb-1111-1111-1111-111111111111', '2026-10-draft'), 'complete',
  'terms can be accepted again after withdrawal');

-- ---------------------------------------------------------------------------
-- A new terms version requires acceptance again
-- ---------------------------------------------------------------------------
update public.policy_versions set is_current = false where type = 'terms';
insert into public.policy_versions (type, version, scope, is_current) values ('terms', '2027-01', 'New scope', true);
select is(private.signup_status('bbbbbbbb-1111-1111-1111-111111111111'), 'needs_terms',
  'a new terms version sends students back to the terms step');
select is(public.get_signup_state('bbbbbbbb-1111-1111-1111-111111111111') ->> 'terms_version', '2027-01',
  'the signup state carries the current terms version');

reset role;
select * from finish();
rollback;
