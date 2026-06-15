-- Resolve ties that cross the Table of Champions cutoff through a play-in.

alter table public.event_bonus_rounds
add column if not exists play_in_status text not null default 'not_required',
add column if not exists play_in_table_id uuid,
add column if not exists play_in_session_id uuid,
add column if not exists play_in_winner_event_guest_id uuid,
add column if not exists play_in_winner_seed_rank integer;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_play_in_status_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_play_in_status_check
check (play_in_status in ('not_required', 'required', 'active', 'completed'));

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_play_in_winner_seed_rank_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_play_in_winner_seed_rank_check
check (play_in_winner_seed_rank is null or play_in_winner_seed_rank > 0);

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_play_in_table_same_event_fk;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_play_in_table_same_event_fk
foreign key (play_in_table_id, event_id)
references public.event_tables(id, event_id)
on delete restrict;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_play_in_session_fk;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_play_in_session_fk
foreign key (play_in_session_id)
references public.table_sessions(id)
on delete set null;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_play_in_winner_same_event_fk;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_play_in_winner_same_event_fk
foreign key (play_in_winner_event_guest_id, event_id)
references public.event_guests(id, event_id)
on delete restrict;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_bonus_table_role_check;
alter table public.event_seating_assignments
add constraint event_seating_assignments_bonus_table_role_check
check (
  bonus_table_role is null
  or bonus_table_role in (
    'table_of_champions',
    'table_of_redemption',
    'table_of_champions_sudden_death',
    'table_of_champions_play_in'
  )
);

alter table public.table_sessions
drop constraint if exists table_sessions_bonus_table_role_check;
alter table public.table_sessions
add constraint table_sessions_bonus_table_role_check
check (
  bonus_table_role is null
  or bonus_table_role in (
    'table_of_champions',
    'table_of_redemption',
    'table_of_champions_sudden_death',
    'table_of_champions_play_in'
  )
);

create or replace function app_private.table_of_champions_play_in_candidates(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  total_points integer,
  seed_rank integer
)
language sql
security definer
set search_path = public
as $$
  with scored_hands as (
    select leaderboard.hands_played
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played > 0
  ),
  minimum as (
    select greatest(
      1,
      ceil((
        coalesce(
          percentile_cont(0.5) within group (order by hands_played),
          0
        )
      ) * 0.5)::integer
    ) as minimum_hands_played
    from scored_hands
  ),
  ranked_players as (
    select
      leaderboard.event_guest_id,
      leaderboard.display_name,
      leaderboard.total_points,
      (row_number() over (
        order by leaderboard.rank asc, leaderboard.total_points desc,
          leaderboard.display_name asc, leaderboard.event_guest_id asc
      ))::integer as seed_rank
    from public.get_event_leaderboard(target_event_id) as leaderboard
    cross join minimum
    join public.event_guests as guest
      on guest.id = leaderboard.event_guest_id
      and guest.event_id = target_event_id
      and guest.attendance_status = 'checked_in'
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played >= minimum.minimum_hands_played
  ),
  cutoff as (
    select ranked_players.total_points
    from ranked_players
    where ranked_players.seed_rank = 4
  ),
  cutoff_players as (
    select ranked_players.*
    from ranked_players
    join cutoff
      on cutoff.total_points = ranked_players.total_points
    where ranked_players.seed_rank >= 4
    order by ranked_players.seed_rank asc
  ),
  cutoff_count as (
    select count(*)::integer as cutoff_player_count
    from cutoff_players
  ),
  lower_seed_candidates as (
    select
      ranked_players.event_guest_id,
      ranked_players.display_name,
      ranked_players.total_points,
      ranked_players.seed_rank,
      row_number() over (order by ranked_players.seed_rank asc)::integer
      as lower_seed_offset
    from ranked_players
    cross join cutoff_count
    where ranked_players.seed_rank > (
        select coalesce(max(cutoff_players.seed_rank), 4)
        from cutoff_players
      )
  ),
  lower_seed_players as (
    select
      lower_seed_candidates.event_guest_id,
      lower_seed_candidates.display_name,
      lower_seed_candidates.total_points,
      lower_seed_candidates.seed_rank
    from lower_seed_candidates
    cross join cutoff_count
    where lower_seed_candidates.lower_seed_offset
      <= greatest(0, 4 - cutoff_count.cutoff_player_count)
  )
  select
    selected.event_guest_id,
    selected.display_name,
    selected.total_points,
    selected.seed_rank
  from (
    select * from cutoff_players
    union all
    select * from lower_seed_players
  ) as selected
  order by selected.seed_rank asc;
$$;

