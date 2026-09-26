-- Exam cycles: the date of each sitting of an exam (e.g. NEET-UG 2027).
-- Reference data: everyone reads, content admins maintain it.
--
-- Target exam years offered at signup come from here, never from a
-- hard-coded month: the first cycle whose date has not passed, and the two
-- years after it. public.target_exam_years() is the single rule, used by the
-- app (to list the years) and by public.complete_profile (to check them).

create table public.exam_cycles (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete cascade,
  exam_year smallint not null check (exam_year between 2025 and 2100),
  exam_date date not null,
  -- false while the date is an estimate (e.g. before the official notice).
  date_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exam_id, exam_year),
  check (extract(year from exam_date) = exam_year)
);

comment on table public.exam_cycles is
  'One row per sitting of an exam. Drives the target exam years offered at signup (public.target_exam_years).';

create trigger set_updated_at before update on public.exam_cycles
  for each row execute function private.set_updated_at();

alter table public.exam_cycles enable row level security;

create policy "exam_cycles: everyone reads" on public.exam_cycles
  for select to anon, authenticated using (true);
create policy "exam_cycles: content admins insert" on public.exam_cycles
  for insert to authenticated with check (private.is_staff('content_admin'));
create policy "exam_cycles: content admins update" on public.exam_cycles
  for update to authenticated
  using (private.is_staff('content_admin')) with check (private.is_staff('content_admin'));
create policy "exam_cycles: content admins delete" on public.exam_cycles
  for delete to authenticated using (private.is_staff('content_admin'));

revoke all on public.exam_cycles from anon, authenticated, service_role;
grant select on public.exam_cycles to anon, authenticated;
grant insert, update, delete on public.exam_cycles to authenticated;
grant select, insert, update, delete on public.exam_cycles to service_role;

-- The rule ------------------------------------------------------------------
-- Years a student may target for an exam, as of a date (default: today in
-- India): the first cycle whose exam date is today or later, and the two
-- years after it. Empty when no upcoming cycle is recorded (content admins
-- must add the next cycle before the current one's date passes).
create or replace function public.target_exam_years(
  p_exam_code text,
  p_as_of date default (now() at time zone 'Asia/Kolkata')::date)
returns smallint[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(y::smallint order by y), '{}')
  from (
    select min(c.exam_year)::int as first_year
    from public.exam_cycles c
    join public.exams e on e.id = c.exam_id
    where e.code = p_exam_code and c.exam_date >= p_as_of
  ) as upcoming
  -- No upcoming cycle: first_year is null, so no rows and an empty array.
  cross join lateral generate_series(upcoming.first_year, upcoming.first_year + 2) as y;
$$;

revoke all on function public.target_exam_years(text, date) from public;
grant execute on function public.target_exam_years(text, date)
  to anon, authenticated, service_role;

-- profiles.target_exam_year: the same rule for every write -------------------
-- Students may also update the column directly (column grant), so the rule
-- is enforced here, not only in complete_profile. Only a change is checked:
-- a year chosen earlier stays valid after its exam date passes.
create or replace function private.guard_target_exam_year()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.target_exam_year is null
     or new.target_exam_year is not distinct from old.target_exam_year then
    return new;
  end if;
  if not (new.target_exam_year = any (public.target_exam_years('NEET_UG'))) then
    raise exception 'target_exam_year_invalid' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger guard_target_exam_year before update of target_exam_year on public.profiles
  for each row execute function private.guard_target_exam_year();

-- complete_profile: same rule for the target exam year ------------------------
create or replace function public.complete_profile(
  p_user_id uuid,
  p_full_name text,
  p_date_of_birth date,
  p_target_exam_year smallint,
  p_category text default null,
  p_preferred_language text default null)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_name text := btrim(p_full_name);
  v_old_dob date;
begin
  select date_of_birth into v_old_dob from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 120 then
    raise exception 'full_name_invalid' using errcode = 'P0001';
  end if;
  if p_date_of_birth is null then
    raise exception 'dob_required' using errcode = 'P0001';
  end if;
  if v_old_dob is not null and v_old_dob <> p_date_of_birth then
    raise exception 'dob_already_set' using errcode = 'P0001';
  end if;
  -- Only NEET-UG for now; profiles gain a target exam when other exams launch.
  if p_target_exam_year is null
     or not (p_target_exam_year = any (public.target_exam_years('NEET_UG'))) then
    raise exception 'target_exam_year_invalid' using errcode = 'P0001';
  end if;
  if p_category is not null and p_category not in ('general', 'ews', 'obc_ncl', 'sc', 'st') then
    raise exception 'category_invalid' using errcode = 'P0001';
  end if;
  if p_preferred_language is not null and p_preferred_language not in ('en', 'kn') then
    raise exception 'language_invalid' using errcode = 'P0001';
  end if;

  -- The DOB trigger enforces the 13-30 age range on first set.
  update public.profiles
  set full_name = v_name,
      date_of_birth = p_date_of_birth,
      target_exam_year = p_target_exam_year,
      category = p_category,
      preferred_language = coalesce(p_preferred_language, preferred_language)
  where id = p_user_id;

  return private.signup_status(p_user_id);
end;
$$;

-- create or replace keeps the existing grants (service role only); restate them.
revoke all on function public.complete_profile(uuid, text, date, smallint, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_profile(uuid, text, date, smallint, text, text)
  to service_role;
