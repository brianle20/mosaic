-- Atomically create and start the durable Finals orchestration graph.

create or replace function app_private.event_seating_assignments_block_live_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.table_sessions as session
    where session.event_id = new.event_id
      and session.status in ('active', 'paused')
  ) and not (
    (
      (tg_op = 'INSERT' and new.finals_contest_id is not null)
      or (
        tg_op = 'UPDATE'
        and old.status = 'active'
        and new.status = 'cleared'
      )
    )
    and not exists (
      select 1 from public.table_sessions as session
      where session.event_table_id = new.event_table_id
        and session.status in ('active', 'paused')
    )
    and not exists (
      select 1
      from public.table_session_seats as seat
      join public.table_sessions as session on session.id = seat.table_session_id
      where session.event_id = new.event_id
        and session.status in ('active', 'paused')
        and seat.event_guest_id = new.event_guest_id
    )
  ) then
    raise exception 'End active or paused sessions before changing seating assignments.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create or replace function app_private.start_assigned_finals_session(
  target_event_id uuid,
  target_bonus_round_id uuid,
  target_bonus_table_role text,
  target_finals_contest_id uuid,
  target_started_at timestamptz
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  table_row public.event_tables%rowtype;
  session_row public.table_sessions%rowtype;
  assignment_rows public.event_seating_assignments[];
  initial_winds constant text[] := array['east', 'south', 'west', 'north'];
  next_session_number integer;
  assignment_index integer;
begin
  if not exists (
    select 1 from public.events as event
    where event.id = target_event_id
      and event.lifecycle_status = 'active'
      and event.current_scoring_phase = 'bonus'
      and event.scoring_open
  ) then
    raise exception 'Event must be active and open for bonus scoring.' using errcode = 'P0001';
  end if;

  select contest.*
  into contest_row
  from public.event_finals_contests as contest
  where contest.id = target_finals_contest_id
    and contest.event_id = target_event_id
    and contest.bonus_round_id = target_bonus_round_id
  for update;

  if not found then
    raise exception 'Finals contest not found for this event.' using errcode = 'P0001';
  end if;

  if contest_row.table_session_id is not null then
    select * into session_row
    from public.table_sessions as session
    where session.id = contest_row.table_session_id
      and session.event_id = target_event_id
      and session.finals_contest_id = contest_row.id;
    if found then
      return session_row;
    end if;
    raise exception 'Finals contest references an unexpected session.' using errcode = 'P0001';
  end if;

  if contest_row.status <> 'ready' then
    raise exception 'This Finals contest is no longer ready to start.' using errcode = 'P0001';
  end if;

  select event_table.*
  into table_row
  from public.event_tables as event_table
  where event_table.id = contest_row.event_table_id
    and event_table.event_id = target_event_id
  for update;

  if not found then
    raise exception 'Selected Finals table is not available for this event.' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.table_sessions as existing_session
    where existing_session.event_table_id = table_row.id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'The selected Finals table already has an active session.' using errcode = 'P0001';
  end if;

  with locked_assignments as (
    select assignment.*
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.bonus_round_id = target_bonus_round_id
      and assignment.bonus_table_role = target_bonus_table_role
      and assignment.finals_contest_id = target_finals_contest_id
      and assignment.event_table_id = table_row.id
      and assignment.assignment_type = 'bonus'
      and assignment.status = 'active'
    order by assignment.seat_index
    for update
  )
  select array_agg(assignment order by assignment.seat_index)
  into assignment_rows
  from locked_assignments as assignment;

  if assignment_rows is null or not (array_length(assignment_rows, 1) between 2 and 4) then
    raise exception 'Two to four active Finals seating assignments are required.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from generate_subscripts(assignment_rows, 1) as item
    where assignment_rows[item].seat_index <> item - 1
  ) then
    raise exception 'Assigned seating must fill seats contiguously from East.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(assignment_rows) as assignment
    where assignment.assignment_round is distinct from assignment_rows[1].assignment_round
      or assignment.assignment_type is distinct from 'bonus'
      or assignment.bonus_round_id is distinct from target_bonus_round_id
      or assignment.bonus_table_role is distinct from target_bonus_table_role
      or assignment.finals_contest_id is distinct from target_finals_contest_id
  ) then
    raise exception 'All Finals assignments must share one assignment round and metadata set.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(assignment_rows) as assignment
    join public.event_guests as guest on guest.id = assignment.event_guest_id
    where guest.attendance_status <> 'checked_in'
  ) then
    raise exception 'All assigned session players must be checked in.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(assignment_rows) as assignment
    join public.table_session_seats as seat on seat.event_guest_id = assignment.event_guest_id
    join public.table_sessions as existing_session on existing_session.id = seat.table_session_id
    where existing_session.event_id = target_event_id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'An assigned guest is already seated in another active session.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.rulesets where id = table_row.default_ruleset_id) then
    raise exception 'Default ruleset not found for the selected Finals table.' using errcode = 'P0001';
  end if;

  select coalesce(max(session.session_number_for_table), 0) + 1
  into next_session_number
  from public.table_sessions as session
  where session.event_table_id = table_row.id;

  insert into public.table_sessions (
    event_id, event_table_id, session_number_for_table, ruleset_id,
    rotation_policy_type, rotation_policy_config_json, status,
    initial_east_seat_index, current_dealer_seat_index, scoring_phase,
    bonus_round_id, bonus_table_role, assignment_round, finals_contest_id,
    started_at, started_by_user_id
  ) values (
    target_event_id, table_row.id, next_session_number, table_row.default_ruleset_id,
    table_row.default_rotation_policy_type, table_row.default_rotation_policy_config_json,
    'active', 0, 0, 'bonus', target_bonus_round_id, target_bonus_table_role,
    assignment_rows[1].assignment_round, target_finals_contest_id,
    coalesce(target_started_at, now()), auth.uid()
  ) returning * into session_row;

  for assignment_index in 1..array_length(assignment_rows, 1) loop
    insert into public.table_session_seats (
      table_session_id, seat_index, initial_wind, event_guest_id
    ) values (
      session_row.id,
      assignment_rows[assignment_index].seat_index,
      initial_winds[assignment_rows[assignment_index].seat_index + 1],
      assignment_rows[assignment_index].event_guest_id
    );
  end loop;

  update public.event_finals_contests
  set status = 'active', table_session_id = session_row.id,
      started_at = session_row.started_at, updated_at = now()
  where id = target_finals_contest_id;

  return session_row;
