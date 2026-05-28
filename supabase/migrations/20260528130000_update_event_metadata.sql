create or replace function public.update_event_metadata(
  target_event_id uuid,
  event_title text,
  event_description text,
  event_venue_name text,
  event_venue_address text,
  event_timezone text,
  event_starts_at timestamptz,
  event_cover_charge_cents integer,
  event_default_ruleset_id text default 'HK_STANDARD'
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_event public.events%rowtype;
  updated_event public.events%rowtype;
  normalized_title text := nullif(btrim(event_title), '');
  normalized_timezone text := nullif(btrim(event_timezone), '');
  normalized_ruleset_id text := coalesce(
    nullif(btrim(event_default_ruleset_id), ''),
    'HK_STANDARD'
  );
begin
  existing_event := app_private.require_owned_event(target_event_id);

  if existing_event.lifecycle_status <> 'draft' then
    raise exception 'Only draft events can be edited.'
      using errcode = 'P0001';
  end if;

  if normalized_title is null then
    raise exception 'Event title is required.'
      using errcode = 'P0001';
  end if;

  if normalized_timezone is null then
    raise exception 'Event timezone is required.'
      using errcode = 'P0001';
  end if;

  if event_starts_at is null then
    raise exception 'Event start time is required.'
      using errcode = 'P0001';
  end if;

  if event_cover_charge_cents is null or event_cover_charge_cents < 0 then
    raise exception 'Event cover charge must be zero or more.'
      using errcode = 'P0001';
  end if;

  update public.events
  set
    title = normalized_title,
    description = nullif(btrim(event_description), ''),
    venue_name = nullif(btrim(event_venue_name), ''),
    venue_address = nullif(btrim(event_venue_address), ''),
    timezone = normalized_timezone,
    starts_at = event_starts_at,
    cover_charge_cents = event_cover_charge_cents,
    default_ruleset_id = normalized_ruleset_id,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_event.id
  returning *
  into updated_event;

  perform app_private.insert_audit_log(
    updated_event.id,
    'event',
    updated_event.id::text,
    'update_metadata',
    to_jsonb(existing_event),
    to_jsonb(updated_event),
    jsonb_build_object(
      'title', updated_event.title,
      'starts_at', updated_event.starts_at,
      'cover_charge_cents', updated_event.cover_charge_cents
    )
  );

  return updated_event;
end;
$$;

grant execute on function public.update_event_metadata(
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  integer,
  text
) to authenticated;
