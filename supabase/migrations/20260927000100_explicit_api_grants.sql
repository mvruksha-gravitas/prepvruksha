-- Explicit Data API privileges for every table, view and helper function.
--
-- prepvruksha-dev was created with "Automatically expose new tables" off, so
-- new tables there got only REFERENCES, TRIGGER, TRUNCATE, MAINTAIN for the API
-- roles: no SELECT/INSERT/UPDATE/DELETE (the app and the service role could
-- not use them) but TRUNCATE, which bypasses RLS. Local Supabase instead grants
-- ALL by default. Earlier migrations relied on those defaults.
--
-- This migration removes the dependence on project settings:
--   1. Default privileges: new objects in public/private get nothing for
--      anon, authenticated, service_role (or PUBLIC for functions), on every
--      environment. Each migration must grant what it needs.
--   2. Every existing table/view: revoke everything from the API roles, then
--      grant exactly what each role needs. RLS still decides which rows.
--   3. Helper functions: execute only for the roles whose policies or
--      defaults call them.
--
-- Never grant TRUNCATE, REFERENCES, TRIGGER or MAINTAIN to API roles.

-- 1. Default privileges for objects created by migrations (role postgres) ----

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated, service_role, public;

alter default privileges for role postgres in schema private
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on functions from anon, authenticated, service_role, public;

-- 2. Reset every existing table and view in public ---------------------------

revoke all on
  public.staff_roles,
  public.profiles,
  public.consents,
  public.exams,
  public.subjects,
  public.chapters,
  public.topics,
  public.questions,
  public.question_options,
  public.question_topics,
  public.seo_questions
from anon, authenticated, service_role;

-- Service role (services/api, pipeline, SEO build): row access only; it
-- bypasses RLS, so code must do its own checks.
grant select, insert, update, delete on
  public.staff_roles,
  public.profiles,
  public.consents,
  public.exams,
  public.subjects,
  public.chapters,
  public.topics,
  public.questions,
  public.question_options,
  public.question_topics
to service_role;

-- Syllabus: everyone reads; writes are limited to content admins by RLS.
grant select on public.exams, public.subjects, public.chapters, public.topics
  to anon, authenticated;
grant insert, update, delete on public.exams, public.subjects, public.chapters, public.topics
  to authenticated;

-- Questions and topic tags: RLS shows published, non-reserved rows to the
-- public and everything to staff; writes are limited to staff by RLS.
grant select on public.questions, public.question_topics to anon, authenticated;
grant insert, update, delete on public.questions, public.question_topics to authenticated;

-- Options: every column except is_correct is readable. Staff can write
-- (RLS), but even staff cannot read is_correct from a client, so client
-- inserts/updates must not ask for it back (PostgREST: Prefer: return=minimal).
grant select (id, question_id, label, content, content_plain, created_at, updated_at)
  on public.question_options to anon, authenticated;
grant insert, update, delete on public.question_options to authenticated;

-- Profiles: users read their own row and edit only these columns. Rows are
-- created by trigger; id, phone and date_of_birth are set by triggers or the API.
grant select on public.profiles to authenticated;
grant update (full_name, preferred_language, target_exam_year, category, home_state)
  on public.profiles to authenticated;

-- Consents: users read their own; only the API (service role) writes.
grant select on public.consents to authenticated;

-- Staff roles: users read their own; super admins manage them (RLS).
grant select, insert, update, delete on public.staff_roles to authenticated;

-- SEO view: service role only. It selects from questions with the caller's
-- privileges (security_invoker), so it also needs the service role grant above.
grant select on public.seo_questions to service_role;

-- 3. Helper functions in private ---------------------------------------------
-- Trigger functions (set_updated_at, handle_auth_user_change,
-- check_published_answer_key) need no EXECUTE grant to fire.

revoke all on all functions in schema private from public, anon, authenticated, service_role;

-- Called by RLS policies, so every role that can reach those tables needs them.
grant execute on function private.is_staff(text[]) to anon, authenticated, service_role;
grant execute on function private.is_public_question(uuid) to anon, authenticated, service_role;
-- Column default for questions.short_id, evaluated as the inserting role.
grant execute on function private.generate_short_id() to authenticated, service_role;
-- Security invoker: callers only see profiles their own grants and RLS allow.
grant execute on function private.is_minor(uuid) to authenticated, service_role;
