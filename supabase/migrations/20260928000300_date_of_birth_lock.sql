-- Date of birth is set once, at signup, and only for ages 13-30. After that
-- only staff can correct it, through public.correct_date_of_birth, which
-- writes an audit entry. Otherwise a minor could change their age to skip
-- parental consent.

create or replace function private.guard_date_of_birth()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.date_of_birth is not distinct from old.date_of_birth then
    return new;
  end if;
  -- Set (transaction-local) only by public.correct_date_of_birth.
  if current_setting('prepvruksha.dob_correction', true) = 'on' then
    return new;
  end if;
  if old.date_of_birth is not null then
    raise exception 'dob_already_set' using errcode = 'P0001';
  end if;
  if extract(year from age(current_date, new.date_of_birth)) not between 13 and 30 then
    raise exception 'age_out_of_range' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger guard_date_of_birth before update of date_of_birth on public.profiles
  for each row execute function private.guard_date_of_birth();

-- Staff correction, called by the API (service role) on behalf of p_actor_id,
-- who must be a super admin. Any age is accepted: staff decide.
create or replace function public.correct_date_of_birth(
  p_actor_id uuid, p_user_id uuid, p_date_of_birth date, p_reason text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_old date;
begin
  if not exists (
    select 1 from public.staff_roles where user_id = p_actor_id and role = 'super_admin'
  ) then
    raise exception 'not_authorised' using errcode = 'P0001';
  end if;
  if p_date_of_birth is null then
    raise exception 'dob_required' using errcode = 'P0001';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'reason_required' using errcode = 'P0001';
  end if;

  select date_of_birth into v_old from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;

  perform set_config('prepvruksha.dob_correction', 'on', true);
  update public.profiles set date_of_birth = p_date_of_birth where id = p_user_id;
  perform set_config('prepvruksha.dob_correction', 'off', true);

  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (p_actor_id, 'profile.date_of_birth.corrected', 'profiles', p_user_id,
          jsonb_build_object('old', v_old, 'new', p_date_of_birth, 'reason', btrim(p_reason)));
end;
$$;

revoke all on function public.correct_date_of_birth(uuid, uuid, date, text)
  from public, anon, authenticated;
grant execute on function public.correct_date_of_birth(uuid, uuid, date, text) to service_role;
