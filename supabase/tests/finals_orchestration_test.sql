begin;

create extension if not exists pgtap with schema extensions;
create schema test_support;

create or replace function test_support.finals_fixture_uuid(
  namespace_value integer,
  item_value integer,
  scenario_value integer default 1
)
returns uuid
language sql
immutable
strict
as $$
  select (
    '00000000-'
    || lpad(scenario_value::text, 4, '0')
    || '-'
    || lpad(namespace_value::text, 4, '0')
    || '-0000-'
    || lpad(item_value::text, 12, '0')
  )::uuid;
$$;

create or replace function test_support.create_finals_fixture(
  player_count integer default 8,
  scenario_value integer default 1
)
returns uuid
language plpgsql
as $$
declare
  host_user_id constant uuid := test_support.finals_fixture_uuid(1, 1, scenario_value);
  target_event_id constant uuid := test_support.finals_fixture_uuid(2, 1, scenario_value);
  qualification_table_id constant uuid := test_support.finals_fixture_uuid(3, 1, scenario_value);
  champions_table_id constant uuid := test_support.finals_fixture_uuid(3, 2, scenario_value);
  redemption_table_id constant uuid := test_support.finals_fixture_uuid(3, 3, scenario_value);
  first_guest_id constant uuid := test_support.finals_fixture_uuid(4, 1, scenario_value);
  opponent_index integer;
  session_id_value uuid;
  hand_id_value uuid;
  opponent_guest_id uuid;
begin
  if player_count < 2 or player_count > 12 then
    raise exception 'Finals fixture player count must be between 2 and 12.';
  end if;

  if scenario_value < 1 or scenario_value > 9999 then
    raise exception 'Finals fixture scenario must be between 1 and 9999.';
  end if;

  perform set_config('request.jwt.claim.sub', host_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.rulesets (id, name, status, definition_json)
  values ('HK_STANDARD', 'Hong Kong Standard', 'active', '{}'::jsonb)
  on conflict (id) do nothing;

  insert into public.users (id, email, display_name)
  values (
    host_user_id,
    'finals-host-' || scenario_value || '@example.test',
    'Finals Host ' || scenario_value
  );

  insert into public.events (
    id,
    owner_user_id,
    title,
    timezone,
    starts_at,
    lifecycle_status,
    checkin_open,
    scoring_open,
    current_scoring_phase
  )
  values (
    target_event_id,
    host_user_id,
    'Finals Fixture Event ' || scenario_value,
    'America/Los_Angeles',
    '2026-07-11 12:00:00-07'::timestamptz,
    'active',
    true,
    true,
    'tournament'
  );

  insert into public.nfc_tags (
    id,
    uid_hex,
    uid_fingerprint,
    default_tag_type,
    display_label,
    status
  )
  values
    (
      test_support.finals_fixture_uuid(5, 1, scenario_value),
      'F1A1' || lpad(scenario_value::text, 4, '0') || '01',
      'finals-fixture-' || scenario_value || '-champions-table',
      'table',
      'Champions Table',
      'active'
    ),
    (
      test_support.finals_fixture_uuid(5, 2, scenario_value),
      'F1A1' || lpad(scenario_value::text, 4, '0') || '02',
      'finals-fixture-' || scenario_value || '-redemption-table',
      'table',
      'Redemption Table',
      'active'
    );

  insert into public.event_tables (
    id,
    event_id,
    label,
    display_order,
    nfc_tag_id
  )
  values
    (qualification_table_id, target_event_id, 'Qualification', 1, null),
    (
      champions_table_id,
      target_event_id,
      'Champions',
      2,
      test_support.finals_fixture_uuid(5, 1, scenario_value)
    ),
    (
      redemption_table_id,
      target_event_id,
      'Redemption',
      3,
      test_support.finals_fixture_uuid(5, 2, scenario_value)
    );

  insert into public.guest_profiles (
    id,
    owner_user_id,
    display_name,
    normalized_name,
    public_display_name
  )
  select
    test_support.finals_fixture_uuid(8, player_index, scenario_value),
    host_user_id,
    'Scenario ' || scenario_value || ' Player ' || player_index,
    'scenario ' || scenario_value || ' player ' || player_index,
    'Scenario ' || scenario_value || ' Player ' || player_index
  from generate_series(1, player_count) as player_index;

  insert into public.event_guests (
    id,
    event_id,
    guest_profile_id,
    display_name,
    normalized_name,
    attendance_status,
    checked_in_at,
    tournament_status,
    public_display_name
  )
  select
    test_support.finals_fixture_uuid(4, player_index, scenario_value),
    target_event_id,
    test_support.finals_fixture_uuid(8, player_index, scenario_value),
    'Scenario ' || scenario_value || ' Player ' || player_index,
    'scenario ' || scenario_value || ' player ' || player_index,
    'checked_in',
    '2026-07-11 11:30:00-07'::timestamptz,
    'qualified',
    'Scenario ' || scenario_value || ' Player ' || player_index
  from generate_series(1, player_count) as player_index;

  -- Completed tournament hands are the source of truth for deterministic
  -- standings. The normal refresh path derives score totals and snapshots.
  for opponent_index in 2..player_count loop
    session_id_value := test_support.finals_fixture_uuid(6, opponent_index, scenario_value);
    hand_id_value := test_support.finals_fixture_uuid(7, opponent_index, scenario_value);
    opponent_guest_id := test_support.finals_fixture_uuid(4, opponent_index, scenario_value);

    insert into public.table_sessions (
      id,
      event_id,
      event_table_id,
      session_number_for_table,
      ruleset_id,
      rotation_policy_type,
      rotation_policy_config_json,
      status,
      initial_east_seat_index,
      current_dealer_seat_index,
      started_at,
      started_by_user_id,
      ended_at,
      ended_by_user_id,
      scoring_phase
    )
    values (
      session_id_value,
      target_event_id,
      qualification_table_id,
      opponent_index - 1,
      'HK_STANDARD',
      'dealer_cycle_return_to_initial_east',
      '{}'::jsonb,
      'completed',
      0,
      1,
      '2026-07-11 10:00:00-07'::timestamptz
        + make_interval(mins => opponent_index),
      host_user_id,
      '2026-07-11 10:05:00-07'::timestamptz
        + make_interval(mins => opponent_index),
      host_user_id,
      'tournament'
    );

    insert into public.table_session_seats (
      table_session_id,
      seat_index,
      initial_wind,
      event_guest_id
    )
    values
      (session_id_value, 0, 'east', first_guest_id),
      (session_id_value, 1, 'south', opponent_guest_id);

    insert into public.hand_results (
      id,
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
      entered_by_user_id,
      entered_at
    )
    values (
      hand_id_value,
      session_id_value,
      1,
      'win',
      0,
      'discard',
      1,
      3,
      8,
      0,
      1,
      true,
      true,
      host_user_id,
      '2026-07-11 10:04:00-07'::timestamptz
        + make_interval(mins => opponent_index)
    );

    insert into public.hand_settlements (
      hand_result_id,
      payer_event_guest_id,
      payee_event_guest_id,
      amount_points
    )
    values (
      hand_id_value,
      opponent_guest_id,
      first_guest_id,
      (opponent_index - 1) * 10
    );
  end loop;

  perform app_private.refresh_event_score_totals(target_event_id);

  return target_event_id;
end;
$$;

create or replace function test_support.score_finals_contest(
  target_event_id uuid,
  target_contest_type text,
  seat_scores integer[]
)
returns uuid
language plpgsql
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  hand_id_value uuid := gen_random_uuid();
  seat_count integer;
  positive_index integer := 1;
  negative_index integer := 1;
  positive_remaining integer;
  negative_remaining integer;
  transfer_amount integer;
  positive_guest uuid;
  negative_guest uuid;
begin
  select contest.* into contest_row
  from public.event_finals_contests as contest
  where contest.event_id = target_event_id
    and contest.contest_type = target_contest_type
    and contest.status in ('active', 'complete')
  order by contest.sequence_number desc
  limit 1;
  if not found then raise exception 'Active test contest not found: %', target_contest_type; end if;

  select count(*) into seat_count
  from public.table_session_seats where table_session_id = contest_row.table_session_id;
  if seat_count <> array_length(seat_scores, 1) then
    raise exception 'Expected % seat scores, got %', seat_count, array_length(seat_scores, 1);
  end if;
  if (select sum(score) from unnest(seat_scores) as score) <> 0 then
    raise exception 'Test scores must sum to zero.';
  end if;

  delete from public.hand_settlements as settlement
  using public.hand_results as hand
  where settlement.hand_result_id = hand.id
    and hand.table_session_id = contest_row.table_session_id;
  delete from public.hand_results where table_session_id = contest_row.table_session_id;
  insert into public.hand_results (
    id, table_session_id, hand_number, result_type, winner_seat_index,
    win_type, discarder_seat_index, fan_count, base_points,
    east_seat_index_before_hand, east_seat_index_after_hand,
    dealer_rotated, session_completed_after_hand, entered_by_user_id, entered_at
  ) values (
    hand_id_value, contest_row.table_session_id, 1, 'win', 0,
    'discard', seat_count - 1, 3, 8, 0, 1, true, true,
    test_support.finals_fixture_uuid(1, 1,
      substring(target_event_id::text from 10 for 4)::integer), now()
  );

  while positive_index <= seat_count and negative_index <= seat_count loop
    while positive_index <= seat_count and seat_scores[positive_index] <= 0 loop
      positive_index := positive_index + 1;
    end loop;
    while negative_index <= seat_count and seat_scores[negative_index] >= 0 loop
      negative_index := negative_index + 1;
    end loop;
    exit when positive_index > seat_count or negative_index > seat_count;
    positive_remaining := seat_scores[positive_index];
    negative_remaining := -seat_scores[negative_index];
    transfer_amount := least(positive_remaining, negative_remaining);
    select event_guest_id into positive_guest from public.table_session_seats
      where table_session_id = contest_row.table_session_id and seat_index = positive_index - 1;
    select event_guest_id into negative_guest from public.table_session_seats
      where table_session_id = contest_row.table_session_id and seat_index = negative_index - 1;
    insert into public.hand_settlements (
      hand_result_id, payer_event_guest_id, payee_event_guest_id, amount_points
    ) values (hand_id_value, negative_guest, positive_guest, transfer_amount);
    seat_scores[positive_index] := seat_scores[positive_index] - transfer_amount;
    seat_scores[negative_index] := seat_scores[negative_index] + transfer_amount;
  end loop;

  update public.table_sessions
  set status = 'completed', ended_at = now(), end_reason = 'test_completed'
  where id = contest_row.table_session_id;
  perform app_private.recalculate_finals_state(contest_row.table_session_id);
  return contest_row.id;
end;
$$;

create or replace function test_support.record_finals_resolution(
  target_contest_id uuid,
  target_result_type text,
  target_winner_seat integer default null
)
returns uuid
language plpgsql
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  hand_id_value uuid := gen_random_uuid();
begin
  select * into contest_row from public.event_finals_contests
  where id = target_contest_id;
  insert into public.hand_results (
    id, table_session_id, hand_number, result_type, winner_seat_index,
    win_type, discarder_seat_index, fan_count, base_points,
    east_seat_index_before_hand, east_seat_index_after_hand,
    dealer_rotated, session_completed_after_hand, entered_by_user_id, entered_at
  ) values (
    hand_id_value, contest_row.table_session_id, 1, target_result_type,
    target_winner_seat,
    case when target_result_type = 'win' then 'discard' end,
    case when target_result_type = 'win' then (target_winner_seat + 1) % 2 end,
    case when target_result_type = 'win' then 3 end,
    case when target_result_type = 'win' then 8 end,
    0, 0, false, target_result_type = 'win',
    (select created_by_user_id from public.event_finals_contests where id = target_contest_id),
    now()
  );
  if target_result_type = 'win' then
    update public.table_sessions
    set status = 'completed', ended_at = now(), end_reason = 'test_resolution'
    where id = contest_row.table_session_id;
  end if;
  perform app_private.recalculate_finals_state(contest_row.table_session_id);
  return hand_id_value;
end;
$$;

create or replace function test_support.create_legacy_finals_fixture(
  scenario_value integer,
  champions_players integer[],
  redemption_players integer[] default array[]::integer[]
)
returns uuid
language plpgsql
as $$
declare
  target_event_id uuid;
  player_count integer;
begin
  select max(player_index)
  into player_count
  from unnest(champions_players || redemption_players) as player_index;

  target_event_id := test_support.create_finals_fixture(player_count, scenario_value);
  update public.events
  set current_scoring_phase = 'bonus'
  where id = target_event_id;

  insert into public.event_bonus_rounds (
    id, event_id, champions_table_id, redemption_table_id,
    assignment_round, status, flow_version, state_version
  ) values (
    test_support.finals_fixture_uuid(10, 1, scenario_value),
    target_event_id,
    test_support.finals_fixture_uuid(3, 2, scenario_value),
    case when cardinality(redemption_players) > 0
      then test_support.finals_fixture_uuid(3, 3, scenario_value)
    end,
    1, 'active', 'legacy', 0
  );

  insert into public.event_seating_assignments (
    id, event_id, event_table_id, event_guest_id, seat_index,
    assignment_round, assignment_type, bonus_round_id, bonus_table_role,
    seed_rank, status, assigned_by_user_id
  )
  select
    test_support.finals_fixture_uuid(14, player_index, scenario_value),
    target_event_id,
    test_support.finals_fixture_uuid(3, 2, scenario_value),
    test_support.finals_fixture_uuid(4, player_index, scenario_value),
    ordinal - 1, 1, 'bonus',
    test_support.finals_fixture_uuid(10, 1, scenario_value),
    'table_of_champions', player_index, 'active',
    test_support.finals_fixture_uuid(1, 1, scenario_value)
  from unnest(champions_players) with ordinality as player(player_index, ordinal);

  insert into public.event_seating_assignments (
    id, event_id, event_table_id, event_guest_id, seat_index,
    assignment_round, assignment_type, bonus_round_id, bonus_table_role,
    seed_rank, status, assigned_by_user_id
  )
  select
    test_support.finals_fixture_uuid(15, player_index, scenario_value),
    target_event_id,
    test_support.finals_fixture_uuid(3, 3, scenario_value),
    test_support.finals_fixture_uuid(4, player_index, scenario_value),
    ordinal - 1, 1, 'bonus',
    test_support.finals_fixture_uuid(10, 1, scenario_value),
    'table_of_redemption', player_index, 'active',
    test_support.finals_fixture_uuid(1, 1, scenario_value)
  from unnest(redemption_players) with ordinality as player(player_index, ordinal);

  return target_event_id;
end;
$$;

create or replace function test_support.add_finals_table(
  scenario_value integer,
  table_item integer,
  tag_is_active boolean default true
)
returns uuid
language plpgsql
as $$
declare
  target_event_id constant uuid := test_support.finals_fixture_uuid(2, 1, scenario_value);
  target_table_id constant uuid := test_support.finals_fixture_uuid(3, table_item, scenario_value);
  target_tag_id constant uuid := test_support.finals_fixture_uuid(5, table_item, scenario_value);
begin
  insert into public.nfc_tags (
    id, uid_hex, uid_fingerprint, default_tag_type, display_label, status
  ) values (
    target_tag_id,
    'FA' || lpad(scenario_value::text, 4, '0') || lpad(table_item::text, 2, '0'),
    'finals-alternate-' || scenario_value || '-' || table_item,
    'table', 'Alternate ' || table_item,
    case when tag_is_active then 'active' else 'retired' end
  );
  insert into public.event_tables (
    id, event_id, label, display_order, nfc_tag_id
  ) values (
    target_table_id, target_event_id, 'Alternate ' || table_item,
    table_item, target_tag_id
  );
  return target_table_id;
end;
$$;

create or replace function test_support.create_ready_orchestrated_contest(
  scenario_value integer,
  contest_type_value text,
  bonus_table_role_value text
)
returns uuid
language plpgsql
as $$
declare
  target_event_id uuid;
  target_table_id uuid;
  target_root_id constant uuid := test_support.finals_fixture_uuid(10, 1, scenario_value);
  target_contest_id constant uuid := test_support.finals_fixture_uuid(11, 1, scenario_value);
begin
  target_event_id := test_support.create_finals_fixture(4, scenario_value);
  target_table_id := case
    when bonus_table_role_value = 'table_of_redemption'
      then test_support.finals_fixture_uuid(3, 3, scenario_value)
    else test_support.finals_fixture_uuid(3, 2, scenario_value)
  end;
  update public.events set current_scoring_phase = 'bonus'
  where id = target_event_id;
  insert into public.event_bonus_rounds (
    id, event_id, champions_table_id, redemption_table_id, assignment_round,
    status, flow_version, state_version, eligible_player_count, format
  ) values (
    target_root_id, target_event_id,
    test_support.finals_fixture_uuid(3, 2, scenario_value),
    test_support.finals_fixture_uuid(3, 3, scenario_value),
    1, 'active', 'orchestrated', 1, 4, 'champions_only'
  );
  insert into public.event_finals_contests (
    id, bonus_round_id, event_id, contest_type, status, event_table_id,
    sequence_number, created_by_user_id
  ) values (
    target_contest_id, target_root_id, target_event_id, contest_type_value,
    'ready', target_table_id, 1,
    test_support.finals_fixture_uuid(1, 1, scenario_value)
  );
  insert into public.event_finals_contest_participants (
    contest_id, event_guest_id, entry_seed, seat_index
  ) values
    (target_contest_id, test_support.finals_fixture_uuid(4, 1, scenario_value), 1, 0),
    (target_contest_id, test_support.finals_fixture_uuid(4, 2, scenario_value), 2, 1);
  return target_event_id;
end;
$$;

create or replace function test_support.occupy_finals_table(
  scenario_value integer,
  table_item integer,
  session_item integer,
  seated_guest_item integer default null
)
returns uuid
language plpgsql
as $$
declare
  target_event_id constant uuid := test_support.finals_fixture_uuid(2, 1, scenario_value);
  target_table_id constant uuid := test_support.finals_fixture_uuid(3, table_item, scenario_value);
  target_session_id constant uuid := test_support.finals_fixture_uuid(6, session_item, scenario_value);
begin
  insert into public.table_sessions (
    id, event_id, event_table_id, session_number_for_table, ruleset_id,
    rotation_policy_type, rotation_policy_config_json, status,
    initial_east_seat_index, current_dealer_seat_index, scoring_phase,
    started_at, started_by_user_id
  ) values (
    target_session_id, target_event_id, target_table_id, session_item,
    'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
    'active', 0, 0, 'bonus', now(),
    test_support.finals_fixture_uuid(1, 1, scenario_value)
  );
  if seated_guest_item is not null then
    insert into public.table_session_seats (
      table_session_id, seat_index, initial_wind, event_guest_id
    ) values (
      target_session_id, 0, 'east',
      test_support.finals_fixture_uuid(4, seated_guest_item, scenario_value)
    );
  end if;
  return target_session_id;
end;
$$;

create or replace function test_support.complete_legacy_finals_session_via_scoring(
  target_event_id uuid,
  target_bonus_table_role text,
  scenario_value integer
)
returns uuid
language plpgsql
as $$
declare
  target_session_id uuid;
  winner_seats constant integer[] := array[0, 1, 2, 3, 0];
  fan_counts constant integer[] := array[10, 3, 3, 3, 3];
  hand_index integer;
  photo_index integer;
begin
  select session.id
  into target_session_id
  from public.table_sessions as session
  where session.event_id = target_event_id
    and session.bonus_table_role = target_bonus_table_role
    and session.status = 'active'
  order by session.started_at, session.id
  limit 1;

  if target_session_id is null then
    raise exception 'Active legacy Finals session not found.';
  end if;

  for hand_index in 1..5 loop
    photo_index := hand_index + case target_bonus_table_role
      when 'table_of_champions' then 10
      else 0
    end;
    perform public.record_hand_result(
      target_table_session_id => target_session_id,
      target_result_type => 'win',
      target_winner_seat_index => winner_seats[hand_index],
      target_win_type => 'discard',
      target_discarder_seat_index => (winner_seats[hand_index] + 1) % 4,
      target_fan_count => fan_counts[hand_index],
      target_photo_client_id => test_support.finals_fixture_uuid(
        16, photo_index, scenario_value
      ),
      target_photo_captured_at => now()
    );
  end loop;

  return target_session_id;
end;
$$;

select plan(324);

select has_table(
  'public',
  'event_finals_contests',
  'event_finals_contests exists'
);
select has_table(
  'public',
  'event_finals_contest_participants',
  'event_finals_contest_participants exists'
);
select has_table(
  'public',
  'event_finals_champions_slots',
  'event_finals_champions_slots exists'
);
select has_table(
  'public',
  'event_finals_eligible_snapshot',
  'event_finals_eligible_snapshot exists'
);
select ok(
  (select relrowsecurity
   from pg_class
   where oid = 'public.event_finals_eligible_snapshot'::regclass),
  'eligible snapshot has row-level security enabled'
);
select is(
  (select count(*)::integer
   from pg_policies
   where schemaname = 'public'
     and tablename = 'event_finals_eligible_snapshot'),
  1,
  'eligible snapshot has only the owner-or-staff read policy'
);
select ok(
  to_regclass('public.event_finals_eligible_snapshot_event_seed_idx') is not null
  and exists (
    select 1 from pg_constraint
    where conrelid = 'public.event_finals_eligible_snapshot'::regclass
      and conname = 'event_finals_eligible_snapshot_root_event_fk'
  )
  and exists (
    select 1 from pg_constraint
    where conrelid = 'public.event_finals_eligible_snapshot'::regclass
      and conname = 'event_finals_eligible_snapshot_guest_event_fk'
  ),
  'eligible snapshot has its event-seed index and same-scope constraints'
);
select has_function('public', 'preview_event_finals', array['uuid']);
select has_function('public', 'get_event_finals_state', array['uuid']);

select is(app_private.finals_format_for_count(4), 'champions_only');
select is(app_private.finals_format_for_count(5), 'automatic_redemption');
select is(app_private.finals_format_for_count(6), 'redemption_advancement');
select is(app_private.finals_format_for_count(7), 'redemption_advancement');
select is(app_private.finals_format_for_count(8), 'parallel_finals');
select is(app_private.finals_direct_slot_count(6), 2);
select is(app_private.finals_direct_slot_count(7), 3);
select lives_ok(
  'select test_support.create_finals_fixture(6, 1)',
  'creates a namespaced source-of-truth Finals fixture'
);
select is(
  (public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
    ->> 'eligible_player_count')::integer,
  6,
  'preview counts source-derived eligible players'
);
select is(
  public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
    ->> 'format',
  'redemption_advancement',
  'preview selects the six-player format'
);
select is(
  (public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
    ->> 'direct_slots')::integer,
  2,
  'preview returns the direct Champions slots'
);
select is(
  jsonb_array_length(
    public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
      -> 'redemption_players'
  ),
  4,
  'preview returns four Redemption players'
);
select ok(
  (
    public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
      ->> 'requires_champions_table'
  )::boolean
  and (
    public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
      ->> 'requires_redemption_table'
  )::boolean,
  'preview reports both required tables'
);
select is(
  public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 1))
    -> 'available_table_ids',
  jsonb_build_array(
    test_support.finals_fixture_uuid(3, 2, 1),
    test_support.finals_fixture_uuid(3, 3, 1)
  ),
  'preview exposes the exact ordered ready-table candidates'
);

