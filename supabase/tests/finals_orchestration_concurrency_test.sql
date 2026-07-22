-- Two-connection regression for the event-lock/session-lock inversion between
-- live Finals scoring and the legacy compatibility start entry point.

create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;

begin;

create schema finals_concurrency_test;

create function finals_concurrency_test.pause_after_session_lock()
returns trigger
language plpgsql
as $$
begin
  if new.table_session_id = '10000000-0000-0000-0000-000000000006'::uuid then
    -- The main test connection owns this session-level barrier. At this point
    -- record_hand_result already owns the table_sessions row lock.
    perform pg_advisory_xact_lock(73111, 1);
  elsif new.table_session_id = '10000000-0000-0000-0000-000000000033'::uuid then
    perform pg_advisory_xact_lock(73111, 2);
  end if;
  return new;
end;
$$;

create trigger finals_concurrency_pause_hand_insert
before insert on public.hand_results
for each row execute function finals_concurrency_test.pause_after_session_lock();

insert into public.rulesets (id, name, status, definition_json)
values ('HK_STANDARD', 'Hong Kong Standard', 'active', '{}'::jsonb)
on conflict (id) do nothing;

insert into public.users (id, email, display_name)
values (
  '10000000-0000-0000-0000-000000000001',
  'finals-concurrency@example.test',
  'Finals Concurrency Host'
);

insert into public.events (
  id, owner_user_id, title, timezone, starts_at, lifecycle_status,
  checkin_open, scoring_open, current_scoring_phase
) values (
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  'Finals Concurrency Test', 'America/Los_Angeles', now(), 'active',
  true, true, 'tournament'
);

insert into public.nfc_tags (
  id, uid_hex, uid_fingerprint, default_tag_type, display_label, status
) values
  (
    '10000000-0000-0000-0000-000000000003',
    'FC0A00000001', 'finals-concurrency-table', 'table',
    'Concurrency Table', 'active'
  ),
  (
    '10000000-0000-0000-0000-000000000030',
    'FC0A00000002', 'finals-contest-race-table', 'table',
    'Contest Race Table', 'active'
  );

insert into public.event_tables (id, event_id, label, display_order, nfc_tag_id)
values
  (
    '10000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000002',
    'Concurrency Table', 1,
    '10000000-0000-0000-0000-000000000003'
  ),
  (
    '10000000-0000-0000-0000-000000000031',
    '10000000-0000-0000-0000-000000000002',
    'Contest Race Table', 2,
    '10000000-0000-0000-0000-000000000030'
  );

insert into public.guest_profiles (
  id, owner_user_id, display_name, normalized_name, public_display_name
) values
  (
    '10000000-0000-0000-0000-000000000011',
    '10000000-0000-0000-0000-000000000001',
    'Concurrency East', 'concurrency east', 'Concurrency East'
  ),
  (
    '10000000-0000-0000-0000-000000000012',
    '10000000-0000-0000-0000-000000000001',
    'Concurrency South', 'concurrency south', 'Concurrency South'
  ),
  (
    '10000000-0000-0000-0000-000000000013',
    '10000000-0000-0000-0000-000000000001',
    'Race Blocker East', 'race blocker east', 'Race Blocker East'
  ),
  (
    '10000000-0000-0000-0000-000000000014',
    '10000000-0000-0000-0000-000000000001',
    'Race Blocker South', 'race blocker south', 'Race Blocker South'
  ),
  (
    '10000000-0000-0000-0000-000000000015',
    '10000000-0000-0000-0000-000000000001',
    'Race Starter East', 'race starter east', 'Race Starter East'
  ),
  (
    '10000000-0000-0000-0000-000000000016',
    '10000000-0000-0000-0000-000000000001',
    'Race Starter South', 'race starter south', 'Race Starter South'
  );

insert into public.event_guests (
  id, event_id, guest_profile_id, display_name, normalized_name,
  attendance_status, checked_in_at, tournament_status, public_display_name
) values
  (
    '10000000-0000-0000-0000-000000000021',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000011',
    'Concurrency East', 'concurrency east', 'checked_in', now(),
    'qualified', 'Concurrency East'
  ),
  (
    '10000000-0000-0000-0000-000000000022',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000012',
    'Concurrency South', 'concurrency south', 'checked_in', now(),
    'qualified', 'Concurrency South'
  ),
  (
    '10000000-0000-0000-0000-000000000023',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000013',
    'Race Blocker East', 'race blocker east', 'checked_in', now(),
    'qualified', 'Race Blocker East'
  ),
  (
    '10000000-0000-0000-0000-000000000024',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000014',
    'Race Blocker South', 'race blocker south', 'checked_in', now(),
    'qualified', 'Race Blocker South'
  ),
  (
    '10000000-0000-0000-0000-000000000025',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000015',
    'Race Starter East', 'race starter east', 'checked_in', now(),
    'qualified', 'Race Starter East'
  ),
  (
    '10000000-0000-0000-0000-000000000026',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000016',
    'Race Starter South', 'race starter south', 'checked_in', now(),
    'qualified', 'Race Starter South'
  );

