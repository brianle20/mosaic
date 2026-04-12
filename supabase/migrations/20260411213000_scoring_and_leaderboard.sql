-- Mosaic MVP scoring and leaderboard
-- Checklist:
--   [x] add owned session/hand helpers
--   [x] add HK fan bucket and multiplier helpers
--   [x] add shared session recalculation
--   [x] add hand record/edit/void RPCs
--   [x] add leaderboard query RPC
--   [x] refresh event score totals from server truth

create or replace function app_private.require_owned_session(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
begin
  select session.*
  into session_row
  from public.table_sessions as session
  join public.events as event
    on event.id = session.event_id
  where session.id = target_table_session_id
    and event.owner_user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Session not found for current host.'
      using errcode = 'P0001';
  end if;

  return session_row;
end;
$$;

create or replace function app_private.require_owned_hand_result(
  target_hand_result_id uuid
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  hand_row public.hand_results%rowtype;
begin
  select hand_result.*
  into hand_row
  from public.hand_results as hand_result
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  join public.events as event
    on event.id = session.event_id
  where hand_result.id = target_hand_result_id
    and event.owner_user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Hand result not found for current host.'
      using errcode = 'P0001';
  end if;

  return hand_row;
end;
$$;

create or replace function app_private.hk_base_points(
  target_fan_count integer
)
returns integer
language sql
immutable
as $$
  select case
    when target_fan_count < 0 then null
    when target_fan_count = 0 then 1
    when target_fan_count = 1 then 2
    when target_fan_count = 2 then 4
    when target_fan_count = 3 then 8
    when target_fan_count between 4 and 6 then 16
    when target_fan_count between 7 and 9 then 32
    when target_fan_count between 10 and 12 then 64
    else 128
  end
$$;

create or replace function app_private.validate_hand_result_input(
  target_result_type text,
  target_winner_seat_index integer,
  target_win_type text,
  target_discarder_seat_index integer,
  target_fan_count integer
)
returns void
language plpgsql
immutable
as $$
begin
  if target_result_type not in ('win', 'washout') then
    raise exception 'Hand result type must be win or washout.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'washout' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null
      or target_fan_count is not null then
      raise exception 'Washout hands cannot include winner, win type, discarder, or fan count.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_winner_seat_index is null
    or target_winner_seat_index not between 0 and 3 then
    raise exception 'Win hands require a valid winner seat.'
      using errcode = 'P0001';
  end if;

  if target_fan_count is null or target_fan_count < 0 then
    raise exception 'Win hands require a non-negative fan count.'
      using errcode = 'P0001';
  end if;

  if target_win_type not in ('discard', 'self_draw') then
    raise exception 'Win hands require a win type of discard or self_draw.'
      using errcode = 'P0001';
  end if;

  if target_win_type = 'discard' then
    if target_discarder_seat_index is null
      or target_discarder_seat_index not between 0 and 3 then
      raise exception 'Discard wins require a valid discarder seat.'
        using errcode = 'P0001';
    end if;

    if target_discarder_seat_index = target_winner_seat_index then
      raise exception 'Discarder seat must be different from winner seat.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_discarder_seat_index is not null then
    raise exception 'Self-draw wins cannot include a discarder seat.'
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function app_private.refresh_event_score_totals(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.event_score_totals
  where event_id = target_event_id;

  insert into public.event_score_totals (
    event_id,
    event_guest_id,
    total_points,
    hands_won,
    self_draw_wins,
    discard_wins,
    sessions_started,
    sessions_completed
  )
  with guest_base as (
    select
      guest.id as event_guest_id,
      guest.event_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
  ),
  points_totals as (
    select
      guest_base.event_guest_id,
      coalesce(sum(case when settlement.payee_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0)
      - coalesce(sum(case when settlement.payer_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0) as total_points
    from guest_base
    left join public.hand_settlements as settlement
      on settlement.payee_event_guest_id = guest_base.event_guest_id
      or settlement.payer_event_guest_id = guest_base.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.id = settlement.hand_result_id
    left join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where session.event_id = target_event_id or session.id is null
    group by guest_base.event_guest_id
  ),
  hand_win_totals as (
    select
      seat.event_guest_id,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index) as hands_won,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'self_draw') as self_draw_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'discard') as discard_wins
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  ),
  session_counts as (
    select
      seat.event_guest_id,
      count(distinct session.id) as sessions_started,
      count(distinct session.id) filter (where session.status = 'completed') as sessions_completed
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    where session.event_id = target_event_id
    group by seat.event_guest_id
  )
  select
    target_event_id,
    guest_base.event_guest_id,
    coalesce(points_totals.total_points, 0),
    coalesce(hand_win_totals.hands_won, 0),
    coalesce(hand_win_totals.self_draw_wins, 0),
    coalesce(hand_win_totals.discard_wins, 0),
    coalesce(session_counts.sessions_started, 0),
    coalesce(session_counts.sessions_completed, 0)
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join hand_win_totals
    on hand_win_totals.event_guest_id = guest_base.event_guest_id
  left join session_counts
    on session_counts.event_guest_id = guest_base.event_guest_id;

  update public.event_guests as guest
  set has_scored_play = exists (
    select 1
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = guest.event_id
      and seat.event_guest_id = guest.id
      and hand_result.status = 'recorded'
  )
  where guest.event_id = target_event_id;
end;
$$;

create or replace function public.recalculate_session(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  updated_session public.table_sessions%rowtype;
  hand_row public.hand_results%rowtype;
  seat_guest_ids uuid[];
  initial_east integer;
  current_east integer;
  east_after integer;
  next_pass_count integer;
  dealer_rotated_flag boolean;
  completion_flag boolean;
  base_points_value integer;
  seat_index integer;
  amount_points_value integer;
  payer_guest_id uuid;
  payee_guest_id uuid;
  multiplier_flags text[];
  recorded_hand_count integer := 0;
begin
  session_row := app_private.require_owned_session(target_table_session_id);

  select array_agg(seat.event_guest_id order by seat.seat_index)
  into seat_guest_ids
  from public.table_session_seats as seat
  where seat.table_session_id = session_row.id;

  if seat_guest_ids is null or array_length(seat_guest_ids, 1) <> 4 then
    raise exception 'Session is missing seat assignments.'
      using errcode = 'P0001';
  end if;

  delete from public.hand_settlements as settlement
  using public.hand_results as hand_result
  where settlement.hand_result_id = hand_result.id
    and hand_result.table_session_id = session_row.id;

  initial_east := session_row.initial_east_seat_index;
  current_east := initial_east;
  next_pass_count := 0;

  for hand_row in
    select *
    from public.hand_results
    where table_session_id = session_row.id
      and status = 'recorded'
    order by hand_number asc
  loop
    recorded_hand_count := recorded_hand_count + 1;
    dealer_rotated_flag := false;
    completion_flag := false;
    base_points_value := null;
    east_after := current_east;

    if hand_row.result_type = 'win' then
      base_points_value := app_private.hk_base_points(hand_row.fan_count);

      if hand_row.winner_seat_index <> current_east then
        east_after := (current_east + 1) % 4;
        dealer_rotated_flag := true;
        next_pass_count := next_pass_count + 1;
      end if;

      payee_guest_id := seat_guest_ids[hand_row.winner_seat_index + 1];

      for seat_index in 0..3 loop
        if seat_index = hand_row.winner_seat_index then
          continue;
        end if;

        multiplier_flags := array[]::text[];
        amount_points_value := base_points_value;

        if hand_row.win_type = 'discard'
          and seat_index = hand_row.discarder_seat_index then
          amount_points_value := amount_points_value * 2;
          multiplier_flags := array_append(multiplier_flags, 'discard');
        end if;

        if hand_row.win_type = 'self_draw' then
          amount_points_value := amount_points_value * 2;
          multiplier_flags := array_append(multiplier_flags, 'self_draw');
        end if;

        if hand_row.winner_seat_index = current_east then
          amount_points_value := amount_points_value * 2;
          multiplier_flags := array_append(multiplier_flags, 'east_wins');
        end if;

        if seat_index = current_east
          and hand_row.winner_seat_index <> current_east then
          amount_points_value := amount_points_value * 2;
          multiplier_flags := array_append(multiplier_flags, 'east_loses');
        end if;

        payer_guest_id := seat_guest_ids[seat_index + 1];

        insert into public.hand_settlements (
          hand_result_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          payer_guest_id,
          payee_guest_id,
          amount_points_value,
          to_jsonb(multiplier_flags)
        );
      end loop;
    end if;

    if east_after = initial_east and next_pass_count >= 4 then
      completion_flag := true;
    end if;

    update public.hand_results
    set
      base_points = base_points_value,
      east_seat_index_before_hand = current_east,
      east_seat_index_after_hand = east_after,
      dealer_rotated = dealer_rotated_flag,
      session_completed_after_hand = completion_flag
    where id = hand_row.id;

    current_east := east_after;
  end loop;

  update public.table_sessions
  set
    current_dealer_seat_index = current_east,
    dealer_pass_count = next_pass_count,
    completed_games_count = recorded_hand_count,
    hand_count = recorded_hand_count,
    status = case
      when session_row.status in ('ended_early', 'aborted') then session_row.status
      when current_east = initial_east and next_pass_count >= 4 then 'completed'
      else 'active'
    end,
    ended_at = case
      when session_row.status in ('ended_early', 'aborted') then session_row.ended_at
      when current_east = initial_east and next_pass_count >= 4 then coalesce(session_row.ended_at, now())
      else null
    end,
    ended_by_user_id = case
      when session_row.status in ('ended_early', 'aborted') then session_row.ended_by_user_id
      when current_east = initial_east and next_pass_count >= 4 then coalesce(session_row.ended_by_user_id, auth.uid())
      else null
    end,
    end_reason = case
      when session_row.status in ('ended_early', 'aborted') then session_row.end_reason
      when current_east = initial_east and next_pass_count >= 4 then null
      else null
    end
  where id = session_row.id
  returning *
  into updated_session;

  perform app_private.refresh_event_score_totals(updated_session.event_id);

  return updated_session;
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

create or replace function public.get_event_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  total_points integer,
  hands_won integer,
  self_draw_wins integer,
  discard_wins integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  select
    score.event_guest_id,
    guest.display_name,
    score.total_points,
    score.hands_won,
    score.self_draw_wins,
    score.discard_wins,
    dense_rank() over (order by score.total_points desc) as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
  where score.event_id = target_event_id
    and app_private.is_event_owner(target_event_id)
  order by score.total_points desc, guest.display_name asc;
$$;