select test_support.create_finals_fixture(4, 418);
select test_support.add_finals_table(418, 4);
select test_support.add_finals_table(418, 5, false);
select test_support.add_finals_table(418, 6);
select test_support.add_finals_table(418, 7);
update public.nfc_tags set default_tag_type = 'player'
where id = test_support.finals_fixture_uuid(5, 6, 418);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 50, 418),
  test_support.finals_fixture_uuid(2, 1, 418),
  test_support.finals_fixture_uuid(3, 7, 418),
  1, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'paused', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 418),
  'tournament'
);
select is(
  public.preview_event_finals(test_support.finals_fixture_uuid(2, 1, 418))
    -> 'available_table_ids',
  jsonb_build_array(
    test_support.finals_fixture_uuid(3, 2, 418),
    test_support.finals_fixture_uuid(3, 3, 418),
    test_support.finals_fixture_uuid(3, 4, 418)
  ),
  'preview excludes tagless, retired, retyped, and occupied tables in deterministic order'
);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 1, 1)::text,
  true
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 1))
    ->> 'overall_status',
  'not_started',
  'read model returns a complete pre-Finals state'
);
select lives_ok(
  'select test_support.create_finals_fixture(4, 2)',
  'creates a second namespaced fixture in the same transaction'
);

insert into public.event_bonus_rounds (
  id,
  event_id,
  champions_table_id,
  redemption_table_id,
  assignment_round,
  status,
  flow_version,
  state_version,
  eligible_player_count,
  format
)
values
  (
    test_support.finals_fixture_uuid(10, 1, 1),
    test_support.finals_fixture_uuid(2, 1, 1),
    test_support.finals_fixture_uuid(3, 2, 1),
    test_support.finals_fixture_uuid(3, 3, 1),
    1,
    'active',
    'orchestrated',
    1,
    6,
    'redemption_advancement'
  ),
  (
    test_support.finals_fixture_uuid(10, 1, 2),
    test_support.finals_fixture_uuid(2, 1, 2),
    test_support.finals_fixture_uuid(3, 2, 2),
    null,
    1,
    'active',
    'orchestrated',
    1,
    4,
    'champions_only'
  ),
  (
    test_support.finals_fixture_uuid(10, 2, 1),
    test_support.finals_fixture_uuid(2, 1, 1),
    test_support.finals_fixture_uuid(3, 2, 1),
    null,
    2,
    'active',
    'orchestrated',
    1,
    4,
    'champions_only'
  );

insert into public.event_finals_contests (
  id,
  bonus_round_id,
  event_id,
  contest_type,
  status,
  event_table_id,
  slots_to_fill,
  slot_start_index,
  sequence_number,
  created_by_user_id
)
values
  (
    test_support.finals_fixture_uuid(11, 1, 1),
    test_support.finals_fixture_uuid(10, 1, 1),
    test_support.finals_fixture_uuid(2, 1, 1),
    'table_of_redemption',
    'ready',
    test_support.finals_fixture_uuid(3, 3, 1),
    2,
    3,
    1,
    test_support.finals_fixture_uuid(1, 1, 1)
  ),
  (
    test_support.finals_fixture_uuid(11, 1, 2),
    test_support.finals_fixture_uuid(10, 1, 2),
    test_support.finals_fixture_uuid(2, 1, 2),
    'table_of_champions',
    'ready',
    test_support.finals_fixture_uuid(3, 2, 2),
    0,
    null,
    1,
    test_support.finals_fixture_uuid(1, 1, 2)
  ),
  (
    test_support.finals_fixture_uuid(11, 3, 1),
    test_support.finals_fixture_uuid(10, 2, 1),
    test_support.finals_fixture_uuid(2, 1, 1),
    'champions_sudden_death',
    'pending',
    test_support.finals_fixture_uuid(3, 2, 1),
    1,
    1,
    1,
    test_support.finals_fixture_uuid(1, 1, 1)
  );

insert into public.event_finals_contests (
  id,
  bonus_round_id,
  event_id,
  contest_type,
  status,
  parent_contest_id,
  sequence_number
)
values (
  test_support.finals_fixture_uuid(11, 5, 1),
  test_support.finals_fixture_uuid(10, 1, 1),
  test_support.finals_fixture_uuid(2, 1, 1),
  'champions_sudden_death',
  'pending',
  test_support.finals_fixture_uuid(11, 1, 1),
  2
);

select lives_ok(
  format(
    'insert into public.event_finals_contest_participants '
    || '(contest_id, event_guest_id, entry_seed) values (%L, %L, 1)',
    test_support.finals_fixture_uuid(11, 1, 1),
    test_support.finals_fixture_uuid(4, 1, 1)
  ),
  'accepts a same-event contest participant'
);
select lives_ok(
  format(
    'insert into public.event_finals_champions_slots '
    || '(bonus_round_id, slot_index, event_guest_id, qualification_method) '
    || 'values (%L, 1, %L, ''direct_seed'')',
    test_support.finals_fixture_uuid(10, 1, 1),
    test_support.finals_fixture_uuid(4, 1, 1)
  ),
  'accepts a same-event Champions slot guest'
);

select throws_ok(
  format(
    'insert into public.event_finals_contests '
    || '(id, bonus_round_id, event_id, contest_type, status, '
    || 'parent_contest_id, sequence_number) '
    || 'values (%L, %L, %L, ''champions_sudden_death'', ''pending'', %L, 2)',
    test_support.finals_fixture_uuid(11, 2, 2),
    test_support.finals_fixture_uuid(10, 1, 2),
    test_support.finals_fixture_uuid(2, 1, 2),
    test_support.finals_fixture_uuid(11, 1, 1)
  ),
  'P0001',
  'Finals parent contest must belong to the same event.',
  'rejects a cross-event parent contest'
);
select throws_ok(
  format(
    'insert into public.event_finals_contests '
    || '(id, bonus_round_id, event_id, contest_type, status, '
    || 'parent_contest_id, sequence_number) '
    || 'values (%L, %L, %L, ''champions_sudden_death'', ''pending'', %L, 2)',
    test_support.finals_fixture_uuid(11, 4, 1),
    test_support.finals_fixture_uuid(10, 1, 1),
    test_support.finals_fixture_uuid(2, 1, 1),
    test_support.finals_fixture_uuid(11, 3, 1)
  ),
  'P0001',
  'Finals parent contest must belong to the same Finals root.',
  'rejects a same-event cross-root parent contest'
);
select throws_ok(
  format(
    'update public.event_finals_contests set table_session_id = %L where id = %L',
    test_support.finals_fixture_uuid(6, 2, 1),
    test_support.finals_fixture_uuid(11, 1, 2)
  ),
  'P0001',
  'Finals contest session must belong to the same event.',
  'rejects a cross-event table session'
);
select throws_ok(
  format(
    'insert into public.event_finals_contest_participants '
    || '(contest_id, event_guest_id, entry_seed) values (%L, %L, 99)',
    test_support.finals_fixture_uuid(11, 1, 1),
    test_support.finals_fixture_uuid(4, 1, 2)
  ),
  'P0001',
  'Finals contest participant must belong to the same event.',
  'rejects a cross-event contest participant'
);
select throws_ok(
  format(
    'insert into public.event_finals_champions_slots '
    || '(bonus_round_id, slot_index, event_guest_id, qualification_method) '
    || 'values (%L, 2, %L, ''direct_seed'')',
    test_support.finals_fixture_uuid(10, 1, 1),
    test_support.finals_fixture_uuid(4, 1, 2)
  ),
  'P0001',
  'Finals Champions slot guest must belong to the same event.',
  'rejects a cross-event Champions slot guest'
);
select throws_ok(
  format(
    'insert into public.event_finals_champions_slots '
    || '(bonus_round_id, slot_index, qualification_method, source_contest_id) '
    || 'values (%L, 3, ''tiebreak_win'', %L)',
    test_support.finals_fixture_uuid(10, 1, 1),
    test_support.finals_fixture_uuid(11, 1, 2)
  ),
  'P0001',
  'Finals Champions slot source contest must belong to the same Finals root.',
  'rejects a cross-root Champions slot source contest'
);
select throws_ok(
  format(
    'update public.event_finals_contests set bonus_round_id = %L where id = %L',
    test_support.finals_fixture_uuid(10, 2, 1),
    test_support.finals_fixture_uuid(11, 5, 1)
  ),
  'P0001',
  'Finals parent contest must belong to the same Finals root.',
  'rejects moving a child contest away from its parent Finals root'
);

select test_support.create_finals_fixture(4, 3);
insert into public.event_bonus_rounds (
  id, event_id, champions_table_id, assignment_round, status, flow_version,
  state_version, eligible_player_count, format
) values (
  test_support.finals_fixture_uuid(10, 1, 3),
  test_support.finals_fixture_uuid(2, 1, 3),
  test_support.finals_fixture_uuid(3, 2, 3), 1, 'active', 'orchestrated',
  4, 4, 'champions_only'
);
insert into public.event_finals_contests (
  id, bonus_round_id, event_id, contest_type, status, event_table_id,
  slots_to_fill, slot_start_index, sequence_number
) values (
  test_support.finals_fixture_uuid(11, 1, 3),
  test_support.finals_fixture_uuid(10, 1, 3),
  test_support.finals_fixture_uuid(2, 1, 3),
  'direct_qualification_tiebreak', 'ready',
  test_support.finals_fixture_uuid(3, 2, 3), 1, 4, 1
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 3))
    -> 'allowed_actions',
  jsonb_build_array(jsonb_build_object(
    'action', 'start_contest',
    'label', 'Start Direct Qualification Tiebreak',
    'contest_id', test_support.finals_fixture_uuid(11, 1, 3),
    'table_id', test_support.finals_fixture_uuid(3, 2, 3),
    'available_table_ids', jsonb_build_array(
      test_support.finals_fixture_uuid(3, 2, 3),
      test_support.finals_fixture_uuid(3, 3, 3)
    ),
    'expected_state_version', 4
  )),
  'ready direct-cutoff contest exposes the exact server start action'
);

select test_support.create_finals_fixture(8, 4);
insert into public.event_bonus_rounds (
  id, event_id, champions_table_id, redemption_table_id, assignment_round,
  status, flow_version, state_version, eligible_player_count, format
) values (
  test_support.finals_fixture_uuid(10, 1, 4),
  test_support.finals_fixture_uuid(2, 1, 4),
  test_support.finals_fixture_uuid(3, 2, 4),
  test_support.finals_fixture_uuid(3, 3, 4), 1, 'active', 'orchestrated',
  9, 8, 'parallel_finals'
);
insert into public.event_finals_contests (
  id, bonus_round_id, event_id, contest_type, status, event_table_id,
  sequence_number
) values
  (
    test_support.finals_fixture_uuid(11, 1, 4),
    test_support.finals_fixture_uuid(10, 1, 4),
    test_support.finals_fixture_uuid(2, 1, 4),
    'table_of_redemption', 'ready',
    test_support.finals_fixture_uuid(3, 3, 4), 1
  ),
  (
    test_support.finals_fixture_uuid(11, 2, 4),
    test_support.finals_fixture_uuid(10, 1, 4),
    test_support.finals_fixture_uuid(2, 1, 4),
    'table_of_champions', 'ready',
    test_support.finals_fixture_uuid(3, 2, 4), 2
  );
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 4))
    -> 'allowed_actions',
  jsonb_build_array(
    jsonb_build_object(
      'action', 'start_contest', 'label', 'Start Table of Redemption',
      'contest_id', test_support.finals_fixture_uuid(11, 1, 4),
      'table_id', test_support.finals_fixture_uuid(3, 3, 4),
      'available_table_ids', jsonb_build_array(
        test_support.finals_fixture_uuid(3, 2, 4),
        test_support.finals_fixture_uuid(3, 3, 4)
      ),
      'expected_state_version', 9
    ),
    jsonb_build_object(
      'action', 'start_contest', 'label', 'Start Table of Champions',
      'contest_id', test_support.finals_fixture_uuid(11, 2, 4),
      'table_id', test_support.finals_fixture_uuid(3, 2, 4),
      'available_table_ids', jsonb_build_array(
        test_support.finals_fixture_uuid(3, 2, 4),
        test_support.finals_fixture_uuid(3, 3, 4)
      ),
      'expected_state_version', 9
    )
  ),
  'every ready contest is exposed in deterministic sequence order'
);

select test_support.create_finals_fixture(4, 411);
insert into public.nfc_tags (
  id, uid_hex, uid_fingerprint, default_tag_type, display_label, status
) values
  (test_support.finals_fixture_uuid(5, 10, 411), 'F41110', 'finals-411-valid', 'table', 'Valid Alternate', 'active'),
  (test_support.finals_fixture_uuid(5, 11, 411), 'F41111', 'finals-411-retired', 'table', 'Retired Alternate', 'retired'),
  (test_support.finals_fixture_uuid(5, 12, 411), 'F41112', 'finals-411-player', 'player', 'Player Alternate', 'active'),
  (test_support.finals_fixture_uuid(5, 13, 411), 'F41113', 'finals-411-occupied', 'table', 'Occupied Alternate', 'active');
insert into public.event_tables (
  id, event_id, label, display_order, nfc_tag_id
) values
  (test_support.finals_fixture_uuid(3, 4, 411), test_support.finals_fixture_uuid(2, 1, 411), 'Valid Alternate', 4, test_support.finals_fixture_uuid(5, 10, 411)),
  (test_support.finals_fixture_uuid(3, 5, 411), test_support.finals_fixture_uuid(2, 1, 411), 'Retired Alternate', 5, test_support.finals_fixture_uuid(5, 11, 411)),
  (test_support.finals_fixture_uuid(3, 6, 411), test_support.finals_fixture_uuid(2, 1, 411), 'Player Alternate', 6, test_support.finals_fixture_uuid(5, 12, 411)),
  (test_support.finals_fixture_uuid(3, 7, 411), test_support.finals_fixture_uuid(2, 1, 411), 'Occupied Alternate', 7, test_support.finals_fixture_uuid(5, 13, 411));
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 50, 411),
  test_support.finals_fixture_uuid(2, 1, 411),
  test_support.finals_fixture_uuid(3, 7, 411),
  1, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 411),
  'bonus'
);
insert into public.event_bonus_rounds (
  id, event_id, champions_table_id, assignment_round, status, flow_version,
  state_version, eligible_player_count, format
) values (
  test_support.finals_fixture_uuid(10, 1, 411),
  test_support.finals_fixture_uuid(2, 1, 411),
  test_support.finals_fixture_uuid(3, 2, 411), 1, 'active', 'orchestrated',
  5, 4, 'champions_only'
);
insert into public.event_finals_contests (
  id, bonus_round_id, event_id, contest_type, status, event_table_id,
  sequence_number
) values (
  test_support.finals_fixture_uuid(11, 1, 411),
  test_support.finals_fixture_uuid(10, 1, 411),
  test_support.finals_fixture_uuid(2, 1, 411),
  'table_of_champions', 'ready', test_support.finals_fixture_uuid(3, 2, 411), 1
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 411))
    #> '{allowed_actions,0}',
  jsonb_build_object(
    'action', 'start_contest', 'label', 'Start Table of Champions',
    'contest_id', test_support.finals_fixture_uuid(11, 1, 411),
    'table_id', test_support.finals_fixture_uuid(3, 2, 411),
    'available_table_ids', jsonb_build_array(
      test_support.finals_fixture_uuid(3, 2, 411),
      test_support.finals_fixture_uuid(3, 3, 411),
      test_support.finals_fixture_uuid(3, 4, 411)
    ),
    'expected_state_version', 5
  ),
  'usable bound table is retained and authoritative candidates are ordered'
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 1, 411);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 411))
    #> '{allowed_actions,0}',
  jsonb_build_object(
    'action', 'start_contest', 'label', 'Start Table of Champions',
    'contest_id', test_support.finals_fixture_uuid(11, 1, 411),
    'table_id', null,
    'available_table_ids', jsonb_build_array(
      test_support.finals_fixture_uuid(3, 3, 411),
      test_support.finals_fixture_uuid(3, 4, 411)
    ),
    'expected_state_version', 5
  ),
  'retired bound and invalid or occupied alternates are excluded'
);
update public.nfc_tags set status = 'active', default_tag_type = 'player'
where id = test_support.finals_fixture_uuid(5, 1, 411);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 411))
    #> '{allowed_actions,0}',
  jsonb_build_object(
    'action', 'start_contest', 'label', 'Start Table of Champions',
    'contest_id', test_support.finals_fixture_uuid(11, 1, 411),
    'table_id', null,
    'available_table_ids', jsonb_build_array(
      test_support.finals_fixture_uuid(3, 3, 411),
      test_support.finals_fixture_uuid(3, 4, 411)
    ),
    'expected_state_version', 5
  ),
  'retyped bound table requires selection and is excluded from candidates'
);
update public.nfc_tags set default_tag_type = 'table'
where id = test_support.finals_fixture_uuid(5, 1, 411);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 51, 411),
  test_support.finals_fixture_uuid(2, 1, 411),
  test_support.finals_fixture_uuid(3, 2, 411),
  1, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'paused', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 411),
  'bonus'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 411))
    #> '{allowed_actions,0}',
  jsonb_build_object(
    'action', 'start_contest', 'label', 'Start Table of Champions',
    'contest_id', test_support.finals_fixture_uuid(11, 1, 411),
    'table_id', null,
    'available_table_ids', jsonb_build_array(
      test_support.finals_fixture_uuid(3, 3, 411),
      test_support.finals_fixture_uuid(3, 4, 411)
    ),
    'expected_state_version', 5
  ),
  'occupied bound table requires selection and is excluded from candidates'
);
select is(
  (select event_table_id from public.event_finals_contests
   where id = test_support.finals_fixture_uuid(11, 1, 411)),
  test_support.finals_fixture_uuid(3, 2, 411),
  'readiness projection does not mutate the persisted contest binding'
);