insert into public.event_bonus_rounds (
  id, event_id, champions_table_id, redemption_table_id, assignment_round,
  status, flow_version, state_version, eligible_player_count, format
) values (
  '10000000-0000-0000-0000-000000000005',
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000004', null, 1,
  'active', 'orchestrated', 1, 2, 'champions_only'
);

insert into public.event_finals_contests (
  id, bonus_round_id, event_id, contest_type, status, event_table_id,
  slots_to_fill, sequence_number, created_by_user_id
) values
  (
    '10000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000002',
    'champions_sudden_death', 'active',
    '10000000-0000-0000-0000-000000000004', 1, 1,
    '10000000-0000-0000-0000-000000000001'
  ),
  (
    '10000000-0000-0000-0000-000000000032',
    '10000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000002',
    'direct_qualification_tiebreak', 'active',
    '10000000-0000-0000-0000-000000000031', 1, 2,
    '10000000-0000-0000-0000-000000000001'
  ),
  (
    '10000000-0000-0000-0000-000000000034',
    '10000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000002',
    'redemption_winner_tiebreak', 'ready',
    '10000000-0000-0000-0000-000000000031', 1, 3,
    '10000000-0000-0000-0000-000000000001'
  );

insert into public.event_finals_contest_participants (
  contest_id, event_guest_id, entry_seed, seat_index
) values
  (
    '10000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000021', 1, 0
  ),
  (
    '10000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000022', 2, 1
  ),
  (
    '10000000-0000-0000-0000-000000000032',
    '10000000-0000-0000-0000-000000000023', 3, 0
  ),
  (
    '10000000-0000-0000-0000-000000000032',
    '10000000-0000-0000-0000-000000000024', 4, 1
  ),
  (
    '10000000-0000-0000-0000-000000000034',
    '10000000-0000-0000-0000-000000000025', 5, 0
  ),
  (
    '10000000-0000-0000-0000-000000000034',
    '10000000-0000-0000-0000-000000000026', 6, 1
  );

insert into public.event_seating_assignments (
  event_id, event_table_id, event_guest_id, seat_index, assignment_round,
  assignment_type, bonus_round_id, bonus_table_role, seed_rank, status,
  assigned_by_user_id, finals_contest_id
) values
  (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000021', 0, 1, 'bonus',
    '10000000-0000-0000-0000-000000000005',
    'table_of_champions_sudden_death', 1, 'active',
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000007'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000022', 1, 1, 'bonus',
    '10000000-0000-0000-0000-000000000005',
    'table_of_champions_sudden_death', 2, 'active',
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000007'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000031',
    '10000000-0000-0000-0000-000000000023', 0, 1, 'bonus',
    '10000000-0000-0000-0000-000000000005',
    'table_of_champions_play_in', 3, 'active',
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000032'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000031',
    '10000000-0000-0000-0000-000000000024', 1, 1, 'bonus',
    '10000000-0000-0000-0000-000000000005',
    'table_of_champions_play_in', 4, 'active',
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000032'
  );

insert into public.table_sessions (
  id, event_id, event_table_id, session_number_for_table, ruleset_id,
  rotation_policy_type, rotation_policy_config_json, status,
  initial_east_seat_index, current_dealer_seat_index, scoring_phase,
  bonus_round_id, bonus_table_role, assignment_round, finals_contest_id,
  started_at, started_by_user_id
) values
  (
    '10000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000004', 1, 'HK_STANDARD',
    'dealer_cycle_return_to_initial_east', '{}'::jsonb, 'active',
    0, 0, 'bonus',
    '10000000-0000-0000-0000-000000000005',
    'table_of_champions_sudden_death', 1,
    '10000000-0000-0000-0000-000000000007',
    now(), '10000000-0000-0000-0000-000000000001'
  ),
  (
    '10000000-0000-0000-0000-000000000033',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000031', 1, 'HK_STANDARD',
    'dealer_cycle_return_to_initial_east', '{}'::jsonb, 'active',
    0, 0, 'bonus',
    '10000000-0000-0000-0000-000000000005',
    'table_of_champions_play_in', 1,
    '10000000-0000-0000-0000-000000000032',
    now(), '10000000-0000-0000-0000-000000000001'
  );

