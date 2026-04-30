-- Scope NFC tags to the signed-in host instead of allowing global mutation.

alter table public.nfc_tags
  add column if not exists owner_user_id uuid references public.users(id) on delete cascade;

update public.nfc_tags as tag
set owner_user_id = owner_source.owner_user_id
from (
  select distinct on (source.nfc_tag_id)
    source.nfc_tag_id,
    source.owner_user_id
  from (
    select table_tag.nfc_tag_id, event.owner_user_id
    from public.event_tables as table_tag
    join public.events as event
      on event.id = table_tag.event_id
    where table_tag.nfc_tag_id is not null
    union all
    select assignment.nfc_tag_id, event.owner_user_id
    from public.event_guest_tag_assignments as assignment
    join public.events as event
      on event.id = assignment.event_id
  ) as source
  order by source.nfc_tag_id, source.owner_user_id
) as owner_source
where tag.id = owner_source.nfc_tag_id
  and tag.owner_user_id is null;

alter table public.nfc_tags
  drop constraint if exists nfc_tags_uid_hex_key,
  drop constraint if exists nfc_tags_uid_fingerprint_key;

create unique index if not exists nfc_tags_owner_uid_hex_unique
  on public.nfc_tags (owner_user_id, uid_hex)
  where owner_user_id is not null;

create unique index if not exists nfc_tags_owner_uid_fingerprint_unique
  on public.nfc_tags (owner_user_id, uid_fingerprint)
  where owner_user_id is not null;

drop policy if exists nfc_tags_authenticated_all on public.nfc_tags;
drop policy if exists nfc_tags_owner_all on public.nfc_tags;
create policy nfc_tags_owner_all
on public.nfc_tags
for all
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create or replace function app_private.ensure_player_tag(
  scanned_uid text,
  scanned_display_label text default null
)
returns public.nfc_tags
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_uid text;
  tag_row public.nfc_tags%rowtype;
begin
  normalized_uid := app_private.normalize_tag_uid(scanned_uid);

  if auth.uid() is null then
    raise exception 'A signed-in host is required.'
      using errcode = 'P0001';
  end if;

  if normalized_uid = '' then
    raise exception 'Tag UID is required.'
      using errcode = 'P0001';
  end if;

  select *
  into tag_row
  from public.nfc_tags
  where owner_user_id = auth.uid()
    and uid_hex = normalized_uid
  for update;

  if not found then
    insert into public.nfc_tags (
      owner_user_id,
      uid_hex,
      uid_fingerprint,
      default_tag_type,
      display_label,
      status,
      first_seen_at,
      last_seen_at
    )
    values (
      auth.uid(),
      normalized_uid,
      normalized_uid,
      'player',
      scanned_display_label,
      'active',
      now(),
      now()
    )
    returning *
    into tag_row;

    return tag_row;
  end if;

  if tag_row.default_tag_type = 'table' then
    raise exception 'Only player tags can be assigned to guests.'
      using errcode = 'P0001';
  end if;

  update public.nfc_tags
  set
    default_tag_type = 'player',
    display_label = coalesce(scanned_display_label, display_label),
    last_seen_at = now(),
    updated_at = now()
  where id = tag_row.id
  returning *
  into tag_row;

  return tag_row;
end;
$$;

create or replace function app_private.ensure_table_tag(
  scanned_uid text,
  scanned_display_label text default null
)
returns public.nfc_tags
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_uid text;
  tag_row public.nfc_tags%rowtype;
begin
  normalized_uid := app_private.normalize_tag_uid(scanned_uid);

  if auth.uid() is null then
    raise exception 'A signed-in host is required.'
      using errcode = 'P0001';
  end if;

  if normalized_uid = '' then
    raise exception 'Table tag UID is required.'
      using errcode = 'P0001';
  end if;

  select *
  into tag_row
  from public.nfc_tags
  where owner_user_id = auth.uid()
    and uid_hex = normalized_uid
  for update;

  if not found then
    insert into public.nfc_tags (
      owner_user_id,
      uid_hex,
      uid_fingerprint,
      default_tag_type,
      display_label,
      status,
      first_seen_at,
      last_seen_at
    )
    values (
      auth.uid(),
      normalized_uid,
      normalized_uid,
      'table',
      scanned_display_label,
      'active',
      now(),
      now()
    )
    returning *
    into tag_row;

    return tag_row;
  end if;

  if tag_row.default_tag_type = 'player' then
    raise exception 'A player tag cannot be rebound as a table tag.'
      using errcode = 'P0001';
  end if;

  update public.nfc_tags
  set
    default_tag_type = 'table',
    display_label = coalesce(scanned_display_label, display_label),
    last_seen_at = now(),
    updated_at = now()
  where id = tag_row.id
  returning *
  into tag_row;

  return tag_row;
end;
$$;