create or replace function public.get_bonus_round_state(
  target_event_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  champions_session_id uuid;
  tied_top_players jsonb := '[]'::jsonb;
  play_in_players jsonb := '[]'::jsonb;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  select *
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.status in ('active', 'completed')
  order by
    case when bonus_round.status = 'active' then 0 else 1 end,
    bonus_round.created_at desc
  limit 1;

  if bonus_round_row.id is null then
    return jsonb_build_object(
      'bonus_round_id', null,
      'event_id', target_event_id,
      'status', null,
      'champions_table_id', null,
      'redemption_table_id', null,
      'champion_resolution_method', 'standard',
      'sudden_death_status', 'not_required',
      'sudden_death_table_id', null,
      'sudden_death_session_id', null,
      'play_in_status', 'not_required',
      'play_in_table_id', null,
      'play_in_session_id', null,
      'play_in_winner_event_guest_id', null,
      'play_in_winner_seed_rank', null,
      'champion_event_guest_id', null,
      'champion_bonus_score_points', null,
      'champion_top_up_points', null,
      'champion_award_points', null,
      'tied_top_players', jsonb_build_array(),
      'play_in_players', jsonb_build_array()
    );
  end if;

  select session.id
  into champions_session_id
  from public.table_sessions as session
  where session.bonus_round_id = bonus_round_row.id
    and session.bonus_table_role = 'table_of_champions'
  order by coalesce(session.ended_at, session.started_at, session.created_at) desc
  limit 1;

  if bonus_round_row.sudden_death_status in ('required', 'active')
    and champions_session_id is not null then
    with scores as (
      select *
      from app_private.table_of_champions_scores(
        bonus_round_row.id,
        champions_session_id
      )
    ),
    max_score as (
      select max(scores.bonus_score_points) as value
      from scores
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_guest_id', scores.event_guest_id,
          'display_name', scores.display_name,
          'bonus_score_points', scores.bonus_score_points,
          'seed_rank', scores.seed_rank
        )
        order by scores.seed_rank asc nulls last, scores.display_name asc
      ),
      '[]'::jsonb
    )
    into tied_top_players
    from scores
    cross join max_score
    where scores.bonus_score_points = max_score.value;
  end if;

  if bonus_round_row.play_in_status in ('active', 'completed') then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_guest_id', assignment.event_guest_id,
          'display_name', guest.display_name,
          'seed_rank', assignment.seed_rank,
          'seat_index', assignment.seat_index
        )
        order by assignment.seed_rank asc, assignment.seat_index asc
      ),
      '[]'::jsonb
    )
    into play_in_players
    from public.event_seating_assignments as assignment
    join public.event_guests as guest
      on guest.id = assignment.event_guest_id
    where assignment.bonus_round_id = bonus_round_row.id
      and assignment.bonus_table_role = 'table_of_champions_play_in'
      and assignment.status = 'active';
  elsif bonus_round_row.play_in_status = 'required' then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_guest_id', candidates.event_guest_id,
          'display_name', candidates.display_name,
          'seed_rank', candidates.seed_rank,
          'seat_index', null
        )
        order by candidates.seed_rank asc
      ),
      '[]'::jsonb
    )
    into play_in_players
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as candidates;
  end if;

  return jsonb_build_object(
    'bonus_round_id', bonus_round_row.id,
    'event_id', bonus_round_row.event_id,
    'status', bonus_round_row.status,
    'champions_table_id', bonus_round_row.champions_table_id,
    'redemption_table_id', bonus_round_row.redemption_table_id,
    'champion_resolution_method', bonus_round_row.champion_resolution_method,
    'sudden_death_status', bonus_round_row.sudden_death_status,
    'sudden_death_table_id', bonus_round_row.sudden_death_table_id,
    'sudden_death_session_id', bonus_round_row.sudden_death_session_id,
    'play_in_status', bonus_round_row.play_in_status,
    'play_in_table_id', bonus_round_row.play_in_table_id,
    'play_in_session_id', bonus_round_row.play_in_session_id,
    'play_in_winner_event_guest_id', bonus_round_row.play_in_winner_event_guest_id,
    'play_in_winner_seed_rank', bonus_round_row.play_in_winner_seed_rank,
    'champion_event_guest_id', bonus_round_row.champion_event_guest_id,
    'champion_bonus_score_points', bonus_round_row.champion_bonus_score_points,
    'champion_top_up_points', bonus_round_row.champion_top_up_points,
    'champion_award_points', bonus_round_row.champion_award_points,
    'tied_top_players', tied_top_players,
    'play_in_players', play_in_players
  );
end;
$$;

