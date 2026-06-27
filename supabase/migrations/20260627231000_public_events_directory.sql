-- Public event directory for mosaicmahjong.com/events.

create or replace function public.get_public_events()
returns table (
  event_id uuid,
  public_slug text,
  title text,
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
    snapshot.updated_at as standings_updated_at
  from public.events as event
  left join public.public_event_standings_snapshots as snapshot
    on snapshot.event_id = event.id
  where event.archived_at is null
    and event.public_slug is not null
    and btrim(event.public_slug) <> ''
  order by
    snapshot.updated_at desc nulls last,
    event.title asc;
$$;

grant execute on function public.get_public_events()
  to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
