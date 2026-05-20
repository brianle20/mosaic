-- Record false win penalties as hands: caller pays every other player 6 fan.

alter table public.hand_results
  add column if not exists penalty_seat_index integer;

alter table public.hand_results
  drop constraint if exists hand_results_penalty_seat_index_check;

alter table public.hand_results
  add constraint hand_results_penalty_seat_index_check
  check (penalty_seat_index is null or penalty_seat_index between 0 and 3);

alter table public.hand_results
  drop constraint if exists hand_results_result_type_check;

alter table public.hand_results
  add constraint hand_results_result_type_check
  check (result_type in ('win', 'washout', 'false_win_penalty'));

alter table public.hand_results
  drop constraint if exists hand_results_check;

alter table public.hand_results
  drop constraint if exists hand_results_result_shape_check;

alter table public.hand_results
  drop constraint if exists hand_results_shape_check;

alter table public.hand_results
  add constraint hand_results_shape_check
  check (
    (
      result_type = 'washout'
      and winner_seat_index is null
      and win_type is null
      and discarder_seat_index is null
      and penalty_seat_index is null
      and fan_count is null
      and base_points is null
    )
    or
    (
      result_type = 'win'
      and winner_seat_index is not null
      and penalty_seat_index is null
      and fan_count is not null
      and fan_count >= 3
      and win_type is not null
      and (
        (
          win_type = 'discard'
          and discarder_seat_index is not null
          and discarder_seat_index <> winner_seat_index
        )
        or
        (
          win_type = 'self_draw'
          and discarder_seat_index is null
        )
      )
    )
    or
    (
      result_type = 'false_win_penalty'
      and winner_seat_index is null
      and win_type is null
      and discarder_seat_index is null
      and penalty_seat_index is not null
      and fan_count = 6
    )
  );

alter table public.hand_results
  drop constraint if exists hand_results_dealer_waiting_draw_check;

alter table public.hand_results
  add constraint hand_results_dealer_waiting_draw_check
  check (
    result_type = 'washout'
    or dealer_was_waiting_at_draw is null
  );

drop function if exists app_private.validate_hand_result_input(
  text,
  text,
  integer,
  text,
  integer,
  integer,
  boolean
);

create or replace function app_private.validate_hand_result_input(
  target_ruleset_id text,
  target_result_type text,
  target_winner_seat_index integer,
  target_win_type text,
  target_discarder_seat_index integer,
  target_fan_count integer,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
)
returns void
language plpgsql
stable
as $$
declare
  minimum_fan integer;
begin
  if target_result_type not in ('win', 'washout', 'false_win_penalty') then
    raise exception 'Hand result type must be win, washout, or false_win_penalty.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'washout' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null
      or target_penalty_seat_index is not null
      or target_fan_count is not null then
      raise exception 'Draw hands cannot include winner, win type, discarder, penalty caller, or fan count.'
        using errcode = 'P0001';
    end if;

    if target_dealer_was_waiting_at_draw is null then
      raise exception 'Select whether dealer was waiting.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_dealer_was_waiting_at_draw is not null then
    raise exception 'Only draw hands can include dealer waiting state.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'false_win_penalty' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null then
      raise exception 'False win penalties cannot include winner, win type, or discarder.'
        using errcode = 'P0001';
    end if;

    if target_penalty_seat_index is null
      or target_penalty_seat_index not between 0 and 3 then
      raise exception 'False win penalties require a valid caller seat.'
        using errcode = 'P0001';
    end if;

    if target_fan_count is not null and target_fan_count <> 6 then
      raise exception 'False win penalties are fixed at 6 fan.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_penalty_seat_index is not null then
    raise exception 'Win hands cannot include a false win caller.'
      using errcode = 'P0001';
  end if;

  if target_winner_seat_index is null
    or target_winner_seat_index not between 0 and 3 then
    raise exception 'Win hands require a valid winner seat.'
      using errcode = 'P0001';
  end if;

  minimum_fan := app_private.ruleset_minimum_winning_fan(target_ruleset_id);

  if target_fan_count is null or target_fan_count < minimum_fan then
    raise exception 'Win hands require at least % fan.', minimum_fan
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
    raise exception 'Self-draw wins cannot include a discarder.'
      using errcode = 'P0001';
  end if;
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
  recorded_hand_count integer := 0;
  dealer_win_count integer := 0;
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
      base_points_value := app_private.ruleset_base_points(session_row.ruleset_id, 6);
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