end;
$$;

create or replace function public.begin_event_finals(
  target_event_id uuid,
  selected_champions_table_id uuid,
  selected_redemption_table_id uuid,
  expected_state_version bigint,
  expected_preview_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  existing_root public.event_bonus_rounds%rowtype;
  bonus_round_row public.event_bonus_rounds%rowtype;
  eligible_count integer;
  finals_format text;
  direct_slot_count integer;
  champions_slot_count integer;
  cutoff_points integer;
  cutoff_min_seed integer;
  cutoff_max_seed integer;
  cutoff_tie_count integer := 0;
  open_direct_slots integer := 0;
  next_assignment_round integer;
  sequence_value integer := 0;
  champions_contest_id uuid;
  redemption_contest_id uuid;
  tiebreak_contest_id uuid;
  started_session public.table_sessions%rowtype;
  transition_started_at timestamptz := now();
  started_sessions jsonb := '[]'::jsonb;
  standings_snapshot_value jsonb := '[]'::jsonb;
begin
  if not app_private.can_manage_event(target_event_id) then
    raise exception 'Event not found for current Finals operator.' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(target_event_id::text, 0));

  select * into event_row
  from public.events as event
  where event.id = target_event_id
  for update;
  if not found or event_row.lifecycle_status <> 'active' or not event_row.scoring_open then
    raise exception 'Event must be active and open for scoring before Finals begin.' using errcode = 'P0001';
  end if;

  select * into existing_root
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and flow_version = 'orchestrated'
    and bonus_round.status in ('active', 'completed')
  order by bonus_round.assignment_round desc
  limit 1
  for update;

  if found then
    if existing_root.champions_table_id = selected_champions_table_id
      and existing_root.redemption_table_id is not distinct from selected_redemption_table_id
    then
      return public.get_event_finals_state(target_event_id);
    end if;
    raise exception 'Finals already began with different table selections. Refresh and try again.' using errcode = 'P0001';
  end if;

  select * into existing_root
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.flow_version = 'legacy'
    and bonus_round.status in ('active', 'completed')
  order by bonus_round.assignment_round desc
  limit 1
  for update;
  if found then
    if existing_root.status = 'active' then
      raise exception 'Active Finals already exist for this event. Use the Finals recovery action.'
        using errcode = 'P0001';
    end if;
    raise exception 'Completed legacy Finals already exist for this event.'
      using errcode = 'P0001';
  end if;

  if coalesce(expected_state_version, 0) <> 0 then
    raise exception 'Finals changed since this screen was loaded. Refresh and try again.' using errcode = 'P0001';
  end if;
  if selected_champions_table_id = selected_redemption_table_id then
    raise exception 'Finals tables must be different.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.event_tables as event_table
    join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table' and tag.status = 'active'
    where event_table.id = selected_champions_table_id and event_table.event_id = target_event_id
  ) then
    raise exception 'Table of Champions must be a ready event table.' using errcode = 'P0001';
  end if;
  if selected_redemption_table_id is not null and not exists (
    select 1 from public.event_tables as event_table
    join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table' and tag.status = 'active'
    where event_table.id = selected_redemption_table_id and event_table.event_id = target_event_id
  ) then
    raise exception 'Table of Redemption must be a ready event table.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.table_sessions as session
    where session.event_table_id in (
      selected_champions_table_id,
      selected_redemption_table_id
    )
      and session.status in ('active', 'paused')
  ) then
    raise exception 'Selected Finals tables must not have active or paused sessions.'
      using errcode = 'P0001';
  end if;

  -- Prelock the complete Begin candidate set before any Finals session starts.
  perform 1
  from public.event_tables as event_table
  where event_table.id in (
    selected_champions_table_id,
    selected_redemption_table_id
  )
  order by event_table.id for update;
  perform 1
  from public.nfc_tags as tag
  where tag.id in (
    select event_table.nfc_tag_id
    from public.event_tables as event_table
    where event_table.id in (
      selected_champions_table_id,
      selected_redemption_table_id
    )
  )
  order by tag.id for update;
  begin
    perform 1
    from public.table_sessions as session
    where session.event_table_id in (
      selected_champions_table_id,
      selected_redemption_table_id
    )
      and session.status in ('active', 'paused')
    order by session.id for update nowait;
  exception
    when lock_not_available then
      raise exception
        'Selected Finals tables are currently being scored. Refresh and try again.'
        using errcode = 'P0001';
  end;

  if exists (
    select 1 from public.table_sessions as session
    where session.event_table_id in (
      selected_champions_table_id,
      selected_redemption_table_id
    )
      and session.status in ('active', 'paused')
  ) then
    raise exception 'Selected Finals tables must not have active or paused sessions.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.table_sessions as session
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End active or paused tournament sessions before beginning Finals.' using errcode = 'P0001';
  end if;

  perform app_private.refresh_event_score_totals(target_event_id);
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_guest_id', snapshot.event_guest_id,
        'display_name', snapshot.display_name,
        'total_points', snapshot.total_points,
        'hands_played', snapshot.hands_played,
        'standing_rank', snapshot.standing_rank,
        'seed_rank', snapshot.seed_rank
      ) order by snapshot.seed_rank
    ),
    '[]'::jsonb
  )
  into standings_snapshot_value
  from app_private.finals_standings_snapshot(target_event_id) as snapshot;
  if expected_preview_token is distinct from md5(standings_snapshot_value::text) then
    raise exception 'Finals changed since this screen was loaded. Refresh and try again.'
      using errcode = 'P0001';
  end if;
  eligible_count := jsonb_array_length(standings_snapshot_value);
  if eligible_count < 2 then
    raise exception 'At least 2 prize-eligible players are required for Finals.' using errcode = 'P0001';
  end if;

  finals_format := app_private.finals_format_for_count(eligible_count);
  case finals_format
    when 'champions_only' then null;
    when 'automatic_redemption' then null;
    when 'redemption_advancement' then null;
    when 'parallel_finals' then null;
    else raise exception 'Unsupported Finals format.' using errcode = 'P0001';
  end case;
  direct_slot_count := app_private.finals_direct_slot_count(eligible_count);
  champions_slot_count := least(4, eligible_count);
  if eligible_count >= 6 and selected_redemption_table_id is null then
    raise exception 'A second ready table is required for Table of Redemption.' using errcode = 'P0001';
  end if;
  if eligible_count <= 5 and selected_redemption_table_id is not null then
    raise exception 'Table of Redemption is not used for this Finals format.' using errcode = 'P0001';
  end if;

  select snapshot.total_points into cutoff_points
  from jsonb_to_recordset(standings_snapshot_value) as snapshot(
    event_guest_id uuid, display_name text, total_points integer,
    hands_played integer, standing_rank integer, seed_rank integer
  )
  where snapshot.seed_rank = direct_slot_count;
  select min(snapshot.seed_rank), max(snapshot.seed_rank), count(*)::integer
  into cutoff_min_seed, cutoff_max_seed, cutoff_tie_count
  from jsonb_to_recordset(standings_snapshot_value) as snapshot(
    event_guest_id uuid, display_name text, total_points integer,
    hands_played integer, standing_rank integer, seed_rank integer
  )
  where snapshot.total_points = cutoff_points;
  if not (cutoff_min_seed <= direct_slot_count and cutoff_max_seed > direct_slot_count) then
    cutoff_tie_count := 0;
  end if;
  if cutoff_tie_count > 4 then
    raise exception 'The Finals cutoff tie has more than four players and requires manual resolution.' using errcode = 'P0001';
  end if;
  if cutoff_tie_count > 0 then
    open_direct_slots := direct_slot_count - cutoff_min_seed + 1;
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id;

  update public.event_seating_assignments set status = 'cleared'
  where event_id = target_event_id
    and status = 'active'
    and not exists (
      select 1 from public.table_sessions as live_table_session
      where live_table_session.event_table_id = event_seating_assignments.event_table_id
        and live_table_session.status in ('active', 'paused')
    )
    and not exists (
      select 1
      from public.table_session_seats as live_seat
      join public.table_sessions as live_guest_session
        on live_guest_session.id = live_seat.table_session_id
      where live_guest_session.event_id = target_event_id
        and live_guest_session.status in ('active', 'paused')
        and live_seat.event_guest_id = event_seating_assignments.event_guest_id
    );

  insert into public.event_bonus_rounds (
    event_id, champions_table_id, redemption_table_id, assignment_round,
    status, flow_version, state_version, eligible_player_count, format,
    redemption_winner_event_guest_id, redemption_resolution_method
  ) values (
    target_event_id, selected_champions_table_id,
    case when eligible_count >= 6 then selected_redemption_table_id else null end,
    next_assignment_round, 'active', 'orchestrated', 0, eligible_count, finals_format,
    case when eligible_count = 5 and cutoff_tie_count = 0 then (
      select snapshot.event_guest_id
      from jsonb_to_recordset(standings_snapshot_value) as snapshot(
        event_guest_id uuid, display_name text, total_points integer,
        hands_played integer, standing_rank integer, seed_rank integer
      )
      where snapshot.seed_rank = 5
    ) end,
    case when eligible_count = 5 and cutoff_tie_count = 0 then 'standing_fifth' end
  ) returning * into bonus_round_row;
  -- The existing event_bonus_rounds_set_event_phase trigger is the supported
  -- event phase transition and atomically opens bonus scoring for this root.

  insert into public.event_finals_eligible_snapshot (
    bonus_round_id, event_id, event_guest_id, display_name, total_points,
    hands_played, standing_rank, seed_rank
  )
  select bonus_round_row.id, target_event_id, snapshot.event_guest_id,
    snapshot.display_name, snapshot.total_points, snapshot.hands_played,
    snapshot.standing_rank, snapshot.seed_rank
  from jsonb_to_recordset(standings_snapshot_value) as snapshot(
    event_guest_id uuid, display_name text, total_points integer,
    hands_played integer, standing_rank integer, seed_rank integer
  );

  insert into public.event_finals_champions_slots (
    bonus_round_id, slot_index, event_guest_id, qualification_method
  )
  select bonus_round_row.id, slot_index,
    case when cutoff_tie_count = 0 or slot_index < cutoff_min_seed then snapshot.event_guest_id end,
    case when cutoff_tie_count = 0 or slot_index < cutoff_min_seed then 'direct_seed' end
  from generate_series(1, champions_slot_count) as slot_index
  left join jsonb_to_recordset(standings_snapshot_value) as snapshot(
    event_guest_id uuid, display_name text, total_points integer,
    hands_played integer, standing_rank integer, seed_rank integer
  )
    on snapshot.seed_rank = slot_index
    and slot_index <= direct_slot_count;

  if cutoff_tie_count > 0 then
    sequence_value := sequence_value + 1;
    tiebreak_contest_id := gen_random_uuid();
    insert into public.event_finals_contests (
      id, bonus_round_id, event_id, contest_type, status, event_table_id,
      slots_to_fill, slot_start_index, sequence_number, created_by_user_id
    ) values (
      tiebreak_contest_id, bonus_round_row.id, target_event_id,
      'direct_qualification_tiebreak', 'ready',
      case when eligible_count >= 6 then selected_redemption_table_id else selected_champions_table_id end,
      open_direct_slots, cutoff_min_seed, sequence_value, auth.uid()
    );
    insert into public.event_finals_contest_participants (
      contest_id, event_guest_id, entry_seed, seat_index
    )
    select tiebreak_contest_id, snapshot.event_guest_id, snapshot.seed_rank,
      row_number() over (order by snapshot.seed_rank)::integer - 1
    from jsonb_to_recordset(standings_snapshot_value) as snapshot(
      event_guest_id uuid, display_name text, total_points integer,
      hands_played integer, standing_rank integer, seed_rank integer
    )
    where snapshot.total_points = cutoff_points;
  end if;

  if eligible_count >= 6 then
    sequence_value := sequence_value + 1;
    redemption_contest_id := gen_random_uuid();
    insert into public.event_finals_contests (
      id, bonus_round_id, event_id, contest_type, status, event_table_id,
      slots_to_fill, slot_start_index, sequence_number, created_by_user_id
    ) values (
      redemption_contest_id, bonus_round_row.id, target_event_id,
      'table_of_redemption', case when cutoff_tie_count > 0 then 'pending' else 'ready' end,
      selected_redemption_table_id,
      case when eligible_count = 6 then 2 when eligible_count = 7 then 1 else 0 end,
      case when eligible_count in (6, 7) then direct_slot_count + 1 end,
      sequence_value, auth.uid()
    );
    if cutoff_tie_count = 0 then
      insert into public.event_finals_contest_participants (contest_id, event_guest_id, entry_seed, seat_index)
      select redemption_contest_id, snapshot.event_guest_id, snapshot.seed_rank,
        row_number() over (order by snapshot.seed_rank)::integer - 1
      from jsonb_to_recordset(standings_snapshot_value) as snapshot(
        event_guest_id uuid, display_name text, total_points integer,
        hands_played integer, standing_rank integer, seed_rank integer
      )
      where (eligible_count in (6, 7) and snapshot.seed_rank > direct_slot_count)
         or (eligible_count >= 8 and snapshot.seed_rank > eligible_count - 4);
    end if;
  end if;

  sequence_value := sequence_value + 1;
  champions_contest_id := gen_random_uuid();
  insert into public.event_finals_contests (
    id, bonus_round_id, event_id, contest_type, status, event_table_id,
    slots_to_fill, slot_start_index, sequence_number, created_by_user_id
  ) values (
    champions_contest_id, bonus_round_row.id, target_event_id, 'table_of_champions',
    case when cutoff_tie_count > 0 or eligible_count in (6, 7) then 'pending' else 'ready' end,
    selected_champions_table_id, 0, null, sequence_value, auth.uid()
  );
  insert into public.event_finals_contest_participants (contest_id, event_guest_id, entry_seed, seat_index)
  select champions_contest_id, slot.event_guest_id, snapshot.seed_rank,
    case when champions_slot_count = 4 then 4 - slot.slot_index else slot.slot_index - 1 end
  from public.event_finals_champions_slots as slot
  join jsonb_to_recordset(standings_snapshot_value) as snapshot(
    event_guest_id uuid, display_name text, total_points integer,
    hands_played integer, standing_rank integer, seed_rank integer
  )
    on snapshot.event_guest_id = slot.event_guest_id
  where slot.bonus_round_id = bonus_round_row.id and slot.event_guest_id is not null;

  if tiebreak_contest_id is not null then
    insert into public.event_seating_assignments (
      event_id, event_table_id, event_guest_id, seat_index, assignment_round,
      assignment_type, bonus_round_id, bonus_table_role, seed_rank, status,
      assigned_at, assigned_by_user_id, finals_contest_id
    )
    select target_event_id,
      case when eligible_count >= 6 then selected_redemption_table_id else selected_champions_table_id end,
      participant.event_guest_id, participant.seat_index, next_assignment_round,
      'bonus', bonus_round_row.id, 'table_of_champions_play_in', participant.entry_seed,
      'active', transition_started_at, auth.uid(), tiebreak_contest_id
    from public.event_finals_contest_participants as participant
    where participant.contest_id = tiebreak_contest_id;
  end if;

  if redemption_contest_id is not null and cutoff_tie_count = 0 then
    insert into public.event_seating_assignments (
      event_id, event_table_id, event_guest_id, seat_index, assignment_round,
      assignment_type, bonus_round_id, bonus_table_role, seed_rank, status,
      assigned_at, assigned_by_user_id, finals_contest_id
    )
    select target_event_id, selected_redemption_table_id, participant.event_guest_id,
      participant.seat_index, next_assignment_round, 'bonus', bonus_round_row.id,
      'table_of_redemption', participant.entry_seed, 'active', transition_started_at,
      auth.uid(), redemption_contest_id
    from public.event_finals_contest_participants as participant
    where participant.contest_id = redemption_contest_id;
  end if;

  if cutoff_tie_count = 0 and eligible_count not in (6, 7) then
    insert into public.event_seating_assignments (
      event_id, event_table_id, event_guest_id, seat_index, assignment_round,
      assignment_type, bonus_round_id, bonus_table_role, seed_rank, status,
      assigned_at, assigned_by_user_id, finals_contest_id
    )
    select target_event_id, selected_champions_table_id, participant.event_guest_id,
      participant.seat_index, next_assignment_round, 'bonus', bonus_round_row.id,
      'table_of_champions', participant.entry_seed, 'active', transition_started_at,
      auth.uid(), champions_contest_id
    from public.event_finals_contest_participants as participant
    where participant.contest_id = champions_contest_id;
  end if;

  if tiebreak_contest_id is not null then
    started_session := app_private.start_assigned_finals_session(
      target_event_id, bonus_round_row.id, 'table_of_champions_play_in',
      tiebreak_contest_id, transition_started_at
    );
    started_sessions := started_sessions || jsonb_build_array(started_session.id);
  elsif eligible_count in (6, 7) then
    started_session := app_private.start_assigned_finals_session(
      target_event_id, bonus_round_row.id, 'table_of_redemption',
      redemption_contest_id, transition_started_at
    );
    started_sessions := started_sessions || jsonb_build_array(started_session.id);
  else
    started_session := app_private.start_assigned_finals_session(
      target_event_id, bonus_round_row.id, 'table_of_champions',
      champions_contest_id, transition_started_at
    );
    started_sessions := started_sessions || jsonb_build_array(started_session.id);
    if eligible_count >= 8 then
      started_session := app_private.start_assigned_finals_session(
        target_event_id, bonus_round_row.id, 'table_of_redemption',
        redemption_contest_id, transition_started_at
      );
      started_sessions := started_sessions || jsonb_build_array(started_session.id);
    end if;
  end if;

  update public.event_bonus_rounds
  set state_version = state_version + 1, updated_at = now()
  where id = bonus_round_row.id;

  perform app_private.insert_audit_log(
    target_event_id, 'event_bonus_round', bonus_round_row.id::text,
    'begin_event_finals', null,
    public.get_event_finals_state(target_event_id),
    jsonb_build_object(
      'actor_user_id', auth.uid(), 'prior_state', 'not_started',
      'new_state', 'active', 'champions_table_id', selected_champions_table_id,
      'redemption_table_id', selected_redemption_table_id,
      'champions_table_label', (
        select label from public.event_tables where id = selected_champions_table_id
      ),
      'redemption_table_label', (
        select label from public.event_tables where id = selected_redemption_table_id
      ),
      'contests', (select jsonb_agg(to_jsonb(contest) order by contest.sequence_number)
        from public.event_finals_contests as contest where contest.bonus_round_id = bonus_round_row.id),
      'participants', (select jsonb_agg(to_jsonb(participant))
        from public.event_finals_contest_participants as participant
        join public.event_finals_contests as contest on contest.id = participant.contest_id
        where contest.bonus_round_id = bonus_round_row.id),
      'started_session_ids', started_sessions
    )
  );

  return public.get_event_finals_state(target_event_id);