create or replace function public.generate_bonus_round_seating_assignments(
  target_event_id uuid,
  champions_table_id uuid,
  redemption_table_id uuid default null
)
returns table (
  id uuid,
  event_id uuid,
  event_table_id uuid,
  table_label text,
  table_display_order integer,
  event_guest_id uuid,
  guest_display_name text,
  seat_index integer,
  assignment_round integer,
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  ranked_player_count integer;
  next_assignment_round integer;
  bonus_round_row public.event_bonus_rounds%rowtype;
  cutoff_tie_crosses_champions boolean := false;
  selected_champions_table_id uuid := champions_table_id;
  selected_redemption_table_id uuid := redemption_table_id;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if selected_champions_table_id = selected_redemption_table_id then
    raise exception 'Finals tables must be different.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_tournament_rounds as current_round
    join public.table_sessions as session
      on session.event_id = current_round.event_id
      and session.tournament_round_id = current_round.id
      and session.scoring_phase = 'tournament'
      and session.status in ('active', 'paused')
    where current_round.event_id = target_event_id
      and current_round.scoring_phase = 'tournament'
      and current_round.status in ('seating', 'active')
  ) then
    raise exception 'End active or paused current tournament round sessions before beginning finals.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = selected_champions_table_id
      and event_table.event_id = target_event_id
  ) then
    raise exception 'Table of Champions must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  if selected_redemption_table_id is not null
    and not exists (
      select 1
      from public.event_tables as event_table
      join public.nfc_tags as tag
        on tag.id = event_table.nfc_tag_id
        and tag.default_tag_type = 'table'
        and tag.status = 'active'
      where event_table.id = selected_redemption_table_id
        and event_table.event_id = target_event_id
    )
  then
    raise exception 'Table of Redemption must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  perform app_private.refresh_event_score_totals(target_event_id);

  with scored_hands as (
    select leaderboard.hands_played
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played > 0
  ),
  minimum as (
    select greatest(
      1,
      ceil((
        coalesce(
          percentile_cont(0.5) within group (order by hands_played),
          0
        )
      ) * 0.5)::integer
    ) as minimum_hands_played
    from scored_hands
  ),
  ranked_players as (
    select
      leaderboard.event_guest_id,
      leaderboard.total_points,
      (row_number() over (
        order by leaderboard.rank asc, leaderboard.total_points desc,
          leaderboard.display_name asc, leaderboard.event_guest_id asc
      ))::integer as seed_rank
    from public.get_event_leaderboard(target_event_id) as leaderboard
    cross join minimum
    join public.event_guests as guest
      on guest.id = leaderboard.event_guest_id
      and guest.event_id = target_event_id
      and guest.attendance_status = 'checked_in'
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played >= minimum.minimum_hands_played
  ),
  cutoff_groups as (
    select
      ranked_players.total_points,
      bool_or(ranked_players.seed_rank <= 4) as has_champions_seed,
      bool_or(ranked_players.seed_rank >= 5) as has_lower_seed
    from ranked_players
    group by ranked_players.total_points
  ),
  ranked_summary as (
    select count(*)::integer as player_count
    from ranked_players
  ),
  cutoff_summary as (
    select coalesce(
      bool_or(
        cutoff_groups.has_champions_seed
        and cutoff_groups.has_lower_seed
      ),
      false
    ) as crosses_cutoff
    from cutoff_groups
  )
  select
    ranked_summary.player_count,
    cutoff_summary.crosses_cutoff
  into ranked_player_count, cutoff_tie_crosses_champions
  from ranked_summary
  cross join cutoff_summary;

  if ranked_player_count = 0 then
    raise exception 'No prize-eligible players are available for finals.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count = 1 then
    raise exception 'At least 2 prize-eligible players are required for finals.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count >= 6 and selected_redemption_table_id is null then
    raise exception 'A second ready table is required for Table of Redemption.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count between 2 and 5 then
    selected_redemption_table_id := null;
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id;

  select *
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.status = 'active'
  order by bonus_round.created_at desc
  limit 1
  for update;

  if bonus_round_row.id is not null
    and (
      not cutoff_tie_crosses_champions
      or bonus_round_row.play_in_status <> 'required'
    ) then
    raise exception 'Active finals already exist for this event.'
      using errcode = 'P0001';
  end if;

  if cutoff_tie_crosses_champions then
    if bonus_round_row.id is null then
      insert into public.event_bonus_rounds (
        event_id,
        champions_table_id,
        redemption_table_id,
        assignment_round,
        status,
        play_in_status
      )
      values (
        target_event_id,
        selected_champions_table_id,
        selected_redemption_table_id,
        next_assignment_round,
        'active',
        'required'
      )
      returning *
      into bonus_round_row;
    else
      update public.event_bonus_rounds
      set
        champions_table_id = selected_champions_table_id,
        redemption_table_id = selected_redemption_table_id,
        play_in_status = 'required',
        play_in_table_id = null,
        play_in_session_id = null,
        play_in_winner_event_guest_id = null,
        play_in_winner_seed_rank = null,
        champion_event_guest_id = null,
        champion_bonus_score_points = null,
        champion_top_up_points = null,
        champion_award_points = null,
        completed_at = null
      where event_bonus_rounds.id = bonus_round_row.id
      returning *
      into bonus_round_row;
    end if;

    update public.event_seating_assignments as assignment
    set status = 'cleared'
    where assignment.event_id = target_event_id
      and assignment.status = 'active';

    -- Play-in required: do not create Table of Champions or Redemption assignments yet.
    return query
    select *
    from public.get_event_seating_assignments(target_event_id) as assignment
    where assignment.bonus_table_role is distinct from 'table_of_champions'
      and assignment.bonus_table_role is distinct from 'table_of_redemption';
    return;
  end if;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = target_event_id
    and assignment.status = 'active';

  insert into public.event_bonus_rounds (
    event_id,
    champions_table_id,
    redemption_table_id,
    assignment_round,
    status,
    play_in_status
  )
  values (
    target_event_id,
    selected_champions_table_id,
    selected_redemption_table_id,
    next_assignment_round,
    'active',
    'not_required'
  )
  returning *
  into bonus_round_row;

  with scored_hands as (
    select leaderboard.hands_played
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played > 0
  ),
  minimum as (
    select greatest(
      1,
      ceil((
        coalesce(
          percentile_cont(0.5) within group (order by hands_played),
          0
        )
      ) * 0.5)::integer
    ) as minimum_hands_played
    from scored_hands
  ),
  ranked_players as (
    select
      leaderboard.event_guest_id,
      (row_number() over (
        order by leaderboard.rank asc, leaderboard.total_points desc,
          leaderboard.display_name asc, leaderboard.event_guest_id asc
      ))::integer as seed_rank,
      count(*) over ()::integer as player_count
    from public.get_event_leaderboard(target_event_id) as leaderboard
    cross join minimum
    join public.event_guests as guest
      on guest.id = leaderboard.event_guest_id
      and guest.event_id = target_event_id
      and guest.attendance_status = 'checked_in'
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played >= minimum.minimum_hands_played
  ),
  champions as (
    select
      ranked_players.event_guest_id,
      ranked_players.seed_rank,
      case
        when ranked_player_count >= 4 then
          case
            when ranked_players.seed_rank = 4 then 0
            when ranked_players.seed_rank = 3 then 1
            when ranked_players.seed_rank = 2 then 2
            when ranked_players.seed_rank = 1 then 3
          end
        else ranked_players.seed_rank - 1
      end as seat_index
    from ranked_players
    where ranked_players.seed_rank between 1 and least(4, ranked_player_count)
  ),
  redemption as (
    select
      ranked_players.event_guest_id,
      ranked_players.seed_rank,
      (ranked_players.seed_rank - (ranked_players.player_count - 4) - 1)::integer
        as seat_index
    from ranked_players
      where selected_redemption_table_id is not null
      and ranked_players.seed_rank > ranked_players.player_count - 4
    order by ranked_players.seed_rank asc
  ),
  selected_bonus_players as (
    select
      selected_champions_table_id as event_table_id,
      champions.event_guest_id,
      champions.seat_index,
      'table_of_champions'::text as bonus_table_role,
      champions.seed_rank
    from champions
    union all
    select
      selected_redemption_table_id as event_table_id,
      redemption.event_guest_id,
      redemption.seat_index,
      'table_of_redemption'::text as bonus_table_role,
      redemption.seed_rank
    from redemption
  )
  insert into public.event_seating_assignments (
    event_id,
    event_table_id,
    event_guest_id,
    seat_index,
    assignment_round,
    assignment_type,
    bonus_round_id,
    bonus_table_role,
    seed_rank,
    status,
    assigned_at,
    assigned_by_user_id
  )
  select
    target_event_id,
    selected_bonus_players.event_table_id,
    selected_bonus_players.event_guest_id,
    selected_bonus_players.seat_index,
    next_assignment_round,
    'bonus',
    bonus_round_row.id,
    selected_bonus_players.bonus_table_role,
    selected_bonus_players.seed_rank,
    'active',
    now(),
    auth.uid()
  from selected_bonus_players
  where selected_bonus_players.bonus_table_role <> 'table_of_champions_play_in';

  return query
  select *
  from public.get_event_seating_assignments(target_event_id);