select has_function(
  'app_private',
  'start_assigned_finals_session',
  array['uuid', 'uuid', 'text', 'uuid', 'timestamp with time zone']
);
select has_trigger(
  'public',
  'table_session_seats',
  'table_session_seats_guard_active_guest_conflict',
  'table_session_seats_guard_active_guest_conflict'
);
select has_function(
  'public',
  'begin_event_finals',
  array['uuid', 'uuid', 'uuid', 'bigint', 'text']
);
select has_function(
  'public',
  'start_finals_contest',
  array['uuid', 'uuid', 'bigint']
);
select has_function(
  'app_private',
  'recalculate_finals_state',
  array['uuid']
);
select has_function(
  'app_private',
  'apply_legacy_bonus_round_champion_award',
  array['uuid']
);
select ok(
  pg_get_functiondef('app_private.apply_bonus_round_champion_award(uuid)'::regprocedure)
    like '%apply_legacy_bonus_round_champion_award%'
  and pg_get_functiondef('app_private.apply_bonus_round_champion_award(uuid)'::regprocedure)
    like '%recalculate_finals_state%',
  'stable champion award hook delegates legacy and orchestrated Finals'
);

select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.create_finals_fixture(2, 101),
    test_support.finals_fixture_uuid(3, 2, 101)
  ),
  'begins two-player Champions Finals'
);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 1, 101)::text,
  true
);
set local role authenticated;
select is(
  (select count(*)::integer
   from public.event_finals_eligible_snapshot
   where event_id = '00000000-0101-0002-0000-000000000001'::uuid),
  2,
  'authenticated event owner can read the frozen eligible snapshot'
);
reset role;
select throws_ok(
  $$set local role authenticated;
    insert into public.event_finals_eligible_snapshot (
      bonus_round_id, event_id, event_guest_id, display_name, total_points,
      hands_played, standing_rank, seed_rank
    )
    select bonus_round_id, event_id, event_guest_id, display_name,
      total_points, hands_played, standing_rank, seed_rank
    from public.event_finals_eligible_snapshot
    where event_id = '00000000-0101-0002-0000-000000000001'::uuid
    limit 1$$,
  '42501',
  'permission denied for table event_finals_eligible_snapshot',
  'authenticated owner cannot insert frozen snapshot rows'
);
select throws_ok(
  $$set local role authenticated;
    update public.event_finals_eligible_snapshot
    set display_name = display_name
    where event_id = '00000000-0101-0002-0000-000000000001'::uuid$$,
  '42501',
  'permission denied for table event_finals_eligible_snapshot',
  'authenticated owner cannot update frozen snapshot rows'
);
select throws_ok(
  $$set local role authenticated;
    delete from public.event_finals_eligible_snapshot
    where event_id = '00000000-0101-0002-0000-000000000001'::uuid$$,
  '42501',
  'permission denied for table event_finals_eligible_snapshot',
  'authenticated owner cannot delete frozen snapshot rows'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.create_finals_fixture(3, 102),
    test_support.finals_fixture_uuid(3, 2, 102)
  ),
  'begins three-player Champions Finals'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.create_finals_fixture(4, 103),
    test_support.finals_fixture_uuid(3, 2, 103)
  ),
  'begins four-player Champions Finals'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.create_finals_fixture(5, 104),
    test_support.finals_fixture_uuid(3, 2, 104)
  ),
  'begins five-player automatic Redemption Finals'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(6, 105),
    test_support.finals_fixture_uuid(3, 2, 105),
    test_support.finals_fixture_uuid(3, 3, 105)
  ),
  'begins six-player Redemption advancement Finals'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(7, 106),
    test_support.finals_fixture_uuid(3, 2, 106),
    test_support.finals_fixture_uuid(3, 3, 106)
  ),
  'begins seven-player Redemption advancement Finals'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(8, 107),
    test_support.finals_fixture_uuid(3, 2, 107),
    test_support.finals_fixture_uuid(3, 3, 107)
  ),
  'begins eight-player parallel Finals atomically'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(9, 108),
    test_support.finals_fixture_uuid(3, 2, 108),
    test_support.finals_fixture_uuid(3, 3, 108)
  ),
  'begins nine-player parallel Finals atomically'
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(12, 109),
    test_support.finals_fixture_uuid(3, 2, 109),
    test_support.finals_fixture_uuid(3, 3, 109)
  ),
  'begins twelve-player parallel Finals atomically'
);

select is(
  (
    select count(*)::integer
    from public.table_sessions as session
    where session.event_id = test_support.finals_fixture_uuid(2, 1, 107)
      and session.finals_contest_id is not null
  ),
  2,
  'eight-player begin starts Champions and Redemption together'
);
select is(
  (
    select string_agg(seat.initial_wind, ',' order by slot.slot_index)
    from public.event_finals_champions_slots as slot
    join public.event_bonus_rounds as bonus_round
      on bonus_round.id = slot.bonus_round_id
    join public.event_finals_contests as contest
      on contest.bonus_round_id = bonus_round.id
      and contest.contest_type = 'table_of_champions'
    join public.table_session_seats as seat
      on seat.table_session_id = contest.table_session_id
      and seat.event_guest_id = slot.event_guest_id
    where bonus_round.event_id = test_support.finals_fixture_uuid(2, 1, 103)
  ),
  'north,west,south,east',
  'four-player Champions slots preserve the approved wind advantage'
);
select is(
  (
    select bonus_round.redemption_resolution_method
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = test_support.finals_fixture_uuid(2, 1, 104)
  ),
  'standing_fifth',
  'five-player Finals records the automatic Redemption result'
);

select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(8, 110),
    test_support.finals_fixture_uuid(3, 2, 110),
    test_support.finals_fixture_uuid(3, 2, 110)
  ),
  'P0001',
  'Finals tables must be different.',
  'rejects conflicting selected Finals tables'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 110)),
  0,
  'selected-table conflict leaves no Finals root'
);