drop function if exists public.record_hand_result(
  uuid,
  text,
  integer,
  text,
  integer,
  integer,
  text,
  boolean
);

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

drop function if exists public.edit_hand_result(
  uuid,
  text,
  integer,
  text,
  integer,
  integer,
  text,
  boolean
);

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
  perform app_private.require_event_for_scoring(session_row.event_id);

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

drop function if exists public.list_event_hand_ledger(uuid);

create or replace function public.list_event_hand_ledger(target_event_id uuid)
returns table (
  event_id uuid,
  table_id uuid,
  table_label text,
  session_id uuid,
  session_number_for_table integer,
  hand_id uuid,
  hand_number integer,
  entered_at timestamptz,
  result_type text,
  status text,
  win_type text,
  fan_count integer,
  penalty_seat_index integer,
  has_settlements boolean,
  cells jsonb
)
language sql
security definer
set search_path = public, app_private
as $$
  with authorized_event as (
    select event.id
    from public.events as event
    where event.id = target_event_id
      and app_private.is_event_owner(target_event_id)
  ),
  hand_rows as (
    select
      session.event_id,
      event_table.id as table_id,
      event_table.label as table_label,
      session.id as session_id,
      session.session_number_for_table,
      hand_result.id as hand_id,
      hand_result.hand_number,
      hand_result.entered_at,
      hand_result.result_type,
      hand_result.status,
      hand_result.win_type,
      hand_result.fan_count,
      hand_result.penalty_seat_index,
      hand_result.east_seat_index_before_hand,
      exists (
        select 1
        from public.hand_settlements as settlement
        where settlement.hand_result_id = hand_result.id
      ) as has_settlements
    from authorized_event
    join public.table_sessions as session
      on session.event_id = authorized_event.id
    join public.event_tables as event_table
      on event_table.id = session.event_table_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
  )
  select
    hand_row.event_id,
    hand_row.table_id,
    hand_row.table_label,
    hand_row.session_id,
    hand_row.session_number_for_table,
    hand_row.hand_id,
    hand_row.hand_number,
    hand_row.entered_at,
    hand_row.result_type,
    hand_row.status,
    hand_row.win_type,
    hand_row.fan_count,
    hand_row.penalty_seat_index,
    hand_row.has_settlements,
    jsonb_agg(
      jsonb_build_object(
        'wind', wind_position.wind,
        'seat_index', seat.seat_index,
        'event_guest_id', seat.event_guest_id,
        'display_name', guest.display_name,
        'points_delta', coalesce(delta.points_delta, 0)
      )
      order by wind_position.sort_order
    ) as cells
  from hand_rows as hand_row
  cross join lateral (
    values
      (0, 'east', hand_row.east_seat_index_before_hand),
      (1, 'south', (hand_row.east_seat_index_before_hand + 1) % 4),
      (2, 'west', (hand_row.east_seat_index_before_hand + 2) % 4),
      (3, 'north', (hand_row.east_seat_index_before_hand + 3) % 4)
  ) as wind_position(sort_order, wind, seat_index)
  join public.table_session_seats as seat
    on seat.table_session_id = hand_row.session_id
   and seat.seat_index = wind_position.seat_index
  join public.event_guests as guest
    on guest.id = seat.event_guest_id
  left join lateral (
    select
      sum(
        case
          when settlement.payee_event_guest_id = seat.event_guest_id
            then settlement.amount_points
          when settlement.payer_event_guest_id = seat.event_guest_id
            then -settlement.amount_points
          else 0
        end
      )::integer as points_delta
    from public.hand_settlements as settlement
    where settlement.hand_result_id = hand_row.hand_id
      and (
        settlement.payee_event_guest_id = seat.event_guest_id
        or settlement.payer_event_guest_id = seat.event_guest_id
      )
  ) as delta on true
  group by
    hand_row.event_id,
    hand_row.table_id,
    hand_row.table_label,
    hand_row.session_id,
    hand_row.session_number_for_table,
    hand_row.hand_id,
    hand_row.hand_number,
    hand_row.entered_at,
    hand_row.result_type,
    hand_row.status,
    hand_row.win_type,
    hand_row.fan_count,
    hand_row.penalty_seat_index,
    hand_row.has_settlements
  order by hand_row.entered_at desc, hand_row.session_id desc, hand_row.hand_number desc;
$$;

grant execute on function public.list_event_hand_ledger(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