end;
$$;

create or replace function public.start_table_of_champions_play_in(
  target_event_id uuid,
  play_in_table_id uuid
)
returns table (
  id uuid,
  event_id uuid,
  event_table_id uuid,
  table_label text,
  table_display_order integer,
  event_guest_id uuid,
  guest_display_name text,
  seat_index integer,
  assignment_round integer,
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  next_assignment_round integer;
  play_in_player_count integer;
  cutoff_player_count integer;
  selected_play_in_table_id uuid := play_in_table_id;
begin
  select *
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.status = 'active'
    and bonus_round.play_in_status = 'required'
  order by bonus_round.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Table of Champions play-in is not required for this event.'
      using errcode = 'P0001';
  end if;

  if not app_private.is_event_owner(bonus_round_row.event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = selected_play_in_table_id
      and event_table.event_id = bonus_round_row.event_id
  ) then
    raise exception 'Play-in table must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as session
    where session.event_table_id = selected_play_in_table_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End the active or paused session at this table before starting the play-in.'
      using errcode = 'P0001';
  end if;

  select count(*)::integer
  into play_in_player_count
  from app_private.table_of_champions_play_in_candidates(
    bonus_round_row.event_id
  );

  select count(*)::integer
  into cutoff_player_count
  from app_private.table_of_champions_play_in_candidates(
    bonus_round_row.event_id
  ) as candidates
  where candidates.total_points = (
    select cutoff.total_points
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as cutoff
    where cutoff.seed_rank = 4
  );

  if play_in_player_count not between 2 and 4 then
    raise exception 'Play-in requires 2 to 4 players.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = bonus_round_row.event_id;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = bonus_round_row.event_id
    and assignment.status = 'active';

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_play_in'
    and assignment.status = 'active';

  with cutoff_players as (
    select *
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    )
    where seed_rank <= (
      select coalesce(max(candidates.seed_rank), 4)
      from app_private.table_of_champions_play_in_candidates(
        bonus_round_row.event_id
      ) as candidates
      where candidates.total_points = (
        select cutoff.total_points
        from app_private.table_of_champions_play_in_candidates(
          bonus_round_row.event_id
        ) as cutoff
        where cutoff.seed_rank = 4
      )
    )
  ),
  lower_seed_players as (
    select *
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    )
    where seed_rank > (
      select coalesce(max(cutoff_players.seed_rank), 4)
      from cutoff_players
    )
    order by seed_rank asc
    limit greatest(0, 4 - cutoff_player_count)
  ),
  selected_play_in_players as (
    select
      candidates.event_guest_id,
      candidates.seed_rank,
      row_number() over (order by random(), candidates.event_guest_id)::integer - 1
        as seat_index
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as candidates
    order by candidates.seed_rank asc
  )
  insert into public.event_seating_assignments (
    event_id,
    event_table_id,
    event_guest_id,
    seat_index,
    assignment_round,
    assignment_type,
    bonus_round_id,
    bonus_table_role,
    seed_rank,
    status,
    assigned_at,
    assigned_by_user_id
  )
  select
    bonus_round_row.event_id,
    selected_play_in_table_id,
    selected_play_in_players.event_guest_id,
    selected_play_in_players.seat_index,
    next_assignment_round,
    'bonus',
    bonus_round_row.id,
    'table_of_champions_play_in',
    selected_play_in_players.seed_rank,
    'active',
    now(),
    auth.uid()
  from selected_play_in_players;

  update public.event_bonus_rounds
  set
    play_in_status = 'active',
    play_in_table_id = selected_play_in_table_id,
    play_in_session_id = null,
    play_in_winner_event_guest_id = null,
    play_in_winner_seed_rank = null
  where event_bonus_rounds.id = bonus_round_row.id;

  return query
  select *
  from public.get_event_seating_assignments(
    bonus_round_row.event_id
  ) as assignment
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_play_in';
end;
$$;

