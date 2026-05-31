-- Hide archived events from public standings and cached snapshot access.

create or replace function app_private.is_public_event_visible(
  target_event_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.events as event
    where event.id = target_event_id
      and event.archived_at is null
  );
$$;

grant execute on function app_private.is_public_event_visible(uuid)
  to anon, authenticated;

drop policy if exists public_event_standings_snapshots_public_read
  on public.public_event_standings_snapshots;
create policy public_event_standings_snapshots_public_read
on public.public_event_standings_snapshots
for select
to anon, authenticated
using (app_private.is_public_event_visible(event_id));

delete from public.public_event_standings_snapshots as snapshot
where not app_private.is_public_event_visible(snapshot.event_id);

create or replace function public.resolve_public_event_id(
  target_public_slug text
)
returns table (
  event_id uuid,
  public_slug text
)
language sql
security definer
set search_path = public
as $$
  select
    event.id,
    event.public_slug
  from public.events as event
  where event.public_slug = lower(btrim(target_public_slug))
    and event.archived_at is null
  limit 1;
$$;

create or replace function public.get_public_event_summary(
  target_event_id uuid
)
returns table (
  event_id uuid,
  title text
)
language sql
security definer
set search_path = public
as $$
  select
    event.id,
    event.title
  from public.events as event
  where event.id = target_event_id
    and event.archived_at is null;
$$;

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

  snapshot_payload :=
    app_private.build_public_event_standings_snapshot(target_event_id);

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

select pg_notify('pgrst', 'reload schema');
