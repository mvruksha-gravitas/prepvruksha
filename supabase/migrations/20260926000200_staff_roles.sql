-- Internal content-team roles. Institution roles (teacher, institute admin)
-- live in `memberships`, added in a later slice.

create table public.staff_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('reviewer', 'content_admin', 'super_admin')),
  granted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, role)
);

comment on table public.staff_roles is
  'Content team roles. super_admin satisfies every role check.';

create trigger set_updated_at before update on public.staff_roles
  for each row execute function private.set_updated_at();

-- True when the current user holds any of the given roles (or super_admin).
-- security definer so policies can call it without granting read access to
-- staff_roles, and so policies on staff_roles itself don't recurse.
create or replace function private.is_staff(variadic roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_roles sr
    where sr.user_id = (select auth.uid())
      and (sr.role = any (roles) or sr.role = 'super_admin')
  );
$$;

revoke all on function private.is_staff(text[]) from public;
grant execute on function private.is_staff(text[]) to anon, authenticated, service_role;

alter table public.staff_roles enable row level security;

create policy "staff_roles: read own, super admins read all"
  on public.staff_roles for select
  to authenticated
  using (user_id = (select auth.uid()) or private.is_staff('super_admin'));

create policy "staff_roles: super admins insert"
  on public.staff_roles for insert
  to authenticated
  with check (private.is_staff('super_admin'));

create policy "staff_roles: super admins update"
  on public.staff_roles for update
  to authenticated
  using (private.is_staff('super_admin'))
  with check (private.is_staff('super_admin'));

create policy "staff_roles: super admins delete"
  on public.staff_roles for delete
  to authenticated
  using (private.is_staff('super_admin'));

revoke all on public.staff_roles from anon;
