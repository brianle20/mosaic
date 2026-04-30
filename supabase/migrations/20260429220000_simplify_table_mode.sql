-- Keep tables as physical seating locations; session mode belongs on future sessions.

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'event_tables'
      and column_name = 'mode'
  ) then
    execute 'alter table public.event_tables drop constraint if exists event_tables_mode_check';
    execute 'alter table public.event_tables drop column mode';
  end if;
end;
$$;

alter table public.event_tables
  drop column if exists status;

drop function if exists public.create_event_table(
  uuid,
  text,
  integer,
  text,
  text,
  jsonb
);

drop function if exists public.create_event_table(
  uuid,
  text,
  text,
  integer,
  text,
  text,
  jsonb
);

create or replace function public.create_event_table(
  target_event_id uuid,
  table_label text,
  table_display_order integer default 0,
  target_default_ruleset_id text default 'HK_STANDARD',
  target_default_rotation_policy_type text default 'dealer_cycle_return_to_initial_east',
  target_default_rotation_policy_config_json jsonb default '{}'::jsonb
)
returns public.event_tables
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_table public.event_tables%rowtype;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  insert into public.event_tables (
    event_id,
    label,
    display_order,
    default_ruleset_id,
    default_rotation_policy_type,
    default_rotation_policy_config_json
  )
  values (
    target_event_id,
    trim(table_label),
    coalesce(table_display_order, 0),
    target_default_ruleset_id,
    target_default_rotation_policy_type,
    coalesce(target_default_rotation_policy_config_json, '{}'::jsonb)
  )
  returning *
  into inserted_table;

  perform app_private.insert_audit_log(
    inserted_table.event_id,
    'event_table',
    inserted_table.id::text,
    'create',
    null,
    to_jsonb(inserted_table)
  );

  return inserted_table;
end;
$$;

drop function if exists public.update_event_table(
  uuid,
  text,
  integer
);

drop function if exists public.update_event_table(
  uuid,
  text,
  text,
  integer
);

create or replace function public.update_event_table(
  target_event_table_id uuid,
  table_label text,
  table_display_order integer default 0
)
returns public.event_tables
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_table public.event_tables%rowtype;
  updated_table public.event_tables%rowtype;
begin
  existing_table := app_private.require_owned_table(target_event_table_id);

  update public.event_tables
  set
    label = trim(table_label),
    display_order = coalesce(table_display_order, 0)
  where id = existing_table.id
  returning *
  into updated_table;

  perform app_private.insert_audit_log(
    updated_table.event_id,
    'event_table',
    updated_table.id::text,
    'update',
    to_jsonb(existing_table),
    to_jsonb(updated_table)
  );

  return updated_table;
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

  if table_row.nfc_tag_id is null then
    raise exception 'A bound table tag is required before starting a session.'
      using errcode = 'P0001';
  end if;

  normalized_table_uid := app_private.normalize_tag_uid(scanned_table_uid);

  select uid_hex
  into bound_tag_uid
  from public.nfc_tags
  where id = table_row.nfc_tag_id;

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
    where uid_hex = scanned_uid
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
