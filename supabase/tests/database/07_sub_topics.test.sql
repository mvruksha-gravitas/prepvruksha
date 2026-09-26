-- Sub-topics, difficulty and the publish guards.
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Commit-time checks run at once, so failures show inside this transaction.
set constraints all immediate;

-- ---------------------------------------------------------------------------
-- Fixtures: Physics / Laws of Motion and Work, Energy and Power
-- ---------------------------------------------------------------------------
insert into public.topics (chapter_id, slug, name_en, is_removed)
select c.id, v.slug, v.name, v.removed
from public.chapters c join public.subjects s on s.id = c.subject_id,
     (values ('newtons-laws', 'Newton''s laws', false), ('old-topic', 'Old topic', true)) as v (slug, name, removed)
where s.code = 'PHY' and c.slug = 'laws-of-motion';
insert into public.topics (chapter_id, slug, name_en)
select c.id, 'work', 'Work'
from public.chapters c join public.subjects s on s.id = c.subject_id
where s.code = 'PHY' and c.slug = 'work-energy-and-power';

insert into public.sub_topics (topic_id, chapter_id, slug, name_en, expert_reviewed, is_removed)
select t.id, t.chapter_id, v.slug, v.name, v.reviewed, v.removed
from public.topics t,
     (values ('newtons-laws', 'third-law', 'Third law', true, false),
             ('newtons-laws', 'draft-only', 'Draft only', false, false),
             ('old-topic', 'removed-bit', 'Removed bit', true, true),
             ('work', 'work-done', 'Work done', true, false)) as v (topic, slug, name, reviewed, removed)
where t.slug = v.topic;

-- ---------------------------------------------------------------------------
-- Seed: the Biology draft (supabase/seed/04_syllabus_biology.sql)
-- ---------------------------------------------------------------------------
select results_eq(
  $$ select s.code, count(distinct st.chapter_id)::int, count(*)::int,
            count(*) filter (where st.expert_reviewed)::int
     from public.sub_topics st
     join public.chapters c on c.id = st.chapter_id
     join public.subjects s on s.id = c.subject_id
     where s.code in ('BOT', 'ZOO')
     group by s.code order by s.code $$,
  $$ values ('BOT', 22, 201, 0), ('ZOO', 16, 160, 0) $$,
  'seed: Biology draft loaded (every chapter, nothing expert-reviewed yet)');
select is(
  (select count(*)::int from public.sub_topics st join public.chapters c on c.id = st.chapter_id
   where c.is_removed and not st.is_removed), 0,
  'seed: everything under a removed chapter is removed');
select is(
  (select count(*)::int from public.chapters c join public.subjects s on s.id = c.subject_id
   where s.code in ('BOT', 'ZOO')
     and not exists (select 1 from public.sub_topics st where st.chapter_id = c.id)), 0,
  'seed: every Biology chapter has at least one sub-topic');

-- ---------------------------------------------------------------------------
-- The tree
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.sub_topics (topic_id, chapter_id, slug, name_en)
     select t.id, (select id from public.chapters where slug = 'work-energy-and-power'), 'x', 'X'
     from public.topics t where t.slug = 'newtons-laws' $$,
  '23503', null, 'a sub-topic''s chapter must be its topic''s chapter');
select throws_ok(
  $$ insert into public.sub_topics (topic_id, chapter_id, slug, name_en)
     select id, chapter_id, 'third-law', 'Again' from public.topics where slug = 'newtons-laws' $$,
  '23505', null, 'sub-topic slugs are unique within a topic');
select throws_ok(
  $$ insert into public.sub_topics (topic_id, chapter_id, slug, name_en)
     select id, chapter_id, 'Bad Slug', 'X' from public.topics where slug = 'newtons-laws' $$,
  '23514', null, 'slugs are lower-case words joined by hyphens');
select is((select count(*)::int from public.sub_topics where is_removed and slug = 'removed-bit'), 1,
  'removed sub-topics stay in the tree');

-- ---------------------------------------------------------------------------
-- Questions: sub-topic in the same chapter; difficulty with its source
-- ---------------------------------------------------------------------------
insert into public.questions (id, exam_id, subject_id, chapter_id, format, stem, source_type)
select 'bbbbbbbb-7777-7777-7777-777777777777', e.id, s.id, c.id, 'single_mcq', 'Q', 'imported'
from public.exams e join public.subjects s on s.exam_id = e.id and s.code = 'PHY'
join public.chapters c on c.subject_id = s.id and c.slug = 'laws-of-motion'
where e.code = 'NEET_UG';
insert into public.question_options (question_id, label, content, is_correct)
select 'bbbbbbbb-7777-7777-7777-777777777777', l, 'Option ' || l, l = 'A'
from unnest(array['A', 'B', 'C', 'D']) as l;

