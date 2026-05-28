-- Keep event ownership helper overloads unambiguous for one-argument callers.
--
-- Postgres does not allow CREATE OR REPLACE FUNCTION to remove an existing
-- default argument, so move the previous defaulted overload out of the way
-- before recreating the two explicit signatures below.
do $$
begin
  if exists (
    select 1
    from pg_proc as proc
    join pg_namespace as ns on ns.oid = proc.pronamespace
    where ns.nspname = 'app_private'
      and proc.proname = 'is_event_owner'
      and pg_get_function_identity_arguments(proc.oid) = 'target_event_id uuid, target_user_id uuid'
  ) and not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as ns on ns.oid = proc.pronamespace
    where ns.nspname = 'app_private'
      and proc.proname = 'is_event_owner_for_user'
      and pg_get_function_identity_arguments(proc.oid) = 'target_event_id uuid, target_user_id uuid'
  ) then
    alter function app_private.is_event_owner(uuid, uuid)
      rename to is_event_owner_for_user;
  end if;
end $$;

create or replace function app_private.is_event_owner(
  target_event_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.events as event
    where event.id = target_event_id
      and event.owner_user_id = target_user_id
  )
$$;

create or replace function app_private.is_event_owner(
  target_event_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.is_event_owner(target_event_id, auth.uid())
$$;
