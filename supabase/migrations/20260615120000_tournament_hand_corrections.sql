create or replace function app_private.require_event_for_hand_correction(
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
  select event.*
  into event_row
  from public.events as event
  where event.id = target_event_id
    and app_private.can_score_tournament(event.id);

  if not found then
    raise exception 'Event not found for current scorer.'
      using errcode = 'P0001';
  end if;

  if event_row.lifecycle_status not in ('active', 'completed') then
    raise exception 'Hand corrections are only available for active or completed events.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function public.record_hand_result(
  target_table_session_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
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
    session_row.ruleset_id,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    target_dealer_was_waiting_at_draw,
    target_penalty_seat_index
  );

  select coalesce(max(hand_number), 0) + 1
  into next_hand_number
  from public.hand_results
  where
    table_session_id = session_row.id
    and status = 'recorded';

  insert into public.hand_results (
    table_session_id,
    hand_number,
    result_type,
    winner_seat_index,
    win_type,
    discarder_seat_index,
    penalty_seat_index,
    fan_count,
    base_points,
    dealer_was_waiting_at_draw,
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
    target_penalty_seat_index,
    case
      when target_result_type = 'false_win_penalty' then 6
      else target_fan_count
    end,
    null,
    case
      when target_result_type = 'washout' then target_dealer_was_waiting_at_draw
      else null
    end,
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
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

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
  target_correction_note text default null,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
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
  perform app_private.require_event_for_hand_correction(session_row.event_id);

  if existing_hand.status <> 'recorded' then
    raise exception 'Only recorded hands can be edited.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    session_row.ruleset_id,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    target_dealer_was_waiting_at_draw,
    target_penalty_seat_index
  );

  update public.hand_results
  set
    result_type = target_result_type,
    winner_seat_index = target_winner_seat_index,
    win_type = target_win_type,
    discarder_seat_index = target_discarder_seat_index,
    penalty_seat_index = target_penalty_seat_index,
    fan_count = case
      when target_result_type = 'false_win_penalty' then 6
      else target_fan_count
    end,
    dealer_was_waiting_at_draw = case
      when target_result_type = 'washout' then target_dealer_was_waiting_at_draw
      else null
    end,
    correction_note = target_correction_note
  where id = existing_hand.id
  returning *
  into updated_hand;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

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
  perform app_private.require_event_for_hand_correction(session_row.event_id);

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
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

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

select pg_notify('pgrst', 'reload schema');