select throws_ok(
  $$ update public.questions set sub_topic_id = (select id from public.sub_topics where slug = 'work-done')
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23503', null, 'a question cannot take a sub-topic from another chapter');
select lives_ok(
  $$ update public.questions set sub_topic_id = (select id from public.sub_topics where slug = 'draft-only'),
            difficulty_ai = 'difficult'
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  'a draft question can be tagged against the draft tree, with the AI''s difficulty');
select throws_ok(
  $$ update public.questions set difficulty = 'easy'
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'a difficulty needs its source');
select throws_ok(
  $$ update public.questions set difficulty = 'hard', difficulty_source = 'reviewer'
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'difficulty is easy, moderate or difficult');
select throws_ok(
  $$ update public.questions set source_type = 'chatgpt'
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'source types are checked');
select lives_ok(
  $$ update public.questions set source_type = 'ai_generated'
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  'ai_generated is a source type');

-- ---------------------------------------------------------------------------
-- Publishing
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.questions set status = 'published', slug = 'q', published_at = now()
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'publishing needs a difficulty');

update public.questions set difficulty = 'moderate', difficulty_source = 'reviewer'
where id = 'bbbbbbbb-7777-7777-7777-777777777777';
select throws_ok(
  $$ update public.questions set status = 'published', slug = 'q', published_at = now()
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'publishing needs a sub-topic the expert approved');

update public.questions set sub_topic_id = null where id = 'bbbbbbbb-7777-7777-7777-777777777777';
select throws_ok(
  $$ update public.questions set status = 'published', slug = 'q', published_at = now()
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'publishing needs a sub-topic');

select lives_ok(
  $$ update public.questions set sub_topic_id = (select id from public.sub_topics where slug = 'third-law'),
            status = 'published', slug = 'q', published_at = now()
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  'with an approved sub-topic and a reviewer difficulty it publishes');
select throws_ok(
  $$ update public.questions set sub_topic_id = (select id from public.sub_topics where slug = 'draft-only')
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  '23514', null, 'a published question cannot move to an unapproved sub-topic');

select lives_ok(
  $$ update public.questions set sub_topic_id = (select id from public.sub_topics where slug = 'removed-bit'),
            chapter_id = (select chapter_id from public.sub_topics where slug = 'removed-bit')
     where id = 'bbbbbbbb-7777-7777-7777-777777777777' $$,
  'a published PYQ can sit on a removed (but approved) sub-topic');

-- ---------------------------------------------------------------------------
-- Access: everyone reads the tree; only content admins change it
-- ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, phone) values
  ('aaaaaaaa-7777-7777-7777-777777777777', 'authenticated', 'authenticated', '919999900001'),
  ('cccccccc-7777-7777-7777-777777777777', 'authenticated', 'authenticated', '919999900002'),
  ('dddddddd-7777-7777-7777-777777777777', 'authenticated', 'authenticated', '919999900003');
insert into public.staff_roles (user_id, role) values
  ('cccccccc-7777-7777-7777-777777777777', 'content_admin'),
  ('dddddddd-7777-7777-7777-777777777777', 'reviewer');

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-7777-7777-7777-777777777777","role":"authenticated"}';
select is((select count(*)::int from public.sub_topics
            where slug in ('third-law', 'draft-only', 'removed-bit', 'work-done')), 4,
  'a student reads the tree');
update public.sub_topics set expert_reviewed = true where slug = 'draft-only';
reset role;
select is((select expert_reviewed from public.sub_topics where slug = 'draft-only'), false,
  'a student cannot approve a sub-topic');

set local role authenticated;
set local request.jwt.claims = '{"sub":"dddddddd-7777-7777-7777-777777777777","role":"authenticated"}';
update public.sub_topics set expert_reviewed = true where slug = 'draft-only';
reset role;
select is((select expert_reviewed from public.sub_topics where slug = 'draft-only'), false,
  'a reviewer cannot approve a sub-topic');

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccccccc-7777-7777-7777-777777777777","role":"authenticated"}';
select lives_ok(
  $$ update public.sub_topics set expert_reviewed = true where slug = 'draft-only' $$,
  'a content admin records the expert''s approval');
reset role;
select is((select expert_reviewed from public.sub_topics where slug = 'draft-only'), true,
  'the approval is saved');

select hasnt_table('public', 'question_topics', 'question_topics is gone (replaced by sub_topic_id)');

select * from finish();
rollback;