insert into public.table_session_seats (
  table_session_id, seat_index, initial_wind, event_guest_id
) values
  (
    '10000000-0000-0000-0000-000000000006', 0, 'east',
    '10000000-0000-0000-0000-000000000021'
  ),
  (
    '10000000-0000-0000-0000-000000000006', 1, 'south',
    '10000000-0000-0000-0000-000000000022'
  ),
  (
    '10000000-0000-0000-0000-000000000033', 0, 'east',
    '10000000-0000-0000-0000-000000000023'
  ),
  (
    '10000000-0000-0000-0000-000000000033', 1, 'south',
    '10000000-0000-0000-0000-000000000024'
  );

update public.event_finals_contests
set table_session_id = '10000000-0000-0000-0000-000000000006'
where id = '10000000-0000-0000-0000-000000000007';

update public.event_finals_contests
set table_session_id = '10000000-0000-0000-0000-000000000033'
where id = '10000000-0000-0000-0000-000000000032';

create function finals_concurrency_test.capture_contest_start()
returns text
language plpgsql
as $$
begin
  perform public.start_finals_contest(
    '10000000-0000-0000-0000-000000000034'::uuid,
    '10000000-0000-0000-0000-000000000031'::uuid,
    (
      select state_version
      from public.event_bonus_rounds
      where id = '10000000-0000-0000-0000-000000000005'
    )
  );
  return 'unexpected_success';
exception
  when others then
    return sqlstate || ':' || sqlerrm;
end;
$$;

create function finals_concurrency_test.capture_compatibility_start()
returns text
language plpgsql
as $$
begin
  perform public.start_bonus_assigned_table_sessions(
    '10000000-0000-0000-0000-000000000002'::uuid,
    'table_of_redemption'
  );
  return 'unexpected_success';
exception
  when others then
    return sqlstate || ':' || sqlerrm;
end;
$$;

commit;

begin;
select plan(9);

select extensions.dblink_connect(
  'finals_score',
  'host=host.docker.internal port=54322 user=postgres password=postgres dbname='
    || current_database()
    || ' application_name=finals_scoring_concurrency'
    || ' options=-cstatement_timeout=5000'
);
select extensions.dblink_connect(
  'finals_compat',
  'host=host.docker.internal port=54322 user=postgres password=postgres dbname='
    || current_database()
    || ' application_name=finals_compatibility_concurrency'
    || ' options=-cstatement_timeout=1500'
);
select extensions.dblink_connect(
  'finals_contest',
  'host=host.docker.internal port=54322 user=postgres password=postgres dbname='
    || current_database()
    || ' application_name=finals_contest_start_concurrency'
    || ' options=-cstatement_timeout=1500'
);
select extensions.dblink_connect(
  'finals_compat_lock',
  'host=host.docker.internal port=54322 user=postgres password=postgres dbname='
    || current_database()
    || ' application_name=finals_compatibility_lock_concurrency'
    || ' options=-cstatement_timeout=1500'
);

select pg_advisory_lock(73111, 1);

select extensions.dblink_send_query(
  'finals_score',
  $$
    select hand.id::text
    from (
      select
        set_config(
          'request.jwt.claim.sub',
          '10000000-0000-0000-0000-000000000001', true
        ),
        set_config('request.jwt.claim.role', 'authenticated', true)
    ) as auth_context
    cross join lateral public.record_hand_result(
      target_table_session_id =>
        '10000000-0000-0000-0000-000000000006'::uuid,
      target_result_type => 'win',
      target_winner_seat_index => 0,
      target_win_type => 'discard',
      target_discarder_seat_index => 1,
      target_fan_count => 3,
      target_photo_client_id =>
        '10000000-0000-0000-0000-000000000008'::uuid,
      target_photo_captured_at => now()
    ) as hand
  $$
);

do $$
declare
  attempt integer;
begin
  for attempt in 1..50 loop
    exit when exists (
      select 1
      from pg_stat_activity
      where application_name = 'finals_scoring_concurrency'
        and wait_event_type = 'Lock'
        and wait_event = 'advisory'
    );
    perform pg_sleep(0.02);
  end loop;
end;
$$;

select ok(
  exists (
    select 1
    from pg_stat_activity
    where application_name = 'finals_scoring_concurrency'
      and wait_event_type = 'Lock'
      and wait_event = 'advisory'
  ),
  'scoring connection holds the session row and reaches the event-lock barrier'
);

select extensions.dblink_send_query(
  'finals_compat',
  $$
    select count(*)::integer
    from (
      select
        set_config(
          'request.jwt.claim.sub',
          '10000000-0000-0000-0000-000000000001', true
        ),
        set_config('request.jwt.claim.role', 'authenticated', true)
    ) as auth_context
    cross join lateral public.start_bonus_assigned_table_sessions(
      '10000000-0000-0000-0000-000000000002'::uuid,
      'table_of_champions_sudden_death'
    ) as started
  $$
);

select lives_ok(
  $$
    select *
    from extensions.dblink_get_result('finals_compat') as result(session_count integer)
  $$,
  'compatibility retry does not wait on the active Finals session row'
);

select pg_advisory_unlock(73111, 1);

