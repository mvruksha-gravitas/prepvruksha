-- Row Level Security: every role against every Week 1 table.
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures (as postgres, which bypasses RLS)
-- ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, phone) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '910000000101'),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', '910000000102'),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', '910000000103'),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', '910000000104'),
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', '910000000105');

insert into public.staff_roles (user_id, role) values
  ('33333333-3333-3333-3333-333333333333', 'reviewer'),
  ('44444444-4444-4444-4444-444444444444', 'content_admin'),
  ('55555555-5555-5555-5555-555555555555', 'super_admin');

insert into public.consents (user_id, type, policy_version, scope, method)
values ('11111111-1111-1111-1111-111111111111', 'terms', '2026-09', 'Test scope', 'in_app');

insert into public.topics (chapter_id, slug, name_en)
select c.id, 'newtons-third-law', 'Newton''s third law'
from public.chapters c join public.subjects s on s.id = c.subject_id
where s.code = 'PHY' and c.slug = 'laws-of-motion';

insert into public.sub_topics (topic_id, chapter_id, slug, name_en, expert_reviewed)
select t.id, t.chapter_id, 'action-reaction-pairs', 'Action-reaction pairs', true
from public.topics t where t.slug = 'newtons-third-law';

-- One public, one draft, one published-but-reserved question.
insert into public.questions
  (id, exam_id, subject_id, chapter_id, format, stem, source_type, status, slug, published_at, exam_reserved,
   sub_topic_id, difficulty, difficulty_source)
select v.id::uuid, e.id, s.id, c.id, 'single_mcq', v.stem, 'original', v.status, v.slug,
       case when v.status = 'published' then now() end, v.reserved,
       st.id, 'moderate', 'reviewer'
from (values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Public question', 'published', 'public-question', false),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'Draft question', 'draft', null, false),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Reserved question', 'published', 'reserved-question', true)
) as v (id, stem, status, slug, reserved)
cross join public.exams e
join public.subjects s on s.exam_id = e.id and s.code = 'PHY'
join public.chapters c on c.subject_id = s.id and c.slug = 'laws-of-motion'
join public.sub_topics st on st.chapter_id = c.id and st.slug = 'action-reaction-pairs'
where e.code = 'NEET_UG';

insert into public.question_options (question_id, label, content, is_correct)
select q.id::uuid, l.label, 'Option ' || l.label, l.label = 'B'
from (values ('aaaaaaaa-0000-0000-0000-000000000001'), ('aaaaaaaa-0000-0000-0000-000000000002'),
             ('aaaaaaaa-0000-0000-0000-000000000003')) as q (id)
cross join (values ('A'), ('B'), ('C'), ('D')) as l (label);


-- ---------------------------------------------------------------------------
-- Anonymous visitor
-- ---------------------------------------------------------------------------
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';

select ok((select count(*) from public.subjects) = 4, 'anon: reads subjects');
select ok((select count(*) from public.chapters) > 0, 'anon: reads chapters');
select results_eq(
  'select stem from public.questions',
  $$ values ('Public question') $$,
  'anon: sees only published, non-reserved questions'
);
select is(
  (select count(*) from public.question_options
   where question_id = 'aaaaaaaa-0000-0000-0000-000000000001')::int, 4,
  'anon: reads options of a public question (without is_correct)'
);
select is(
  (select count(*) from public.question_options
   where question_id in ('aaaaaaaa-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000003'))::int, 0,
  'anon: cannot read options of draft or reserved questions'
);
select is((select count(*)::int from public.sub_topics where slug = 'action-reaction-pairs'), 1,
  'anon: reads the sub-topic tree');
select throws_ok(
  $$ insert into public.sub_topics (topic_id, chapter_id, slug, name_en)
     select topic_id, chapter_id, 'x', 'X' from public.sub_topics limit 1 $$,
  '42501', null, 'anon: cannot add sub-topics');
select throws_ok('select is_correct from public.question_options', '42501', null,
  'anon: cannot read is_correct');
select throws_ok('select * from public.question_options', '42501', null,
  'anon: select * on options is refused because it includes is_correct');
select throws_ok('select * from public.profiles', '42501', null, 'anon: cannot read profiles');
select throws_ok('select * from public.consents', '42501', null, 'anon: cannot read consents');
select throws_ok('select * from public.staff_roles', '42501', null, 'anon: cannot read staff_roles');
select throws_ok(
  $$ insert into public.exams (code, slug, name_en) values ('KCET', 'kcet', 'KCET') $$,
  '42501', null, 'anon: cannot insert syllabus');
select throws_ok('select * from public.seo_questions', '42501', null,
  'anon: cannot read the SEO view');

reset role;

-- ---------------------------------------------------------------------------
-- Student 1
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq('select id from public.profiles',
  $$ values ('11111111-1111-1111-1111-111111111111'::uuid) $$,
  'student: reads only their own profile');
select lives_ok(
  $$ update public.profiles set full_name = 'Asha', preferred_language = 'kn'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  'student: updates their own name and language');
select throws_ok(
  $$ update public.profiles set phone = '919000000000' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'student: cannot change their phone');
select throws_ok(
  $$ update public.profiles set date_of_birth = '2000-01-01' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'student: cannot change their date of birth');
update public.profiles set full_name = 'Hacked' where id = '22222222-2222-2222-2222-222222222222';
select throws_ok(
  $$ insert into public.profiles (id) values ('33333333-3333-3333-3333-333333333333') $$,
  '42501', null, 'student: cannot insert profiles');