select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.create_finals_fixture(8, 111),
    test_support.finals_fixture_uuid(3, 2, 111),
    test_support.finals_fixture_uuid(3, 3, 111)
  ),
  'owner may begin Finals'
);
create temporary table unauthorized_score_snapshot as
select jsonb_agg(
  jsonb_build_object('guest', score.event_guest_id, 'row', score.ctid::text)
  order by score.event_guest_id
) as rows
from public.event_score_totals as score
where score.event_id = test_support.finals_fixture_uuid(2, 1, 101);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(1, 1, 2),
    test_support.finals_fixture_uuid(2, 1, 101),
    test_support.finals_fixture_uuid(3, 2, 101)
  ),
  'P0001',
  'Event not found for current Finals operator.',
  'unrelated authenticated user may not begin Finals'
);
select is(
  (select jsonb_agg(
     jsonb_build_object('guest', score.event_guest_id, 'row', score.ctid::text)
     order by score.event_guest_id
   )
   from public.event_score_totals as score
   where score.event_id = test_support.finals_fixture_uuid(2, 1, 101)),
  (select rows from unauthorized_score_snapshot),
  'unauthorized legacy Begin performs no score refresh write'
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', '''', true); '
    || 'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 101),
    test_support.finals_fixture_uuid(3, 2, 101)
  ),
  'P0001',
  'Event not found for current Finals operator.',
  'anonymous user may not begin Finals'
);

create temporary table duplicate_score_snapshot as
select jsonb_agg(
  jsonb_build_object('guest', score.event_guest_id, 'row', score.ctid::text)
  order by score.event_guest_id
) as rows
from public.event_score_totals as score
where score.event_id = test_support.finals_fixture_uuid(2, 1, 107);
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.begin_event_finals(%L, %L, %L, 1)',
    test_support.finals_fixture_uuid(1, 1, 107),
    test_support.finals_fixture_uuid(2, 1, 107),
    test_support.finals_fixture_uuid(3, 2, 107),
    test_support.finals_fixture_uuid(3, 3, 107)
  ),
  'duplicate begin returns the existing orchestrated state'
);
select is(
  (select jsonb_agg(
     jsonb_build_object('guest', score.event_guest_id, 'row', score.ctid::text)
     order by score.event_guest_id
   )
   from public.event_score_totals as score
   where score.event_id = test_support.finals_fixture_uuid(2, 1, 107)),
  (select rows from duplicate_score_snapshot),
  'duplicate legacy Begin returns before any score refresh write'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 107)),
  1,
  'duplicate begin does not create another Finals root'
);

select test_support.create_finals_fixture(8, 112);
update public.hand_settlements
set amount_points = 30
where payer_event_guest_id = test_support.finals_fixture_uuid(4, 5, 112);
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.finals_fixture_uuid(1, 1, 112),
    test_support.finals_fixture_uuid(2, 1, 112),
    test_support.finals_fixture_uuid(3, 2, 112),
    test_support.finals_fixture_uuid(3, 3, 112)
  ),
  'starts a two-player direct-cutoff tiebreak'
);
select is(
  (
    select count(*)::integer
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 112)
      and contest.contest_type = 'direct_qualification_tiebreak'
      and contest.status = 'active'
  ),
  2,
  'direct-cutoff tiebreak contains only the tied players'
);
select is(
  (
    select count(*)::integer
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 112)
      and contest.contest_type = 'table_of_redemption'
  ),
  0,
  'pending Redemption does not pre-resolve cutoff-tied players by seed order'
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 112)
     and contest_type = 'direct_qualification_tiebreak'),
  'win', 0
);
select ok(
  (select count(*) = 4 from public.event_finals_champions_slots as slot
   join public.event_bonus_rounds as root on root.id = slot.bonus_round_id
   where root.event_id = test_support.finals_fixture_uuid(2, 1, 112)
     and slot.event_guest_id is not null)
  and (select count(*) = 1 from public.event_finals_contests
       where event_id = test_support.finals_fixture_uuid(2, 1, 112)
         and contest_type = 'table_of_redemption' and status = 'ready'),
  'direct-qualification tiebreak winner fills the open slot and unlocks dependents'
);
select public.start_finals_contest(
  (select id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 112)
     and contest_type = 'table_of_redemption'),
  test_support.finals_fixture_uuid(3, 3, 112),
  (select state_version from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 112))
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.void_hand_result(%L, ''Cannot change direct result after Redemption started'')',
    test_support.finals_fixture_uuid(1, 1, 112),
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 112)
       and contest.contest_type = 'direct_qualification_tiebreak')
  ),
  'P0001',
  'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.',
  'direct-qualification result cannot change after dependent Redemption starts'
);

select test_support.create_finals_fixture(5, 121);
update public.hand_settlements
set amount_points = 30
where payer_event_guest_id = test_support.finals_fixture_uuid(4, 5, 121);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 121),
    test_support.finals_fixture_uuid(3, 2, 121)
  ),
  'starts a five-player direct-cutoff tiebreak'
);
select is(
  (
    select redemption_winner_event_guest_id
    from public.event_bonus_rounds
    where event_id = test_support.finals_fixture_uuid(2, 1, 121)
  ),
  null,
  'five-player cutoff tie does not choose the automatic Redemption winner by seed'
);

select test_support.create_finals_fixture(8, 113);
update public.hand_settlements
set amount_points = 10
where payer_event_guest_id in (
  select test_support.finals_fixture_uuid(4, player_index, 113)
  from generate_series(2, 6) as player_index
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.finals_fixture_uuid(1, 1, 113),
    test_support.finals_fixture_uuid(2, 1, 113),
    test_support.finals_fixture_uuid(3, 2, 113),
    test_support.finals_fixture_uuid(3, 3, 113)
  ),
  'P0001',
  'The Finals cutoff tie has more than four players and requires manual resolution.',
  'rejects a direct-cutoff tie group larger than four'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 113)),
  0,
  'oversized cutoff tie leaves no Finals state'
);

select test_support.create_finals_fixture(4, 114);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 99, 114),
  test_support.finals_fixture_uuid(2, 1, 114),
  test_support.finals_fixture_uuid(3, 1, 114),
  99, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 114), 'tournament'
);
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 114),
    test_support.finals_fixture_uuid(3, 2, 114)
  ),
  'P0001',
  'End active or paused tournament sessions before beginning Finals.',
  'rejects a blocking live tournament session'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 114)),
  0,
  'blocking tournament session leaves no Finals root'
);

select test_support.create_finals_fixture(4, 116);
insert into public.guest_profiles (
  id, owner_user_id, display_name, normalized_name, public_display_name
)
select
  test_support.finals_fixture_uuid(8, player_index, 116),
  test_support.finals_fixture_uuid(1, 1, 116),
  'Unrelated Player ' || player_index,
  'unrelated player ' || player_index,
  'Unrelated Player ' || player_index
from generate_series(20, 21) as player_index;
insert into public.event_guests (
  id, event_id, guest_profile_id, display_name, normalized_name,
  attendance_status, checked_in_at, tournament_status, public_display_name
)
select
  test_support.finals_fixture_uuid(4, player_index, 116),
  test_support.finals_fixture_uuid(2, 1, 116),
  test_support.finals_fixture_uuid(8, player_index, 116),
  'Unrelated Player ' || player_index,
  'unrelated player ' || player_index,
  'checked_in', now(), 'withdrawn', 'Unrelated Player ' || player_index
from generate_series(20, 21) as player_index;
insert into public.event_tables (id, event_id, label, display_order)
values (
  test_support.finals_fixture_uuid(3, 4, 116),
  test_support.finals_fixture_uuid(2, 1, 116),
  'Unrelated Table', 4
);
insert into public.event_seating_assignments (
  event_id, event_table_id, event_guest_id, seat_index, assignment_round,
  assignment_type, status, assigned_by_user_id
)
values
  (
    test_support.finals_fixture_uuid(2, 1, 116),
    test_support.finals_fixture_uuid(3, 4, 116),
    test_support.finals_fixture_uuid(4, 20, 116),
    0, 99, 'random', 'active', test_support.finals_fixture_uuid(1, 1, 116)
  ),
  (
    test_support.finals_fixture_uuid(2, 1, 116),
    test_support.finals_fixture_uuid(3, 4, 116),
    test_support.finals_fixture_uuid(4, 21, 116),
    1, 99, 'random', 'active', test_support.finals_fixture_uuid(1, 1, 116)
  );
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 99, 116),
  test_support.finals_fixture_uuid(2, 1, 116),
  test_support.finals_fixture_uuid(3, 4, 116),
  99, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 116), 'qualification'
);
insert into public.table_session_seats (table_session_id, seat_index, initial_wind, event_guest_id)
values
  (test_support.finals_fixture_uuid(6, 99, 116), 0, 'east', test_support.finals_fixture_uuid(4, 20, 116)),
  (test_support.finals_fixture_uuid(6, 99, 116), 1, 'south', test_support.finals_fixture_uuid(4, 21, 116));
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 116),
    test_support.finals_fixture_uuid(3, 2, 116)
  ),
  'an unrelated active session with a disjoint table and participants does not block Finals'
);
select is(
  (
    select count(*)::integer from public.event_seating_assignments
    where event_id = test_support.finals_fixture_uuid(2, 1, 116)
      and event_table_id = test_support.finals_fixture_uuid(3, 4, 116)
      and status = 'active'
  ),
  2,
  'Begin Finals preserves durable assignments for a disjoint live session'
);

select test_support.create_finals_fixture(4, 117);
insert into public.users (id, email, display_name)
values (
  test_support.finals_fixture_uuid(1, 2, 117),
  'finals-scorer-117@example.test',
  'Finals Scorer 117'
);
insert into public.approved_logistics_identities (
  id, email, email_lower, display_name, status, approved_by_user_id
) values (
  test_support.finals_fixture_uuid(12, 1, 117),
  'finals-scorer-117@example.test', 'finals-scorer-117@example.test',
  'Finals Scorer 117', 'active', test_support.finals_fixture_uuid(1, 1, 117)
);
insert into public.event_staff_memberships (
  id, event_id, approved_identity_id, user_id, role, status, created_by_user_id
) values (
  test_support.finals_fixture_uuid(13, 1, 117),
  test_support.finals_fixture_uuid(2, 1, 117),
  test_support.finals_fixture_uuid(12, 1, 117),
  test_support.finals_fixture_uuid(1, 2, 117),
  'event_scorer', 'active', test_support.finals_fixture_uuid(1, 1, 117)
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(1, 2, 117),
    test_support.finals_fixture_uuid(2, 1, 117),
    test_support.finals_fixture_uuid(3, 2, 117)
  ),
  'P0001',
  'Event not found for current Finals operator.',
  'scoring-only staff may not begin Finals'
);

create or replace function test_support.force_unchecked_finals_assignment()
returns trigger language plpgsql as $$
begin
  if new.event_id = test_support.finals_fixture_uuid(2, 1, 118) then
    update public.event_guests set attendance_status = 'expected', checked_in_at = null
    where id = new.event_guest_id;
  end if;
  return new;
end;
$$;
create trigger force_unchecked_finals_assignment
after insert on public.event_seating_assignments
for each row execute function test_support.force_unchecked_finals_assignment();
select test_support.create_finals_fixture(4, 118);
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 118),
    test_support.finals_fixture_uuid(3, 2, 118)
  ),
  'P0001',
  'All Finals players must be checked in before starting.',
  'unchecked player race rolls back Finals start'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 118)),
  0,
  'unchecked player failure leaves no Finals root'
);
drop trigger force_unchecked_finals_assignment on public.event_seating_assignments;

select test_support.create_finals_fixture(4, 120);
set session_replication_role = replica;
update public.event_tables
set default_ruleset_id = 'MISSING_FINALS_RULESET'
where id = test_support.finals_fixture_uuid(3, 2, 120);
set session_replication_role = origin;
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 120),
    test_support.finals_fixture_uuid(3, 2, 120)
  ),
  'P0001',
  'Default ruleset not found for the selected Finals table.',
  'missing selected-table ruleset aborts Finals start'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 120)),
  0,
  'missing ruleset failure leaves no Finals root'
);
set session_replication_role = replica;
update public.event_tables
set default_ruleset_id = 'HK_STANDARD'
where id = test_support.finals_fixture_uuid(3, 2, 120);
set session_replication_role = origin;

create or replace function test_support.force_finals_session_insert_failure()
returns trigger language plpgsql as $$
begin
  if new.event_id = test_support.finals_fixture_uuid(2, 1, 119)
    and new.finals_contest_id is not null then
    raise exception 'Forced Finals session insert failure.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger force_finals_session_insert_failure
before insert on public.table_sessions
for each row execute function test_support.force_finals_session_insert_failure();
select test_support.create_finals_fixture(4, 119);
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 119),
    test_support.finals_fixture_uuid(3, 2, 119)
  ),
  'P0001',
  'Forced Finals session insert failure.',
  'forced session insert failure aborts the atomic start'
);
select ok(
  not exists (
    select 1 from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 119)
  ) and not exists (
    select 1 from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 119)
  ) and not exists (
    select 1 from public.event_seating_assignments where event_id = test_support.finals_fixture_uuid(2, 1, 119)
  ) and not exists (
    select 1 from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 119)
      and finals_contest_id is not null
  ) and (
    select current_scoring_phase = 'tournament' from public.events where id = test_support.finals_fixture_uuid(2, 1, 119)
  ),
  'forced failure rolls back root, contests, assignments, sessions, and phase change'
);
drop trigger force_finals_session_insert_failure on public.table_sessions;

select ok(
  pg_get_functiondef('public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure)
    like '%pg_advisory_xact_lock%',
  'concurrent Begin Finals requests are serialized by an event advisory lock'
);
select ok(
  (
    select metadata_json ? 'champions_table_label'
      and metadata_json ? 'redemption_table_label'
    from public.audit_logs
    where event_id = test_support.finals_fixture_uuid(2, 1, 107)
      and action = 'begin_event_finals'
  ),
  'Finals transition audit records the selected table labels'
);

select is(
  (
    select string_agg(seat.initial_wind, ',' order by seat.seat_index)
    from public.table_session_seats as seat
    join public.table_sessions as session on session.id = seat.table_session_id
    where session.event_id = test_support.finals_fixture_uuid(2, 1, 101)
      and session.finals_contest_id is not null
  ),
  'east,south',
  'two-player Champions uses contiguous East-first seats'
);
select is(
  (
    select string_agg(seat.initial_wind, ',' order by seat.seat_index)
    from public.table_session_seats as seat
    join public.table_sessions as session on session.id = seat.table_session_id
    where session.event_id = test_support.finals_fixture_uuid(2, 1, 102)
      and session.finals_contest_id is not null
  ),
  'east,south,west',
  'three-player Champions uses contiguous East-first seats'
);
select ok(
  (
    select redemption_winner_event_guest_id = test_support.finals_fixture_uuid(4, 5, 104)
    from public.event_bonus_rounds
    where event_id = test_support.finals_fixture_uuid(2, 1, 104)
  ) and (
    select count(*) = 1 from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 104)
      and finals_contest_id is not null
  ),
  'five-player Finals starts Champions and records fifth place as Redemption winner'
);
select is(
  (
    select string_agg(slot.slot_index || ':' || snapshot.seed_rank, ',' order by slot.slot_index)
    from public.event_finals_champions_slots as slot
    join public.event_bonus_rounds as bonus_round on bonus_round.id = slot.bonus_round_id
    join app_private.finals_standings_snapshot(bonus_round.event_id) as snapshot
      on snapshot.event_guest_id = slot.event_guest_id
    where bonus_round.event_id = test_support.finals_fixture_uuid(2, 1, 105)
  ),
  '1:1,2:2',
  'six-player Finals freezes two direct Champions slots'
);
select is(
  (
    select string_agg(participant.entry_seed::text, ',' order by participant.seat_index)
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 106)
      and contest.contest_type = 'table_of_redemption'
      and contest.status = 'active'
  ),
  '4,5,6,7',
  'seven-player Finals starts Redemption with seeds four through seven'
);
select is(
  (
    select string_agg(participant.entry_seed::text, ',' order by participant.entry_seed)
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 108)
      and contest.contest_type = 'table_of_redemption'
  ),
  '6,7,8,9',
  'nine-player Finals selects the bottom four for Redemption'
);
select is(
  (
    select string_agg(participant.entry_seed::text, ',' order by participant.entry_seed)
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 109)
      and contest.contest_type = 'table_of_redemption'
  ),
  '9,10,11,12',
  'twelve-player Finals selects the bottom four for Redemption'
);

select test_support.create_finals_fixture(8, 123);
update public.hand_settlements set amount_points = 20
where payer_event_guest_id in (
  test_support.finals_fixture_uuid(4, 4, 123),
  test_support.finals_fixture_uuid(4, 5, 123)
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.finals_fixture_uuid(2, 1, 123),
    test_support.finals_fixture_uuid(3, 2, 123),
    test_support.finals_fixture_uuid(3, 3, 123)
  ),
  'starts a three-player direct-cutoff tiebreak'
);
select is(
  (
    select count(*)::integer
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 123)
      and contest.contest_type = 'direct_qualification_tiebreak'
  ),
  3,
  'three-player cutoff tiebreak retains all three tied players'
);

select test_support.create_finals_fixture(8, 124);
update public.hand_settlements set amount_points = 10
where payer_event_guest_id in (
  test_support.finals_fixture_uuid(4, 3, 124),
  test_support.finals_fixture_uuid(4, 4, 124),
  test_support.finals_fixture_uuid(4, 5, 124)
);
select lives_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.finals_fixture_uuid(2, 1, 124),
    test_support.finals_fixture_uuid(3, 2, 124),
    test_support.finals_fixture_uuid(3, 3, 124)
  ),
  'starts a four-player direct-cutoff tiebreak'
);
select is(
  (
    select count(*)::integer
    from public.event_finals_contest_participants as participant
    join public.event_finals_contests as contest on contest.id = participant.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 124)
      and contest.contest_type = 'direct_qualification_tiebreak'
  ),
  4,
  'four-player cutoff tiebreak retains all four tied players'
);

select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 1)',
    test_support.create_finals_fixture(4, 125),
    test_support.finals_fixture_uuid(3, 2, 125)
  ),
  'P0001',
  'Finals changed since this screen was loaded. Refresh and try again.',
  'rejects a stale initial Finals version'
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.begin_event_finals(%L, %L, %L, 1)',
    test_support.finals_fixture_uuid(1, 1, 107),
    test_support.finals_fixture_uuid(2, 1, 107),
    test_support.finals_fixture_uuid(3, 3, 107),
    test_support.finals_fixture_uuid(3, 2, 107)
  ),
  'P0001',
  'Finals already began with different table selections. Refresh and try again.',
  'rejects conflicting selections after Finals already began'
);

select test_support.create_finals_fixture(4, 126);
insert into public.event_bonus_rounds (
  event_id, champions_table_id, redemption_table_id, assignment_round, status
) values (
  test_support.finals_fixture_uuid(2, 1, 126),
  test_support.finals_fixture_uuid(3, 2, 126), null, 1, 'active'
);
insert into public.event_seating_assignments (
  event_id, event_table_id, event_guest_id, seat_index, assignment_round,
  assignment_type, bonus_round_id, bonus_table_role, seed_rank, status,
  assigned_by_user_id
)
select
  test_support.finals_fixture_uuid(2, 1, 126),
  test_support.finals_fixture_uuid(3, 2, 126),
  test_support.finals_fixture_uuid(4, player_index, 126),
  player_index - 1, 1, 'bonus', bonus_round.id, 'table_of_champions',
  player_index, 'active', test_support.finals_fixture_uuid(1, 1, 126)
from generate_series(1, 4) as player_index
cross join public.event_bonus_rounds as bonus_round
where bonus_round.event_id = test_support.finals_fixture_uuid(2, 1, 126);
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 126),
    test_support.finals_fixture_uuid(3, 2, 126)
  ),
  'P0001',
  'Active Finals already exist for this event. Use the Finals recovery action.',
  'fails closed when active legacy Finals already exist'
);
select is(
  (
    select count(*)::integer from public.event_seating_assignments
    where event_id = test_support.finals_fixture_uuid(2, 1, 126) and status = 'active'
  ),
  4,
  'legacy Finals rejection preserves existing active assignments'
);

select test_support.create_finals_fixture(6, 127);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 99, 127),
  test_support.finals_fixture_uuid(2, 1, 127),
  test_support.finals_fixture_uuid(3, 2, 127),
  99, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 127), 'qualification'
);
insert into public.table_session_seats (table_session_id, seat_index, initial_wind, event_guest_id)
values
  (test_support.finals_fixture_uuid(6, 99, 127), 0, 'east', test_support.finals_fixture_uuid(4, 1, 127)),
  (test_support.finals_fixture_uuid(6, 99, 127), 1, 'south', test_support.finals_fixture_uuid(4, 2, 127));
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0)',
    test_support.finals_fixture_uuid(2, 1, 127),
    test_support.finals_fixture_uuid(3, 2, 127),
    test_support.finals_fixture_uuid(3, 3, 127)
  ),
  'P0001',
  'Selected Finals tables must not have active or paused sessions.',
  'rejects an occupied dependent Champions table before starting Redemption'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 127)),
  0,
  'occupied selected table leaves no Finals root'
);

select is(
  (
    select current_scoring_phase from public.events
    where id = test_support.finals_fixture_uuid(2, 1, 103)
  ),
  'bonus',
  'successful Begin Finals uses the supported bonus-round phase transition'
);

select test_support.create_finals_fixture(4, 128);
insert into public.event_bonus_rounds (
  event_id, champions_table_id, redemption_table_id, assignment_round, status
) values (
  test_support.finals_fixture_uuid(2, 1, 128),
  test_support.finals_fixture_uuid(3, 2, 128), null, 1, 'completed'
);
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.finals_fixture_uuid(2, 1, 128),
    test_support.finals_fixture_uuid(3, 2, 128)
  ),
  'P0001',
  'Completed legacy Finals already exist for this event.',
  'completed legacy Finals history blocks a new orchestrated root'
);

-- Task 3 progression, advancement, tiebreak, award, and completion scenarios.
select public.begin_event_finals(
  test_support.create_finals_fixture(6, 201),
  test_support.finals_fixture_uuid(3, 2, 201),
  test_support.finals_fixture_uuid(3, 3, 201), 0
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 201))
    -> 'allowed_actions',
  '[]'::jsonb,
  'active Redemption exposes no invalid mutation action'
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 201), 'table_of_redemption',
  array[30, 10, -10, -30]
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 201))
    -> 'allowed_actions',
  jsonb_build_array(jsonb_build_object(
    'action', 'start_contest',
    'label', 'Start Table of Champions',
    'contest_id', (select id from public.event_finals_contests
      where event_id = test_support.finals_fixture_uuid(2, 1, 201)
        and contest_type = 'table_of_champions'),
    'table_id', test_support.finals_fixture_uuid(3, 2, 201),
    'available_table_ids', jsonb_build_array(
      test_support.finals_fixture_uuid(3, 2, 201),
      test_support.finals_fixture_uuid(3, 3, 201)
    ),
    'expected_state_version', (select state_version from public.event_bonus_rounds
      where event_id = test_support.finals_fixture_uuid(2, 1, 201))
  )),
  'ready Champions exposes the exact server start action'
);
select is(
  (select string_agg(slot.slot_index || ':' || participant.entry_seed, ',' order by slot.slot_index)
   from public.event_finals_champions_slots as slot
   join public.event_finals_contest_participants as participant
     on participant.event_guest_id = slot.event_guest_id
   join public.event_finals_contests as contest on contest.id = participant.contest_id
   where slot.bonus_round_id = (select id from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 201))
     and contest.contest_type = 'table_of_redemption'),
  '3:3,4:4',
  'six-player Redemption fills slots three and four in finish order'
);
select is(
  (select redemption_winner_event_guest_id from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 201)),
  test_support.finals_fixture_uuid(4, 3, 201),
  'six-player Redemption preserves its first-place winner'
);
select ok(
  (select count(*) > 0 from public.get_public_event_finals_leaderboard(test_support.finals_fixture_uuid(2, 1, 201)))
  and exists (
    select 1 from public.public_event_standings_snapshots
    where event_id = test_support.finals_fixture_uuid(2, 1, 201)
      and jsonb_array_length(payload -> 'finalsLeaderboards') > 0
  ),
  'Redemption result refreshes the public Finals projection and snapshot'
);
select throws_ok(
  format('select public.complete_event(%L)', test_support.finals_fixture_uuid(2, 1, 201)),
  'P0001',
  'Resolve every required Finals contest before completing the event.',
  'event completion rejects a ready required Finals contest'
);
update public.event_finals_contests
set status = 'pending'
where event_id = test_support.finals_fixture_uuid(2, 1, 201)
  and contest_type = 'table_of_champions';
delete from public.event_finals_contest_participants
where contest_id = (
  select id from public.event_finals_contests
  where event_id = test_support.finals_fixture_uuid(2, 1, 201)
    and contest_type = 'table_of_champions'
);
delete from public.event_finals_eligible_snapshot
where bonus_round_id = (
  select id from public.event_bonus_rounds
  where event_id = test_support.finals_fixture_uuid(2, 1, 201)
)
  and event_guest_id = test_support.finals_fixture_uuid(4, 1, 201);
select throws_ok(
  format(
    'select app_private.ensure_champions_contest_ready(%L)',
    (select id from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 201))
  ),
  'P0001',
  'Finals eligible snapshot is incomplete for this root.',
  'Champions rebuild fails closed when an occupied slot has no frozen seed'
);
select is(
  (select count(*)::integer
   from public.event_finals_contest_participants
   where contest_id = (
     select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 201)
       and contest_type = 'table_of_champions'
   )),
  0,
  'failed Champions rebuild writes no partial participant rows'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(7, 202),
  test_support.finals_fixture_uuid(3, 2, 202),
  test_support.finals_fixture_uuid(3, 3, 202), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 202), 'table_of_redemption', array[30, 10, -10, -30]);
select is(
  (select event_guest_id from public.event_finals_champions_slots
   where bonus_round_id = (select id from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 202))
     and slot_index = 4),
  test_support.finals_fixture_uuid(4, 4, 202),
  'seven-player Redemption winner fills slot four'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 203),
  test_support.finals_fixture_uuid(3, 2, 203),
  test_support.finals_fixture_uuid(3, 3, 203), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 203), 'table_of_redemption', array[30, 10, 10, -50]);
select is(
  (select count(*)::integer from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 203)
     and contest_type = 'redemption_advancement_tiebreak' and status = 'ready'),
  1,
  'advancement tie at the cutoff creates one ready tiebreak'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 203))
    #>> '{allowed_actions,0,label}',
  'Start Redemption Tiebreak',
  'ready advancement tiebreak exposes its host-safe start action'
);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, -1)',
    (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 203)
      and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 3, 203)
  ),
  'P0001',
  'Finals changed since this screen was loaded. Refresh and try again.',
  'stale contest start fails before creating assignments or a session'
);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 203)
    and contest_type = 'redemption_advancement_tiebreak'),
  test_support.finals_fixture_uuid(3, 3, 203),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 203))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 203)
    and contest_type = 'redemption_advancement_tiebreak'), 'win', 0
);
select is(
  (select status from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 203)
     and contest_type = 'table_of_champions'),
  'ready',
  'final Redemption advancement tiebreak unlocks Table of Champions'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 204),
  test_support.finals_fixture_uuid(3, 2, 204),
  test_support.finals_fixture_uuid(3, 3, 204), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 204), 'table_of_redemption', array[20, 20, -10, -30]);
select is(
  (select slots_to_fill from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 204)
     and contest_type = 'redemption_advancement_tiebreak'),
  2,
  'tie affecting finish order creates a two-slot tiebreak even when both advance'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 205),
  test_support.finals_fixture_uuid(3, 2, 205),
  test_support.finals_fixture_uuid(3, 3, 205), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 205), 'table_of_redemption', array[10, 10, 10, -30]);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 205)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'ready'),
  test_support.finals_fixture_uuid(3, 3, 205),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 205))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 205)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'active'), 'win', 0
);
select ok(
  (select count(*) = 2 from public.event_finals_contest_participants as participant
   join public.event_finals_contests as contest on contest.id = participant.contest_id
   where contest.event_id = test_support.finals_fixture_uuid(2, 1, 205)
     and contest.parent_contest_id is not null and contest.status = 'ready')
  and (select count(*) = 1 from public.event_finals_champions_slots as slot
       join public.event_bonus_rounds as root on root.id = slot.bonus_round_id
       where root.event_id = test_support.finals_fixture_uuid(2, 1, 205)
         and slot.qualification_method = 'tiebreak_win'),
  'elimination tiebreak advances the first winner and excludes them from the next contest'
);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 205)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'ready'),
  test_support.finals_fixture_uuid(3, 3, 205),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 205))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 205)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'active'), 'washout', null
);
select is(
  (select count(*)::integer from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 205)
     and contest_type = 'redemption_advancement_tiebreak' and status = 'active'),
  1,
  'draw advances nobody and keeps the same sudden-death contest active'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(8, 206),
  test_support.finals_fixture_uuid(3, 2, 206),
  test_support.finals_fixture_uuid(3, 3, 206), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 206), 'table_of_redemption', array[10, 10, -10, -10]);
select is(
  (select count(*)::integer from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 206)
     and contest_type = 'redemption_winner_tiebreak' and status = 'ready'),
  0,
  'standalone eight-player Redemption winner tie does not create a winner tiebreak'
);
select is(
  (select count(*)::integer
   from public.event_finals_contest_participants as participant
   join public.event_finals_contests as contest
     on contest.id = participant.contest_id
   where contest.event_id = test_support.finals_fixture_uuid(2, 1, 206)
     and contest.contest_type = 'table_of_redemption'
     and participant.outcome = 'winner'),
  2,
  'standalone eight-player Redemption winner tie records both leaders as winners'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(4, 207),
  test_support.finals_fixture_uuid(3, 2, 207), null, 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 207), 'table_of_champions', array[10, 10, -10, -10]);
select is(
  (select count(*)::integer from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 207)
     and contest_type = 'champions_sudden_death' and status = 'ready'),
  1,
  'Champions tie creates one ready sudden-death contest'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 207))
    #>> '{allowed_actions,0,label}',
  'Start Champions Sudden Death',
  'ready Champions sudden death exposes its host-safe start action'
);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 207)
    and contest_type = 'champions_sudden_death'),
  test_support.finals_fixture_uuid(3, 2, 207),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 207))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 207)
    and contest_type = 'champions_sudden_death'), 'win', 0
);
select ok(
  (select champion_event_guest_id is not null and status = 'completed'
   from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 207)),
  'decisive Champions sudden death records the champion and completes the root'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 207))
    -> 'allowed_actions',
  '[]'::jsonb,
  'completed Finals exposes no invalid mutation action'
);
select is(
  (select count(*)::integer from public.event_score_adjustments
   where event_id = test_support.finals_fixture_uuid(2, 1, 207)
     and adjustment_type = 'finals_champion_award'),
  1,
  'unique final result creates the champion award exactly once'
);
select app_private.recalculate_finals_state(
  (select table_session_id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 207)
     and contest_type = 'champions_sudden_death')
);
select ok(
  (select count(*) = 1 from public.event_score_adjustments
   where event_id = test_support.finals_fixture_uuid(2, 1, 207)
     and adjustment_type = 'finals_champion_award')
  and (
    select champion_total.total_points > max(other_total.total_points)
    from public.event_bonus_rounds as root
    join public.event_score_totals as champion_total
      on champion_total.event_id = root.event_id
      and champion_total.event_guest_id = root.champion_event_guest_id
    join public.event_score_totals as other_total
      on other_total.event_id = root.event_id
      and other_total.event_guest_id <> root.champion_event_guest_id
    where root.event_id = test_support.finals_fixture_uuid(2, 1, 207)
    group by champion_total.total_points
  ),
  'repeated champion recalculation preserves one stable top-up award'
);
select lives_ok(
  format('select public.complete_event(%L)', test_support.finals_fixture_uuid(2, 1, 207)),
  'event completion is allowed only after the Finals root is complete'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(4, 208),
  test_support.finals_fixture_uuid(3, 2, 208), null, 0
);
update public.table_sessions set status = 'completed', ended_at = now()
where event_id = test_support.finals_fixture_uuid(2, 1, 208) and finals_contest_id is not null;
select throws_ok(
  format('select public.complete_event(%L)', test_support.finals_fixture_uuid(2, 1, 208)),
  'P0001',
  'Resolve every required Finals contest before completing the event.',
  'event completion rejects an incomplete orchestrated Finals root'
);
update public.event_finals_contests set status = 'pending'
where event_id = test_support.finals_fixture_uuid(2, 1, 208)
  and contest_type = 'table_of_champions';
select throws_ok(
  format('select public.complete_event(%L)', test_support.finals_fixture_uuid(2, 1, 208)),
  'P0001',
  'Resolve every required Finals contest before completing the event.',
  'event completion rejects a pending required Finals contest'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(4, 209),
  test_support.finals_fixture_uuid(3, 2, 209), null, 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 209), 'table_of_champions', array[30, 10, -10, -30]);
select ok(
  (select count(*) > 0 from public.get_public_event_finals_leaderboard(test_support.finals_fixture_uuid(2, 1, 209))),
  'public Finals projection includes orchestrated Champions results'
);
select ok(
  exists (
    select 1 from public.public_event_standings_snapshots
    where event_id = test_support.finals_fixture_uuid(2, 1, 209)
      and jsonb_array_length(payload -> 'bonusResults') > 0
  ),
  'public standings snapshot refresh includes orchestrated champion results'
);

select test_support.create_ready_orchestrated_contest(
  299, 'table_of_champions', 'table_of_champions'
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); select public.start_finals_contest(%L, %L, %s)',
    test_support.finals_fixture_uuid(1, 1, 2),
    test_support.finals_fixture_uuid(11, 1, 299),
    test_support.finals_fixture_uuid(3, 2, 299),
    (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 299))
  ),
  'P0001', 'Finals contest not found for current operator.',
  'scoring-only or unrelated users may not start a Finals contest'
);
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); select public.start_finals_contest(%L, %L, %s)',
    test_support.finals_fixture_uuid(1, 1, 299),
    test_support.finals_fixture_uuid(11, 1, 299),
    test_support.finals_fixture_uuid(3, 2, 299),
    (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 299))
  ),
  'owner may start a ready Finals contest'
);
select lives_ok(
  format(
    'select public.start_finals_contest(%L, %L, -1)',
    test_support.finals_fixture_uuid(11, 1, 299),
    test_support.finals_fixture_uuid(3, 2, 299)
  ),
  'duplicate contest start returns current state even with a stale retry version'
);
select is(
  (select redemption_resolution_method from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 206)),
  'table_score_tie',
  'standalone Redemption tie records its co-winner resolution'
);
select ok(
  pg_get_functiondef('public.start_finals_contest(uuid,uuid,bigint)'::regprocedure)
    like '%pg_advisory_xact_lock%'
  and pg_get_functiondef('public.start_finals_contest(uuid,uuid,bigint)'::regprocedure)
    like '%hashtextextended(contest_row.event_id::text, 0)%',
  'contest starts serialize concurrent requests on the canonical event lock'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 210),
  test_support.finals_fixture_uuid(3, 2, 210),
  test_support.finals_fixture_uuid(3, 3, 210), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 210), 'table_of_redemption', array[30, 10, -10, -30]);
select lives_ok(
  format(
    'select test_support.score_finals_contest(%L, ''table_of_redemption'', array[20,20,-10,-30])',
    test_support.finals_fixture_uuid(2, 1, 210)
  ),
  'upstream hand edit before dependent contest start rebuilds ready state'
);
select ok(
  (select count(*) = 1 from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 210)
     and contest_type = 'table_of_champions' and status = 'pending')
  and (select count(*) = 1 from public.event_finals_contests
       where event_id = test_support.finals_fixture_uuid(2, 1, 210)
         and contest_type = 'redemption_advancement_tiebreak' and status = 'ready')
  and (select count(*) = 2 from public.event_finals_champions_slots as slot
       join public.event_bonus_rounds as root on root.id = slot.bonus_round_id
       where root.event_id = test_support.finals_fixture_uuid(2, 1, 210)
         and slot.event_guest_id is not null),
  'ready dependent contest is cancelled and rebuilt from corrected source results'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 211),
  test_support.finals_fixture_uuid(3, 2, 211),
  test_support.finals_fixture_uuid(3, 3, 211), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 211), 'table_of_redemption', array[30, 10, -10, -30]);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 211)
    and contest_type = 'table_of_champions'),
  test_support.finals_fixture_uuid(3, 2, 211),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 211))
);
select throws_ok(
  format(
    'select public.void_hand_result(%L, ''Corrected after Champions started'')',
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 211)
       and contest.contest_type = 'table_of_redemption')
  ),
  'P0001',
  'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.',
  'upstream hand edit after dependent contest start fails closed'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(4, 213),
  test_support.finals_fixture_uuid(3, 2, 213), null, 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 213), 'table_of_champions', array[10, 10, -10, -10]);
select lives_ok(
  format(
    'select public.edit_hand_result(%L, ''win'', 1, ''discard'', 0, 3, null, ''Corrected before sudden death'', null, null)',
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 213)
       and contest.contest_type = 'table_of_champions')
  ),
  'Champions hand edit before sudden death starts rebuilds the dependent state'
);
select ok(
  not exists (
    select 1 from public.event_finals_contests
    where event_id = test_support.finals_fixture_uuid(2, 1, 213)
      and contest_type = 'champions_sudden_death' and status = 'ready'
  ),
  'Champions edit cancels the obsolete ready sudden-death contest'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(4, 214),
  test_support.finals_fixture_uuid(3, 2, 214), null, 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 214), 'table_of_champions', array[10, 10, -10, -10]);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 214)
    and contest_type = 'champions_sudden_death'),
  test_support.finals_fixture_uuid(3, 2, 214),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 214))
);
select throws_ok(
  format(
    'select public.void_hand_result(%L, ''Cannot change after sudden death started'')',
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 214)
       and contest.contest_type = 'table_of_champions')
  ),
  'P0001',
  'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.',
  'Champions void after sudden death starts fails closed'
);

select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.void_hand_result(%L, ''Cannot change after next tiebreak started'')',
    test_support.finals_fixture_uuid(1, 1, 205),
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 205)
       and contest.contest_type = 'redemption_advancement_tiebreak'
       and contest.status = 'complete')
  ),
  'P0001',
  'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.',
  'completed elimination tiebreak cannot be voided after its child starts'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 216),
  test_support.finals_fixture_uuid(3, 2, 216),
  test_support.finals_fixture_uuid(3, 3, 216), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 216), 'table_of_redemption', array[30, 10, -10, -30]);
select lives_ok(
  format(
    'select public.void_hand_result(%L, ''Void before dependent Champions start'')',
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 216)
       and contest.contest_type = 'table_of_redemption')
  ),
  'Redemption void before dependent start reopens source state'
);
select ok(
  (select count(*) = 1 from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 216)
     and contest_type = 'table_of_redemption' and status = 'active')
  and (select count(*) = 1 from public.event_finals_contests
       where event_id = test_support.finals_fixture_uuid(2, 1, 216)
         and contest_type = 'table_of_champions' and status = 'pending')
  and (select redemption_winner_event_guest_id is null
       from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 216)),
  'Redemption void clears derived winner and slots while preserving pending dependency'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 217),
  test_support.finals_fixture_uuid(3, 2, 217),
  test_support.finals_fixture_uuid(3, 3, 217), 0
);
select test_support.score_finals_contest(test_support.finals_fixture_uuid(2, 1, 217), 'table_of_redemption', array[10, 10, 10, -30]);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 217)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'ready'),
  test_support.finals_fixture_uuid(3, 3, 217),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 217))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 217)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'active'), 'win', 0
);
select public.start_finals_contest(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 217)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'ready'),
  test_support.finals_fixture_uuid(3, 3, 217),
  (select state_version from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 217))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 217)
    and contest_type = 'redemption_advancement_tiebreak' and status = 'active'), 'win', 0
);
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.edit_hand_result(%L, ''win'', 1, ''discard'', 0, 3, null, ''Correct final tiebreak winner'', null, null)',
    test_support.finals_fixture_uuid(1, 1, 217),
    (select hand.id from public.hand_results as hand
     join public.event_finals_contests as contest on contest.table_session_id = hand.table_session_id
     where contest.event_id = test_support.finals_fixture_uuid(2, 1, 217)
       and contest.contest_type = 'redemption_advancement_tiebreak'
       and contest.parent_contest_id is not null
     order by contest.sequence_number desc limit 1)
  ),
  'final chained advancement result may be corrected before Champions starts'
);
select ok(
  (select redemption_winner_event_guest_id = test_support.finals_fixture_uuid(4, 3, 217)
   from public.event_bonus_rounds where event_id = test_support.finals_fixture_uuid(2, 1, 217))
  and (select status = 'ready' from public.event_finals_contests
       where event_id = test_support.finals_fixture_uuid(2, 1, 217)
         and contest_type = 'table_of_champions')
  and (
    select
      (select string_agg(slot.event_guest_id::text, ',' order by slot.event_guest_id)
       from public.event_finals_champions_slots as slot
       where slot.bonus_round_id = root.id)
      =
      (select string_agg(participant.event_guest_id::text, ',' order by participant.event_guest_id)
       from public.event_finals_contest_participants as participant
       join public.event_finals_contests as contest on contest.id = participant.contest_id
       where contest.bonus_round_id = root.id and contest.contest_type = 'table_of_champions')
    from public.event_bonus_rounds as root
    where root.event_id = test_support.finals_fixture_uuid(2, 1, 217)
  ),
  'chained correction preserves parent Redemption winner and rebuilds Champions participants'
);

select test_support.create_finals_fixture(8, 218);
update public.hand_settlements set amount_points = 30
where payer_event_guest_id = test_support.finals_fixture_uuid(4, 5, 218);
select public.begin_event_finals(
  test_support.finals_fixture_uuid(2, 1, 218),
  test_support.finals_fixture_uuid(3, 2, 218),
  test_support.finals_fixture_uuid(3, 3, 218), 0
);
update public.event_guests
set attendance_status = 'checked_out', display_name = 'Changed after Begin'
where id = test_support.finals_fixture_uuid(4, 8, 218);
update public.hand_settlements
set payer_event_guest_id = test_support.finals_fixture_uuid(4, 1, 218),
    payee_event_guest_id = test_support.finals_fixture_uuid(4, 8, 218),
    amount_points = 99999
where payer_event_guest_id = test_support.finals_fixture_uuid(4, 8, 218);
select app_private.refresh_event_score_totals(
  test_support.finals_fixture_uuid(2, 1, 218)
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests where event_id = test_support.finals_fixture_uuid(2, 1, 218)
    and contest_type = 'direct_qualification_tiebreak'), 'win', 1
);
select ok(
  (select count(*) = 8
   from public.event_finals_eligible_snapshot as snapshot
   join public.event_bonus_rounds as root on root.id = snapshot.bonus_round_id
   where root.event_id = test_support.finals_fixture_uuid(2, 1, 218))
  and exists (
    select 1
    from public.event_finals_eligible_snapshot as snapshot
    join public.event_bonus_rounds as root on root.id = snapshot.bonus_round_id
    where root.event_id = test_support.finals_fixture_uuid(2, 1, 218)
      and snapshot.event_guest_id = test_support.finals_fixture_uuid(4, 8, 218)
      and snapshot.display_name = 'Scenario 218 Player 8'
      and snapshot.seed_rank = 8
  ),
  'Begin persists the complete ordered eligible snapshot before live data changes'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 218))
    #>> '{allowed_actions,0,label}',
  'Start Table of Redemption',
  'direct-cutoff resolution exposes the ready Redemption start action'
);
select ok(
  (select count(*) = 4 from public.event_finals_champions_slots as slot
   join public.event_bonus_rounds as root on root.id = slot.bonus_round_id
   where root.event_id = test_support.finals_fixture_uuid(2, 1, 218)
     and slot.event_guest_id is not null)
  and (select count(*) = 4 from public.event_finals_contest_participants as participant
       join public.event_finals_contests as contest on contest.id = participant.contest_id
       where contest.event_id = test_support.finals_fixture_uuid(2, 1, 218)
         and contest.contest_type = 'table_of_redemption')
  and not exists (
    select 1 from public.event_finals_champions_slots as slot
    join public.event_bonus_rounds as root on root.id = slot.bonus_round_id
    join public.event_finals_contests as redemption
      on redemption.bonus_round_id = root.id and redemption.contest_type = 'table_of_redemption'
    join public.event_finals_contest_participants as participant
      on participant.contest_id = redemption.id and participant.event_guest_id = slot.event_guest_id
    where root.event_id = test_support.finals_fixture_uuid(2, 1, 218)
  ),
  'eight-player cutoff winner produces disjoint four-player Champions and Redemption sets'
);

select test_support.create_finals_fixture(4, 215);
insert into public.event_bonus_rounds (
  id, event_id, champions_table_id, redemption_table_id, assignment_round,
  status, flow_version
) values (
  test_support.finals_fixture_uuid(10, 1, 215),
  test_support.finals_fixture_uuid(2, 1, 215),
  test_support.finals_fixture_uuid(3, 2, 215), null, 1, 'active', 'legacy'
);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase, bonus_round_id, bonus_table_role
) values (
  test_support.finals_fixture_uuid(6, 99, 215),
  test_support.finals_fixture_uuid(2, 1, 215),
  test_support.finals_fixture_uuid(3, 2, 215), 99, 'HK_STANDARD',
  'dealer_cycle_return_to_initial_east', '{}'::jsonb, 'active', 0, 0, now(),
  test_support.finals_fixture_uuid(1, 1, 215), 'bonus',
  test_support.finals_fixture_uuid(10, 1, 215), 'table_of_champions'
);
select lives_ok(
  format('select app_private.apply_bonus_round_champion_award(%L)', test_support.finals_fixture_uuid(6, 99, 215)),
  'stable champion hook preserves live legacy Finals behavior'
);
select is(
  (select flow_version || ':' || status from public.event_bonus_rounds
   where id = test_support.finals_fixture_uuid(10, 1, 215)),
  'legacy:active',
  'legacy award delegation leaves an unresolved legacy root active'
);
select ok(
  exists (select 1 from public.audit_logs where action = 'create_finals_contest')
  and exists (select 1 from public.audit_logs where action = 'cancel_finals_contest')
  and exists (select 1 from public.audit_logs where action = 'complete_finals_contest')
  and exists (select 1 from public.audit_logs where action = 'fill_finals_champions_slot')
  and exists (select 1 from public.audit_logs where action = 'resolve_redemption_winner')
  and exists (select 1 from public.audit_logs where action = 'award_finals_champion'),
  'Finals contest, slot, Redemption, and award transitions write granular audit activity'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(4, 212),
  test_support.finals_fixture_uuid(3, 2, 212), null, 0
);
insert into public.users (id, email, display_name) values (
  test_support.finals_fixture_uuid(1, 2, 212), 'finals-scorer-212@example.test', 'Finals Scorer 212'
);
insert into public.approved_logistics_identities (
  id, email, email_lower, display_name, status, approved_by_user_id
) values (
  test_support.finals_fixture_uuid(12, 1, 212), 'finals-scorer-212@example.test',
  'finals-scorer-212@example.test', 'Finals Scorer 212', 'active',
  test_support.finals_fixture_uuid(1, 1, 212)
);
insert into public.event_staff_memberships (
  id, event_id, approved_identity_id, user_id, role, status, created_by_user_id
) values (
  test_support.finals_fixture_uuid(13, 1, 212), test_support.finals_fixture_uuid(2, 1, 212),
  test_support.finals_fixture_uuid(12, 1, 212), test_support.finals_fixture_uuid(1, 2, 212),
  'event_scorer', 'active', test_support.finals_fixture_uuid(1, 1, 212)
);
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.record_hand_result(%L, ''washout'')',
    test_support.finals_fixture_uuid(1, 2, 212),
    (select table_session_id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 212)
       and contest_type = 'table_of_champions')
  ),
  'existing scoring-role authorization remains valid for Finals hand entry'
);

select has_function(
  'public', 'resume_event_finals_start', array['uuid', 'text']
);
select has_function(
  'public', 'start_bonus_assigned_table_sessions', array['uuid', 'text']
);

-- Exact stranded screenshot state: active legacy root, complete disjoint
-- Champions and Redemption seating, and no Finals sessions.
select lives_ok(
  $$select test_support.create_legacy_finals_fixture(
    301, array[1,2,3,4], array[5,6,7,8]
  )$$,
  'creates the complete seating-only legacy Finals screenshot state'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
    ->> 'overall_status',
  'recoverable_missing_sessions',
  'classifies the screenshot state as recoverable missing sessions'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
    #>> '{allowed_actions,0,recovery_token}',
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
    ->> 'recovery_token',
  'legacy recovery action carries the exact top-level recovery token'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
    -> 'allowed_actions',
  jsonb_build_array(jsonb_build_object(
    'action', 'start_finals_tables',
    'label', 'Start Finals Tables',
    'recovery_token', public.get_event_finals_state(
      test_support.finals_fixture_uuid(2, 1, 301)
    ) ->> 'recovery_token'
  )),
  'offers the exact nested Start Finals Tables recovery payload'
);
select ok(
  length(public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
    ->> 'recovery_token') > 10,
  'returns a nonempty stable recovery token'
);
create temporary table legacy_recovery_request_token as
select public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
  ->> 'recovery_token' as token;
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
    ->> 'recovery_token',
  (select token from legacy_recovery_request_token),
  'repeated reads return the same recovery token for unchanged state'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 301),
    (select token from legacy_recovery_request_token)
  ),
  'atomically starts both disjoint legacy Finals tables'
);
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 301)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 301)),
  2,
  'creates exactly the two expected Finals sessions'
);
select is(
  jsonb_array_length(
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
      -> 'sessions'
  ),
  2,
  'legacy recovery returns the existing and newly started session references'
);
select ok(
  (select count(*) = 8 from public.event_seating_assignments
   where event_id = test_support.finals_fixture_uuid(2, 1, 301)
     and status = 'active')
  and (select flow_version = 'legacy' from public.event_bonus_rounds
       where id = test_support.finals_fixture_uuid(10, 1, 301)),
  'recovery preserves assignments and the legacy flow version'
);
select ok(
  exists (
    select 1 from public.audit_logs
    where event_id = test_support.finals_fixture_uuid(2, 1, 301)
      and action = 'resume_event_finals_start'
      and actor_user_id = test_support.finals_fixture_uuid(1, 1, 301)
      and metadata_json ? 'candidate_tables'
      and metadata_json ? 'existing_session_ids'
      and metadata_json ? 'newly_started_session_ids'
      and metadata_json ? 'recovery_classification'
  ),
  'records the recovery candidate, existing, new-session, actor, and classification audit'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 301),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 301))
      ->> 'recovery_token'
  ),
  'duplicate recovery returns the existing sessions'
);
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 301)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 301)),
  2,
  'duplicate recovery does not create additional sessions'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 301),
    (select token from legacy_recovery_request_token)
  ),
  'a response-loss retry with the original token returns existing sessions'
);

-- Historical six/seven topology. Current constraints prevent two active rows
-- for one guest, so relax only the active index inside this rollback-only test.
drop index public.event_seating_assignments_active_guest_idx;
alter table public.event_seating_assignments
  drop constraint event_seating_assignments_event_id_assignment_round_event_g_key;
discard plans;
select lives_ok(
  $$select test_support.create_legacy_finals_fixture(
    302, array[1,2,3,4], array[3,4,5,6]
  )$$,
  'creates a historical overlapping Champions and Redemption topology'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 302),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 302))
      ->> 'recovery_token'
  ),
  'recovers an overlapping legacy topology by starting Redemption only'
);
select is(
  (select string_agg(bonus_table_role, ',' order by bonus_table_role)
   from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 302)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 302)),
  'table_of_redemption',
  'overlapping legacy Finals does not start Champions concurrently'
);
select test_support.create_legacy_finals_fixture(
  310, array[1,2,3,4], array[3,4,5,6]
);
select (app_private.start_assigned_finals_session(
  test_support.finals_fixture_uuid(2, 1, 310),
  test_support.finals_fixture_uuid(10, 1, 310),
  'table_of_champions', null, now()
)).id;
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 310))
    ->> 'blocking_reason',
  'A Finals player is already playing at another table.',
  'an overlapping topology with Champions already active is blocked'
);
delete from public.table_sessions
where event_id = test_support.finals_fixture_uuid(2, 1, 310);
delete from public.events where id = test_support.finals_fixture_uuid(2, 1, 310);
delete from public.table_sessions
where event_id = test_support.finals_fixture_uuid(2, 1, 302);
delete from public.events where id = test_support.finals_fixture_uuid(2, 1, 302);
alter table public.event_seating_assignments
  add constraint event_seating_assignments_event_id_assignment_round_event_g_key
  unique (event_id, assignment_round, event_guest_id);
create unique index event_seating_assignments_active_guest_idx
  on public.event_seating_assignments (event_id, event_guest_id)
  where status = 'active';

drop index public.event_seating_assignments_active_guest_idx;
alter table public.event_seating_assignments
  drop constraint event_seating_assignments_event_id_assignment_round_event_g_key;
discard plans;
select test_support.create_legacy_finals_fixture(309, array[1,2], array[]::integer[]);
update public.event_seating_assignments
set event_guest_id = test_support.finals_fixture_uuid(4, 1, 309),
    assignment_round = 2
where id = test_support.finals_fixture_uuid(14, 2, 309);
select ok(
  (public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 309))
    ->> 'overall_status') = 'blocked_legacy_state'
  and length(public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 309))
    ->> 'blocking_reason') > 0,
  'duplicate legacy Finals guests are blocked with a host-safe reason'
);
delete from public.table_sessions
where event_id = test_support.finals_fixture_uuid(2, 1, 309);
delete from public.events where id = test_support.finals_fixture_uuid(2, 1, 309);
alter table public.event_seating_assignments
  add constraint event_seating_assignments_event_id_assignment_round_event_g_key
  unique (event_id, assignment_round, event_guest_id);
create unique index event_seating_assignments_active_guest_idx
  on public.event_seating_assignments (event_id, event_guest_id)
  where status = 'active';

-- Partial start: an old app started Champions, recovery starts only Redemption.
select test_support.create_legacy_finals_fixture(
  303, array[1,2,3,4], array[5,6,7,8]
);
select * from public.start_bonus_assigned_table_sessions(
  test_support.finals_fixture_uuid(2, 1, 303), 'table_of_champions'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 303))
    -> 'allowed_actions',
  jsonb_build_array(jsonb_build_object(
    'action', 'resume_finals_start',
    'label', 'Resume Finals Start',
    'recovery_token', public.get_event_finals_state(
      test_support.finals_fixture_uuid(2, 1, 303)
    ) ->> 'recovery_token'
  )),
  'a partial disjoint start offers the exact Resume Finals Start payload'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 303),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 303))
      ->> 'recovery_token'
  ),
  'partial recovery starts only the missing table'
);
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 303)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 303)),
  2,
  'partial recovery preserves the existing session and adds one'
);

-- Incomplete, role-inconsistent, unexpected-session, and player-conflict
-- topologies fail closed with host-safe reasons.
select test_support.create_legacy_finals_fixture(304, array[1,2], array[]::integer[]);
delete from public.event_seating_assignments
where id = test_support.finals_fixture_uuid(14, 2, 304);
select ok(
  (public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 304))
    ->> 'overall_status') = 'blocked_legacy_state'
  and length(public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 304))
    ->> 'blocking_reason') > 0,
  'incomplete legacy seating is blocked with a host-safe reason'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 304))
    -> 'allowed_actions',
  '[]'::jsonb,
  'blocked legacy Finals exposes no mutation action'
);

select test_support.create_legacy_finals_fixture(305, array[1,2], array[]::integer[]);
update public.event_seating_assignments
set event_table_id = test_support.finals_fixture_uuid(3, 3, 305)
where id = test_support.finals_fixture_uuid(14, 2, 305);
select ok(
  (public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 305))
    ->> 'overall_status') = 'blocked_legacy_state'
  and length(public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 305))
    ->> 'blocking_reason') > 0,
  'role-inconsistent legacy seating is blocked with a host-safe reason'
);

select test_support.create_legacy_finals_fixture(306, array[1,2], array[]::integer[]);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase, bonus_round_id, bonus_table_role,
  assignment_round
) values (
  test_support.finals_fixture_uuid(6, 99, 306),
  test_support.finals_fixture_uuid(2, 1, 306),
  test_support.finals_fixture_uuid(3, 3, 306),
  99, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'completed', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 306),
  'bonus', test_support.finals_fixture_uuid(10, 1, 306),
  'table_of_redemption', 1
);
select ok(
  (public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 306))
    ->> 'overall_status') = 'blocked_legacy_state'
  and length(public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 306))
    ->> 'blocking_reason') > 0,
  'an unexpected legacy session is blocked with a host-safe reason'
);

select test_support.create_legacy_finals_fixture(307, array[1,2], array[]::integer[]);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 99, 307),
  test_support.finals_fixture_uuid(2, 1, 307),
  test_support.finals_fixture_uuid(3, 1, 307),
  99, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 307),
  'tournament'
);
insert into public.table_session_seats (
  table_session_id, seat_index, initial_wind, event_guest_id
) values (
  test_support.finals_fixture_uuid(6, 99, 307), 0, 'east',
  test_support.finals_fixture_uuid(4, 1, 307)
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 307))
    ->> 'blocking_reason',
  'A Finals player is already playing at another table.',
  'a conflicting Finals player is blocked with the exact safe reason'
);
select throws_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, null)',
    test_support.finals_fixture_uuid(2, 1, 307)
  ),
  'P0001',
  'A Finals player is already playing at another table.',
  'old start RPC returns exact host-safe participant-conflict copy'
);

select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.resume_event_finals_start(%L, ''stale-token'')',
    test_support.finals_fixture_uuid(1, 1, 304),
    test_support.finals_fixture_uuid(2, 1, 304)
  ),
  'P0001',
  'Finals changed since this screen loaded. Refresh and try again.',
  'rejects a mismatched recovery token'
);

select test_support.create_legacy_finals_fixture(312, array[1,2], array[]::integer[]);
create temporary table authoritative_change_token as
select public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 312))
  ->> 'recovery_token' as token;
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase, bonus_round_id, bonus_table_role,
  assignment_round
) values (
  test_support.finals_fixture_uuid(6, 99, 312),
  test_support.finals_fixture_uuid(2, 1, 312),
  test_support.finals_fixture_uuid(3, 3, 312),
  99, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'completed', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 312),
  'bonus', test_support.finals_fixture_uuid(10, 1, 312),
  'table_of_redemption', 1
);
select throws_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 312),
    (select token from authoritative_change_token)
  ),
  'P0001',
  'Finals changed since this screen loaded. Refresh and try again.',
  'an authoritative session change invalidates the recovery token'
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.resume_event_finals_start(%L, ''any-token'')',
    test_support.finals_fixture_uuid(1, 99, 304),
    test_support.finals_fixture_uuid(2, 1, 304)
  ),
  'P0001',
  'Event not found for current Finals operator.',
  'non-owners cannot run the Finals management recovery command'
);
select throws_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.start_bonus_assigned_table_sessions(%L, null)',
    test_support.finals_fixture_uuid(1, 99, 304),
    test_support.finals_fixture_uuid(2, 1, 304)
  ),
  'P0001',
  'Event not found for current Finals operator.',
  'the compatibility RPC cannot bypass owner-only Finals management'
);

create temporary table orchestrated_compatibility_cases (
  scenario integer primary key,
  contest_type text not null,
  bonus_table_role text not null
);
insert into orchestrated_compatibility_cases values
  (420, 'direct_qualification_tiebreak', 'table_of_champions_play_in'),
  (421, 'redemption_advancement_tiebreak', 'table_of_champions_play_in'),
  (422, 'redemption_winner_tiebreak', 'table_of_redemption'),
  (423, 'champions_sudden_death', 'table_of_champions_sudden_death'),
  (424, 'table_of_champions', 'table_of_champions'),
  (425, 'table_of_redemption', 'table_of_redemption');
select test_support.create_ready_orchestrated_contest(
  compatibility.scenario,
  compatibility.contest_type,
  compatibility.bonus_table_role
)
from orchestrated_compatibility_cases as compatibility
order by compatibility.scenario;
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(1, 1, compatibility.scenario),
    test_support.finals_fixture_uuid(2, 1, compatibility.scenario),
    compatibility.bonus_table_role
  ),
  format('old RPC starts ready orchestrated %s', compatibility.contest_type)
)
from orchestrated_compatibility_cases as compatibility
order by compatibility.scenario;
select ok(
  (
    select session.bonus_table_role = compatibility.bonus_table_role
      and session.finals_contest_id = contest.id
      and contest.status = 'active'
      and contest.table_session_id = session.id
    from public.event_finals_contests as contest
    join public.table_sessions as session on session.id = contest.table_session_id
    where contest.id = test_support.finals_fixture_uuid(
      11, 1, compatibility.scenario
    )
  ),
  format('old RPC maps %s to the correct session role', compatibility.contest_type)
)
from orchestrated_compatibility_cases as compatibility
order by compatibility.scenario;
select lives_ok(
  format(
    'select set_config(''request.jwt.claim.sub'', %L, true); '
    || 'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(1, 1, compatibility.scenario),
    test_support.finals_fixture_uuid(2, 1, compatibility.scenario),
    compatibility.bonus_table_role
  ),
  format('old RPC retry is idempotent for %s', compatibility.contest_type)
)
from orchestrated_compatibility_cases as compatibility
order by compatibility.scenario;
select is(
  (
    select count(*)::integer
    from public.table_sessions as session
    where session.event_id = test_support.finals_fixture_uuid(
      2, 1, compatibility.scenario
    )
      and session.finals_contest_id = test_support.finals_fixture_uuid(
        11, 1, compatibility.scenario
      )
  ),
  1,
  format('old RPC retry creates no duplicate for %s', compatibility.contest_type)
)
from orchestrated_compatibility_cases as compatibility
order by compatibility.scenario;

select test_support.create_ready_orchestrated_contest(
  430, 'table_of_champions', 'table_of_champions'
);
update public.event_guests set attendance_status = 'expected', checked_in_at = null
where id = test_support.finals_fixture_uuid(4, 1, 430);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, 1)',
    test_support.finals_fixture_uuid(11, 1, 430),
    test_support.finals_fixture_uuid(3, 2, 430)
  ),
  'P0001',
  'All Finals players must be checked in before starting.',
  'contest start returns exact host-safe unchecked-player copy'
);
select ok(
  (select status = 'ready' and table_session_id is null
   from public.event_finals_contests
   where id = test_support.finals_fixture_uuid(11, 1, 430))
  and not exists (
    select 1 from public.table_sessions
    where finals_contest_id = test_support.finals_fixture_uuid(11, 1, 430)
  ),
  'unchecked contest start rolls back without a session mutation'
);

select test_support.create_ready_orchestrated_contest(
  431, 'table_of_champions', 'table_of_champions'
);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 50, 431),
  test_support.finals_fixture_uuid(2, 1, 431),
  test_support.finals_fixture_uuid(3, 1, 431),
  1, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 431),
  'tournament'
);
insert into public.table_session_seats (
  table_session_id, seat_index, initial_wind, event_guest_id
) values (
  test_support.finals_fixture_uuid(6, 50, 431), 0, 'east',
  test_support.finals_fixture_uuid(4, 1, 431)
);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, 1)',
    test_support.finals_fixture_uuid(11, 1, 431),
    test_support.finals_fixture_uuid(3, 2, 431)
  ),
  'P0001',
  'A Finals player is already playing at another table.',
  'contest start returns exact host-safe participant-conflict copy'
);
select ok(
  (select status = 'ready' and table_session_id is null
   from public.event_finals_contests
   where id = test_support.finals_fixture_uuid(11, 1, 431))
  and not exists (
    select 1 from public.table_sessions
    where finals_contest_id = test_support.finals_fixture_uuid(11, 1, 431)
  ),
  'participant-conflict contest start adds no Finals session mutation'
);

select test_support.create_legacy_finals_fixture(432, array[1,2], array[]::integer[]);
update public.event_guests set attendance_status = 'expected', checked_in_at = null
where id = test_support.finals_fixture_uuid(4, 1, 432);
select throws_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 432),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 432))
      ->> 'recovery_token'
  ),
  'P0001',
  'All Finals players must be checked in before starting.',
  'legacy resume returns exact host-safe unchecked-player copy'
);

select test_support.create_ready_orchestrated_contest(
  433, 'table_of_champions', 'table_of_champions'
);
update public.event_guests set attendance_status = 'expected', checked_in_at = null
where id = test_support.finals_fixture_uuid(4, 1, 433);
select throws_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 433),
    'table_of_champions'
  ),
  'P0001',
  'All Finals players must be checked in before starting.',
  'old start RPC returns exact host-safe unchecked-player copy'
);

select test_support.create_ready_orchestrated_contest(
  434, 'table_of_champions', 'table_of_champions'
);
select * from public.start_bonus_assigned_table_sessions(
  test_support.finals_fixture_uuid(2, 1, 434), 'table_of_champions'
);
insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, started_at,
  started_by_user_id, scoring_phase
) values (
  test_support.finals_fixture_uuid(6, 50, 434),
  test_support.finals_fixture_uuid(2, 1, 434),
  test_support.finals_fixture_uuid(3, 1, 434),
  1, 'HK_STANDARD', 'dealer_cycle_return_to_initial_east', '{}'::jsonb,
  'active', 0, 0, now(), test_support.finals_fixture_uuid(1, 1, 434),
  'tournament'
);
select throws_ok(
  format(
    'insert into public.table_session_seats '
    || '(table_session_id, seat_index, initial_wind, event_guest_id) '
    || 'values (%L, 0, ''east'', %L)',
    test_support.finals_fixture_uuid(6, 50, 434),
    test_support.finals_fixture_uuid(4, 1, 434)
  ),
  'P0001',
  'A player is already playing at another table.',
  'shared seat invariant rejects normal-path overlap with an active Finals player'
);
select is(
  (
    select count(*)::integer
    from public.table_session_seats as seat
    join public.table_sessions as session on session.id = seat.table_session_id
    where seat.event_guest_id = test_support.finals_fixture_uuid(4, 1, 434)
      and session.status in ('active', 'paused')
  ),
  1,
  'cross-path overlap leaves one active seat for the player'
);

select test_support.create_legacy_finals_fixture(311, array[1,2], array[]::integer[]);
update public.event_seating_assignments
set bonus_table_role = 'table_of_champions_sudden_death'
where event_id = test_support.finals_fixture_uuid(2, 1, 311)
  and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 311);
select lives_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, '
    || '''table_of_champions_sudden_death'')',
    test_support.finals_fixture_uuid(2, 1, 311)
  ),
  'legacy app compatibility still starts sudden-death assigned seating'
);
select is(
  (select bonus_table_role from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 311)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 311)),
  'table_of_champions_sudden_death',
  'legacy sudden-death compatibility uses the shared assigned-session starter'
);

