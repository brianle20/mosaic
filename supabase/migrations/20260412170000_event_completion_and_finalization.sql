-- Mosaic MVP event completion and finalization
-- Checklist:
--   [x] add lifecycle validation helpers
--   [x] add complete/finalize RPCs
--   [x] enforce closed-event scoring guards
--   [x] enforce finalized-event prize guards
--   [x] audit lifecycle transitions

create or replace function app_private.require_event_for_live_scoring(
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

  if event_row.lifecycle_status in ('completed', 'finalized', 'cancelled') then
    raise exception 'Completed, finalized, or cancelled events cannot start sessions or record hands.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.require_event_for_prize_configuration(
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

  if event_row.lifecycle_status in ('finalized', 'cancelled') then
    raise exception 'Finalized or cancelled events cannot change prize configuration.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.assert_event_has_no_live_sessions(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  live_session_count integer;
begin
  select count(*)
  into live_session_count
  from public.table_sessions as session
  where session.event_id = target_event_id
    and session.status in ('active', 'paused');

  if live_session_count > 0 then
    raise exception '% active or paused session(s) must be ended before changing the event lifecycle.',
      live_session_count
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function app_private.assert_prizes_ready_for_finalization(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  prize_plan_row public.prize_plans%rowtype;
begin
  select prize_plan.*
  into prize_plan_row
  from public.prize_plans as prize_plan
  where prize_plan.event_id = target_event_id
  for update;

  if not found or prize_plan_row.mode = 'none' then
    return;
  end if;

  if prize_plan_row.status <> 'locked' then
    raise exception 'Prize awards must be locked before finalization.'
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.complete_event(
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

  if existing_event.lifecycle_status <> 'active' then
    raise exception 'Only active events can be completed.'
      using errcode = 'P0001';
  end if;

  perform app_private.assert_event_has_no_live_sessions(target_event_id);

  update public.events
  set
    lifecycle_status = 'completed',
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
    'complete',
    to_jsonb(existing_event),
    to_jsonb(updated_event)
  );

  return updated_event;
end;
$$;

create or replace function public.finalize_event(
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

  if existing_event.lifecycle_status <> 'completed' then
    raise exception 'Only completed events can be finalized.'
      using errcode = 'P0001';
  end if;

  perform app_private.assert_event_has_no_live_sessions(target_event_id);
  perform app_private.assert_prizes_ready_for_finalization(target_event_id);

  update public.events
  set
    lifecycle_status = 'finalized',
    checkin_open = false,
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
    'finalize',
    to_jsonb(existing_event),
    to_jsonb(updated_event)
  );

  return updated_event;
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
  perform app_private.require_event_for_live_scoring(table_row.event_id);

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
  perform app_private.require_event_for_live_scoring(session_row.event_id);

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
  perform app_private.require_event_for_live_scoring(session_row.event_id);

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
  perform app_private.require_event_for_live_scoring(session_row.event_id);

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

create or replace function public.upsert_prize_plan(
  target_event_id uuid,
  target_mode text,
  target_reserve_fixed_cents integer default 0,
  target_reserve_percentage_bps integer default 0,
  target_note text default null,
  target_tiers jsonb default '[]'::jsonb
)
returns public.prize_plans
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  existing_plan public.prize_plans%rowtype;
  saved_plan public.prize_plans%rowtype;
  had_existing_plan boolean := false;
begin
  event_row := app_private.require_event_for_prize_configuration(target_event_id);

  perform app_private.validate_prize_plan_input(
    target_mode,
    target_reserve_fixed_cents,
    target_reserve_percentage_bps,
    target_tiers
  );

  select plan.*
  into existing_plan
  from public.prize_plans as plan
  where plan.event_id = target_event_id
  for update;

  had_existing_plan := found;

  if had_existing_plan and existing_plan.status = 'locked' then
    raise exception 'Locked prize plans cannot be edited.'
      using errcode = 'P0001';
  end if;

  if had_existing_plan then
    update public.prize_plans
    set
      mode = target_mode,
      status = 'draft',
      reserve_fixed_cents = target_reserve_fixed_cents,
      reserve_percentage_bps = target_reserve_percentage_bps,
      note = target_note
    where id = existing_plan.id
    returning *
    into saved_plan;
  else
    insert into public.prize_plans (
      event_id,
      mode,
      status,
      reserve_fixed_cents,
      reserve_percentage_bps,
      note,
      created_by_user_id
    )
    values (
      target_event_id,
      target_mode,
      'draft',
      target_reserve_fixed_cents,
      target_reserve_percentage_bps,
      target_note,
      auth.uid()
    )
    returning *
    into saved_plan;
  end if;

  delete from public.prize_tiers
  where prize_plan_id = saved_plan.id;

  insert into public.prize_tiers (
    prize_plan_id,
    place,
    label,
    percentage_bps,
    fixed_amount_cents
  )
  select
    saved_plan.id,
    (tier.value ->> 'place')::integer,
    nullif(tier.value ->> 'label', ''),
    case
      when target_mode = 'percentage' then (tier.value ->> 'percentage_bps')::integer
      else null
    end,
    case
      when target_mode = 'fixed' then (tier.value ->> 'fixed_amount_cents')::integer
      else null
    end
  from jsonb_array_elements(coalesce(target_tiers, '[]'::jsonb)) as tier(value)
  order by (tier.value ->> 'place')::integer;

  perform app_private.insert_audit_log(
    event_row.id,
    'prize_plan',
    saved_plan.id::text,
    case when had_existing_plan then 'update' else 'create' end,
    case when had_existing_plan then to_jsonb(existing_plan) else null end,
    to_jsonb(saved_plan),
    jsonb_build_object('tiers', coalesce(target_tiers, '[]'::jsonb))
  );

  return saved_plan;
end;
$$;

create or replace function public.lock_prize_awards(
  target_event_id uuid
)
returns setof public.prize_awards
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  existing_plan public.prize_plans%rowtype;
  locked_plan public.prize_plans%rowtype;
begin
  event_row := app_private.require_event_for_prize_configuration(target_event_id);

  select plan.*
  into existing_plan
  from public.prize_plans as plan
  where plan.event_id = target_event_id
  for update;

  if not found then
    raise exception 'Prize plan not found for this event.'
      using errcode = 'P0001';
  end if;

  if existing_plan.status = 'locked' then
    return query
    select award.*
    from public.prize_awards as award
    where award.event_id = target_event_id
    order by award.rank_start, award.display_rank, award.event_guest_id;
    return;
  end if;

  delete from public.prize_awards
  where event_id = target_event_id;

  insert into public.prize_awards (
    event_id,
    event_guest_id,
    rank_start,
    rank_end,
    display_rank,
    award_amount_cents
  )
  select
    target_event_id,
    preview.event_guest_id,
    preview.rank_start,
    preview.rank_end,
    preview.display_rank,
    preview.award_amount_cents
  from public.preview_prize_awards(target_event_id) as preview;

  update public.prize_plans
  set status = 'locked'
  where id = existing_plan.id
  returning *
  into locked_plan;

  perform app_private.insert_audit_log(
    event_row.id,
    'prize_plan',
    locked_plan.id::text,
    'lock',
    to_jsonb(existing_plan),
    to_jsonb(locked_plan)
  );

  return query
  select award.*
  from public.prize_awards as award
  where award.event_id = target_event_id
  order by award.rank_start, award.display_rank, award.event_guest_id;
end;
$$;
