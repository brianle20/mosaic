-- Expose each public event's scheduled time and last recorded hand time.

create or replace function app_private.public_event_last_recorded_hand_at(
  target_event_id uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select max(hand_result.entered_at)
  from public.table_sessions as session
  join public.hand_results as hand_result
    on hand_result.table_session_id = session.id
  where session.event_id = target_event_id
    and hand_result.status = 'recorded';
$$;

revoke all on function app_private.public_event_last_recorded_hand_at(uuid)
  from public;

create or replace function app_private.refresh_public_event_standings_snapshot(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  snapshot_payload jsonb;
  target_public_slug text;
  latest_hand_recorded_at timestamptz;
begin
  if target_event_id is null then
    return;
  end if;

  if not app_private.is_public_event_visible(target_event_id) then
    delete from public.public_event_standings_snapshots as snapshot
    where snapshot.event_id = target_event_id;
    return;
  end if;

  select event.public_slug
  into target_public_slug
  from public.events as event
  where event.id = target_event_id;

  if target_public_slug is null then
    return;
  end if;

  latest_hand_recorded_at :=
    app_private.public_event_last_recorded_hand_at(target_event_id);
  snapshot_payload := jsonb_set(
    app_private.build_public_event_standings_snapshot(target_event_id),
    '{updatedAt}',
    coalesce(to_jsonb(latest_hand_recorded_at), 'null'::jsonb),
    true
  );

  insert into public.public_event_standings_snapshots (
    event_id,
    public_slug,
    payload,
    updated_at
  )
  values (
    target_event_id,
    target_public_slug,
    snapshot_payload,
    now()
  )
  on conflict (event_id) do update
  set
    public_slug = excluded.public_slug,
    payload = excluded.payload,
    updated_at = excluded.updated_at;
end;
$$;

drop function if exists public.get_public_events();

create function public.get_public_events()
returns table (
  event_id uuid,
  public_slug text,
  title text,
  event_starts_at timestamptz,
  event_timezone text,
  standings_updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    event.id as event_id,
    event.public_slug,
    event.title,
    event.starts_at as event_starts_at,
    event.timezone as event_timezone,
    app_private.public_event_last_recorded_hand_at(event.id)
      as standings_updated_at
  from public.events as event
  where event.archived_at is null
    and event.lifecycle_status <> 'cancelled'
    and event.public_slug is not null
    and btrim(event.public_slug) <> ''
  order by
    event.starts_at desc,
    event.title asc;
$$;

grant execute on function public.get_public_events()
  to anon, authenticated;

do $$
declare
  event_row record;
begin
  for event_row in
    select event.id
    from public.events as event
    where event.public_slug is not null
      and btrim(event.public_slug) <> ''
  loop
    perform app_private.refresh_public_event_standings_snapshot(event_row.id);
  end loop;
end $$;

select pg_notify('pgrst', 'reload schema');
