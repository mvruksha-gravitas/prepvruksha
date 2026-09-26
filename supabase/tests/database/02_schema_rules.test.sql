-- Schema rules: triggers, derived values, constraints and seed data.
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, phone)
values ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', '910000000101');

select is(
  (select phone from public.profiles where id = '11111111-1111-1111-1111-111111111111'), '910000000101',
  'a profile is created with the phone for every new auth user');

update auth.users set phone = '910000000109' where id = '11111111-1111-1111-1111-111111111111';
select is(
  (select phone from public.profiles where id = '11111111-1111-1111-1111-111111111111'), '910000000109',
  'a phone change in auth is copied to the profile');

select is(private.is_minor('11111111-1111-1111-1111-111111111111'), null::boolean,
  'is_minor is null when the date of birth is unknown');

update public.profiles set date_of_birth = current_date - interval '17 years'
where id = '11111111-1111-1111-1111-111111111111';
select is(private.is_minor('11111111-1111-1111-1111-111111111111'), true, 'is_minor: 17 years old');

update public.profiles set date_of_birth = current_date - interval '18 years'
where id = '11111111-1111-1111-1111-111111111111';
select is(private.is_minor('11111111-1111-1111-1111-111111111111'), false, 'is_minor: 18th birthday today');

update public.profiles set date_of_birth = current_date - interval '18 years' + interval '1 day'
where id = '11111111-1111-1111-1111-111111111111';
select is(private.is_minor('11111111-1111-1111-1111-111111111111'), true, 'is_minor: one day before turning 18');

select hasnt_column('public', 'profiles', 'is_minor', 'profiles has no stored is_minor column');

-- updated_at trigger (now() is fixed within a transaction, so backdate first)
update public.profiles set updated_at = '2000-01-01' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set full_name = 'Asha' where id = '11111111-1111-1111-1111-111111111111';
select ok(
  (select updated_at > '2000-01-01' from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'updated_at is set on update');

-- ---------------------------------------------------------------------------
-- Consents
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.consents (user_id, type, policy_version, method)
     values ('11111111-1111-1111-1111-111111111111', 'parental', '2026-09', 'parent_otp') $$,
  '23514', null, 'parental consent must name the parent and their phone');
select lives_ok(
  $$ insert into public.consents (user_id, type, policy_version, method, granted_by_name, granted_by_phone)
     values ('11111111-1111-1111-1111-111111111111', 'parental', '2026-09', 'parent_otp', 'Parent', '910000000110') $$,
  'parental consent with parent details is accepted');

-- ---------------------------------------------------------------------------
-- Questions
-- ---------------------------------------------------------------------------
create temporary table ctx on commit drop as
select e.id as exam_id,
       phy.id as phy_id,
       che.id as che_id,
       (select id from public.chapters where subject_id = phy.id and slug = 'laws-of-motion') as phy_chapter_id,
       (select id from public.chapters where subject_id = che.id and slug = 'solutions') as che_chapter_id
from public.exams e
join public.subjects phy on phy.exam_id = e.id and phy.code = 'PHY'
join public.subjects che on che.exam_id = e.id and che.code = 'CHE'
where e.code = 'NEET_UG';

select lives_ok(
  $$ insert into public.questions (exam_id, subject_id, format, stem, source_type)
     select exam_id, phy_id, 'single_mcq', 'Short id check', 'original' from ctx $$,
  'a draft question needs no options, slug or chapter');
select matches(
  (select short_id from public.questions where stem = 'Short id check'), '^[a-z2-9]{8}$',
  'short_id is generated: 8 url-safe characters');

select throws_ok(
  $$ insert into public.questions (exam_id, subject_id, chapter_id, format, stem, source_type)
     select exam_id, phy_id, che_chapter_id, 'single_mcq', 'Wrong chapter', 'original' from ctx $$,
  '23503', null, 'the chapter must belong to the question''s subject');
select throws_ok(
  $$ insert into public.questions (exam_id, subject_id, format, stem, source_type)
     select exam_id, phy_id, 'single_mcq', 'PYQ without year', 'pyq' from ctx $$,
  '23514', null, 'a previous-year question needs its year');
select throws_ok(
  $$ insert into public.questions (exam_id, subject_id, format, stem, source_type, status)
     select exam_id, phy_id, 'single_mcq', 'No slug', 'original', 'published' from ctx $$,
  '23514', null, 'a published question needs a slug and publish date');

-- Answer key checks run at commit; SET CONSTRAINTS IMMEDIATE forces them here.
select throws_ok(
  $$ do $x$
     declare qid uuid;
     begin
       insert into public.questions (exam_id, subject_id, format, stem, source_type, status, slug, published_at)
       select exam_id, phy_id, 'single_mcq', 'Two correct', 'original', 'published', 'two-correct', now()
       from ctx returning id into qid;
       insert into public.question_options (question_id, label, content, is_correct)
       select qid, l, 'Option ' || l, l in ('A', 'B') from unnest(array['A', 'B', 'C', 'D']) as l;
       set constraints all immediate;
     end $x$ $$,
  '23514', null, 'a published question cannot have two correct options');

select throws_ok(
  $$ do $x$
     declare qid uuid;
     begin
       insert into public.questions (exam_id, subject_id, format, stem, source_type, status, slug, published_at)
       select exam_id, phy_id, 'single_mcq', 'Three options', 'original', 'published', 'three-options', now()
       from ctx returning id into qid;
       insert into public.question_options (question_id, label, content, is_correct)
       select qid, l, 'Option ' || l, l = 'A' from unnest(array['A', 'B', 'C']) as l;
       set constraints all immediate;
     end $x$ $$,
  '23514', null, 'a published question needs four options');

select lives_ok(
  $$ do $x$
     declare qid uuid;
     begin
       insert into public.questions (exam_id, subject_id, format, stem, source_type, status, slug, published_at)
       select exam_id, phy_id, 'single_mcq', 'Valid published', 'original', 'published', 'valid-published', now()
       from ctx returning id into qid;
       insert into public.question_options (question_id, label, content, is_correct)
       select qid, l, 'Option ' || l, l = 'C' from unnest(array['A', 'B', 'C', 'D']) as l;
       set constraints all immediate;
     end $x$ $$,
  'a published question with four options and one correct is accepted');

select throws_ok(
  $$ do $x$
     begin
       update public.question_options o set is_correct = false
       from public.questions q
       where o.question_id = q.id and q.stem = 'Valid published';
       set constraints all immediate;
     end $x$ $$,
  '23514', null, 'the answer key of a published question cannot be removed');

-- ---------------------------------------------------------------------------
-- Syllabus seed
-- ---------------------------------------------------------------------------
select results_eq(
  $$ select s.code from public.subjects s join public.exams e on e.id = s.exam_id
     where e.code = 'NEET_UG' order by s.sort_order $$,
  $$ values ('PHY'), ('CHE'), ('BOT'), ('ZOO') $$,
  'NEET-UG has Physics, Chemistry, Botany and Zoology');
select ok((select count(*) from public.chapters where not is_removed) >= 80,
  'NEET-UG has its current chapters seeded');
select is((select count(*) from public.chapters where name_kn is null)::int, 0,
  'every seeded chapter has a drafted Kannada name');
select is((select count(*) from public.chapters where name_kn_reviewed)::int, 0,
  'no drafted Kannada name is marked reviewed');
select throws_ok(
  $$ update public.subjects set name_kn = null, name_kn_reviewed = true where code = 'PHY' $$,
  '23514', null, 'a Kannada name cannot be marked reviewed when it is empty');

select * from finish();
rollback;
