-- Syllabus gains a fourth level (subject → chapter → topic → sub-topic), and
-- questions are tagged at sub-topic level with a difficulty
-- (docs/DATA_MODEL.md section 10; decided 26 Sep 2026).
--
-- Publishing needs: a sub-topic in the question's own chapter, a
-- reviewer-set difficulty, and a sub-topic the subject expert has approved
-- (expert_reviewed). Tagging against the draft tree is allowed before that.
--
-- Removed syllabus (chapters, topics and sub-topics with is_removed) stays in
-- the tree so older PYQs still get a sub-topic. Practice and mocks exclude
-- questions on removed sub-topics by default (enforced where those are built).

-- topics: removed flag, and a key for the chapter-consistency FK below
alter table public.topics
  add column is_removed boolean not null default false,
  add constraint topics_id_chapter_id_key unique (id, chapter_id);

-- sub_topics -------------------------------------------------------------------
create table public.sub_topics (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null,
  -- Stored so questions can check "sub-topic in my chapter" with a plain FK;
  -- kept equal to the topic's chapter by the composite FK below.
  chapter_id uuid not null,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text not null check (char_length(btrim(name_en)) between 1 and 200),
  name_kn text,
  name_kn_reviewed boolean not null default false,
  ncert_ref text,
  -- No longer in the exam syllabus; kept for tagging older PYQs.
  is_removed boolean not null default false,
  -- The subject expert approved this sub-topic. Questions on it can be
  -- published only when true.
  expert_reviewed boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (topic_id, chapter_id) references public.topics (id, chapter_id) on delete restrict,
  unique (topic_id, slug),
  unique (id, chapter_id),
  check (not name_kn_reviewed or name_kn is not null)
);

comment on table public.sub_topics is
  'Lowest syllabus level; questions are tagged here. Source: docs/syllabus/*.md, loaded by migrations.';

create index sub_topics_chapter_id_idx on public.sub_topics (chapter_id);

create trigger set_updated_at before update on public.sub_topics
  for each row execute function private.set_updated_at();

alter table public.sub_topics enable row level security;
create policy "sub_topics: everyone reads" on public.sub_topics
  for select to anon, authenticated using (true);
create policy "sub_topics: content admins insert" on public.sub_topics
  for insert to authenticated with check (private.is_staff('content_admin'));
create policy "sub_topics: content admins update" on public.sub_topics
  for update to authenticated
  using (private.is_staff('content_admin')) with check (private.is_staff('content_admin'));
create policy "sub_topics: content admins delete" on public.sub_topics
  for delete to authenticated using (private.is_staff('content_admin'));

revoke all on public.sub_topics from anon, authenticated, service_role;
grant select on public.sub_topics to anon, authenticated;
grant insert, update, delete on public.sub_topics to authenticated;
grant select, insert, update, delete on public.sub_topics to service_role;

-- questions: sub-topic, difficulty, AI-generated source ------------------------
alter table public.questions
  add column sub_topic_id uuid,
  add column difficulty text check (difficulty in ('easy', 'moderate', 'difficult')),
  -- The AI's suggestion (import worker or generator); never the published value.
  add column difficulty_ai text check (difficulty_ai in ('easy', 'moderate', 'difficult')),
  -- Who set `difficulty`: a reviewer, or recalibration from attempt data.
  add column difficulty_source text check (difficulty_source in ('reviewer', 'calibrated')),
  -- The sub-topic must be in the question's own chapter.
  add constraint questions_sub_topic_in_chapter
    foreign key (sub_topic_id, chapter_id) references public.sub_topics (id, chapter_id)
    on delete restrict,
  add constraint difficulty_has_source check ((difficulty is null) = (difficulty_source is null)),
  add constraint published_has_sub_topic_and_difficulty check (
    status <> 'published' or (sub_topic_id is not null and difficulty is not null)
  );

alter table public.questions drop constraint questions_source_type_check;
alter table public.questions add constraint questions_source_type_check
  check (source_type in ('pyq', 'original', 'imported', 'ai_generated'));

create index questions_sub_topic_difficulty_status_idx
  on public.questions (sub_topic_id, difficulty, status);

-- Publishing needs an expert-reviewed sub-topic. Checked at commit, like the
-- answer key, so a question and its tags can be written in any order.
create or replace function private.check_published_sub_topic()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'published' and not exists (
    select 1 from public.sub_topics
    where id = new.sub_topic_id and expert_reviewed
  ) then
    raise exception 'published question % needs a sub-topic approved by the subject expert', new.id
      using errcode = 'check_violation';
  end if;
  return null;
end;
$$;

revoke all on function private.check_published_sub_topic() from public;

create constraint trigger questions_published_sub_topic
  after insert or update of status, sub_topic_id on public.questions
  deferrable initially deferred
  for each row execute function private.check_published_sub_topic();

-- question_topics: replaced by questions.sub_topic_id (empty everywhere) -------
drop table public.question_topics;