select throws_ok(
  $$ delete from public.profiles where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'student: cannot delete profiles');

select is((select count(*) from public.consents)::int, 1, 'student: reads their own consents');
select throws_ok(
  $$ insert into public.consents (user_id, type, policy_version, method)
     values ('11111111-1111-1111-1111-111111111111', 'marketing', '2026-09', 'in_app') $$,
  '42501', null, 'student: cannot record consents directly');

select is((select count(*) from public.staff_roles)::int, 0, 'student: holds no staff roles');
select throws_ok(
  $$ insert into public.staff_roles (user_id, role) values ('11111111-1111-1111-1111-111111111111', 'super_admin') $$,
  '42501', null, 'student: cannot grant themselves a staff role');

select results_eq('select stem from public.questions', $$ values ('Public question') $$,
  'student: sees only published, non-reserved questions');
select throws_ok('select is_correct from public.question_options', '42501', null,
  'student: cannot read is_correct');
select throws_ok(
  $$ insert into public.questions (exam_id, subject_id, format, stem, source_type)
     select exam_id, id, 'single_mcq', 'x', 'original' from public.subjects limit 1 $$,
  '42501', null, 'student: cannot insert questions');
select throws_ok(
  $$ insert into public.chapters (subject_id, slug, name_en)
     select id, 'new-chapter', 'New' from public.subjects limit 1 $$,
  '42501', null, 'student: cannot insert chapters');
update public.questions set stem = 'Changed' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
select throws_ok('select * from public.seo_questions', '42501', null,
  'student: cannot read the SEO view');

reset role;

select is(
  (select full_name from public.profiles where id = '22222222-2222-2222-2222-222222222222'), null,
  'student: update of another profile changed nothing');
select is(
  (select stem from public.questions where id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'Public question',
  'student: update of a question changed nothing');

-- ---------------------------------------------------------------------------
-- Reviewer
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is((select count(*) from public.questions)::int, 3, 'reviewer: sees all questions');
select is((select count(*) from public.question_options)::int, 12, 'reviewer: sees all options');
select throws_ok('select is_correct from public.question_options', '42501', null,
  'reviewer: cannot read is_correct from the client either');
select lives_ok(
  $$ insert into public.questions (exam_id, subject_id, format, stem, source_type)
     select exam_id, id, 'single_mcq', 'Reviewer draft', 'original' from public.subjects where code = 'CHE' $$,
  'reviewer: inserts a draft question');
select lives_ok(
  $$ update public.questions set stem = 'Draft question (edited)'
     where id = 'aaaaaaaa-0000-0000-0000-000000000002' $$,
  'reviewer: edits a question');
delete from public.questions where id = 'aaaaaaaa-0000-0000-0000-000000000002';
select throws_ok(
  $$ insert into public.subjects (exam_id, code, slug, name_en)
     select id, 'MAT', 'maths', 'Maths' from public.exams limit 1 $$,
  '42501', null, 'reviewer: cannot change the syllabus');
select is((select count(*) from public.profiles)::int, 1, 'reviewer: reads only their own profile');
select is((select count(*) from public.consents)::int, 0, 'reviewer: cannot read student consents');

reset role;

select is(
  (select count(*) from public.questions where id = 'aaaaaaaa-0000-0000-0000-000000000002')::int, 1,
  'reviewer: delete of a question changed nothing');

-- ---------------------------------------------------------------------------
-- Content admin
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select lives_ok(
  $$ insert into public.chapters (subject_id, slug, name_en)
     select id, 'test-chapter', 'Test chapter' from public.subjects where code = 'PHY' $$,
  'content admin: adds a chapter');
select lives_ok(
  $$ delete from public.questions where id = 'aaaaaaaa-0000-0000-0000-000000000002' $$,
  'content admin: deletes a question');
select is((select count(*) from public.staff_roles)::int, 1, 'content admin: sees only their own role');
select throws_ok(
  $$ insert into public.staff_roles (user_id, role) values ('11111111-1111-1111-1111-111111111111', 'reviewer') $$,
  '42501', null, 'content admin: cannot grant staff roles');

reset role;

select is(
  (select count(*) from public.questions where id = 'aaaaaaaa-0000-0000-0000-000000000002')::int, 0,
  'content admin: the delete took effect');

-- ---------------------------------------------------------------------------
-- Super admin
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}';

select is((select count(*) from public.consents)::int, 1, 'super admin: reads all consents');
select is((select count(*) from public.staff_roles)::int, 3, 'super admin: reads all staff roles');
select lives_ok(
  $$ insert into public.staff_roles (user_id, role, granted_by)
     values ('11111111-1111-1111-1111-111111111111', 'reviewer', '55555555-5555-5555-5555-555555555555') $$,
  'super admin: grants a staff role');
select throws_ok(
  $$ insert into public.consents (user_id, type, policy_version, method)
     values ('11111111-1111-1111-1111-111111111111', 'marketing', '2026-09', 'in_app') $$,
  '42501', null, 'super admin: consents are still written only by the API');

reset role;

-- ---------------------------------------------------------------------------
-- Service role (API, SEO build)
-- ---------------------------------------------------------------------------
set local role service_role;

select results_eq('select stem from public.seo_questions', $$ values ('Public question') $$,
  'service role: SEO view excludes drafts and exam-reserved questions');
select is(
  (select count(*) from public.question_options where is_correct)::int, 2,
  'service role: reads is_correct');

reset role;

select * from finish();
rollback;
