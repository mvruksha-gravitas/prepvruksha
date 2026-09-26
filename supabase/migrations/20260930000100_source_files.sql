-- Import pipeline, slice 1: uploaded source files, the import queue and the
-- parsed items it will produce, plus the private Storage bucket for files.
--
-- Every file records its rights status at upload (CLAUDE.md rule 14):
--   owned_licensed  we own or licensed the content; may be published
--   official_pyq    an official previous-year paper; records exam and year
--   reference_only  never published; similarity checks and inspiration only
-- Reference-only files and their items are visible only to content admins and
-- super admins, not reviewers.
--
-- Clients only read (RLS). All writes go through service-role functions that
-- take the acting staff member and check their role; the API calls them.

-- source_files ---------------------------------------------------------------
create table public.source_files (
  id uuid primary key default gen_random_uuid(),
  original_name text not null check (char_length(btrim(original_name)) between 1 and 255),
  file_type text not null check (file_type in ('pdf', 'docx')),
  size_bytes bigint not null check (size_bytes between 1 and 104857600),
  sha256 text not null unique check (sha256 ~ '^[0-9a-f]{64}$'),
  storage_path text not null unique,
  rights_status text not null check (rights_status in ('owned_licensed', 'official_pyq', 'reference_only')),
  rights_note text not null check (char_length(btrim(rights_note)) between 1 and 2000),
  pyq_exam_id uuid references public.exams (id) on delete restrict,
  pyq_year smallint check (pyq_year between 1980 and 2100),
  uploaded_by uuid references auth.users (id) on delete set null,
  status text not null default 'awaiting_upload' check (status in (
    'awaiting_upload', 'queued', 'extracting', 'parsing', 'needs_review', 'done', 'failed'
  )),
  error text,
  queued_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Official PYQ files name their exam and year; other files have neither.
  constraint pyq_exam_and_year check (
    (rights_status = 'official_pyq') = (pyq_exam_id is not null and pyq_year is not null)
    and (pyq_exam_id is null) = (pyq_year is null)
  )
);

comment on table public.source_files is
  'Uploaded PDF/Word files for the import pipeline. Rights status is required; reference_only content is never published.';
comment on column public.source_files.sha256 is
  'Hex SHA-256 computed in the browser. Identical files are rejected. The worker re-checks it (slice 2).';

create index source_files_status_created_idx on public.source_files (status, created_at desc);

create trigger set_updated_at before update on public.source_files
  for each row execute function private.set_updated_at();

-- import_jobs: queue for the slice 2 worker ----------------------------------
create table public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  source_file_id uuid not null references public.source_files (id) on delete cascade,
  step text not null default 'extract_parse' check (step in ('extract_parse')),
  status text not null default 'queued' check (status in ('queued', 'running', 'done', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  locked_at timestamptz,
  locked_by text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_file_id, step)
);

comment on table public.import_jobs is
  'Work queue polled by the import worker with FOR UPDATE SKIP LOCKED.';

create index import_jobs_status_created_idx on public.import_jobs (status, created_at);

create trigger set_updated_at before update on public.import_jobs
  for each row execute function private.set_updated_at();