-- Force the second helper insertion to fail. The first insertion must roll back.
select test_support.create_legacy_finals_fixture(
  308, array[1,2,3,4], array[5,6,7,8]
);
create function test_support.fail_redemption_session_insert()
returns trigger language plpgsql as $$
begin
  if new.bonus_table_role = 'table_of_redemption' then
    raise exception 'forced second-table failure' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger test_fail_redemption_session_insert
before insert on public.table_sessions
for each row execute function test_support.fail_redemption_session_insert();
select throws_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 308),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 308))
      ->> 'recovery_token'
  ),
  'P0001', 'forced second-table failure',
  'forced second-table failure aborts the atomic recovery command'
);
drop trigger test_fail_redemption_session_insert on public.table_sessions;
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 308)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 308)),
  0,
  'forced second-table failure rolls back the first new session'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.start_bonus_assigned_table_sessions(uuid,text)',
    'EXECUTE'
  ),
  'legacy app versions retain execute access to the old bulk-start RPC'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.get_event_finals_state_before_legacy_recovery(uuid)',
    'EXECUTE'
  ),
  'authenticated callers cannot bypass the authoritative recovery read model'
);
select ok(
  not has_function_privilege(
    'service_role',
    'public.get_event_finals_state_before_legacy_recovery(uuid)',
    'EXECUTE'
  ),
  'service callers cannot bypass the authoritative recovery read model'
);