end;
$$;

create or replace function public.begin_event_finals(
  target_event_id uuid,
  selected_champions_table_id uuid,
  selected_redemption_table_id uuid,
  expected_state_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  existing_root public.event_bonus_rounds%rowtype;
begin
  if not app_private.can_manage_event(target_event_id) then
    raise exception 'Event not found for current Finals operator.' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(target_event_id::text, 0));
  select * into event_row
  from public.events as event
  where event.id = target_event_id
  for update;
  if not found or event_row.lifecycle_status <> 'active' or not event_row.scoring_open then
    raise exception 'Event must be active and open for scoring before Finals begin.' using errcode = 'P0001';
  end if;
  select * into existing_root
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and flow_version = 'orchestrated'
    and bonus_round.status in ('active', 'completed')
  order by bonus_round.assignment_round desc
  limit 1
  for update;
  if found then
    if existing_root.champions_table_id = selected_champions_table_id
      and existing_root.redemption_table_id is not distinct from selected_redemption_table_id
    then
      return public.get_event_finals_state(target_event_id);
    end if;
    raise exception 'Finals already began with different table selections. Refresh and try again.'
      using errcode = 'P0001';
  end if;
  select * into existing_root
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.flow_version = 'legacy'
    and bonus_round.status in ('active', 'completed')
  order by bonus_round.assignment_round desc
  limit 1
  for update;
  if found then
    if existing_root.status = 'active' then
      raise exception 'Active Finals already exist for this event. Use the Finals recovery action.'
        using errcode = 'P0001';
    end if;
    raise exception 'Completed legacy Finals already exist for this event.'
      using errcode = 'P0001';
  end if;
  perform app_private.refresh_event_score_totals(target_event_id);
  return public.begin_event_finals(
    target_event_id,
    selected_champions_table_id,
    selected_redemption_table_id,
    expected_state_version,
    app_private.finals_preview_token(target_event_id)
  );
end;
$$;

revoke all on function app_private.start_assigned_finals_session(uuid, uuid, text, uuid, timestamptz) from public;
revoke all on function public.begin_event_finals(uuid, uuid, uuid, bigint, text) from public;
revoke all on function public.begin_event_finals(uuid, uuid, uuid, bigint) from public;
grant execute on function public.begin_event_finals(uuid, uuid, uuid, bigint, text) to authenticated;
grant execute on function public.begin_event_finals(uuid, uuid, uuid, bigint) to authenticated;

select pg_notify('pgrst', 'reload schema');
