-- Add permanent public event slugs for spectator standings URLs.

alter table public.events
add column if not exists public_slug text;

create or replace function app_private.event_public_slug_base(raw_title text)
returns text
language sql
immutable
as $$
  select coalesce(
    nullif(
      regexp_replace(
        regexp_replace(lower(btrim(coalesce(raw_title, ''))), '[^a-z0-9]+', '-', 'g'),
        '(^-+|-+$)',
        '',
        'g'
      ),
      ''
    ),
    'event'
  );
$$;

create or replace function app_private.generate_unique_event_public_slug(
  raw_title text,
  existing_event_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  base_slug text := app_private.event_public_slug_base(raw_title);
  candidate_slug text := base_slug;
  suffix integer := 2;
begin
  loop
    if not exists (
      select 1
      from public.events as event
      where event.public_slug = candidate_slug
        and (existing_event_id is null or event.id <> existing_event_id)
    ) then
      return candidate_slug;
    end if;

    candidate_slug := base_slug || '-' || suffix;
    suffix := suffix + 1;
  end loop;
end;
$$;

create or replace function app_private.set_event_public_slug()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.public_slug := app_private.generate_unique_event_public_slug(
    coalesce(nullif(new.public_slug, ''), new.title),
    new.id
  );
  return new;
end;
$$;

drop trigger if exists events_set_public_slug_before_insert on public.events;

create trigger events_set_public_slug_before_insert
before insert on public.events
for each row
execute function app_private.set_event_public_slug();

do $$
declare
  event_row record;
begin
  for event_row in
    select id, title
    from public.events
    where public_slug is null or btrim(public_slug) = ''
    order by created_at, id
  loop
    update public.events
    set public_slug = app_private.generate_unique_event_public_slug(
      event_row.title,
      event_row.id
    )
    where id = event_row.id;
  end loop;
end;
$$;

alter table public.events
alter column public_slug set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_public_slug_key'
      and conrelid = 'public.events'::regclass
  ) then
    alter table public.events
    add constraint events_public_slug_key unique (public_slug);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_public_slug_format_check'
      and conrelid = 'public.events'::regclass
  ) then
    alter table public.events
    add constraint events_public_slug_format_check
    check (public_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');
  end if;
end;
$$;

create or replace function app_private.prevent_event_public_slug_update()
returns trigger
language plpgsql
as $$
begin
  if new.public_slug is distinct from old.public_slug then
    raise exception 'Event public slugs cannot be changed.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists events_prevent_public_slug_update on public.events;

create trigger events_prevent_public_slug_update
before update of public_slug on public.events
for each row
execute function app_private.prevent_event_public_slug_update();

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
  limit 1;
$$;

grant execute on function public.resolve_public_event_id(text) to anon, authenticated;

alter table public.public_event_standings_snapshots
add column if not exists public_slug text;

update public.public_event_standings_snapshots as snapshot
set public_slug = event.public_slug
from public.events as event
where snapshot.event_id = event.id
  and snapshot.public_slug is distinct from event.public_slug;

alter table public.public_event_standings_snapshots
alter column public_slug set not null;

create unique index if not exists public_event_standings_snapshots_slug_idx
on public.public_event_standings_snapshots (public_slug);

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

do $$
declare
  event_row record;
begin
  for event_row in select id from public.events loop
    perform app_private.refresh_public_event_standings_snapshot(event_row.id);
  end loop;
end;
$$;

select pg_notify('pgrst', 'reload schema');