-- The setup preview token binds the host-approved standings to Begin Finals.
select test_support.create_finals_fixture(7, 399);
create temporary table stale_finals_preview_token as
select public.preview_event_finals(
  test_support.finals_fixture_uuid(2, 1, 399)
)->>'preview_token' as token;
update public.event_guests
set attendance_status = 'checked_out'
where id = test_support.finals_fixture_uuid(4, 7, 399);
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, %L, 0, %L)',
    test_support.finals_fixture_uuid(2, 1, 399),
    test_support.finals_fixture_uuid(3, 2, 399),
    test_support.finals_fixture_uuid(3, 3, 399),
    (select token from stale_finals_preview_token)
  ),
  'P0001',
  'Finals changed since this screen was loaded. Refresh and try again.',
  'Begin Finals rejects an eligibility change after preview'
);
select is(
  (select count(*)::integer from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 399)),
  0,
  'stale setup preview rejection writes no Finals root'
);

-- A prebound contest may move only when its original table is unavailable.
select public.begin_event_finals(
  test_support.create_finals_fixture(6, 401),
  test_support.finals_fixture_uuid(3, 2, 401),
  test_support.finals_fixture_uuid(3, 3, 401), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 401),
  'table_of_redemption', array[30, 10, 10, -50]
);
select test_support.add_finals_table(401, 4);
update public.event_seating_assignments
set status = 'cleared'
where event_id = test_support.finals_fixture_uuid(2, 1, 401)
  and finals_contest_id = (
    select id from public.event_finals_contests
    where event_id = test_support.finals_fixture_uuid(2, 1, 401)
      and contest_type = 'table_of_redemption'
  );
