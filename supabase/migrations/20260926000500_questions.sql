-- Question bank: questions, options, topic tags.
--
-- Answer correctness (question_options.is_correct) is never readable by app
-- clients (anon / authenticated). It is read only by services using the
-- service role: scoring after submission, practice feedback, the review
-- console's server-side functions and the SEO build.
--
-- Deferred to later slices: embedding + HNSW index (import slice, once the
-- embedding model is chosen), foreign key source_file_id -> source_files
-- (import slice), trap_type (P1).

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete restrict,
  subject_id uuid not null,
  chapter_id uuid,
  format text not null check (format in (
    'single_mcq', 'assertion_reason', 'match_following', 'multi_statement', 'numerical'
  )),
  stem text not null,
  stem_plain text not null default '',
  language text not null default 'en' check (language in ('en', 'kn')),
  translation_of uuid references public.questions (id) on delete set null,
  status text not null default 'draft' check (status in ('draft', 'review', 'published', 'retired')),
  source_type text not null check (source_type in ('pyq', 'original', 'imported')),
  pyq_year smallint check (pyq_year between 1980 and 2100),
  source_file_id uuid,
  source_page integer check (source_page > 0),
  slug text check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  short_id text not null unique default private.generate_short_id(),
  difficulty_b numeric,
  discrimination_a numeric,
  canonical_id uuid references public.questions (id) on delete set null,
  -- Held back for live mocks: never shown publicly (app browsing or SEO
  -- pages), even when published. Served only by the API inside an attempt.
  exam_reserved boolean not null default false,
  published_at timestamptz,
  published_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Subject must belong to the exam, and chapter to the subject.
  foreign key (subject_id, exam_id) references public.subjects (id, exam_id),
  foreign key (chapter_id, subject_id) references public.chapters (id, subject_id),
  constraint pyq_has_year check (source_type <> 'pyq' or pyq_year is not null),
  constraint published_has_slug_and_date check (
    status <> 'published' or (slug is not null and published_at is not null)
  ),
  constraint translation_not_self check (translation_of <> id),
  constraint canonical_not_self check (canonical_id <> id)
);

comment on column public.questions.slug is
  'SEO slug. Not unique on its own: the public URL is {slug}-{short_id}. Never changes once published.';

create index questions_status_subject_chapter_idx
  on public.questions (status, subject_id, chapter_id);
create index questions_stem_plain_fts_idx
  on public.questions using gin (to_tsvector('simple', stem_plain));
create index questions_chapter_id_idx on public.questions (chapter_id);

create trigger set_updated_at before update on public.questions
  for each row execute function private.set_updated_at();


create table public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete cascade,
  label text not null check (label in ('A', 'B', 'C', 'D')),
  content text not null,
  content_plain text not null default '',
  is_correct boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (question_id, label)
);

create trigger set_updated_at before update on public.question_options
  for each row execute function private.set_updated_at();


create table public.question_topics (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete cascade,
  topic_id uuid not null references public.topics (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (question_id, topic_id)
);

create index question_topics_topic_id_idx on public.question_topics (topic_id);

create trigger set_updated_at before update on public.question_topics
  for each row execute function private.set_updated_at();


-- A published option-based question must have options A-D with exactly one
-- correct. Checked at commit time so a question and its options can be
-- written in one transaction in any order.
create or replace function private.check_published_answer_key()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  qid uuid;
  q record;
  option_count int;
  correct_count int;
begin
  if tg_table_name = 'questions' then
    qid := new.id;
  elsif tg_op = 'DELETE' then
    qid := old.question_id;
  else
    qid := new.question_id;
  end if;

  select status, format into q from public.questions where id = qid;
  if not found or q.status <> 'published' or q.format = 'numerical' then
    return null;
  end if;

  select count(*), count(*) filter (where is_correct)
    into option_count, correct_count
  from public.question_options
  where question_id = qid;

  if option_count <> 4 or correct_count <> 1 then
    raise exception 'published question % must have options A-D with exactly one correct (has % options, % correct)',
      qid, option_count, correct_count
      using errcode = 'check_violation';
  end if;
  return null;
end;
$$;

create constraint trigger questions_published_answer_key
  after insert or update of status, format on public.questions
  deferrable initially deferred
  for each row execute function private.check_published_answer_key();

create constraint trigger question_options_published_answer_key
  after insert or update or delete on public.question_options
  deferrable initially deferred
  for each row execute function private.check_published_answer_key();


-- Visible to the public app: published and not reserved for live mocks.
create or replace function private.is_public_question(p_question_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.questions q
    where q.id = p_question_id and q.status = 'published' and not q.exam_reserved
  );
$$;

revoke all on function private.is_public_question(uuid) from public;
grant execute on function private.is_public_question(uuid) to anon, authenticated, service_role;


alter table public.questions enable row level security;
alter table public.question_options enable row level security;
alter table public.question_topics enable row level security;

create policy "questions: public reads published, staff read all"
  on public.questions for select
  to anon, authenticated
  using (
    (status = 'published' and not exam_reserved)
    or private.is_staff('reviewer', 'content_admin')
  );

create policy "questions: staff insert"
  on public.questions for insert
  to authenticated
  with check (private.is_staff('reviewer', 'content_admin'));

create policy "questions: staff update"
  on public.questions for update
  to authenticated
  using (private.is_staff('reviewer', 'content_admin'))
  with check (private.is_staff('reviewer', 'content_admin'));

create policy "questions: content admins delete"
  on public.questions for delete
  to authenticated
  using (private.is_staff('content_admin'));

create policy "question_options: public reads published, staff read all"
  on public.question_options for select
  to anon, authenticated
  using (
    private.is_public_question(question_id)
    or private.is_staff('reviewer', 'content_admin')
  );

create policy "question_options: staff insert"
  on public.question_options for insert
  to authenticated
  with check (private.is_staff('reviewer', 'content_admin'));

create policy "question_options: staff update"
  on public.question_options for update
  to authenticated
  using (private.is_staff('reviewer', 'content_admin'))
  with check (private.is_staff('reviewer', 'content_admin'));

create policy "question_options: staff delete"
  on public.question_options for delete
  to authenticated
  using (private.is_staff('reviewer', 'content_admin'));

create policy "question_topics: public reads published, staff read all"
  on public.question_topics for select
  to anon, authenticated
  using (
    private.is_public_question(question_id)
    or private.is_staff('reviewer', 'content_admin')
  );

create policy "question_topics: staff insert"
  on public.question_topics for insert
  to authenticated
  with check (private.is_staff('reviewer', 'content_admin'));

create policy "question_topics: staff update"
  on public.question_topics for update
  to authenticated
  using (private.is_staff('reviewer', 'content_admin'))
  with check (private.is_staff('reviewer', 'content_admin'));

create policy "question_topics: staff delete"
  on public.question_topics for delete
  to authenticated
  using (private.is_staff('reviewer', 'content_admin'));

revoke insert, update, delete, truncate on public.questions, public.question_options,
  public.question_topics from anon;

-- Column-level: clients can read every option column except is_correct.
-- (A select that names is_correct, or uses *, fails with permission denied.)
revoke select on public.question_options from anon, authenticated;
grant select (id, question_id, label, content, content_plain, created_at, updated_at)
  on public.question_options to anon, authenticated;


-- The only source for public SEO pages: published, not reserved for live
-- mocks. Readable by the service role only (the SEO build).
create view public.seo_questions
with (security_invoker = true)
as
  select q.*
  from public.questions q
  where q.status = 'published' and not q.exam_reserved;

revoke all on public.seo_questions from anon, authenticated;
grant select on public.seo_questions to service_role;
