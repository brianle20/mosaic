-- Simplify Mosaic's HK ruleset to a single living HK_STANDARD definition.

do $$
declare
  hk_standard_definition jsonb := '{
    "id": "HK_STANDARD",
    "name": "Hong Kong Standard",
    "minimumWinningFan": 3,
    "winTypes": ["discard", "self_draw"],
    "fanBuckets": [
      { "min": 3, "max": 3, "basePoints": 8 },
      { "min": 4, "max": 6, "basePoints": 16 },
      { "min": 7, "max": 9, "basePoints": 32 },
      { "min": 10, "max": 12, "basePoints": 64 },
      { "min": 13, "basePoints": 128 }
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

alter table public.events
  alter column default_ruleset_id set default 'HK_STANDARD';

alter table public.event_tables
  alter column default_ruleset_id set default 'HK_STANDARD';

update public.events
set default_ruleset_id = 'HK_STANDARD'
where default_ruleset_id = 'HK_STANDARD' || '_V1';

update public.event_tables
set default_ruleset_id = 'HK_STANDARD'
where default_ruleset_id = 'HK_STANDARD' || '_V1';

update public.table_sessions
set ruleset_id = 'HK_STANDARD'
where ruleset_id = 'HK_STANDARD' || '_V1';

delete from public.rulesets
where id = 'HK_STANDARD' || '_V1'
  and not exists (
    select 1 from public.events where default_ruleset_id = 'HK_STANDARD' || '_V1'
  )
  and not exists (
    select 1 from public.event_tables where default_ruleset_id = 'HK_STANDARD' || '_V1'
  )
  and not exists (
    select 1 from public.table_sessions where ruleset_id = 'HK_STANDARD' || '_V1'
  );

alter table public.rulesets
  drop column if exists version;

do $$
begin
  execute 'alter table public.table_sessions drop column if exists '
    || quote_ident('ruleset_' || 'version');
end;
$$;

update public.hand_results
set
  fan_count = 3,
  base_points = 8
where result_type = 'win'
  and fan_count < 3;

alter table public.hand_results
  drop constraint if exists hand_results_win_minimum_fan_check;

alter table public.hand_results
  add constraint hand_results_win_minimum_fan_check
  check (result_type <> 'win' or fan_count >= 3);

drop function if exists app_private.validate_hand_result_input(
  text,
  integer,
  text,
  integer,
  integer
);

create or replace function app_private.ruleset_minimum_winning_fan(
  target_ruleset_id text
)
returns integer
language plpgsql
stable
as $$
declare
  ruleset_definition jsonb;
  minimum_fan integer;
begin
  select definition_json
  into ruleset_definition
  from public.rulesets
  where id = target_ruleset_id;

  if ruleset_definition is null then
    raise exception 'Ruleset not found: %', target_ruleset_id
      using errcode = 'P0001';
  end if;

  minimum_fan := (ruleset_definition ->> 'minimumWinningFan')::integer;

  if minimum_fan is null or minimum_fan < 0 then
    raise exception 'Ruleset % is missing a valid minimumWinningFan.', target_ruleset_id
      using errcode = 'P0001';
  end if;

  return minimum_fan;
end;
$$;

create or replace function app_private.ruleset_base_points(
  target_ruleset_id text,
  target_fan_count integer
)
returns integer
language plpgsql
stable
as $$
declare
  ruleset_definition jsonb;
  bucket jsonb;
  bucket_min integer;
  bucket_max integer;
  bucket_base_points integer;
begin
  if target_fan_count is null then
    raise exception 'Fan count is required for base point lookup.'
      using errcode = 'P0001';
  end if;

  select definition_json
  into ruleset_definition
  from public.rulesets
  where id = target_ruleset_id;

  if ruleset_definition is null then
    raise exception 'Ruleset not found: %', target_ruleset_id
      using errcode = 'P0001';
  end if;

  if jsonb_typeof(ruleset_definition -> 'fanBuckets') <> 'array' then
    raise exception 'Ruleset % is missing fanBuckets.', target_ruleset_id
      using errcode = 'P0001';
  end if;

  for bucket in
    select value
    from jsonb_array_elements(ruleset_definition -> 'fanBuckets')
  loop
    bucket_min := (bucket ->> 'min')::integer;
    bucket_max := nullif(bucket ->> 'max', '')::integer;
    bucket_base_points := (bucket ->> 'basePoints')::integer;

    if bucket_min is null or bucket_base_points is null then
      raise exception 'Ruleset % has an invalid fan bucket.', target_ruleset_id
        using errcode = 'P0001';
    end if;

    if target_fan_count >= bucket_min
      and (bucket_max is null or target_fan_count <= bucket_max) then
      return bucket_base_points;
    end if;
  end loop;

  raise exception 'No base point bucket for % fan in ruleset %.',
    target_fan_count,
    target_ruleset_id
    using errcode = 'P0001';
end;
$$;

create or replace function app_private.validate_hand_result_input(
  target_ruleset_id text,
  target_result_type text,
  target_winner_seat_index integer,
  target_win_type text,
  target_discarder_seat_index integer,
  target_fan_count integer
)
returns void
language plpgsql
stable
as $$
declare
  minimum_fan integer;
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
    session_row.ruleset_id,
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