select test_support.occupy_finals_table(401, 3, 90);
select lives_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 401)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 401),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 401))
  ),
  'occupied original table permits an atomic rebind to a ready alternate'
);
select ok(
  (select event_table_id = test_support.finals_fixture_uuid(3, 4, 401)
      and table_session_id is not null
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 401)
     and contest_type = 'redemption_advancement_tiebreak')
  and exists (
    select 1 from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 401)
      and event_table_id = test_support.finals_fixture_uuid(3, 4, 401)
      and status = 'active'
  ),
  'successful rebind binds both contest and new session to the alternate'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 402),
  test_support.finals_fixture_uuid(3, 2, 402),
  test_support.finals_fixture_uuid(3, 3, 402), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 402),
  'table_of_redemption', array[30, 10, 10, -50]
);
select test_support.add_finals_table(402, 4);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 402)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 402),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 402))
  ),
  'P0001',
  'This Finals contest is assigned to a different table. Refresh and try again.',
  'usable original table rejects an alternate selection'
);
select is(
  (select event_table_id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 402)
     and contest_type = 'redemption_advancement_tiebreak'),
  test_support.finals_fixture_uuid(3, 3, 402),
  'rejected usable-original rebind leaves the contest binding unchanged'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 403),
  test_support.finals_fixture_uuid(3, 2, 403),
  test_support.finals_fixture_uuid(3, 3, 403), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 403),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 2, 403);
select test_support.add_finals_table(403, 4);
select test_support.occupy_finals_table(403, 4, 90);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 403)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 403),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 403))
  ),
  'P0001',
  'Selected Finals table is not available for this event.',
  'occupied alternate table is rejected'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 404),
  test_support.finals_fixture_uuid(3, 2, 404),
  test_support.finals_fixture_uuid(3, 3, 404), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 404),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 2, 404);
select test_support.add_finals_table(404, 4, false);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 404)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 404),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 404))
  ),
  'P0001',
  'Selected Finals table is not available for this event.',
  'tagless or inactive-tag alternate table is rejected'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 405),
  test_support.finals_fixture_uuid(3, 2, 405),
  test_support.finals_fixture_uuid(3, 3, 405), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 405),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 2, 405);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 1, 405)::text,
  true
);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 405)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 404),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 405))
  ),
  'P0001',
  'Selected Finals table is not available for this event.',
  'alternate table from another event is rejected'
);
select ok(
  (select event_table_id = test_support.finals_fixture_uuid(3, 3, 403)
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 403)
     and contest_type = 'redemption_advancement_tiebreak')
  and (select event_table_id = test_support.finals_fixture_uuid(3, 3, 404)
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 404)
     and contest_type = 'redemption_advancement_tiebreak')
  and (select event_table_id = test_support.finals_fixture_uuid(3, 3, 405)
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 405)
     and contest_type = 'redemption_advancement_tiebreak'),
  'invalid alternate attempts leave every contest binding unchanged'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 406),
  test_support.finals_fixture_uuid(3, 2, 406),
  test_support.finals_fixture_uuid(3, 3, 406), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 406),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 2, 406);
select test_support.add_finals_table(406, 4);
update public.event_seating_assignments
set status = 'cleared'
where event_id = test_support.finals_fixture_uuid(2, 1, 406)
  and finals_contest_id = (
    select id from public.event_finals_contests
    where event_id = test_support.finals_fixture_uuid(2, 1, 406)
      and contest_type = 'table_of_redemption'
  );
select test_support.occupy_finals_table(406, 1, 90, 4);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 406)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 406),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 406))
  ),
  'P0001',
  'A Finals player is already playing at another table.',
  'participant conflict rejects the alternate start'
);
select ok(
  (select event_table_id = test_support.finals_fixture_uuid(3, 3, 406)
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 406)
     and contest_type = 'redemption_advancement_tiebreak')
  and not exists (
    select 1 from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 406)
      and event_table_id = test_support.finals_fixture_uuid(3, 4, 406)
  ),
  'participant conflict rolls back the contest rebind and alternate session'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 407),
  test_support.finals_fixture_uuid(3, 2, 407),
  test_support.finals_fixture_uuid(3, 3, 407), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 407),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 2, 407);
select test_support.add_finals_table(407, 4);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, -1)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 407)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 4, 407)
  ),
  'P0001',
  'Finals changed since this screen was loaded. Refresh and try again.',
  'stale state version rejects before rebinding'
);
select is(
  (select event_table_id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 407)
     and contest_type = 'redemption_advancement_tiebreak'),
  test_support.finals_fixture_uuid(3, 3, 407),
  'stale state version leaves the original contest binding unchanged'
);
select ok(
  strpos(pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ), 'pg_advisory_xact_lock')
  < strpos(pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ), 'select * into bonus_round_row')
  and strpos(pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ), 'order by event_table.id')
  < strpos(pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ), 'order by tag.id')
  and strpos(pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ), 'order by tag.id')
  < strpos(pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ), 'order by session.event_table_id, session.id')
  and pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ) like '%order by tag.id%for update of tag%',
  'contest start locks event, root, tables, tags, and live sessions in order'
);
select ok(
  exists (
    select 1 from public.audit_logs
    where event_id = test_support.finals_fixture_uuid(2, 1, 401)
      and action = 'start_finals_contest'
      and metadata_json ->> 'original_table_id' =
        test_support.finals_fixture_uuid(3, 3, 401)::text
      and metadata_json ->> 'original_table_label' = 'Redemption'
      and metadata_json ->> 'table_id' =
        test_support.finals_fixture_uuid(3, 4, 401)::text
      and metadata_json ->> 'table_label' = 'Alternate 4'
  ),
  'rebound contest audit records old and new table IDs and labels'
);

-- The final shared starter is authoritative for NFC table readiness.
select public.begin_event_finals(
  test_support.create_finals_fixture(6, 408),
  test_support.finals_fixture_uuid(3, 2, 408),
  test_support.finals_fixture_uuid(3, 3, 408), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 408),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 2, 408);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 408)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 3, 408),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 408))
  ),
  'P0001',
  'Selected Finals table is not available for this event.',
  'same-table contest start rejects a retired bound table tag'
);
select ok(
  (select event_table_id = test_support.finals_fixture_uuid(3, 3, 408)
      and table_session_id is null
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 408)
     and contest_type = 'redemption_advancement_tiebreak')
  and (select state_version = 2 from public.event_bonus_rounds
       where event_id = test_support.finals_fixture_uuid(2, 1, 408)),
  'retired same-table rejection changes no binding, session, or state version'
);

select public.begin_event_finals(
  test_support.create_finals_fixture(6, 409),
  test_support.finals_fixture_uuid(3, 2, 409),
  test_support.finals_fixture_uuid(3, 3, 409), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 409),
  'table_of_redemption', array[30, 10, 10, -50]
);
update public.nfc_tags set default_tag_type = 'player'
where id = test_support.finals_fixture_uuid(5, 2, 409);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, %s)',
    (select id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 409)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(3, 3, 409),
    (select state_version from public.event_bonus_rounds
     where event_id = test_support.finals_fixture_uuid(2, 1, 409))
  ),
  'P0001',
  'Selected Finals table is not available for this event.',
  'same-table contest start rejects a retyped bound table tag'
);
select ok(
  (select event_table_id = test_support.finals_fixture_uuid(3, 3, 409)
      and table_session_id is null
   from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 409)
     and contest_type = 'redemption_advancement_tiebreak')
  and (select state_version = 2 from public.event_bonus_rounds
       where event_id = test_support.finals_fixture_uuid(2, 1, 409)),
  'retyped same-table rejection changes no binding, session, or state version'
);

select test_support.create_legacy_finals_fixture(
  320, array[1,2,3,4], array[5,6,7,8]
);
create temporary table legacy_tag_token_320 as
select public.get_event_finals_state(
  test_support.finals_fixture_uuid(2, 1, 320)
)->>'recovery_token' as token;
update public.nfc_tags set status = 'retired'
where id = test_support.finals_fixture_uuid(5, 1, 320);
select ok(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 320))
    ->> 'overall_status' = 'blocked_legacy_state'
  and public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 320))
    -> 'allowed_actions' = '[]'::jsonb,
  'legacy recovery blocks retired-tag candidates without offering an action'
);
select isnt(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 320))
    ->> 'recovery_token',
  (select token from legacy_tag_token_320),
  'legacy recovery token changes with authoritative tag status'
);
select throws_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 320),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 320))
      ->> 'recovery_token'
  ),
  'P0001',
  'Finals could not be safely recovered. Review the table assignments.',
  'legacy recovery rejects a retired-tag candidate even with the current token'
);

select test_support.create_legacy_finals_fixture(
  321, array[1,2,3,4], array[5,6,7,8]
);
update public.nfc_tags set default_tag_type = 'player'
where id = test_support.finals_fixture_uuid(5, 2, 321);
select ok(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 321))
    ->> 'overall_status' = 'blocked_legacy_state'
  and public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 321))
    -> 'allowed_actions' = '[]'::jsonb,
  'legacy recovery blocks retyped-tag candidates without offering an action'
);

create or replace function test_support.retire_champions_tag_after_root()
returns trigger
language plpgsql
as $$
begin
  update public.nfc_tags
  set status = 'retired'
  where id = (
    select event_table.nfc_tag_id
    from public.event_tables as event_table
    where event_table.id = new.champions_table_id
  );
  return new;
end;
$$;
create trigger retire_champions_tag_after_root
after insert on public.event_bonus_rounds
for each row execute function test_support.retire_champions_tag_after_root();
select throws_ok(
  format(
    'select public.begin_event_finals(%L, %L, null, 0)',
    test_support.create_finals_fixture(4, 410),
    test_support.finals_fixture_uuid(3, 2, 410)
  ),
  'P0001',
  'Selected Finals table is not available for this event.',
  'shared starter rejects tag retirement after Begin preflight'
);
drop trigger retire_champions_tag_after_root on public.event_bonus_rounds;
select ok(
  not exists (
    select 1 from public.event_bonus_rounds
    where event_id = test_support.finals_fixture_uuid(2, 1, 410)
  )
  and not exists (
    select 1 from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 410)
      and scoring_phase = 'bonus'
  )
  and (select status = 'active' from public.nfc_tags
       where id = test_support.finals_fixture_uuid(5, 1, 410)),
  'Begin tag-race rejection rolls back root, session, and tag mutation'
);
select ok(
  pg_get_functiondef(
    'app_private.start_assigned_finals_session(uuid,uuid,text,uuid,timestamp with time zone)'::regprocedure
  ) like '%select event_table.* into table_row%select tag.* into tag_row%for update of tag%'
  and pg_get_functiondef(
    'app_private.start_assigned_finals_session(uuid,uuid,text,uuid,timestamp with time zone)'::regprocedure
  ) like '%tag_row.default_tag_type <> ''table''%tag_row.status <> ''active''%',
  'final shared starter locks table then tag and enforces active table readiness'
);

select ok(
  position('order by event_table.id for update' in pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  )) > 0
  and position('order by tag.id for update' in pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  )) > position('order by event_table.id for update' in pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  ))
  and position('order by session.id for update' in pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  )) > position('order by tag.id for update' in pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  )),
  'Begin locks its complete table, tag, and session candidate sets in order'
);
select ok(
  (length(pg_get_functiondef(
    'public.start_bonus_assigned_table_sessions(uuid,text)'::regprocedure
  )) - length(replace(pg_get_functiondef(
    'public.start_bonus_assigned_table_sessions(uuid,text)'::regprocedure
  ), 'order by event_table.id for update', '')))
    / length('order by event_table.id for update') = 2
  and (length(pg_get_functiondef(
    'public.start_bonus_assigned_table_sessions(uuid,text)'::regprocedure
  )) - length(replace(pg_get_functiondef(
    'public.start_bonus_assigned_table_sessions(uuid,text)'::regprocedure
  ), 'order by tag.id for update', '')))
    / length('order by tag.id for update') = 2
  and (length(pg_get_functiondef(
    'public.start_bonus_assigned_table_sessions(uuid,text)'::regprocedure
  )) - length(replace(pg_get_functiondef(
    'public.start_bonus_assigned_table_sessions(uuid,text)'::regprocedure
  ), 'order by session.id for update', '')))
    / length('order by session.id for update') = 2,
  'legacy and orchestrated compatibility branches each prelock all candidate sets'
);

select test_support.create_legacy_finals_fixture(
  435, array[1,2,3,4], array[5,6,7,8]
);
select lives_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, null)',
    test_support.finals_fixture_uuid(2, 1, 435)
  ),
  'multi-table legacy compatibility starts both Finals tables atomically'
);
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 435)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 435)),
  2,
  'multi-table compatibility creates exactly two Finals sessions'
);
select is(
  (select count(*)::integer from public.audit_logs
   where event_id = test_support.finals_fixture_uuid(2, 1, 435)
     and action = 'start_bonus_assigned_table_sessions'),
  1,
  'legacy compatibility audits its multi-table start once'
);
select lives_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, null)',
    test_support.finals_fixture_uuid(2, 1, 435)
  ),
  'legacy compatibility retry returns without duplicating its audit'
);
select is(
  (select count(*)::integer from public.audit_logs
   where event_id = test_support.finals_fixture_uuid(2, 1, 435)
     and action = 'start_bonus_assigned_table_sessions'),
  1,
  'legacy compatibility retry writes no duplicate audit'
);

select test_support.create_legacy_finals_fixture(
  436, array[1,2,3,4], array[5,6,7,8]
);
create or replace function test_support.reject_second_compatibility_table()
returns trigger language plpgsql as $$
begin
  if new.event_id = test_support.finals_fixture_uuid(2, 1, 436)
    and new.event_table_id = test_support.finals_fixture_uuid(3, 3, 436)
  then
    raise exception 'forced second compatibility table failure' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger reject_second_compatibility_table
before insert on public.table_sessions
for each row execute function test_support.reject_second_compatibility_table();
select throws_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, null)',
    test_support.finals_fixture_uuid(2, 1, 436)
  ),
  'P0001',
  'forced second compatibility table failure',
  'a second-table compatibility failure aborts the multi-table start'
);
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 436)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 436)),
  0,
  'multi-table compatibility rolls back the first session when the second fails'
);
drop trigger reject_second_compatibility_table on public.table_sessions;
drop function test_support.reject_second_compatibility_table();

-- Server-owned Finals state is readable but cannot be mutated directly by
-- authenticated clients; every write must pass through an audited command.
select ok(
  not has_table_privilege('authenticated', 'public.event_finals_contests', 'INSERT')
  and not has_table_privilege('authenticated', 'public.event_finals_contests', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.event_finals_contests', 'DELETE')
  and not has_table_privilege('authenticated', 'public.event_finals_contest_participants', 'INSERT')
  and not has_table_privilege('authenticated', 'public.event_finals_contest_participants', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.event_finals_contest_participants', 'DELETE')
  and not has_table_privilege('authenticated', 'public.event_finals_champions_slots', 'INSERT')
  and not has_table_privilege('authenticated', 'public.event_finals_champions_slots', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.event_finals_champions_slots', 'DELETE')
  and (select count(*) = 0 from pg_policies
       where schemaname = 'public'
         and tablename in (
           'event_finals_contests',
           'event_finals_contest_participants',
           'event_finals_champions_slots'
         )
         and cmd <> 'SELECT'),
  'server-owned Finals tables expose authenticated reads but no direct writes'
);

-- The legacy compatibility entry point is a real state transition for an
-- orchestrated contest: version and audit advance once, while retries do not.
select test_support.create_ready_orchestrated_contest(
  437, 'table_of_champions', 'table_of_champions'
);
select lives_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 437),
    'table_of_champions'
  ),
  'orchestrated compatibility starts a ready contest through one command'
);
select ok(
  (select state_version = 2 from public.event_bonus_rounds
   where id = test_support.finals_fixture_uuid(10, 1, 437))
  and (select count(*) = 1 from public.audit_logs
       where event_id = test_support.finals_fixture_uuid(2, 1, 437)
         and action = 'start_bonus_assigned_table_sessions'),
  'orchestrated compatibility increments state version and audits exactly once'
);
select lives_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 437),
    'table_of_champions'
  ),
  'orchestrated compatibility retry returns the existing session'
);
select ok(
  (select state_version = 2 from public.event_bonus_rounds
   where id = test_support.finals_fixture_uuid(10, 1, 437))
  and (select count(*) = 1 from public.audit_logs
       where event_id = test_support.finals_fixture_uuid(2, 1, 437)
         and action = 'start_bonus_assigned_table_sessions')
  and (select count(*) = 1 from public.table_sessions
       where finals_contest_id = test_support.finals_fixture_uuid(11, 1, 437)),
  'orchestrated compatibility retry changes no version, audit, or session count'
);

-- Existing legacy sessions are authoritative only when their exact guest and
-- seat topology matches the durable assignment set.
select test_support.create_legacy_finals_fixture(
  438, array[1,2,3,4], array[5,6,7,8]
);
select (app_private.start_assigned_finals_session(
  test_support.finals_fixture_uuid(2, 1, 438),
  test_support.finals_fixture_uuid(10, 1, 438),
  'table_of_champions', null, now()
)).id;
update public.table_session_seats
set event_guest_id = test_support.finals_fixture_uuid(4, 5, 438)
where table_session_id = (
    select id from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 438)
      and bonus_table_role = 'table_of_champions'
  )
  and seat_index = 0;
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 438))
    ->> 'overall_status',
  'blocked_legacy_state',
  'legacy recovery rejects an existing session whose exact seats differ from assignments'
);
select throws_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 438),
    'table_of_champions'
  ),
  'P0001',
  'Finals could not be safely recovered. Review the table assignments.',
  'legacy compatibility retry fails closed when durable seats differ'
);

-- A completed, exact half of a disjoint legacy pair remains authoritative and
-- recovery starts only the still-missing table without changing it.
select test_support.create_legacy_finals_fixture(
  439, array[1,2,3,4], array[5,6,7,8]
);
select (app_private.start_assigned_finals_session(
  test_support.finals_fixture_uuid(2, 1, 439),
  test_support.finals_fixture_uuid(10, 1, 439),
  'table_of_champions', null, now()
)).id;
update public.table_sessions
set status = 'completed', ended_at = now(), end_reason = 'test_completed'
where event_id = test_support.finals_fixture_uuid(2, 1, 439)
  and bonus_table_role = 'table_of_champions';
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 439))
    #>> '{allowed_actions,0,action}',
  'resume_finals_start',
  'completed exact legacy half still offers Resume Finals Start'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 439),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 439))
      ->> 'recovery_token'
  ),
  'legacy recovery preserves a completed half and starts the missing table'
);
select ok(
  (select count(*) = 2 from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 439)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 439))
  and (select count(*) = 1 from public.table_sessions
       where event_id = test_support.finals_fixture_uuid(2, 1, 439)
         and bonus_table_role = 'table_of_champions'
         and status = 'completed'),
  'completed legacy session is unchanged and exactly one missing session is added'
);

-- Only the historical six/seven-player overlap shapes are unambiguous.
drop index public.event_seating_assignments_active_guest_idx;
alter table public.event_seating_assignments
  drop constraint event_seating_assignments_event_id_assignment_round_event_g_key;
discard plans;
select test_support.create_legacy_finals_fixture(
  440, array[1,2,3,4], array[2,3,4,5]
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 440))
    ->> 'overall_status',
  'blocked_legacy_state',
  'ambiguous three-player legacy overlap fails closed'
);
delete from public.table_sessions
where event_id = test_support.finals_fixture_uuid(2, 1, 440);
delete from public.events where id = test_support.finals_fixture_uuid(2, 1, 440);
alter table public.event_seating_assignments
  add constraint event_seating_assignments_event_id_assignment_round_event_g_key
  unique (event_id, assignment_round, event_guest_id);
create unique index event_seating_assignments_active_guest_idx
  on public.event_seating_assignments (event_id, event_guest_id)
  where status = 'active';

