-- Data API privileges: the exact grants each role has, independent of project
-- settings such as "Automatically expose new tables". A new table or view in
-- public fails here until it is added to the matrix below.
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Expected table privileges per role. Column-level grants (profiles update,
-- question_options select) are checked separately below.
create temporary table expected_privs (tbl text, role text, privs text[]) on commit drop;
insert into expected_privs values
  ('exams',            'anon',          '{SELECT}'),
  ('exams',            'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('exam_cycles',      'anon',          '{SELECT}'),
  ('exam_cycles',      'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('subjects',         'anon',          '{SELECT}'),
  ('subjects',         'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('chapters',         'anon',          '{SELECT}'),
  ('chapters',         'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('topics',           'anon',          '{SELECT}'),
  ('topics',           'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('questions',        'anon',          '{SELECT}'),
  ('questions',        'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('question_topics',  'anon',          '{SELECT}'),
  ('question_topics',  'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('question_options', 'anon',          '{}'),
  ('question_options', 'authenticated', '{INSERT,UPDATE,DELETE}'),
  ('profiles',         'anon',          '{}'),
  ('profiles',         'authenticated', '{SELECT}'),
  ('consents',         'anon',          '{}'),
  ('consents',         'authenticated', '{SELECT}'),
  ('staff_roles',      'anon',          '{}'),
  ('staff_roles',      'authenticated', '{SELECT,INSERT,UPDATE,DELETE}'),
  ('seo_questions',    'anon',          '{}'),
  ('seo_questions',    'authenticated', '{}'),
  ('seo_questions',    'service_role',  '{SELECT}'),
  ('policy_versions',  'anon',          '{SELECT}'),
  ('policy_versions',  'authenticated', '{SELECT}'),
  ('parental_consent_requests', 'anon',          '{}'),
  ('parental_consent_requests', 'authenticated', '{}'),
  ('audit_log',        'anon',          '{}'),
  ('audit_log',        'authenticated', '{SELECT}'),
  ('audit_log',        'service_role',  '{SELECT,INSERT}');
insert into expected_privs
select t, 'service_role', '{SELECT,INSERT,UPDATE,DELETE}'
from unnest(array['exams', 'exam_cycles', 'subjects', 'chapters', 'topics', 'questions', 'question_topics',
                  'question_options', 'profiles', 'consents', 'staff_roles', 'policy_versions',
                  'parental_consent_requests']) as t;

select is(
  (select array_agg(c.relname::text order by c.relname)
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p')),
  (select array_agg(distinct tbl order by tbl) from expected_privs),
  'every table and view in public has an entry in the privilege matrix');

select table_privs_are('public', tbl, role, privs,
  format('%s: %s has exactly %s', tbl, role, privs))
from expected_privs order by tbl, role;

-- Column-level grants
-- (Table-level INSERT/UPDATE also show up per column for authenticated.)
select column_privs_are('public', 'question_options', col, e.role, e.privs,
  format('question_options.%s readable by %s', col, e.role))
from unnest(array['id', 'question_id', 'label', 'content', 'content_plain', 'created_at', 'updated_at']) as col
cross join (values ('anon', '{SELECT}'::text[]), ('authenticated', '{SELECT,INSERT,UPDATE}'::text[])) as e (role, privs);
select column_privs_are('public', 'question_options', 'is_correct', r, '{INSERT,UPDATE}',
  format('question_options.is_correct is not readable by %s', r))
from unnest(array['authenticated']) as r;
select column_privs_are('public', 'question_options', 'is_correct', 'anon', '{}',
  'question_options.is_correct: anon has no privileges');
select column_privs_are('public', 'profiles', col, 'authenticated', '{SELECT,UPDATE}',
  format('profiles.%s editable by its owner', col))
from unnest(array['full_name', 'preferred_language', 'target_exam_year', 'category', 'home_state']) as col;
select column_privs_are('public', 'profiles', col, 'authenticated', '{SELECT}',
  format('profiles.%s is read-only for clients', col))
from unnest(array['id', 'phone', 'date_of_birth']) as col;

-- RLS is on for every table in public
select is(
  (select array_agg(c.relname::text order by c.relname)
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  null,
  'row level security is enabled on every table in public');

-- Default privileges: new objects created by migrations get nothing for API roles
select is(
  (select array_agg(distinct format('%s %s %s', n.nspname, d.defaclobjtype, a.grantee::regrole))
   from pg_default_acl d
   join pg_namespace n on n.oid = d.defaclnamespace
   cross join lateral aclexplode(d.defaclacl) a
   where d.defaclrole = 'postgres'::regrole
     and n.nspname in ('public', 'private')
     and a.grantee in ('anon'::regrole, 'authenticated'::regrole, 'service_role'::regrole)),
  null,
  'default privileges grant nothing to anon, authenticated or service_role in public/private');

-- The SEO view behaves as intended for each role
set local role anon;
select throws_ok('select * from public.seo_questions', '42501', null, 'anon cannot read seo_questions');
reset role;
set local role authenticated;
select throws_ok('select * from public.seo_questions', '42501', null,
  'authenticated cannot read seo_questions');
reset role;
set local role service_role;
select lives_ok('select * from public.seo_questions', 'service role reads seo_questions');
select hasnt_column('public', 'seo_questions', 'is_correct', 'seo_questions exposes no answer key');
reset role;

-- Helper functions: only the roles whose policies or defaults need them
select function_privs_are('private', 'is_staff', array['text[]'], r, '{EXECUTE}',
  format('%s can execute private.is_staff', r))
from unnest(array['anon', 'authenticated', 'service_role']) as r;
select function_privs_are('private', 'generate_short_id', array[]::text[], 'anon', '{}',
  'anon cannot execute private.generate_short_id');
select function_privs_are('private', 'handle_auth_user_change', array[]::text[], r, '{}',
  format('%s cannot execute the auth trigger function', r))
from unnest(array['anon', 'authenticated']) as r;

-- Signup functions: only the API (service role) may call them
select function_privs_are('public', f.name, f.args, r, '{}',
  format('%s cannot execute public.%s', r, f.name))
from (values
  ('get_signup_state', array['uuid']),
  ('complete_profile', array['uuid', 'text', 'date', 'smallint', 'text', 'text']),
  ('accept_terms', array['uuid', 'text']),
  ('start_parental_consent', array['uuid', 'text', 'text', 'text']),
  ('verify_parental_consent', array['uuid', 'text']),
  ('withdraw_consent', array['uuid', 'text']),
  ('correct_date_of_birth', array['uuid', 'uuid', 'date', 'text'])
) as f (name, args)
cross join unnest(array['anon', 'authenticated']) as r;
select function_privs_are('public', f.name, f.args, 'service_role', '{EXECUTE}',
  format('service_role can execute public.%s', f.name))
from (values
  ('get_signup_state', array['uuid']),
  ('complete_profile', array['uuid', 'text', 'date', 'smallint', 'text', 'text']),
  ('accept_terms', array['uuid', 'text']),
  ('start_parental_consent', array['uuid', 'text', 'text', 'text']),
  ('verify_parental_consent', array['uuid', 'text']),
  ('withdraw_consent', array['uuid', 'text']),
  ('correct_date_of_birth', array['uuid', 'uuid', 'date', 'text'])
) as f (name, args);
select function_privs_are('private', 'signup_status', array['uuid', 'date'], r, '{}',
  format('%s cannot execute private.signup_status', r))
from unnest(array['anon', 'authenticated']) as r;

select * from finish();
rollback;
