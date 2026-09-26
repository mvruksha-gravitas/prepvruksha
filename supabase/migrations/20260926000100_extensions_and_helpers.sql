-- Extensions and shared helpers.

create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- Schema for helper functions used by RLS policies. Not exposed through the
-- Data API (only `public` is), so these cannot be called as RPC endpoints.
create schema if not exists private;
grant usage on schema private to anon, authenticated, service_role;

-- Keeps updated_at current. Attach with:
--   create trigger set_updated_at before update on <table>
--     for each row execute function private.set_updated_at();
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Short, URL-safe random id (8 chars, lowercase base32 without look-alikes).
-- Used in public question URLs: /neet/{subject}/{chapter}/{slug}-{short_id}.
create or replace function private.generate_short_id()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
  bytes bytea := extensions.gen_random_bytes(8);
  result text := '';
begin
  for i in 0..7 loop
    result := result || substr(alphabet, (get_byte(bytes, i) % length(alphabet)) + 1, 1);
  end loop;
  return result;
end;
$$;
