-- Mosaic MVP live operations controls
-- Checklist:
--   [x] add event operational guard helpers
--   [x] add start/operational flag RPCs
--   [x] gate check-in and tag assignment on check-in open
--   [x] gate session start and hand writes on scoring open

create or replace function app_private.require_event_for_checkin(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  event_row := app_private.require_owned_event(target_event_id);

  if event_row.lifecycle_status <> 'active' then
    raise exception 'Check-in is only available while the event is active.'
      using errcode = 'P0001';
  end if;

  if not event_row.checkin_open then
    raise exception 'Check-in is closed for this event.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.require_event_for_scoring(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  event_row := app_private.require_owned_event(target_event_id);

  if event_row.lifecycle_status <> 'active' then
    raise exception 'Scoring is only available while the event is active.'
      using errcode = 'P0001';
  end if;

  if not event_row.scoring_open then
    raise exception 'Scoring is closed for this event.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.require_event_for_live_scoring(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
begin
  return app_private.require_event_for_scoring(target_event_id);
end;
$$;

create or replace function public.start_event(
  target_event_id uuid
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

  if existing_event.lifecycle_status <> 'draft' then
    raise exception 'Only draft events can be started.'
      using errcode = 'P0001';
  end if;

  update public.events
  set
    lifecycle_status = 'active',
    checkin_open = true,
    scoring_open = false,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_event.id
  returning *
  into updated_event;

  perform app_private.insert_audit_log(
    updated_event.id,
    'event',
    updated_event.id::text,
    'start',
    to_jsonb(existing_event),
    to_jsonb(updated_event)
  );

  return updated_event;
end;
$$;

create or replace function public.set_event_operational_flags(
  target_event_id uuid,
  target_checkin_open boolean,
  target_scoring_open boolean
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

  if existing_event.lifecycle_status <> 'active' then
    raise exception 'Operational flags can only change while the event is active.'
      using errcode = 'P0001';
  end if;

  update public.events
  set
    checkin_open = target_checkin_open,
    scoring_open = target_scoring_open,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_event.id
  returning *
  into updated_event;

  perform app_private.insert_audit_log(
    updated_event.id,
    'event',
    updated_event.id::text,
    'set_operational_flags',
    to_jsonb(existing_event),
    to_jsonb(updated_event),
    jsonb_build_object(
      'checkin_open', target_checkin_open,
      'scoring_open', target_scoring_open
    )
  );

  return updated_event;
end;
$$;

create or replace function public.check_in_guest(
  target_event_guest_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  updated_guest public.event_guests%rowtype;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);
  perform app_private.require_event_for_checkin(guest_row.event_id);

  update public.event_guests
  set
    attendance_status = 'checked_in',
    checked_in_at = coalesce(checked_in_at, now())
  where id = guest_row.id
  returning *
  into updated_guest;

  perform app_private.insert_audit_log(
    updated_guest.event_id,
    'event_guest',
    updated_guest.id::text,
    'check_in',
    to_jsonb(guest_row),
    to_jsonb(updated_guest)
  );

  return updated_guest;
end;
$$;

create or replace function public.assign_guest_tag(
  target_event_guest_id uuid,
  scanned_uid text,
  scanned_display_label text default null
)
returns table (
  assignment_id uuid,
  event_id uuid,
  event_guest_id uuid,
  status text,
  assigned_at timestamptz,
  nfc_tag jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  tag_row public.nfc_tags%rowtype;
  existing_assignment_id uuid;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);
  perform app_private.require_event_for_checkin(guest_row.event_id);

  if guest_row.cover_status not in ('paid', 'comped') then
    raise exception 'Guest must be paid or comped before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  if guest_row.attendance_status <> 'checked_in' then
    raise exception 'Guest must be checked in before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  select assignment.id
  into existing_assignment_id
  from public.event_guest_tag_assignments as assignment
  where assignment.event_guest_id = guest_row.id
    and assignment.event_id = guest_row.event_id
    and assignment.status = 'assigned'
  limit 1;

  if existing_assignment_id is not null then
    raise exception 'This guest already has an active player tag.'
      using errcode = 'P0001';
  end if;

  tag_row := app_private.ensure_player_tag(scanned_uid, scanned_display_label);

  if exists (
    select 1
    from public.event_guest_tag_assignments as assignment
    where assignment.event_id = guest_row.event_id
      and assignment.nfc_tag_id = tag_row.id
      and assignment.status = 'assigned'
  ) then
    raise exception 'This tag is already assigned to another guest in this event.'
      using errcode = 'P0001';
  end if;

  insert into public.event_guest_tag_assignments (
    event_id,
    event_guest_id,
    nfc_tag_id,
    status,
    assigned_at,
    assigned_by_user_id
  )
  values (
    guest_row.event_id,
    guest_row.id,
    tag_row.id,
    'assigned',
    now(),
    auth.uid()
  );

  perform app_private.insert_audit_log(
    guest_row.event_id,
    'event_guest_tag_assignment',
    guest_row.id::text,
    'assign',
    null,
    jsonb_build_object(
      'event_guest_id', guest_row.id,
      'nfc_tag_id', tag_row.id,
      'uid_hex', tag_row.uid_hex
    )
  );

  return query
  select *
  from public.get_guest_tag_assignment_summary(guest_row.id);
end;
$$;

create or replace function public.replace_guest_tag(
  target_event_guest_id uuid,
  scanned_uid text,
  scanned_display_label text default null
)
returns table (
  assignment_id uuid,
  event_id uuid,
  event_guest_id uuid,
  status text,
  assigned_at timestamptz,
  nfc_tag jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  current_assignment public.event_guest_tag_assignments%rowtype;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);
  perform app_private.require_event_for_checkin(guest_row.event_id);

  if guest_row.cover_status not in ('paid', 'comped') then
    raise exception 'Guest must be paid or comped before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  if guest_row.attendance_status <> 'checked_in' then
    raise exception 'Guest must be checked in before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  select *
  into current_assignment
  from public.event_guest_tag_assignments
  where event_guest_id = guest_row.id
    and event_id = guest_row.event_id
    and status = 'assigned'
  for update;

  if not found then
    raise exception 'Guest does not have an active tag to replace.'
      using errcode = 'P0001';
  end if;

  update public.event_guest_tag_assignments
  set
    status = 'replaced',
    released_at = now(),
    release_reason = 'replaced'
  where id = current_assignment.id;

  return query
  select *
  from public.assign_guest_tag(
    target_event_guest_id,
    scanned_uid,
    scanned_display_label
  );
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
    ruleset_version,
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
    ruleset_row.id,
    ruleset_row.version,
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
    table_row.event_id,
    'table_session',
    session_row.id::text,
    'start',
    null,
    to_jsonb(session_row),
    jsonb_build_object(
      'event_table_id', table_row.id,
      'seat_guest_ids', to_jsonb(seat_guest_ids),
      'ruleset_id', session_row.ruleset_id,
      'rotation_policy_type', session_row.rotation_policy_type
    )
  );

  perform app_private.refresh_event_score_totals(table_row.event_id);

  return session_row;
end;
$$;

create or replace function public.record_hand_result(
  target_table_session_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  inserted_hand public.hand_results%rowtype;
  next_hand_number integer;
begin
  session_row := app_private.require_owned_session(target_table_session_id);
  perform app_private.require_event_for_scoring(session_row.event_id);

  if session_row.status <> 'active' then
    raise exception 'Hands can only be recorded for active sessions.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count
  );

  select coalesce(max(hand_number), 0) + 1
  into next_hand_number
  from public.hand_results
  where table_session_id = session_row.id;

  insert into public.hand_results (
    table_session_id,
    hand_number,
    result_type,
    winner_seat_index,
    win_type,
    discarder_seat_index,
    fan_count,
    base_points,
    east_seat_index_before_hand,
    east_seat_index_after_hand,
    dealer_rotated,
    session_completed_after_hand,
    status,
    entered_by_user_id,
    entered_at,
    correction_note
  )
  values (
    session_row.id,
    next_hand_number,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    null,
    session_row.current_dealer_seat_index,
    session_row.current_dealer_seat_index,
    false,
    false,
    'recorded',
    auth.uid(),
    now(),
    target_correction_note
  )
  returning *
  into inserted_hand;

  perform public.recalculate_session(session_row.id);

  select *
  into inserted_hand
  from public.hand_results
  where id = inserted_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    inserted_hand.id::text,
    'create',
    null,
    to_jsonb(inserted_hand)
  );

  return inserted_hand;
end;
$$;

create or replace function public.edit_hand_result(
  target_hand_result_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_hand public.hand_results%rowtype;
  updated_hand public.hand_results%rowtype;
  session_row public.table_sessions%rowtype;
begin
  existing_hand := app_private.require_owned_hand_result(target_hand_result_id);
  session_row := app_private.require_owned_session(existing_hand.table_session_id);
  perform app_private.require_event_for_scoring(session_row.event_id);

  if existing_hand.status <> 'recorded' then
    raise exception 'Only recorded hands can be edited.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count
  );

  update public.hand_results
  set
    result_type = target_result_type,
    winner_seat_index = target_winner_seat_index,
    win_type = target_win_type,
    discarder_seat_index = target_discarder_seat_index,
    fan_count = target_fan_count,
    correction_note = target_correction_note
  where id = existing_hand.id
  returning *
  into updated_hand;

  perform public.recalculate_session(session_row.id);

  select *
  into updated_hand
  from public.hand_results
  where id = updated_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    updated_hand.id::text,
    'edit',
    to_jsonb(existing_hand),
    to_jsonb(updated_hand)
  );

  return updated_hand;