create or replace function public.start_table_session(
  target_event_table_id uuid,
  scanned_table_uid text,
  east_player_uid text,
  south_player_uid text,
  west_player_uid text,
  north_player_uid text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  session_row public.table_sessions%rowtype;
  ruleset_row public.rulesets%rowtype;
  normalized_table_uid text;
  bound_tag_uid text;
  next_session_number integer;
  seat_guest_ids uuid[];
  seat_index integer;
  scanned_uid text;
  resolved_tag_row public.nfc_tags%rowtype;
  resolved_assignment_row public.event_guest_tag_assignments%rowtype;
  resolved_guest_row public.event_guests%rowtype;
  scanned_player_uids text[] := array[
    east_player_uid,
    south_player_uid,
    west_player_uid,
    north_player_uid
  ];
  initial_winds text[] := array['east', 'south', 'west', 'north'];
begin
  table_row := app_private.require_owned_table(target_event_table_id);
  perform app_private.require_event_for_scoring(table_row.event_id);

  if table_row.nfc_tag_id is null then
    raise exception 'A bound table tag is required before starting a session.'
      using errcode = 'P0001';
  end if;

  normalized_table_uid := app_private.normalize_tag_uid(scanned_table_uid);

  select uid_hex
  into bound_tag_uid
  from public.nfc_tags
  where id = table_row.nfc_tag_id
    and owner_user_id = auth.uid();

  if bound_tag_uid is null or bound_tag_uid <> normalized_table_uid then
    raise exception 'The scanned table tag does not match the selected table.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as existing_session
    where existing_session.event_table_id = table_row.id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'This table already has an active session.'
      using errcode = 'P0001';
  end if;

  seat_guest_ids := array[]::uuid[];

  for seat_index in 1..array_length(scanned_player_uids, 1) loop
    scanned_uid := app_private.normalize_tag_uid(scanned_player_uids[seat_index]);

    if scanned_uid = '' then
      raise exception 'Each seat requires a player tag.'
        using errcode = 'P0001';
    end if;

    if scanned_uid = any (
      coalesce(scanned_player_uids[1:seat_index - 1], array[]::text[])
    ) then
      raise exception 'Duplicate player tag scanned in the same session setup.'
        using errcode = 'P0001';
    end if;

    select *
    into resolved_tag_row
    from public.nfc_tags
    where owner_user_id = auth.uid()
      and uid_hex = scanned_uid
    for update;

    if not found then
      raise exception 'Unknown player tag. Register player tags during check-in first.'
        using errcode = 'P0001';
    end if;

    if resolved_tag_row.default_tag_type <> 'player' then
      raise exception 'Expected a player tag for seat assignment.'
        using errcode = 'P0001';
    end if;

    select assignment.*
    into resolved_assignment_row
    from public.event_guest_tag_assignments as assignment
    where assignment.event_id = table_row.event_id
      and assignment.nfc_tag_id = resolved_tag_row.id
      and assignment.status = 'assigned'
    for update;

    if not found then
      raise exception 'The scanned player tag is not assigned to an eligible guest in this event.'
        using errcode = 'P0001';
    end if;

    select guest.*
    into resolved_guest_row
    from public.event_guests as guest
    where guest.id = resolved_assignment_row.event_guest_id
    for update;

    if resolved_guest_row.attendance_status <> 'checked_in' then
      raise exception 'All session players must be checked in.'
        using errcode = 'P0001';
    end if;

    if resolved_guest_row.id = any (seat_guest_ids) then
      raise exception 'Duplicate guest scanned in the same session setup.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.table_session_seats as seat
      join public.table_sessions as existing_session
        on existing_session.id = seat.table_session_id
      where seat.event_guest_id = resolved_guest_row.id
        and existing_session.event_id = table_row.event_id
        and existing_session.status in ('active', 'paused')
    ) then
      raise exception 'A scanned guest is already seated in another active session.'
        using errcode = 'P0001';
    end if;

    seat_guest_ids := array_append(seat_guest_ids, resolved_guest_row.id);
  end loop;

  select *
  into ruleset_row
  from public.rulesets
  where id = table_row.default_ruleset_id;

  if not found then
    raise exception 'Default ruleset not found for the selected table.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(session_number_for_table), 0) + 1
  into next_session_number
  from public.table_sessions
  where event_table_id = table_row.id;

  insert into public.table_sessions (
    event_id,
    event_table_id,
    session_number_for_table,
    ruleset_id,
    rotation_policy_type,
    rotation_policy_config_json,
    status,
    initial_east_seat_index,
    current_dealer_seat_index,
    dealer_pass_count,
    completed_games_count,
    hand_count,
    started_at,
    started_by_user_id
  )
  values (
    table_row.event_id,
    table_row.id,
    next_session_number,
    table_row.default_ruleset_id,
    table_row.default_rotation_policy_type,
    table_row.default_rotation_policy_config_json,
    'active',
    0,
    0,
    0,
    0,
    0,
    now(),
    auth.uid()
  )
  returning *
  into session_row;

  for seat_index in 1..array_length(seat_guest_ids, 1) loop
    insert into public.table_session_seats (
      table_session_id,
      seat_index,
      initial_wind,
      event_guest_id
    )
    values (
      session_row.id,
      seat_index - 1,
      initial_winds[seat_index],
      seat_guest_ids[seat_index]
    );
  end loop;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'table_session',
    session_row.id::text,
    'start',
    null,
    to_jsonb(session_row),
    jsonb_build_object(
      'event_table_id', table_row.id,
      'seat_guest_ids', seat_guest_ids,
      'scanned_table_uid', normalized_table_uid
    )
  );

  return session_row;
end;
$$;

select pg_notify('pgrst', 'reload schema');