select lives_ok(
  $$
    select *
    from extensions.dblink_get_result('finals_score') as result(hand_id text)
  $$,
  'scoring completes after the compatibility retry releases the event lock'
);

select ok(
  (select count(*) = 1 from public.table_sessions
   where finals_contest_id = '10000000-0000-0000-0000-000000000007')
  and (select status = 'completed' from public.table_sessions
       where id = '10000000-0000-0000-0000-000000000006')
  and (select status = 'complete' from public.event_finals_contests
       where id = '10000000-0000-0000-0000-000000000007'),
  'concurrent retry creates no duplicate and decisive scoring completes normally'
);

select extensions.dblink_disconnect('finals_score');
select extensions.dblink_connect(
  'finals_score',
  'host=host.docker.internal port=54322 user=postgres password=postgres dbname='
    || current_database()
    || ' application_name=finals_scoring_concurrency'
    || ' options=-cstatement_timeout=5000'
);

select pg_advisory_lock(73111, 2);

select extensions.dblink_send_query(
  'finals_score',
  $$
    select hand.id::text
    from (
      select
        set_config(
          'request.jwt.claim.sub',
          '10000000-0000-0000-0000-000000000001', true
        ),
        set_config('request.jwt.claim.role', 'authenticated', true)
    ) as auth_context
    cross join lateral public.record_hand_result(
      target_table_session_id =>
        '10000000-0000-0000-0000-000000000033'::uuid,
      target_result_type => 'washout'
    ) as hand
  $$
);

do $$
declare
  attempt integer;
begin
  for attempt in 1..50 loop
    exit when exists (
      select 1
      from pg_stat_activity
      where application_name = 'finals_scoring_concurrency'
        and wait_event_type = 'Lock'
        and wait_event = 'advisory'
    );
    perform pg_sleep(0.02);
  end loop;
end;
$$;

select ok(
  extensions.dblink_is_busy('finals_score') = 1,
  'scoring query is active while contest start races its session row lock'
);

select extensions.dblink_send_query(
  'finals_contest',
  $$
    select finals_concurrency_test.capture_contest_start()
    from (
      select
        set_config(
          'request.jwt.claim.sub',
          '10000000-0000-0000-0000-000000000001', true
        ),
        set_config('request.jwt.claim.role', 'authenticated', true)
    ) as auth_context
  $$
);

select is(
  (
    select response
    from extensions.dblink_get_result('finals_contest')
      as result(response text)
  ),
  'P0001:Selected Finals table is currently being scored. Refresh and try again.',
  'contest start fails fast instead of waiting behind a scoring session lock'
);

select is(
  (
    select response
    from extensions.dblink(
      'finals_compat_lock',
      $$
        select finals_concurrency_test.capture_compatibility_start()
        from (
          select
            set_config(
              'request.jwt.claim.sub',
              '10000000-0000-0000-0000-000000000001', true
            ),
            set_config('request.jwt.claim.role', 'authenticated', true)
        ) as auth_context
      $$
    ) as result(response text)
  ),
  'P0001:Finals tables are currently being scored. Refresh and try again.',
  'compatibility start translates candidate-table lock contention safely'
);

select pg_advisory_unlock(73111, 2);

select lives_ok(
  $$
    select *
    from extensions.dblink_get_result('finals_score') as result(hand_id text)
  $$,
  'scoring completes after the failed contest start releases the event lock'
);

select ok(
  (select status = 'ready' and table_session_id is null
   from public.event_finals_contests
   where id = '10000000-0000-0000-0000-000000000034')
  and (select count(*) = 1 from public.table_sessions
       where event_table_id = '10000000-0000-0000-0000-000000000031'),
  'failed concurrent contest start leaves its contest ready and creates no session'
);

select extensions.dblink_disconnect('finals_score');
select extensions.dblink_disconnect('finals_compat');
select extensions.dblink_disconnect('finals_contest');
select extensions.dblink_disconnect('finals_compat_lock');

select * from finish();

drop schema finals_concurrency_test cascade;
delete from public.table_sessions
where event_id = '10000000-0000-0000-0000-000000000002';
delete from public.event_bonus_rounds
where event_id = '10000000-0000-0000-0000-000000000002';
delete from public.events
where id = '10000000-0000-0000-0000-000000000002';
delete from public.guest_profiles
where id in (
  '10000000-0000-0000-0000-000000000011',
  '10000000-0000-0000-0000-000000000012',
  '10000000-0000-0000-0000-000000000013',
  '10000000-0000-0000-0000-000000000014',
  '10000000-0000-0000-0000-000000000015',
  '10000000-0000-0000-0000-000000000016'
);
delete from public.nfc_tags
where id in (
  '10000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000030'
);
delete from public.users
where id = '10000000-0000-0000-0000-000000000001';

commit;