end;
$$;

create or replace function public.void_hand_result(
  target_hand_result_id uuid,
  target_correction_note text default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_hand public.hand_results%rowtype;
  updated_hand public.hand_results%rowtype;
  session_row public.table_sessions%rowtype;
begin
  existing_hand := app_private.require_owned_hand_result(target_hand_result_id);
  session_row := app_private.require_owned_session(existing_hand.table_session_id);
  perform app_private.require_event_for_scoring(session_row.event_id);

  if existing_hand.status = 'voided' then
    return existing_hand;
  end if;

  update public.hand_results
  set
    status = 'voided',
    correction_note = coalesce(target_correction_note, correction_note)
  where id = existing_hand.id
  returning *
  into updated_hand;

  perform public.recalculate_session(session_row.id);

  select *
  into updated_hand
  from public.hand_results
  where id = updated_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    updated_hand.id::text,
    'void',
    to_jsonb(existing_hand),
    to_jsonb(updated_hand)
  );

  return updated_hand;
end;
$$;

create or replace function public.pause_table_session(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_session public.table_sessions%rowtype;
  updated_session public.table_sessions%rowtype;
begin
  existing_session := app_private.require_owned_session(target_table_session_id);

  if existing_session.status <> 'active' then
    raise exception 'Only active sessions can be paused.'
      using errcode = 'P0001';
  end if;

  update public.table_sessions
  set
    status = 'paused',
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_session.id
  returning *
  into updated_session;

  perform app_private.insert_audit_log(
    updated_session.event_id,
    'table_session',
    updated_session.id::text,
    'pause',
    to_jsonb(existing_session),
    to_jsonb(updated_session)
  );

  return updated_session;
end;
$$;

create or replace function public.resume_table_session(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_session public.table_sessions%rowtype;
  updated_session public.table_sessions%rowtype;
begin
  existing_session := app_private.require_owned_session(target_table_session_id);
  perform app_private.require_event_for_scoring(existing_session.event_id);

  if existing_session.status <> 'paused' then
    raise exception 'Only paused sessions can be resumed.'
      using errcode = 'P0001';
  end if;

  update public.table_sessions
  set
    status = 'active',
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_session.id
  returning *
  into updated_session;

  perform app_private.insert_audit_log(
    updated_session.event_id,
    'table_session',
    updated_session.id::text,
    'resume',
    to_jsonb(existing_session),
    to_jsonb(updated_session)
  );

  return updated_session;
end;
$$;

create or replace function public.end_table_session(
  target_table_session_id uuid,
  target_end_reason text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_session public.table_sessions%rowtype;
  updated_session public.table_sessions%rowtype;
  normalized_end_reason text;
begin
  existing_session := app_private.require_owned_session(target_table_session_id);
  normalized_end_reason := trim(coalesce(target_end_reason, ''));

  if existing_session.status not in ('active', 'paused') then
    raise exception 'Only active or paused sessions can end early.'
      using errcode = 'P0001';
  end if;

  if normalized_end_reason = '' then
    raise exception 'An end reason is required.'
      using errcode = 'P0001';
  end if;

  update public.table_sessions
  set
    status = 'ended_early',
    ended_at = coalesce(ended_at, now()),
    ended_by_user_id = auth.uid(),
    end_reason = normalized_end_reason,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_session.id
  returning *
  into updated_session;

  perform app_private.insert_audit_log(
    updated_session.event_id,
    'table_session',
    updated_session.id::text,
    'end_early',
    to_jsonb(existing_session),
    to_jsonb(updated_session),
    jsonb_build_object('reason', normalized_end_reason)
  );

  return updated_session;
end;
$$;
