-- Source files, rights status, import queue (pipeline slice 1).
-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures: a student, a reviewer, a content admin, a super admin
-- ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, phone) values
  ('aaaaaaaa-6666-6666-6666-666666666666', 'authenticated', 'authenticated', '919999900001'),
  ('bbbbbbbb-6666-6666-6666-666666666666', 'authenticated', 'authenticated', '919999900003'),
  ('cccccccc-6666-6666-6666-666666666666', 'authenticated', 'authenticated', '919999900002'),
  ('dddddddd-6666-6666-6666-666666666666', 'authenticated', 'authenticated', '919999900004');
insert into public.staff_roles (user_id, role) values
  ('bbbbbbbb-6666-6666-6666-666666666666', 'reviewer'),
  ('cccccccc-6666-6666-6666-666666666666', 'content_admin'),
  ('dddddddd-6666-6666-6666-666666666666', 'super_admin');

-- Bucket
select results_eq(
  $$ select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'source-files' $$,
  $$ values (false, 104857600::bigint, array['application/pdf',
       'application/vnd.openxmlformats-officedocument.wordprocessingml.document']) $$,
  'bucket source-files: private, 100 MB, PDF and Word only');
select is(
  (select count(*)::int from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and (qual like '%source-files%' or with_check like '%source-files%')),
  0, 'no client storage policies for source-files');

-- ---------------------------------------------------------------------------
-- create_source_file: roles and validation
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select public.create_source_file('bbbbbbbb-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), 'owned_licensed', 'Our own notes') $$,
  'P0001', 'not_authorised', 'a reviewer cannot upload');
select throws_ok(
  $$ select public.create_source_file('aaaaaaaa-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), 'owned_licensed', 'Our own notes') $$,
  'P0001', 'not_authorised', 'a student cannot upload');

select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), null, 'note') $$,
  'P0001', 'rights_status_invalid', 'rights status is required');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), 'owned_licensed', '  ') $$,
  'P0001', 'rights_note_required', 'rights note is required');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), 'official_pyq', 'NTA paper') $$,
  'P0001', 'pyq_exam_and_year_required', 'official PYQ needs exam and year');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), 'official_pyq', 'NTA paper', 'NEET_UG', 2999::smallint) $$,
  'P0001', 'pyq_year_invalid', 'PYQ year cannot be in the future');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       repeat('a', 64), 'owned_licensed', 'Ours', 'NEET_UG', 2023::smallint) $$,
  'P0001', 'pyq_fields_only_for_official_pyq', 'exam and year only for official PYQ');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.xlsx', 'xlsx', 10,
       repeat('a', 64), 'owned_licensed', 'Ours') $$,
  'P0001', 'file_type_invalid', 'only pdf and docx');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 104857601,
       repeat('a', 64), 'owned_licensed', 'Ours') $$,
  'P0001', 'file_size_invalid', 'at most 100 MB');
select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'a.pdf', 'pdf', 10,
       'xyz', 'owned_licensed', 'Ours') $$,
  'P0001', 'sha256_invalid', 'hash must be 64 hex characters');

-- Three files: owned, official PYQ (NEET 2023), reference only
select lives_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'Own set A.pdf', 'pdf', 1000,
       repeat('a', 64), 'owned_licensed', 'Written by our teachers') $$,
  'a content admin records an owned file');
select lives_ok(
  $$ select public.create_source_file('dddddddd-6666-6666-6666-666666666666', 'NEET 2023.pdf', 'pdf', 2000,
       upper(repeat('b', 64)), 'official_pyq', 'NTA question paper', 'NEET_UG', 2023::smallint) $$,
  'a super admin records an official PYQ (hash accepted in upper case)');
select lives_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'Guide.docx', 'docx', 3000,
       repeat('c', 64), 'reference_only', 'Commercial guide, not ours') $$,
  'a content admin records a reference-only file');

select results_eq(
  $$ select f.rights_status, e.code, f.pyq_year, f.status, f.storage_path = 'uploads/' || f.id || '.pdf'
     from public.source_files f left join public.exams e on e.id = f.pyq_exam_id
     where f.sha256 = repeat('b', 64) $$,
  $$ values ('official_pyq', 'NEET_UG', 2023::smallint, 'awaiting_upload', true) $$,
  'official PYQ file records exam, year, status and storage path');
select is(
  (select count(*)::int from public.audit_log where action = 'source_file.created'), 3,
  'each new file is audited');
select is(
  (select details ->> 'rights_status' from public.audit_log a
   join public.source_files f on f.id = a.target_id where f.sha256 = repeat('c', 64)),
  'reference_only', 'the audit entry records the rights status');

select throws_ok(
  $$ insert into public.source_files (original_name, file_type, size_bytes, sha256, storage_path,
       rights_status, rights_note)
     values ('x.pdf', 'pdf', 1, repeat('d', 64), 'uploads/x.pdf', 'official_pyq', 'n') $$,
  '23514', null, 'table check: official PYQ rows must have exam and year');