-- import_items: parsed candidate questions (written from slice 2) -------------
create table public.import_items (
  id uuid primary key default gen_random_uuid(),
  source_file_id uuid not null references public.source_files (id) on delete cascade,
  page integer check (page > 0),
  raw_extract text,
  parsed jsonb not null default '{}',
  confidence numeric check (confidence between 0 and 1),
  flags text[] not null default '{}',
  duplicate_of uuid references public.questions (id) on delete set null,
  -- 'reference': an item of a reference_only file (similarity corpus only).
  status text not null default 'needs_review' check (status in ('needs_review', 'approved', 'rejected', 'reference')),
  question_id uuid references public.questions (id) on delete set null,
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.import_items is
  'One row per parsed candidate question. Items of reference_only files have status reference and are never approved.';

create index import_items_source_file_idx on public.import_items (source_file_id, page);
create index import_items_status_idx on public.import_items (status);

create trigger set_updated_at before update on public.import_items
  for each row execute function private.set_updated_at();

-- questions.source_file_id (deferred from the questions migration) ------------
alter table public.questions
  add constraint questions_source_file_id_fkey
  foreign key (source_file_id) references public.source_files (id) on delete set null;
create index questions_source_file_id_idx on public.questions (source_file_id);

-- Row Level Security ----------------------------------------------------------
-- True when the current user may see a file with this rights status:
-- content admins (and super admins) see everything, reviewers everything
-- except reference_only.
create or replace function private.can_see_source_file(p_rights_status text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select private.is_staff('content_admin')
      or (p_rights_status <> 'reference_only' and private.is_staff('reviewer'));
$$;

revoke all on function private.can_see_source_file(text) from public;
grant execute on function private.can_see_source_file(text) to authenticated, service_role;

alter table public.source_files enable row level security;
alter table public.import_jobs enable row level security;
alter table public.import_items enable row level security;

create policy "source_files: staff read (reference_only: content admins)" on public.source_files
  for select to authenticated using (private.can_see_source_file(rights_status));

create policy "import_jobs: content admins read" on public.import_jobs
  for select to authenticated using (private.is_staff('content_admin'));

-- The subquery is itself filtered by the source_files policy.
create policy "import_items: staff read items of files they can see" on public.import_items
  for select to authenticated
  using (exists (select 1 from public.source_files f where f.id = source_file_id));

revoke all on public.source_files, public.import_jobs, public.import_items
  from anon, authenticated, service_role;
grant select on public.source_files, public.import_jobs, public.import_items to authenticated;
grant select, insert, update, delete on public.source_files, public.import_jobs, public.import_items
  to service_role;

-- Storage bucket ----------------------------------------------------------------
-- Private; PDF and Word only; 100 MB. No storage policies for clients: files
-- arrive only through signed upload URLs created by the API.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('source-files', 'source-files', false, 104857600, array[
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
])
on conflict (id) do nothing;

-- Functions (service role only) ------------------------------------------------
create or replace function private.require_content_admin(p_actor_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_actor_id is null or not exists (
    select 1 from public.staff_roles
    where user_id = p_actor_id and role in ('content_admin', 'super_admin')
  ) then
    raise exception 'not_authorised' using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function private.require_content_admin(uuid) from public;
grant execute on function private.require_content_admin(uuid) to service_role;

-- Checks rights status + PYQ exam/year; returns the exam id for official_pyq.
create or replace function private.check_rights(
  p_rights_status text, p_rights_note text, p_pyq_exam_code text, p_pyq_year smallint)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_exam_id uuid;
begin
  if p_rights_status is null
     or p_rights_status not in ('owned_licensed', 'official_pyq', 'reference_only') then
    raise exception 'rights_status_invalid' using errcode = 'P0001';
  end if;
  if coalesce(btrim(p_rights_note), '') = '' then
    raise exception 'rights_note_required' using errcode = 'P0001';
  end if;
  if p_rights_status = 'official_pyq' then
    select id into v_exam_id from public.exams where code = p_pyq_exam_code;
    if v_exam_id is null or p_pyq_year is null then
      raise exception 'pyq_exam_and_year_required' using errcode = 'P0001';
    end if;
    if p_pyq_year < 1980 or p_pyq_year > extract(year from now())::int then
      raise exception 'pyq_year_invalid' using errcode = 'P0001';
    end if;
  elsif p_pyq_exam_code is not null or p_pyq_year is not null then
    raise exception 'pyq_fields_only_for_official_pyq' using errcode = 'P0001';
  end if;
  return v_exam_id;
end;
$$;

revoke all on function private.check_rights(text, text, text, smallint) from public;
grant execute on function private.check_rights(text, text, text, smallint) to service_role;

-- Records a new file before its upload. Returns the row; the API then hands
-- out a signed upload URL for storage_path. An earlier attempt with the same
-- content that never finished uploading is reused instead of rejected.
create or replace function public.create_source_file(
  p_actor_id uuid,
  p_original_name text,
  p_file_type text,
  p_size_bytes bigint,
  p_sha256 text,
  p_rights_status text,
  p_rights_note text,
  p_pyq_exam_code text default null,
  p_pyq_year smallint default null)
returns public.source_files
language plpgsql
set search_path = ''
as $$
declare
  v_exam_id uuid;
  v_hash text := lower(p_sha256);
  v_row public.source_files;
begin
  perform private.require_content_admin(p_actor_id);
  if p_file_type is null or p_file_type not in ('pdf', 'docx') then
    raise exception 'file_type_invalid' using errcode = 'P0001';
  end if;
  if p_size_bytes is null or p_size_bytes < 1 or p_size_bytes > 104857600 then
    raise exception 'file_size_invalid' using errcode = 'P0001';
  end if;
  if v_hash is null or v_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'sha256_invalid' using errcode = 'P0001';
  end if;
  if coalesce(btrim(p_original_name), '') = '' then
    raise exception 'file_name_required' using errcode = 'P0001';
  end if;
  v_exam_id := private.check_rights(p_rights_status, p_rights_note, p_pyq_exam_code, p_pyq_year);

  select * into v_row from public.source_files where sha256 = v_hash for update;
  if found and v_row.status <> 'awaiting_upload' then
    raise exception 'duplicate_file' using errcode = 'P0001';
  end if;

  if found then
    update public.source_files set
      original_name = btrim(p_original_name), file_type = p_file_type, size_bytes = p_size_bytes,
      storage_path = 'uploads/' || id || '.' || p_file_type,
      rights_status = p_rights_status, rights_note = btrim(p_rights_note),
      pyq_exam_id = v_exam_id, pyq_year = p_pyq_year, uploaded_by = p_actor_id
    where id = v_row.id
    returning * into v_row;
  else
    v_row.id := gen_random_uuid();
    insert into public.source_files (
      id, original_name, file_type, size_bytes, sha256, storage_path,
      rights_status, rights_note, pyq_exam_id, pyq_year, uploaded_by)
    values (
      v_row.id, btrim(p_original_name), p_file_type, p_size_bytes, v_hash,
      'uploads/' || v_row.id || '.' || p_file_type,
      p_rights_status, btrim(p_rights_note), v_exam_id, p_pyq_year, p_actor_id)
    returning * into v_row;
  end if;

  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (p_actor_id, 'source_file.created', 'source_files', v_row.id, jsonb_build_object(
    'rights_status', v_row.rights_status, 'pyq_exam_code', p_pyq_exam_code,
    'pyq_year', v_row.pyq_year, 'sha256', v_row.sha256));
  return v_row;
end;
$$;

-- Confirms the upload: the object must be in the bucket with the recorded
-- size. Marks the file queued and creates its import job, in one transaction.
create or replace function public.complete_source_file_upload(p_actor_id uuid, p_file_id uuid)
returns public.source_files
language plpgsql
set search_path = ''
as $$
declare
  v_row public.source_files;
  v_size bigint;
begin
  perform private.require_content_admin(p_actor_id);
  select * into v_row from public.source_files where id = p_file_id for update;
  if not found then
    raise exception 'file_not_found' using errcode = 'P0001';
  end if;
  if v_row.status <> 'awaiting_upload' then
    raise exception 'file_already_uploaded' using errcode = 'P0001';
  end if;

  select (o.metadata ->> 'size')::bigint into v_size
  from storage.objects o
  where o.bucket_id = 'source-files' and o.name = v_row.storage_path;
  if not found then
    raise exception 'upload_missing' using errcode = 'P0001';
  end if;
  if v_size is distinct from v_row.size_bytes then
    raise exception 'upload_size_mismatch' using errcode = 'P0001';
  end if;

  update public.source_files set status = 'queued', queued_at = now()
  where id = p_file_id returning * into v_row;
  insert into public.import_jobs (source_file_id) values (p_file_id);
  return v_row;
end;
$$;

-- Changes a file's rights status later (audited with a reason). Once a file
-- has published questions it may only move to reference_only (a takedown):
-- its published questions are then retired in the same transaction, each
-- with an audit entry. Slice 3 adds the block on publishing them again.
create or replace function public.set_source_file_rights(
  p_actor_id uuid,
  p_file_id uuid,
  p_rights_status text,
  p_rights_note text,
  p_reason text,
  p_pyq_exam_code text default null,
  p_pyq_year smallint default null)
returns public.source_files
language plpgsql
set search_path = ''
as $$
declare
  v_old public.source_files;
  v_row public.source_files;
  v_exam_id uuid;
  v_retired uuid[];
begin
  perform private.require_content_admin(p_actor_id);
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'reason_required' using errcode = 'P0001';
  end if;
  v_exam_id := private.check_rights(p_rights_status, p_rights_note, p_pyq_exam_code, p_pyq_year);

  select * into v_old from public.source_files where id = p_file_id for update;
  if not found then
    raise exception 'file_not_found' using errcode = 'P0001';
  end if;
  if p_rights_status <> 'reference_only' and exists (
    select 1 from public.questions where source_file_id = p_file_id and status = 'published'
  ) then
    raise exception 'rights_locked_by_published_questions' using errcode = 'P0001';
  end if;

  update public.source_files set
    rights_status = p_rights_status, rights_note = btrim(p_rights_note),
    pyq_exam_id = v_exam_id, pyq_year = p_pyq_year
  where id = p_file_id returning * into v_row;

  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (p_actor_id, 'source_file.rights_changed', 'source_files', p_file_id, jsonb_build_object(
    'old', jsonb_build_object('rights_status', v_old.rights_status, 'rights_note', v_old.rights_note,
                              'pyq_exam_id', v_old.pyq_exam_id, 'pyq_year', v_old.pyq_year),
    'new', jsonb_build_object('rights_status', v_row.rights_status, 'rights_note', v_row.rights_note,
                              'pyq_exam_id', v_row.pyq_exam_id, 'pyq_year', v_row.pyq_year),
    'reason', btrim(p_reason)));

  if p_rights_status = 'reference_only' then
    with retired as (
      update public.questions set status = 'retired'
      where source_file_id = p_file_id and status = 'published'
      returning id
    )
    select coalesce(array_agg(id), '{}') into v_retired from retired;

    insert into public.audit_log (actor_id, action, target_table, target_id, details)
    select p_actor_id, 'question.retired', 'questions', q, jsonb_build_object(
      'cause', 'source_file_reference_only', 'source_file_id', p_file_id, 'reason', btrim(p_reason))
    from unnest(v_retired) as q;
  end if;
  return v_row;
end;
$$;

revoke all on function public.create_source_file(uuid, text, text, bigint, text, text, text, text, smallint)
  from public, anon, authenticated;
revoke all on function public.complete_source_file_upload(uuid, uuid) from public, anon, authenticated;
revoke all on function public.set_source_file_rights(uuid, uuid, text, text, text, text, smallint)
  from public, anon, authenticated;
grant execute on function public.create_source_file(uuid, text, text, bigint, text, text, text, text, smallint)
  to service_role;
grant execute on function public.complete_source_file_upload(uuid, uuid) to service_role;
grant execute on function public.set_source_file_rights(uuid, uuid, text, text, text, text, smallint)
  to service_role;
