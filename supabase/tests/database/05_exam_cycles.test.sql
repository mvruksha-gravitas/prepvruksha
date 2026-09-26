-- Exam cycles and the target exam year rule (public.target_exam_years).
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Seed: NEET-UG 2027 is set for May 2027, not yet confirmed
-- ---------------------------------------------------------------------------
select results_eq(
  $$ select c.exam_date, c.date_confirmed from public.exam_cycles c
     join public.exams e on e.id = c.exam_id
     where e.code = 'NEET_UG' and c.exam_year = 2027 $$,
  $$ values (date '2027-05-02', false) $$,
  'seed: NEET-UG 2027 on 2 May 2027, unconfirmed');

-- ---------------------------------------------------------------------------
-- Fixtures (as postgres): fixed cycles, independent of the seed and of today
-- ---------------------------------------------------------------------------
delete from public.exam_cycles;
insert into public.exam_cycles (exam_id, exam_year, exam_date)
select e.id, y, d
from public.exams e,
     (values (2040::smallint, date '2040-05-06'), (2041::smallint, date '2041-05-05')) as v (y, d)
where e.code = 'NEET_UG';

-- ---------------------------------------------------------------------------
-- The rule: first cycle whose date has not passed, and the two years after it
-- ---------------------------------------------------------------------------
select is(public.target_exam_years('NEET_UG', '2039-12-31'), '{2040,2041,2042}'::smallint[],
  'before the 2040 exam: 2040 to 2042');
select is(public.target_exam_years('NEET_UG', '2040-05-06'), '{2040,2041,2042}'::smallint[],
  'on the exam day the exam still counts');
select is(public.target_exam_years('NEET_UG', '2040-05-07'), '{2041,2042,2043}'::smallint[],
  'the day after the exam: starts at the next cycle');
select is(public.target_exam_years('NEET_UG', '2041-05-06'), '{}'::smallint[],
  'no upcoming cycle recorded: nothing is offered');
select is(public.target_exam_years('KCET', '2039-12-31'), '{}'::smallint[],
  'an exam without cycles: nothing is offered');

select throws_ok(
  $$ insert into public.exam_cycles (exam_id, exam_year, exam_date)
     select id, 2042, date '2043-05-01' from public.exams where code = 'NEET_UG' $$,
  '23514', null, 'the exam date must fall in the exam year');

-- ---------------------------------------------------------------------------
-- Everyone reads cycles and the rule; only content admins change cycles
-- ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, phone) values
  ('aaaaaaaa-2222-2222-2222-222222222222', 'authenticated', 'authenticated', '919999900001'),
  ('cccccccc-2222-2222-2222-222222222222', 'authenticated', 'authenticated', '919999900003');
insert into public.staff_roles (user_id, role) values ('cccccccc-2222-2222-2222-222222222222', 'content_admin');

set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is((select count(*)::int from public.exam_cycles), 2, 'anon reads exam cycles');
select ok(cardinality(public.target_exam_years('NEET_UG')) in (0, 3), 'anon can call target_exam_years');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-2222-2222-2222-222222222222","role":"authenticated"}';
select throws_ok(
  $$ insert into public.exam_cycles (exam_id, exam_year, exam_date)
     select id, 2045, date '2045-05-07' from public.exams where code = 'NEET_UG' $$,
  '42501', null, 'a student cannot add an exam cycle');
update public.exam_cycles set exam_date = date '2040-05-13' where exam_year = 2040;
reset role;
select is((select exam_date from public.exam_cycles where exam_year = 2040), date '2040-05-06',
  'a student cannot change an exam date');

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccccccc-2222-2222-2222-222222222222","role":"authenticated"}';
select lives_ok(
  $$ update public.exam_cycles set exam_date = date '2040-05-13', date_confirmed = true
     where exam_year = 2040 $$,
  'a content admin can set the official date');
reset role;
select results_eq(
  $$ select exam_date, date_confirmed from public.exam_cycles where exam_year = 2040 $$,
  $$ values (date '2040-05-13', true) $$, 'the new date is saved');

-- ---------------------------------------------------------------------------
-- Direct profile updates follow the same rule (students own the column)
-- ---------------------------------------------------------------------------
-- Cycles relative to today for this part: next May is the next sitting.
delete from public.exam_cycles;
insert into public.exam_cycles (exam_id, exam_year, exam_date)
select id, extract(year from current_date)::smallint + 1,
       make_date(extract(year from current_date)::int + 1, 5, 2)
from public.exams where code = 'NEET_UG';
-- Fixture only: an old year, written with triggers off (the rule would reject it).
set local session_replication_role = replica;
update public.profiles set target_exam_year = 2025 where id = 'aaaaaaaa-2222-2222-2222-222222222222';
reset session_replication_role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-2222-2222-2222-222222222222","role":"authenticated"}';
select throws_ok(
  format($$ update public.profiles set target_exam_year = %s where id = 'aaaaaaaa-2222-2222-2222-222222222222' $$,
         extract(year from current_date)::int + 4),
  'P0001', 'target_exam_year_invalid', 'a student cannot set a year outside the rule directly');
select lives_ok(
  format($$ update public.profiles set target_exam_year = %s where id = 'aaaaaaaa-2222-2222-2222-222222222222' $$,
         extract(year from current_date)::int + 2),
  'a student can change to a year the rule allows');
reset role;

-- A year chosen earlier stays valid after its exam passes (only changes are checked).
set local session_replication_role = replica;
update public.profiles set target_exam_year = 2025, full_name = 'Asha'
  where id = 'aaaaaaaa-2222-2222-2222-222222222222';
reset session_replication_role;
select lives_ok(
  $$ update public.profiles set full_name = 'Asha K' where id = 'aaaaaaaa-2222-2222-2222-222222222222' $$,
  'other profile edits keep an old target year');

select * from finish();
rollback;