-- An unfinished upload of the same content is reused, not rejected
select is(
  (select id from public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'Own set A (2).pdf',
     'pdf', 1000, repeat('a', 64), 'owned_licensed', 'Written by our teachers')),
  (select id from public.source_files where sha256 = repeat('a', 64)),
  'retrying an unfinished upload reuses its row');
select is((select count(*)::int from public.source_files), 3, 'no second row for the retry');

-- ---------------------------------------------------------------------------
-- complete_source_file_upload: object must exist with the recorded size
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$ select public.complete_source_file_upload('cccccccc-6666-6666-6666-666666666666', %L) $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'upload_missing', 'cannot complete before the object is uploaded');

insert into storage.objects (bucket_id, name, metadata)
select 'source-files', storage_path, jsonb_build_object('size', 999)
from public.source_files where sha256 = repeat('a', 64);
select throws_ok(
  format($$ select public.complete_source_file_upload('cccccccc-6666-6666-6666-666666666666', %L) $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'upload_size_mismatch', 'the uploaded size must match');

update storage.objects set metadata = jsonb_build_object('size', 1000)
where bucket_id = 'source-files'
  and name = (select storage_path from public.source_files where sha256 = repeat('a', 64));
select throws_ok(
  format($$ select public.complete_source_file_upload('bbbbbbbb-6666-6666-6666-666666666666', %L) $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'not_authorised', 'a reviewer cannot complete an upload');
select lives_ok(
  format($$ select public.complete_source_file_upload('cccccccc-6666-6666-6666-666666666666', %L) $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'a content admin completes the upload');
select results_eq(
  $$ select f.status, f.queued_at is not null, j.step, j.status, j.attempts
     from public.source_files f join public.import_jobs j on j.source_file_id = f.id
     where f.sha256 = repeat('a', 64) $$,
  $$ values ('queued', true, 'extract_parse', 'queued', 0) $$,
  'the file is queued with an import job');
select throws_ok(
  format($$ select public.complete_source_file_upload('cccccccc-6666-6666-6666-666666666666', %L) $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'file_already_uploaded', 'completing twice fails');

select throws_ok(
  $$ select public.create_source_file('cccccccc-6666-6666-6666-666666666666', 'copy.pdf', 'pdf', 1000,
       repeat('a', 64), 'owned_licensed', 'Same file again') $$,
  'P0001', 'duplicate_file', 'an identical, already uploaded file is rejected');

-- ---------------------------------------------------------------------------
-- set_source_file_rights: audited; locked by published questions
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$ select public.set_source_file_rights('cccccccc-6666-6666-6666-666666666666', %L,
           'reference_only', 'Unsure after all', '  ') $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'reason_required', 'a reason is required');
select throws_ok(
  format($$ select public.set_source_file_rights('bbbbbbbb-6666-6666-6666-666666666666', %L,
           'reference_only', 'Unsure', 'Owner called') $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'not_authorised', 'a reviewer cannot change rights');
select lives_ok(
  format($$ select public.set_source_file_rights('cccccccc-6666-6666-6666-666666666666', %L,
           'official_pyq', 'Turned out to be the NTA paper', 'Checked the source', 'NEET_UG', 2022::smallint) $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'a content admin changes the rights status');
select results_eq(
  $$ select a.details -> 'old' ->> 'rights_status', a.details -> 'new' ->> 'rights_status',
            (a.details -> 'new' ->> 'pyq_year')::int, a.details ->> 'reason'
     from public.audit_log a where a.action = 'source_file.rights_changed' $$,
  $$ values ('owned_licensed', 'official_pyq', 2022, 'Checked the source') $$,
  'the change is audited with old, new and reason');

-- A published question from the file locks it (only reference_only allowed)
insert into public.topics (chapter_id, slug, name_en)
select c.id, 'fixture-topic', 'Fixture topic'
from public.chapters c join public.subjects s on s.id = c.subject_id
where s.code = 'PHY' and c.slug = 'laws-of-motion';
insert into public.sub_topics (topic_id, chapter_id, slug, name_en, expert_reviewed)
select id, chapter_id, 'fixture-sub-topic', 'Fixture sub-topic', true
from public.topics where slug = 'fixture-topic';
insert into public.questions (exam_id, subject_id, chapter_id, format, stem, source_type, pyq_year,
                              source_file_id, status, slug, published_at,
                              sub_topic_id, difficulty, difficulty_source)
select e.id, s.id, st.chapter_id, 'single_mcq', 'Q?', 'pyq', 2022, f.id, 'published', 'q', now(),
       st.id, 'easy', 'reviewer'
from public.exams e join public.subjects s on s.exam_id = e.id and s.code = 'PHY',
     public.source_files f, public.sub_topics st
where e.code = 'NEET_UG' and f.sha256 = repeat('a', 64) and st.slug = 'fixture-sub-topic';
select throws_ok(
  format($$ select public.set_source_file_rights('cccccccc-6666-6666-6666-666666666666', %L,
           'owned_licensed', 'x', 'y') $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'P0001', 'rights_locked_by_published_questions', 'with published questions only reference_only is allowed');
select lives_ok(
  format($$ select public.set_source_file_rights('cccccccc-6666-6666-6666-666666666666', %L,
           'reference_only', 'Owner asked us to stop', 'Takedown request') $$,
         (select id from public.source_files where sha256 = repeat('a', 64))),
  'moving to reference_only is still allowed');
select is(
  (select status from public.questions where source_file_id =
     (select id from public.source_files where sha256 = repeat('a', 64))),
  'retired', 'takedown: the file''s published question is retired');
select results_eq(
  $$ select a.details ->> 'cause', a.details ->> 'reason' from public.audit_log a
     join public.questions q on q.id = a.target_id where a.action = 'question.retired' $$,
  $$ values ('source_file_reference_only', 'Takedown request') $$,
  'takedown: each retired question is audited');

-- ---------------------------------------------------------------------------
-- Visibility: reviewers never see reference_only files or their items
-- ---------------------------------------------------------------------------
insert into public.import_items (source_file_id, page, status)
select id, 1, case when rights_status = 'reference_only' then 'reference' else 'needs_review' end
from public.source_files;

set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbbbbbb-6666-6666-6666-666666666666","role":"authenticated"}';
select results_eq(
  $$ select rights_status from public.source_files order by rights_status $$,
  $$ values ('official_pyq') $$,
  'a reviewer sees only non-reference files');
select is((select count(*)::int from public.import_items), 1,
  'a reviewer sees only items of files they can see');
select is((select count(*)::int from public.import_jobs), 0, 'a reviewer does not see import jobs');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccccccc-6666-6666-6666-666666666666","role":"authenticated"}';
select is((select count(*)::int from public.source_files), 3, 'a content admin sees every file');
select is((select count(*)::int from public.import_items), 3, 'a content admin sees every item');
select is((select count(*)::int from public.import_jobs), 1, 'a content admin sees import jobs');
select throws_ok(
  $$ insert into public.source_files (original_name, file_type, size_bytes, sha256, storage_path,
       rights_status, rights_note)
     values ('x.pdf', 'pdf', 1, repeat('e', 64), 'uploads/x.pdf', 'owned_licensed', 'n') $$,
  '42501', null, 'staff cannot write source_files directly');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"dddddddd-6666-6666-6666-666666666666","role":"authenticated"}';
select is((select count(*)::int from public.source_files), 3, 'a super admin sees every file');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-6666-6666-6666-666666666666","role":"authenticated"}';
select is((select count(*)::int from public.source_files), 0, 'a student sees no files');
select is((select count(*)::int from public.import_items), 0, 'a student sees no items');
reset role;

-- ---------------------------------------------------------------------------
-- Read functions for the API (same visibility, by acting staff member)
-- ---------------------------------------------------------------------------
select is(public.get_staff_roles('dddddddd-6666-6666-6666-666666666666'), '{super_admin}'::text[],
  'get_staff_roles: super admin');
select is(public.get_staff_roles('aaaaaaaa-6666-6666-6666-666666666666'), '{}'::text[],
  'get_staff_roles: a student has none');
select is(jsonb_array_length(public.list_source_files('cccccccc-6666-6666-6666-666666666666')), 3,
  'list: a content admin gets every file');
select results_eq(
  $$ select f ->> 'rights_status', f ->> 'pyq_exam_code', (f ->> 'pyq_year')::int
     from jsonb_array_elements(public.list_source_files('bbbbbbbb-6666-6666-6666-666666666666')) f $$,
  $$ values ('official_pyq', 'NEET_UG', 2023) $$,
  'list: a reviewer gets only non-reference files, with the PYQ exam code');
select is(jsonb_array_length(public.list_source_files('cccccccc-6666-6666-6666-666666666666',
  p_rights_status => 'reference_only')), 2, 'list: filter by rights status');
select is(jsonb_array_length(public.list_source_files('cccccccc-6666-6666-6666-666666666666',
  p_status => 'queued')), 1, 'list: filter by status');
select throws_ok(
  $$ select public.list_source_files('aaaaaaaa-6666-6666-6666-666666666666') $$,
  'P0001', 'not_authorised', 'list: a student is refused');
select throws_ok(
  format($$ select public.get_source_file('bbbbbbbb-6666-6666-6666-666666666666', %L) $$,
         (select id from public.source_files where sha256 = repeat('c', 64))),
  'P0001', 'file_not_found', 'get: a reference-only file looks missing to a reviewer');
select is(
  public.get_source_file('cccccccc-6666-6666-6666-666666666666',
    (select id from public.source_files where sha256 = repeat('c', 64))) ->> 'original_name',
  'Guide.docx', 'get: a content admin reads a reference-only file');

select * from finish();
rollback;