-- A two-way tie for both advancement positions fully resolves both the child
-- tiebreak participants and the source Redemption finish outcomes.
select public.begin_event_finals(
  test_support.create_finals_fixture(6, 441),
  test_support.finals_fixture_uuid(3, 2, 441),
  test_support.finals_fixture_uuid(3, 3, 441), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 441),
  'table_of_redemption', array[20,20,-10,-30]
);
select public.start_finals_contest(
  (select id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 441)
     and contest_type = 'redemption_advancement_tiebreak'),
  test_support.finals_fixture_uuid(3, 3, 441),
  (select state_version from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 441))
);
select test_support.record_finals_resolution(
  (select id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 441)
     and contest_type = 'redemption_advancement_tiebreak'),
  'win', 0
);
select is(
  (
    select string_agg(
      source.entry_seed || ':' || source.outcome || ':'
        || source.outcome_order || ':' || source.advanced_champions_slot,
      ',' order by source.entry_seed
    )
    from public.event_finals_contest_participants as source
    join public.event_finals_contests as contest on contest.id = source.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 441)
      and contest.contest_type = 'table_of_redemption'
      and source.entry_seed in (3, 4)
  ) || '|' || (
    select string_agg(
      child.entry_seed || ':' || child.outcome || ':'
        || child.outcome_order || ':' || child.advanced_champions_slot,
      ',' order by child.entry_seed
    )
    from public.event_finals_contest_participants as child
    join public.event_finals_contests as contest on contest.id = child.contest_id
    where contest.event_id = test_support.finals_fixture_uuid(2, 1, 441)
      and contest.contest_type = 'redemption_advancement_tiebreak'
  ),
  '3:winner:1:3,4:runner_up:2:4|3:winner:1:3,4:runner_up:2:4',
  'two-slot tiebreak resolves winner and runner-up outcomes in child and source contests'
);

-- Production record_hand_result, not a test helper, must complete every
-- decisive one-hand tiebreak session on its first valid win.
select public.begin_event_finals(
  test_support.create_finals_fixture(6, 442),
  test_support.finals_fixture_uuid(3, 2, 442),
  test_support.finals_fixture_uuid(3, 3, 442), 0
);
select test_support.score_finals_contest(
  test_support.finals_fixture_uuid(2, 1, 442),
  'table_of_redemption', array[10,10,-10,-10]
);
select public.start_finals_contest(
  (select id from public.event_finals_contests
   where event_id = test_support.finals_fixture_uuid(2, 1, 442)
     and contest_type = 'redemption_advancement_tiebreak'),
  test_support.finals_fixture_uuid(3, 3, 442),
  (select state_version from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 442))
);
select lives_ok(
  format(
    'select public.record_hand_result('
      || 'target_table_session_id => %L, target_result_type => ''win'', '
      || 'target_winner_seat_index => 0, target_win_type => ''discard'', '
      || 'target_discarder_seat_index => 1, target_fan_count => 3, '
      || 'target_photo_client_id => %L, target_photo_captured_at => now())',
    (select table_session_id from public.event_finals_contests
     where event_id = test_support.finals_fixture_uuid(2, 1, 442)
       and contest_type = 'redemption_advancement_tiebreak'),
    test_support.finals_fixture_uuid(16, 1, 442)
  ),
  'production hand-entry path accepts the decisive Redemption advancement tiebreak win'
);
select ok(
  (select session.status = 'completed' and contest.status = 'complete'
   from public.event_finals_contests as contest
   join public.table_sessions as session on session.id = contest.table_session_id
   where contest.event_id = test_support.finals_fixture_uuid(2, 1, 442)
     and contest.contest_type = 'redemption_advancement_tiebreak'),
  'first valid Redemption advancement tiebreak win completes both session and contest'
);

-- Read access remains available to scoring staff, but server-authored mutation
-- actions are emitted only to event managers.
select test_support.create_ready_orchestrated_contest(
  443, 'table_of_champions', 'table_of_champions'
);
insert into public.users (id, email, display_name) values (
  test_support.finals_fixture_uuid(1, 2, 443),
  'finals-state-scorer-443@example.test', 'Finals State Scorer 443'
);
insert into public.approved_logistics_identities (
  id, email, email_lower, display_name, status, approved_by_user_id
) values (
  test_support.finals_fixture_uuid(12, 1, 443),
  'finals-state-scorer-443@example.test',
  'finals-state-scorer-443@example.test',
  'Finals State Scorer 443', 'active',
  test_support.finals_fixture_uuid(1, 1, 443)
);
insert into public.event_staff_memberships (
  id, event_id, approved_identity_id, user_id, role, status, created_by_user_id
) values (
  test_support.finals_fixture_uuid(13, 1, 443),
  test_support.finals_fixture_uuid(2, 1, 443),
  test_support.finals_fixture_uuid(12, 1, 443),
  test_support.finals_fixture_uuid(1, 2, 443),
  'event_scorer', 'active', test_support.finals_fixture_uuid(1, 1, 443)
);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 2, 443)::text,
  true
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 443))
    ->> 'flow_version',
  'orchestrated',
  'event scorer retains read access to orchestrated Finals state'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 443))
    -> 'allowed_actions',
  '[]'::jsonb,
  'event scorer receives no orchestrated Finals mutation actions'
);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 1, 443)::text,
  true
);

select test_support.create_legacy_finals_fixture(
  444, array[1,2,3,4], array[5,6,7,8]
);
insert into public.event_staff_memberships (
  id, event_id, approved_identity_id, user_id, role, status, created_by_user_id
) values (
  test_support.finals_fixture_uuid(13, 1, 444),
  test_support.finals_fixture_uuid(2, 1, 444),
  test_support.finals_fixture_uuid(12, 1, 443),
  test_support.finals_fixture_uuid(1, 2, 443),
  'event_scorer', 'active', test_support.finals_fixture_uuid(1, 1, 444)
);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 2, 443)::text,
  true
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 444))
    ->> 'overall_status',
  'recoverable_missing_sessions',
  'event scorer retains read access to legacy recovery state'
);
select is(
  public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 444))
    -> 'allowed_actions',
  '[]'::jsonb,
  'event scorer receives no legacy Finals mutation actions'
);
select set_config(
  'request.jwt.claim.sub',
  test_support.finals_fixture_uuid(1, 1, 444)::text,
  true
);

-- An orchestrated contest's idempotent return is valid only while its exact
-- durable assignment topology still matches the session seats.
select test_support.create_ready_orchestrated_contest(
  445, 'table_of_champions', 'table_of_champions'
);
select public.start_bonus_assigned_table_sessions(
  test_support.finals_fixture_uuid(2, 1, 445), 'table_of_champions'
);
delete from public.table_session_seats
where table_session_id = (
    select table_session_id from public.event_finals_contests
    where event_id = test_support.finals_fixture_uuid(2, 1, 445)
      and contest_type = 'table_of_champions'
  )
  and seat_index = 1;
select throws_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 445),
    'table_of_champions'
  ),
  'P0001',
  'Existing Finals session seats do not match the durable assignments.',
  'orchestrated compatibility retry fails closed when durable seats differ'
);

-- Legacy sudden-death/play-in compatibility uses the same exact-seat guard
-- and writes one audit only for the real start transition.
select test_support.create_legacy_finals_fixture(446, array[1,2]);
update public.event_seating_assignments
set bonus_table_role = 'table_of_champions_sudden_death'
where event_id = test_support.finals_fixture_uuid(2, 1, 446);
select public.start_bonus_assigned_table_sessions(
  test_support.finals_fixture_uuid(2, 1, 446),
  'table_of_champions_sudden_death'
);
select is(
  (select count(*)::integer from public.audit_logs
   where event_id = test_support.finals_fixture_uuid(2, 1, 446)
     and action = 'start_bonus_assigned_table_sessions'),
  1,
  'legacy sudden-death compatibility audits its start transition once'
);
delete from public.table_session_seats
where table_session_id = (
    select id from public.table_sessions
    where event_id = test_support.finals_fixture_uuid(2, 1, 446)
      and bonus_table_role = 'table_of_champions_sudden_death'
  )
  and seat_index = 1;
select throws_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 446),
    'table_of_champions_sudden_death'
  ),
  'P0001',
  'Existing Finals session seats do not match the durable assignments.',
  'legacy sudden-death retry fails closed when durable seats differ'
);

-- Historical six-player overlap starts Redemption first, then releases the
-- exact durable Champions assignment only after real Redemption completion.
drop index public.event_seating_assignments_active_guest_idx;
alter table public.event_seating_assignments
  drop constraint event_seating_assignments_event_id_assignment_round_event_g_key;
discard plans;
select test_support.create_legacy_finals_fixture(
  447, array[1,2,3,4], array[3,4,5,6]
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 447),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 447))
      ->> 'recovery_token'
  ),
  'recognized six-player overlap starts Redemption first'
);
select lives_ok(
  format(
    'select test_support.complete_legacy_finals_session_via_scoring(%L, %L, 447)',
    test_support.finals_fixture_uuid(2, 1, 447),
    'table_of_redemption'
  ),
  'production scoring completes the overlapping Redemption session'
);
select ok(
  (select status = 'completed' from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 447)
     and bonus_table_role = 'table_of_redemption')
  and public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 447))
    #>> '{allowed_actions,0,action}' = 'resume_finals_start',
  'completed overlapping Redemption releases the missing Champions start'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 447),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 447))
      ->> 'recovery_token'
  ),
  'overlap recovery starts Champions after Redemption completes'
);
select is(
  (select string_agg(
     seat.seat_index || ':' || right(guest.id::text, 1),
     ',' order by seat.seat_index
   )
   from public.table_sessions as session
   join public.table_session_seats as seat on seat.table_session_id = session.id
   join public.event_guests as guest on guest.id = seat.event_guest_id
   where session.event_id = test_support.finals_fixture_uuid(2, 1, 447)
     and session.bonus_table_role = 'table_of_champions'),
  '0:1,1:2,2:3,3:4',
  'overlap Champions seats preserve the exact durable assignment order'
);
select lives_ok(
  format(
    'select test_support.complete_legacy_finals_session_via_scoring(%L, %L, 447)',
    test_support.finals_fixture_uuid(2, 1, 447),
    'table_of_champions'
  ),
  'production scoring completes the recovered Champions session'
);
select ok(
  (select status = 'completed' and champion_event_guest_id is not null
   from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 447))
  and (select count(*) = 2 from public.table_sessions
       where event_id = test_support.finals_fixture_uuid(2, 1, 447)
         and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 447)
         and status = 'completed')
  and (select count(*) = 1 from public.event_score_adjustments
       where event_id = test_support.finals_fixture_uuid(2, 1, 447)
         and adjustment_type = 'finals_champion_award'),
  'overlap flow completes both real sessions and awards one champion'
);
delete from public.table_sessions
where event_id = test_support.finals_fixture_uuid(2, 1, 447);
delete from public.events where id = test_support.finals_fixture_uuid(2, 1, 447);
alter table public.event_seating_assignments
  add constraint event_seating_assignments_event_id_assignment_round_event_g_key
  unique (event_id, assignment_round, event_guest_id);
create unique index event_seating_assignments_active_guest_idx
  on public.event_seating_assignments (event_id, event_guest_id)
  where status = 'active';

-- A real legacy Champions completion can leave a completed root with the
-- disjoint Redemption table missing. Recovery preserves the award/session,
-- reopens only for Redemption, then returns terminal after real scoring.
select test_support.create_legacy_finals_fixture(
  448, array[1,2,3,4], array[5,6,7,8]
);
select lives_ok(
  format(
    'select public.start_bonus_assigned_table_sessions(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 448),
    'table_of_champions'
  ),
  'legacy compatibility starts only Champions for completed-partial coverage'
);
select lives_ok(
  format(
    'select test_support.complete_legacy_finals_session_via_scoring(%L, %L, 448)',
    test_support.finals_fixture_uuid(2, 1, 448),
    'table_of_champions'
  ),
  'production scoring creates the historical completed-partial root shape'
);
select ok(
  (select status = 'completed' and champion_event_guest_id is not null
   from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 448))
  and (select count(*) = 1 from public.event_score_adjustments
       where event_id = test_support.finals_fixture_uuid(2, 1, 448)
         and adjustment_type = 'finals_champion_award')
  and public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 448))
    #>> '{allowed_actions,0,action}' = 'resume_finals_start',
  'completed-partial state exposes safe Redemption recovery without re-awarding'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 448),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 448))
      ->> 'recovery_token'
  ),
  'completed-partial recovery starts the missing Redemption table'
);
select ok(
  (select status = 'active' and champion_event_guest_id is not null
   from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 448))
  and (select status = 'completed' from public.table_sessions
       where event_id = test_support.finals_fixture_uuid(2, 1, 448)
         and bonus_table_role = 'table_of_champions')
  and (select status = 'active' from public.table_sessions
       where event_id = test_support.finals_fixture_uuid(2, 1, 448)
         and bonus_table_role = 'table_of_redemption'),
  'recovery preserves completed Champions and reopens only for Redemption'
);
select lives_ok(
  format(
    'select test_support.complete_legacy_finals_session_via_scoring(%L, %L, 448)',
    test_support.finals_fixture_uuid(2, 1, 448),
    'table_of_redemption'
  ),
  'production scoring completes the recovered Redemption session'
);
select ok(
  (select status = 'completed' and champion_event_guest_id is not null
   from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 448))
  and (select count(*) = 1 from public.event_score_adjustments
       where event_id = test_support.finals_fixture_uuid(2, 1, 448)
         and adjustment_type = 'finals_champion_award')
  and (select count(*) = 2 from public.table_sessions
       where event_id = test_support.finals_fixture_uuid(2, 1, 448)
         and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 448)
         and status = 'completed'),
  'completed-partial recovery returns terminal with one unchanged champion award'
);

select ok(
  pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ) like '%for update nowait%'
  and pg_get_functiondef(
    'public.start_finals_contest(uuid,uuid,bigint)'::regprocedure
  ) like '%Selected Finals table is currently being scored.%',
  'contest start uses a fail-fast session lock contract'
);
select ok(
  pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  ) like '%for update nowait%'
  and pg_get_functiondef(
    'public.begin_event_finals(uuid,uuid,uuid,bigint,text)'::regprocedure
  ) like '%Selected Finals tables are currently being scored.%',
  'Begin Finals uses a fail-fast session lock contract'
);

-- The recognized seven-player legacy overlap follows the same real scoring
-- path as six players: Redemption first, then exact durable Champions seats.
drop index public.event_seating_assignments_active_guest_idx;
alter table public.event_seating_assignments
  drop constraint event_seating_assignments_event_id_assignment_round_event_g_key;
discard plans;
select test_support.create_legacy_finals_fixture(
  449, array[1,2,3,4], array[4,5,6,7]
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 449),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 449))
      ->> 'recovery_token'
  ),
  'recognized seven-player overlap starts Redemption first'
);
select lives_ok(
  format(
    'select test_support.complete_legacy_finals_session_via_scoring(%L, %L, 449)',
    test_support.finals_fixture_uuid(2, 1, 449),
    'table_of_redemption'
  ),
  'production scoring completes seven-player Redemption'
);
select ok(
  (select status = 'completed' from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 449)
     and bonus_table_role = 'table_of_redemption')
  and public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 449))
    #>> '{allowed_actions,0,action}' = 'resume_finals_start',
  'seven-player Redemption completion releases Champions start'
);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 449),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 449))
      ->> 'recovery_token'
  ),
  'seven-player overlap starts Champions after Redemption'
);
select is(
  (select string_agg(
     seat.seat_index || ':' || right(guest.id::text, 1),
     ',' order by seat.seat_index
   )
   from public.table_sessions as session
   join public.table_session_seats as seat on seat.table_session_id = session.id
   join public.event_guests as guest on guest.id = seat.event_guest_id
   where session.event_id = test_support.finals_fixture_uuid(2, 1, 449)
     and session.bonus_table_role = 'table_of_champions'),
  '0:1,1:2,2:3,3:4',
  'seven-player Champions seats preserve durable assignment order'
);
select lives_ok(
  format(
    'select test_support.complete_legacy_finals_session_via_scoring(%L, %L, 449)',
    test_support.finals_fixture_uuid(2, 1, 449),
    'table_of_champions'
  ),
  'production scoring completes seven-player Champions'
);
select ok(
  (select status = 'completed' and champion_event_guest_id is not null
   from public.event_bonus_rounds
   where event_id = test_support.finals_fixture_uuid(2, 1, 449))
  and (select count(*) = 2 from public.table_sessions
       where event_id = test_support.finals_fixture_uuid(2, 1, 449)
         and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 449)
         and status = 'completed')
  and (select count(*) = 1 from public.event_score_adjustments
       where event_id = test_support.finals_fixture_uuid(2, 1, 449)
         and adjustment_type = 'finals_champion_award'),
  'seven-player overlap terminates with two sessions and one champion award'
);
delete from public.table_sessions
where event_id = test_support.finals_fixture_uuid(2, 1, 449);
delete from public.events where id = test_support.finals_fixture_uuid(2, 1, 449);
alter table public.event_seating_assignments
  add constraint event_seating_assignments_event_id_assignment_round_event_g_key
  unique (event_id, assignment_round, event_guest_id);
create unique index event_seating_assignments_active_guest_idx
  on public.event_seating_assignments (event_id, event_guest_id)
  where status = 'active';

-- Active contest retries are idempotent only while the linked session and
-- exact durable seat topology remain authoritative.
select test_support.create_ready_orchestrated_contest(
  450, 'table_of_champions', 'table_of_champions'
);
select public.start_finals_contest(
  test_support.finals_fixture_uuid(11, 1, 450),
  test_support.finals_fixture_uuid(3, 2, 450), 1
);
delete from public.table_session_seats
where table_session_id = (
    select table_session_id from public.event_finals_contests
    where id = test_support.finals_fixture_uuid(11, 1, 450)
  ) and seat_index = 1;
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, 2)',
    test_support.finals_fixture_uuid(11, 1, 450),
    test_support.finals_fixture_uuid(3, 2, 450)
  ),
  'P0001',
  'Existing Finals session seats do not match the durable assignments.',
  'active contest retry fails closed after exact seats are changed'
);

select test_support.create_ready_orchestrated_contest(
  451, 'table_of_champions', 'table_of_champions'
);
select public.start_finals_contest(
  test_support.finals_fixture_uuid(11, 1, 451),
  test_support.finals_fixture_uuid(3, 2, 451), 1
);
update public.event_finals_contests
set table_session_id = null
where id = test_support.finals_fixture_uuid(11, 1, 451);
select throws_ok(
  format(
    'select public.start_finals_contest(%L, %L, 2)',
    test_support.finals_fixture_uuid(11, 1, 451),
    test_support.finals_fixture_uuid(3, 2, 451)
  ),
  'P0001',
  'Finals contest references an unexpected session.',
  'active contest retry fails closed when its linked session is missing'
);

-- An unrelated active table remains outside the recovery session-lock set.
select test_support.create_legacy_finals_fixture(
  452, array[1,2,3,4], array[5,6,7,8]
);
select test_support.add_finals_table(452, 4);
select test_support.occupy_finals_table(452, 4, 99);
select lives_ok(
  format(
    'select public.resume_event_finals_start(%L, %L)',
    test_support.finals_fixture_uuid(2, 1, 452),
    public.get_event_finals_state(test_support.finals_fixture_uuid(2, 1, 452))
      ->> 'recovery_token'
  ),
  'legacy recovery ignores an unrelated active event table'
);
select is(
  (select count(*)::integer from public.table_sessions
   where event_id = test_support.finals_fixture_uuid(2, 1, 452)
     and bonus_round_id = test_support.finals_fixture_uuid(10, 1, 452)),
  2,
  'unrelated active table does not change the two recovered Finals sessions'
);

select * from finish();
rollback;
