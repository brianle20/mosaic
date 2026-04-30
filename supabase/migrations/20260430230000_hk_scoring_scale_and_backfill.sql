-- Update HK scoring scale and rebuild all recorded settlements/totals.

do $$
declare
  hk_standard_definition jsonb := '{
    "id": "HK_STANDARD",
    "name": "Hong Kong Standard",
    "minimumWinningFan": 3,
    "winTypes": ["discard", "self_draw"],
    "fanBuckets": [
      { "min": 0, "max": 0, "basePoints": 1 },
      { "min": 1, "max": 1, "basePoints": 2 },
      { "min": 2, "max": 2, "basePoints": 4 },
      { "min": 3, "max": 3, "basePoints": 8 },
      { "min": 4, "max": 4, "basePoints": 16 },
      { "min": 5, "max": 5, "basePoints": 24 },
      { "min": 6, "max": 6, "basePoints": 32 },
      { "min": 7, "max": 7, "basePoints": 48 },
      { "min": 8, "max": 8, "basePoints": 64 },
      { "min": 9, "max": 9, "basePoints": 96 },
      { "min": 10, "max": 10, "basePoints": 128 },
      { "min": 11, "max": 11, "basePoints": 192 },
      { "min": 12, "max": 12, "basePoints": 256 },
      { "min": 13, "basePoints": 384 }
    ],
    "washoutDealerBehavior": "retain_current_east",
    "rotationPolicyDefaults": ["dealer_cycle_return_to_initial_east"]
  }'::jsonb;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rulesets'
      and column_name = 'version'
  ) then
    insert into public.rulesets (
      id,
      name,
      version,
      status,
      definition_json
    ) values (
      'HK_STANDARD',
      'Hong Kong Standard',
      1,
      'active',
      hk_standard_definition
    )
    on conflict (id) do update
    set
      name = excluded.name,
      version = excluded.version,
      status = excluded.status,
      definition_json = excluded.definition_json;
  else
    insert into public.rulesets (
      id,
      name,
      status,
      definition_json
    ) values (
      'HK_STANDARD',
      'Hong Kong Standard',
      'active',
      hk_standard_definition
    )
    on conflict (id) do update
    set
      name = excluded.name,
      status = excluded.status,
      definition_json = excluded.definition_json;
  end if;
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
    when target_fan_count = 4 then 16
    when target_fan_count = 5 then 24
    when target_fan_count = 6 then 32
    when target_fan_count = 7 then 48
    when target_fan_count = 8 then 64
    when target_fan_count = 9 then 96
    when target_fan_count = 10 then 128
    when target_fan_count = 11 then 192
    when target_fan_count = 12 then 256
    else 384
  end
$$;

alter table public.hand_results
  drop constraint if exists hand_results_win_minimum_fan_check;

alter table public.hand_results
  drop constraint if exists hand_results_result_shape_check;

do $$
declare
  constraint_row record;
begin
  for constraint_row in
    select constraint_info.conname
    from pg_constraint as constraint_info
    where constraint_info.conrelid = 'public.hand_results'::regclass
      and constraint_info.contype = 'c'
      and pg_get_constraintdef(constraint_info.oid) like '%fan_count >= 3%'
  loop
    execute format(
      'alter table public.hand_results drop constraint %I',
      constraint_row.conname
    );
  end loop;
end;
$$;

alter table public.hand_results
  add constraint hand_results_result_shape_check
  check (
    (
      result_type = 'washout'
      and winner_seat_index is null
      and win_type is null
      and discarder_seat_index is null
      and fan_count is null
      and base_points is null
    )
    or
    (
      result_type = 'win'
      and winner_seat_index is not null
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
  );

alter table public.hand_results
  add constraint hand_results_win_minimum_fan_check
  check (result_type <> 'win' or fan_count >= 3);

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
  recorded_hand_count integer := 0;
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

create or replace function public.recalculate_session(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
begin
  perform app_private.require_owned_session(target_table_session_id);
  return app_private.recalculate_session_unowned(target_table_session_id);
end;
$$;

do $$
declare
  session_row record;
  event_row record;
begin
  for session_row in
    select distinct session.id, session.started_at
    from public.table_sessions as session
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    order by session.started_at asc, session.id asc
  loop
    perform app_private.recalculate_session_unowned(session_row.id);
  end loop;

  for event_row in select id from public.events loop
    perform app_private.refresh_event_score_totals(event_row.id);
  end loop;
end;
$$;
