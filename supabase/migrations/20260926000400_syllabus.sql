-- Syllabus: exams > subjects > chapters > topics. Public reference data.
-- Kannada names may be AI-drafted; name_kn_reviewed marks translator approval.

create table public.exams (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z0-9_]*$'),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text not null,
  name_kn text,
  name_kn_reviewed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (not name_kn_reviewed or name_kn is not null)
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete restrict,
  code text not null check (code ~ '^[A-Z][A-Z0-9_]*$'),
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text not null,
  name_kn text,
  name_kn_reviewed boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exam_id, code),
  unique (exam_id, slug),
  -- Target for composite foreign keys that keep questions consistent.
  unique (id, exam_id),
  check (not name_kn_reviewed or name_kn is not null)
);

create table public.chapters (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects (id) on delete restrict,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text not null,
  name_kn text,
  name_kn_reviewed boolean not null default false,
  -- Null for syllabus units with no NCERT chapter (e.g. experimental skills).
  class_level smallint check (class_level in (11, 12)),
  ncert_ref text,
  neet_weightage numeric(5, 2) check (neet_weightage between 0 and 100),
  -- Removed from the current exam syllabus. Kept so older PYQs can be tagged.
  is_removed boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subject_id, slug),
  unique (id, subject_id),
  check (not name_kn_reviewed or name_kn is not null)
);

create table public.topics (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters (id) on delete restrict,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text not null,
  name_kn text,
  name_kn_reviewed boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chapter_id, slug),
  check (not name_kn_reviewed or name_kn is not null)
);

create index subjects_exam_id_idx on public.subjects (exam_id);
create index chapters_subject_id_idx on public.chapters (subject_id);
create index topics_chapter_id_idx on public.topics (chapter_id);

create trigger set_updated_at before update on public.exams
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.subjects
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.chapters
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.topics
  for each row execute function private.set_updated_at();

-- Everyone reads; content admins write.
do $$
declare
  t text;
begin
  foreach t in array array['exams', 'subjects', 'chapters', 'topics'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "%1$s: everyone reads" on public.%1$I for select to anon, authenticated using (true)', t);
    execute format(
      'create policy "%1$s: content admins insert" on public.%1$I for insert to authenticated with check (private.is_staff(''content_admin''))', t);
    execute format(
      'create policy "%1$s: content admins update" on public.%1$I for update to authenticated using (private.is_staff(''content_admin'')) with check (private.is_staff(''content_admin''))', t);
    execute format(
      'create policy "%1$s: content admins delete" on public.%1$I for delete to authenticated using (private.is_staff(''content_admin''))', t);
    execute format('revoke insert, update, delete, truncate on public.%I from anon', t);
  end loop;
end;
$$;
