-- Append-only audit log for sensitive changes: date-of-birth corrections now;
-- publishing, answer-key edits and staff role changes when the review console
-- is built.

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  -- Staff member who made the change (null if their account is deleted).
  actor_id uuid references auth.users (id) on delete set null,
  action text not null check (char_length(action) between 1 and 80),
  target_table text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  -- Rows are never updated (no API role has UPDATE); kept for the
  -- created_at/updated_at convention.
  updated_at timestamptz not null default now()
);

comment on table public.audit_log is
  'Append-only. Written by the API (service role) or its functions; read by super admins.';

create index audit_log_target_idx on public.audit_log (target_table, target_id);

alter table public.audit_log enable row level security;

create policy "audit_log: super admins read"
  on public.audit_log for select
  to authenticated
  using (private.is_staff('super_admin'));

grant select on public.audit_log to authenticated;
grant select, insert on public.audit_log to service_role;