create or replace function app_private.apply_bonus_round_champion_award(
  target_table_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  champion_event_guest_id_value uuid;
  champion_bonus_score_points_value integer := 0;
  champion_base_total_value integer;
  top_non_champion_total_value integer;
  champion_top_up_points_value integer;
  champion_award_points_value integer;
  top_score integer;
  tied_top_count integer;
  sudden_death_winner uuid;
  play_in_winner_event_guest_id_value uuid;
  play_in_winner_seed_rank_value integer;
  next_assignment_round integer;
begin
  select *
  into session_row
  from public.table_sessions
  where id = target_table_session_id
  for update;

  if not found
    or session_row.bonus_round_id is null
    or session_row.bonus_table_role not in (
      'table_of_champions',
      'table_of_champions_sudden_death',
      'table_of_champions_play_in'
    ) then
    return;
  end if;

  if session_row.bonus_table_role = 'table_of_champions_play_in' then
    select
      seat.event_guest_id,
      assignment.seed_rank
    into
      play_in_winner_event_guest_id_value,
      play_in_winner_seed_rank_value
    from public.hand_results as hand_result
    join public.table_session_seats as seat
      on seat.table_session_id = hand_result.table_session_id
      and seat.seat_index = hand_result.winner_seat_index
    left join public.event_seating_assignments as assignment
      on assignment.bonus_round_id = session_row.bonus_round_id
      and assignment.bonus_table_role = 'table_of_champions_play_in'
      and assignment.event_guest_id = seat.event_guest_id
    where hand_result.table_session_id = session_row.id
      and hand_result.status = 'recorded'
      and hand_result.result_type = 'win'
    order by hand_result.hand_number desc, hand_result.created_at desc
    limit 1;

    if play_in_winner_event_guest_id_value is null then
      update public.event_bonus_rounds
      set
        play_in_status = 'active',
        play_in_table_id = session_row.event_table_id,
        play_in_session_id = session_row.id,
        play_in_winner_event_guest_id = null,
        play_in_winner_seed_rank = null
      where id = session_row.bonus_round_id;

      perform app_private.refresh_event_score_totals(session_row.event_id);
      return;
    end if;

    select coalesce(max(assignment.assignment_round), 0) + 1
    into next_assignment_round
    from public.event_seating_assignments as assignment
    where assignment.event_id = session_row.event_id;

    update public.event_seating_assignments as assignment
    set status = 'cleared'
    where assignment.bonus_round_id = session_row.bonus_round_id
      and assignment.bonus_table_role in (
        'table_of_champions',
        'table_of_redemption',
        'table_of_champions_play_in'
      )
      and assignment.status = 'active';

    update public.event_bonus_rounds
    set
      play_in_status = 'completed',
      play_in_table_id = session_row.event_table_id,
      play_in_session_id = session_row.id,
      play_in_winner_event_guest_id = play_in_winner_event_guest_id_value,
      play_in_winner_seed_rank = play_in_winner_seed_rank_value,
      champion_event_guest_id = null,
      champion_bonus_score_points = null,
      champion_top_up_points = null,
      champion_award_points = null,
      completed_at = null
    where id = session_row.bonus_round_id;

    with scored_hands as (
      select leaderboard.hands_played
      from public.get_event_leaderboard(session_row.event_id) as leaderboard
      where leaderboard.tournament_status = 'qualified'
        and leaderboard.hands_played > 0
    ),
    minimum as (
      select greatest(
        1,
        ceil((
          coalesce(
            percentile_cont(0.5) within group (order by hands_played),
            0
          )
        ) * 0.5)::integer
      ) as minimum_hands_played
      from scored_hands
    ),
    ranked_players as (
      select
        leaderboard.event_guest_id,
        leaderboard.total_points,
        (row_number() over (
          order by leaderboard.rank asc, leaderboard.total_points desc,
            leaderboard.display_name asc, leaderboard.event_guest_id asc
        ))::integer as seed_rank,
        count(*) over ()::integer as player_count
      from public.get_event_leaderboard(session_row.event_id) as leaderboard
      cross join minimum
      join public.event_guests as guest
        on guest.id = leaderboard.event_guest_id
        and guest.event_id = session_row.event_id
        and guest.attendance_status = 'checked_in'
      where leaderboard.tournament_status = 'qualified'
        and leaderboard.hands_played >= minimum.minimum_hands_played
    ),
    safe_champions as (
      select
        ranked_players.event_guest_id,
        ranked_players.seed_rank
      from ranked_players
      where ranked_players.seed_rank < 4
    ),
    play_in_winner as (
      select
        play_in_winner_event_guest_id_value as event_guest_id,
        play_in_winner_seed_rank_value as seed_rank
    ),
    final_champions as (
      select
        safe_champions.event_guest_id,
        safe_champions.seed_rank,
        row_number() over (order by safe_champions.seed_rank asc)::integer
          as final_seed_rank
      from safe_champions
      union all
      select
        play_in_winner.event_guest_id,
        play_in_winner.seed_rank,
        4::integer as final_seed_rank
      from play_in_winner
    ),
    redemption as (
      select
        ranked_players.event_guest_id,
        ranked_players.seed_rank,
        (ranked_players.seed_rank - (ranked_players.player_count - 4) - 1)::integer
          as seat_index
      from ranked_players
      where (
          select redemption_table_id
          from public.event_bonus_rounds
          where id = session_row.bonus_round_id
        ) is not null
        and ranked_players.seed_rank > ranked_players.player_count - 4
        and ranked_players.event_guest_id not in (
          select final_champions.event_guest_id
          from final_champions
        )
      order by ranked_players.seed_rank asc
    ),
    selected_bonus_players as (
      select
        (
          select champions_table_id
          from public.event_bonus_rounds
          where id = session_row.bonus_round_id
        ) as event_table_id,
        final_champions.event_guest_id,
        case final_champions.final_seed_rank
          when 4 then 0
          when 3 then 1
          when 2 then 2
          when 1 then 3
          else final_champions.final_seed_rank - 1
        end as seat_index,
        'table_of_champions'::text as bonus_table_role,
        final_champions.seed_rank
      from final_champions
      union all
      select
        (
          select redemption_table_id
          from public.event_bonus_rounds
          where id = session_row.bonus_round_id
        ) as event_table_id,
        redemption.event_guest_id,
        redemption.seat_index,
        'table_of_redemption'::text as bonus_table_role,
        redemption.seed_rank
      from redemption
    )
    insert into public.event_seating_assignments (
      event_id,
      event_table_id,
      event_guest_id,
      seat_index,
      assignment_round,
      assignment_type,
      bonus_round_id,
      bonus_table_role,
      seed_rank,
      status,
      assigned_at,
      assigned_by_user_id
    )
    select
      session_row.event_id,
      selected_bonus_players.event_table_id,
      selected_bonus_players.event_guest_id,
      selected_bonus_players.seat_index,
      next_assignment_round,
      'bonus',
      session_row.bonus_round_id,
      selected_bonus_players.bonus_table_role,
      selected_bonus_players.seed_rank,
      'active',
      now(),
      auth.uid()
    from selected_bonus_players
    where selected_bonus_players.event_table_id is not null;

    perform app_private.refresh_event_score_totals(session_row.event_id);
    return;
  end if;

  delete from public.event_score_adjustments as adjustment
  using public.table_sessions as source_session
  where adjustment.adjustment_type = 'finals_champion_award'
    and adjustment.source_table_session_id = source_session.id
    and source_session.bonus_round_id = session_row.bonus_round_id
    and source_session.bonus_table_role in (
      'table_of_champions',
      'table_of_champions_sudden_death'
    );

  if session_row.bonus_table_role = 'table_of_champions' then
    if session_row.status <> 'completed' then
      update public.event_bonus_rounds
      set
        status = 'active',
        champion_resolution_method = 'standard',
        sudden_death_status = 'not_required',
        sudden_death_table_id = null,
        sudden_death_session_id = null,
        champion_event_guest_id = null,
        champion_bonus_score_points = null,
        champion_top_up_points = null,
        champion_award_points = null,
        completed_at = null
      where id = session_row.bonus_round_id;

      perform app_private.refresh_event_score_totals(session_row.event_id);
      return;
    end if;

    perform app_private.refresh_event_score_totals(session_row.event_id);

    with scores as (
      select *
      from app_private.table_of_champions_scores(
        session_row.bonus_round_id,
        session_row.id
      )
    ),
    max_score as (
      select max(scores.bonus_score_points) as value
      from scores
    ),
    tied_top_players as (
      select scores.*
      from scores
      cross join max_score
      where scores.bonus_score_points = max_score.value
    )
    select
      max_score.value,
      count(tied_top_players.event_guest_id)::integer
    into top_score, tied_top_count
    from max_score
    left join tied_top_players on true
    group by max_score.value;

    if tied_top_count > 1 then
      update public.event_bonus_rounds
      set
        status = 'active',
        champion_resolution_method = 'sudden_death',
        sudden_death_status = 'required',
        sudden_death_table_id = null,
        sudden_death_session_id = null,
        champion_event_guest_id = null,
        champion_bonus_score_points = null,
        champion_top_up_points = null,
        champion_award_points = null,
        completed_at = null
      where id = session_row.bonus_round_id;

      perform app_private.refresh_event_score_totals(session_row.event_id);
      return;
    end if;

    select scores.event_guest_id, scores.bonus_score_points
    into champion_event_guest_id_value, champion_bonus_score_points_value
    from app_private.table_of_champions_scores(
      session_row.bonus_round_id,
      session_row.id
    ) as scores
    order by scores.bonus_score_points desc, scores.event_guest_id asc
    limit 1;
  end if;

  if session_row.bonus_table_role = 'table_of_champions_sudden_death' then
    select seat.event_guest_id
    into sudden_death_winner
    from public.hand_results as hand_result
    join public.table_session_seats as seat
      on seat.table_session_id = hand_result.table_session_id
      and seat.seat_index = hand_result.winner_seat_index
    where hand_result.table_session_id = session_row.id
      and hand_result.status = 'recorded'
      and hand_result.result_type = 'win'
    order by hand_result.hand_number desc, hand_result.created_at desc
    limit 1;

    if sudden_death_winner is null then
      update public.event_bonus_rounds
      set
        champion_resolution_method = 'sudden_death',
        sudden_death_status = 'active',
        sudden_death_session_id = session_row.id,
        champion_event_guest_id = null,
        champion_bonus_score_points = null,
        champion_top_up_points = null,
        champion_award_points = null,
        completed_at = null
      where id = session_row.bonus_round_id;

      perform app_private.refresh_event_score_totals(session_row.event_id);
      return;
    end if;

    champion_event_guest_id_value := sudden_death_winner;
    champion_bonus_score_points_value := 0;

    update public.table_sessions
    set
      status = 'completed',
      ended_at = coalesce(ended_at, now()),
      ended_by_user_id = coalesce(ended_by_user_id, auth.uid()),
      end_reason = coalesce(end_reason, 'sudden_death_resolved')
    where id = session_row.id
      and status in ('active', 'paused');
  end if;

  if champion_event_guest_id_value is null then
    return;
  end if;

  select coalesce(total.total_points, 0)
  into champion_base_total_value
  from public.event_score_totals as total
  where total.event_id = session_row.event_id
    and total.event_guest_id = champion_event_guest_id_value;

  champion_base_total_value := coalesce(champion_base_total_value, 0);

  select coalesce(max(total.total_points), 0)
  into top_non_champion_total_value
  from public.event_score_totals as total
  where total.event_id = session_row.event_id
    and total.event_guest_id <> champion_event_guest_id_value;

  top_non_champion_total_value := coalesce(top_non_champion_total_value, 0);
  champion_top_up_points_value := greatest(
    0,
    top_non_champion_total_value + 1
      - (champion_base_total_value + champion_bonus_score_points_value)
  );
  champion_award_points_value :=
    champion_bonus_score_points_value + champion_top_up_points_value;

  update public.event_bonus_rounds
  set
    status = 'completed',
    champion_resolution_method =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then 'sudden_death'
        else 'standard'
      end,
    sudden_death_status =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then 'completed'
        else 'not_required'
      end,
    sudden_death_table_id =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then sudden_death_table_id
        else null
      end,
    sudden_death_session_id =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then session_row.id
        else null
      end,
    champion_event_guest_id = champion_event_guest_id_value,
    champion_bonus_score_points = champion_bonus_score_points_value,
    champion_top_up_points = champion_top_up_points_value,
    champion_award_points = champion_award_points_value,
    completed_at = now()
  where id = session_row.bonus_round_id;

  if champion_award_points_value > 0 then
    insert into public.event_score_adjustments (
      event_id,
      event_guest_id,
      adjustment_type,
      amount_points,
      label,
      source_table_session_id,
      context_json,
      created_by_user_id
    )
    values (
      session_row.event_id,
      champion_event_guest_id_value,
      'finals_champion_award',
      champion_award_points_value,
      'Finals champion award',
      session_row.id,
      jsonb_build_object(
        'formula',
        'award_points = finals score or sudden death resolution + top-up',
        'champion_bonus_score_points', champion_bonus_score_points_value,
        'champion_base_total', champion_base_total_value,
        'top_non_champion_event_total_before_champion_award',
          top_non_champion_total_value,
        'champion_top_up_points', champion_top_up_points_value,
        'award_points', champion_award_points_value,
        'champion_resolution_method',
          case
            when session_row.bonus_table_role =
              'table_of_champions_sudden_death'
              then 'sudden_death'
            else 'standard'
          end
      ),
      auth.uid()
    );
  end if;

  perform app_private.refresh_event_score_totals(session_row.event_id);
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
  draws_always_rotate_effective_at constant timestamptz :=
    '2026-06-05T12:00:00Z'::timestamptz;
  dealer_multiplier_removed_for_events_created_at constant timestamptz :=
    '2026-06-05T13:00:00Z'::timestamptz;
  round_time_limit_duration constant interval := interval '1 hour';
  recorded_hand_count integer := 0;
  dealer_win_count integer := 0;
  round_time_completed boolean := false;
  legacy_draw_rotation_event boolean := false;
  dealer_multiplier_free_event boolean := false;
  short_bonus_player_count integer := 0;
  short_bonus_has_win boolean := false;
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

  select
    (
      lower(btrim(coalesce(event.public_slug, ''))) in (
        'fv-mahjong-1',
        'fv-mahjong-2'
      )
      or lower(btrim(event.title)) in (
        'fv mahjong 1',
        'fv mahjong 2'
      )
    ),
    event.created_at >= dealer_multiplier_removed_for_events_created_at
  into
    legacy_draw_rotation_event,
    dealer_multiplier_free_event
  from public.events as event
  where event.id = session_row.event_id;

  if session_row.bonus_table_role in (
      'table_of_champions_sudden_death',
      'table_of_champions_play_in'
    ) then
    select count(*)::integer
    into short_bonus_player_count
    from public.table_session_seats as seat
    where seat.table_session_id = session_row.id;

    if session_row.bonus_table_role = 'table_of_champions_sudden_death'
      and short_bonus_player_count not between 2 and 4 then
      raise exception 'Sudden death requires 2 to 4 seated players.'
        using errcode = 'P0001';
    end if;

    if session_row.bonus_table_role = 'table_of_champions_play_in'
      and short_bonus_player_count not between 2 and 4 then
      raise exception 'Play-in requires 2 to 4 seated players.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.hand_results as hand_result
      where hand_result.table_session_id = session_row.id
        and hand_result.status = 'recorded'
        and hand_result.result_type = 'win'
        and not exists (
          select 1
          from public.table_session_seats as seat
          where seat.table_session_id = hand_result.table_session_id
            and seat.seat_index = hand_result.winner_seat_index
        )
    ) then
      raise exception 'Bonus resolution winner seat must be occupied.'
        using errcode = 'P0001';
    end if;

    delete from public.hand_settlements as settlement
    using public.hand_results as hand_result
    where settlement.hand_result_id = hand_result.id
      and hand_result.table_session_id = session_row.id;

    for hand_row in
      select *
      from public.hand_results
      where table_session_id = session_row.id
        and status = 'recorded'
      order by hand_number asc
    loop
      recorded_hand_count := recorded_hand_count + 1;
      short_bonus_has_win :=
        short_bonus_has_win or hand_row.result_type = 'win';

      update public.hand_results
      set
        base_points = case
          when hand_row.result_type = 'win'
            then app_private.ruleset_base_points(
              session_row.ruleset_id,
              hand_row.fan_count
            )
          else null
        end,
        east_seat_index_before_hand = session_row.current_dealer_seat_index,
        east_seat_index_after_hand = session_row.current_dealer_seat_index,
        dealer_rotated = false,
        session_completed_after_hand = hand_row.result_type = 'win'
      where id = hand_row.id;
    end loop;

    update public.table_sessions
    set
      completed_games_count = recorded_hand_count,
      hand_count = recorded_hand_count,
      status = case
        when session_row.status in ('ended_early', 'aborted') then session_row.status
        when short_bonus_has_win then 'completed'
        when session_row.status = 'paused' then 'paused'
        else 'active'
      end,
      ended_at = case
        when session_row.status in ('ended_early', 'aborted') then session_row.ended_at
        when short_bonus_has_win then coalesce(session_row.ended_at, now())
        else null
      end,
      ended_by_user_id = case
        when session_row.status in ('ended_early', 'aborted') then session_row.ended_by_user_id
        when short_bonus_has_win then coalesce(session_row.ended_by_user_id, auth.uid())
        else null
      end,
      end_reason = case
        when session_row.status in ('ended_early', 'aborted') then session_row.end_reason
        when short_bonus_has_win and session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then coalesce(session_row.end_reason, 'sudden_death_resolved')
        when short_bonus_has_win and session_row.bonus_table_role = 'table_of_champions_play_in'
          then coalesce(session_row.end_reason, 'play_in_resolved')
        else null
      end,
      round_timer_paused_at = case
        when short_bonus_has_win then null
        else session_row.round_timer_paused_at
      end
    where id = session_row.id
    returning *
    into updated_session;

    perform app_private.refresh_event_score_totals(updated_session.event_id);
    perform app_private.apply_bonus_round_champion_award(updated_session.id);

    return updated_session;
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

        if hand_row.winner_seat_index = current_east
          and not dealer_multiplier_free_event then
          if hand_row.entered_at >= dealer_multiplier_1_5_effective_at then
            amount_points_value := (amount_points_value * 3) / 2;
          else
            amount_points_value := amount_points_value * 2;
          end if;
          multiplier_flags := array_append(multiplier_flags, 'east_wins');
        end if;

        if seat_index = current_east
          and hand_row.winner_seat_index <> current_east
          and not dealer_multiplier_free_event then
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
      and not legacy_draw_rotation_event
      and hand_row.entered_at >= draws_always_rotate_effective_at then
      east_after := (current_east + 1) % 4;
      dealer_rotated_flag := true;
      next_pass_count := next_pass_count + 1;
      dealer_win_count := 0;
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

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
      and bonus_round.sudden_death_status in ('required', 'active')
  ) then
    raise exception 'Resolve Table of Champions sudden death before completing the event.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
      and bonus_round.play_in_status in ('required', 'active')
  ) then
    raise exception 'Resolve Table of Champions play-in before completing the event.'
      using errcode = 'P0001';
  end if;

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

grant execute on function public.get_bonus_round_state(uuid)
  to authenticated;

grant execute on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid)
  to authenticated;

grant execute on function public.start_table_of_champions_play_in(uuid, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
