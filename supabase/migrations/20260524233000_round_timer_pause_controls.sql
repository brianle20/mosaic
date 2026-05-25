-- Freeze tournament/finals round timers while table sessions are paused.

alter table public.table_sessions
  add column if not exists round_timer_paused_at timestamptz,
  add column if not exists round_timer_paused_seconds integer not null default 0;

alter table public.table_sessions
  drop constraint if exists table_sessions_round_timer_paused_seconds_check;

alter table public.table_sessions
  add constraint table_sessions_round_timer_paused_seconds_check
  check (round_timer_paused_seconds >= 0);

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
    round_timer_paused_at = case
      when existing_session.scoring_phase in ('tournament', 'bonus')
        then now()
      else round_timer_paused_at
    end,
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
    round_timer_paused_seconds = case
      when existing_session.round_timer_paused_at is null
        then round_timer_paused_seconds
      else round_timer_paused_seconds + extract(epoch from (
        now() - existing_session.round_timer_paused_at
      ))::integer
    end,
    round_timer_paused_at = null,
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

create or replace function app_private.recalculate_session_unowned(
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
  dealer_multiplier_1_5_effective_at constant timestamptz :=
    '2026-05-17T18:23:17Z'::timestamptz;
  dealer_compound_cap_effective_at constant timestamptz :=
    '2026-05-19T14:00:00Z'::timestamptz;
  round_time_limit_effective_at constant timestamptz :=
    '2026-05-21T12:00:00Z'::timestamptz;
  round_time_limit_duration constant interval := interval '1 hour';
  recorded_hand_count integer := 0;
  dealer_win_count integer := 0;
  round_time_completed boolean := false;
begin
  select *
  into session_row
  from public.table_sessions
  where id = target_table_session_id
  for update;

  if not found then
    raise exception 'Session not found: %', target_table_session_id
      using errcode = 'P0001';
  end if;

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
      base_points_value := app_private.ruleset_base_points(
        session_row.ruleset_id,
        hand_row.fan_count
      );

      if hand_row.winner_seat_index = current_east then
        if hand_row.entered_at >= dealer_compound_cap_effective_at then
          dealer_win_count := dealer_win_count + 1;

          if dealer_win_count >= 2 then
            east_after := (current_east + 1) % 4;
            dealer_rotated_flag := true;
            next_pass_count := next_pass_count + 1;
            dealer_win_count := 0;
          end if;
        end if;
      else
        east_after := (current_east + 1) % 4;
        dealer_rotated_flag := true;
        next_pass_count := next_pass_count + 1;
        dealer_win_count := 0;
      end if;

      payee_guest_id := seat_guest_ids[hand_row.winner_seat_index + 1];

      for seat_index in 0..3 loop
        if seat_index = hand_row.winner_seat_index then
          continue;
        end if;

        if hand_row.win_type = 'discard'
          and seat_index <> hand_row.discarder_seat_index then
          continue;
        end if;

        multiplier_flags := array[]::text[];
        amount_points_value := base_points_value;

        if hand_row.win_type = 'discard' then
          amount_points_value := amount_points_value * 2;
          multiplier_flags := array_append(multiplier_flags, 'discard');
        end if;

        if hand_row.winner_seat_index = current_east then
          if hand_row.entered_at >= dealer_multiplier_1_5_effective_at then
            amount_points_value := (amount_points_value * 3) / 2;
          else
            amount_points_value := amount_points_value * 2;
          end if;
          multiplier_flags := array_append(multiplier_flags, 'east_wins');
        end if;

        if seat_index = current_east
          and hand_row.winner_seat_index <> current_east then
          if hand_row.entered_at >= dealer_multiplier_1_5_effective_at then
            amount_points_value := (amount_points_value * 3) / 2;
          else
            amount_points_value := amount_points_value * 2;
          end if;
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
    elsif hand_row.result_type = 'false_win_penalty' then
      base_points_value :=
        app_private.ruleset_base_points(session_row.ruleset_id, 6);
      payer_guest_id := seat_guest_ids[hand_row.penalty_seat_index + 1];

      for seat_index in 0..3 loop
        if seat_index = hand_row.penalty_seat_index then
          continue;
        end if;

        payee_guest_id := seat_guest_ids[seat_index + 1];

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
          base_points_value,
          to_jsonb(array['false_win_penalty']::text[])
        );
      end loop;
    elsif hand_row.result_type = 'washout'
      and hand_row.dealer_was_waiting_at_draw is false then
      east_after := (current_east + 1) % 4;
      dealer_rotated_flag := true;
      next_pass_count := next_pass_count + 1;
      dealer_win_count := 0;
    end if;

    if east_after = initial_east and next_pass_count >= 4 then
      completion_flag := true;
    end if;

    if not round_time_completed
      and session_row.scoring_phase in ('tournament', 'bonus')
      and hand_row.entered_at >= round_time_limit_effective_at
      and hand_row.entered_at >=
        session_row.started_at + round_time_limit_duration +
        make_interval(secs => session_row.round_timer_paused_seconds) then
      completion_flag := true;
      round_time_completed := true;
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
      when round_time_completed then 'completed'
      when current_east = initial_east and next_pass_count >= 4 then 'completed'
      when session_row.status = 'paused' then 'paused'
      else 'active'
    end,
    ended_at = case
      when session_row.status in ('ended_early', 'aborted') then session_row.ended_at
      when round_time_completed then coalesce(session_row.ended_at, now())
      when current_east = initial_east and next_pass_count >= 4 then coalesce(session_row.ended_at, now())
      else null
    end,
    ended_by_user_id = case
      when session_row.status in ('ended_early', 'aborted') then session_row.ended_by_user_id
      when round_time_completed then coalesce(session_row.ended_by_user_id, auth.uid())
      when current_east = initial_east and next_pass_count >= 4 then coalesce(session_row.ended_by_user_id, auth.uid())
      else null
    end,
    end_reason = case
      when session_row.status in ('ended_early', 'aborted') then session_row.end_reason
      when round_time_completed then null
      when current_east = initial_east and next_pass_count >= 4 then null
      else null
    end,
    round_timer_paused_at = case
      when round_time_completed
        or (current_east = initial_east and next_pass_count >= 4)
        then null
      else session_row.round_timer_paused_at
    end
  where id = session_row.id
  returning *
  into updated_session;

  perform app_private.refresh_event_score_totals(updated_session.event_id);
  perform app_private.apply_bonus_round_champion_award(updated_session.id);

  return updated_session;
end;
$$;

select pg_notify('pgrst', 'reload schema');
