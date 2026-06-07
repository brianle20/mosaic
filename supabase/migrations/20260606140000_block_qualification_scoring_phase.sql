-- Prevent future events from re-entering the deprecated qualification scoring
-- phase through the public phase mutation RPC. Historical rows remain readable.

create or replace function public.update_event_scoring_phase(
  target_event_id uuid,
  target_scoring_phase text
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_event public.events%rowtype;
  updated_event public.events%rowtype;
begin
  existing_event := app_private.require_owned_event(target_event_id);

  if target_scoring_phase = 'qualification' then
    raise exception 'Qualification scoring is no longer available.'
      using errcode = 'P0001';
  end if;

  if target_scoring_phase not in ('tournament', 'bonus') then
    raise exception 'Unsupported scoring phase.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as session
    where session.event_id = target_event_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End active or paused sessions before changing scoring phase.'
      using errcode = 'P0001';
  end if;

  update public.events
  set
    current_scoring_phase = target_scoring_phase,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_event.id
  returning *
  into updated_event;

  if target_scoring_phase = 'tournament'
    and existing_event.current_scoring_phase <> 'tournament'
  then
    delete from public.event_seating_assignments
    where event_id = target_event_id;

    perform public.generate_random_seating_assignments(target_event_id);
  end if;

  perform app_private.insert_audit_log(
    updated_event.id,
    'event',
    updated_event.id::text,
    'update_scoring_phase',
    to_jsonb(existing_event),
    to_jsonb(updated_event),
    jsonb_build_object('scoring_phase', target_scoring_phase)
  );

  return updated_event;
end;
$$;

select pg_notify('pgrst', 'reload schema');
