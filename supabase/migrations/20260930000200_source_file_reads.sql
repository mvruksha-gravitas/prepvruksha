-- Read functions for the API (service role): staff roles and source files.
-- The API uses the secret key (no RLS), so these apply the same visibility
-- rule as the source_files policy, for the acting staff member:
-- reference_only files only for content admins and super admins.

create or replace function public.get_staff_roles(p_user_id uuid)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(role order by role), '{}')
  from public.staff_roles where user_id = p_user_id;
$$;

create or replace function private.actor_can_see_source_file(p_actor_id uuid, p_rights_status text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_roles
    where user_id = p_actor_id
      and (role in ('content_admin', 'super_admin')
           or (role = 'reviewer' and p_rights_status <> 'reference_only'))
  );
$$;

create or replace function private.source_file_json(p_file public.source_files)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_file.id,
    'original_name', p_file.original_name,
    'file_type', p_file.file_type,
    'size_bytes', p_file.size_bytes,
    'sha256', p_file.sha256,
    'storage_path', p_file.storage_path,
    'rights_status', p_file.rights_status,
    'rights_note', p_file.rights_note,
    'pyq_exam_code', (select code from public.exams where id = p_file.pyq_exam_id),
    'pyq_year', p_file.pyq_year,
    'status', p_file.status,
    'error', p_file.error,
    'uploaded_by', p_file.uploaded_by,
    'created_at', p_file.created_at,
    'queued_at', p_file.queued_at);
$$;

create or replace function public.get_source_file(p_actor_id uuid, p_file_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_file public.source_files;
begin
  select * into v_file from public.source_files where id = p_file_id;
  -- Hidden files look the same as missing ones.
  if not found or not private.actor_can_see_source_file(p_actor_id, v_file.rights_status) then
    raise exception 'file_not_found' using errcode = 'P0001';
  end if;
  return private.source_file_json(v_file);
end;
$$;

-- Newest first. Optional filters by status and rights status.
create or replace function public.list_source_files(
  p_actor_id uuid,
  p_status text default null,
  p_rights_status text default null,
  p_limit integer default 200)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  if not exists (select 1 from public.staff_roles where user_id = p_actor_id) then
    raise exception 'not_authorised' using errcode = 'P0001';
  end if;
  return coalesce((
    select jsonb_agg(private.source_file_json(f) order by f.created_at desc)
    from (
      select * from public.source_files f
      where private.actor_can_see_source_file(p_actor_id, f.rights_status)
        and (p_status is null or f.status = p_status)
        and (p_rights_status is null or f.rights_status = p_rights_status)
      order by f.created_at desc
      limit least(greatest(coalesce(p_limit, 200), 1), 500)
    ) f
  ), '[]'::jsonb);
end;
$$;

revoke all on function private.actor_can_see_source_file(uuid, text) from public;
revoke all on function private.source_file_json(public.source_files) from public;
grant execute on function private.actor_can_see_source_file(uuid, text) to service_role;
grant execute on function private.source_file_json(public.source_files) to service_role;

revoke all on function public.get_staff_roles(uuid) from public, anon, authenticated;
revoke all on function public.get_source_file(uuid, uuid) from public, anon, authenticated;
revoke all on function public.list_source_files(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.get_staff_roles(uuid) to service_role;
grant execute on function public.get_source_file(uuid, uuid) to service_role;
grant execute on function public.list_source_files(uuid, text, text, integer) to service_role;
