-- Finals seating now uses qualified checked-in players instead of player tags.

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
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if champions_table_id = redemption_table_id then
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

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
  ) then
    raise exception 'Active finals already exist for this event.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = champions_table_id
      and event_table.event_id = target_event_id
  ) then
    raise exception 'Table of Champions must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  if redemption_table_id is not null
    and not exists (
      select 1
      from public.event_tables as event_table
      join public.nfc_tags as tag
        on tag.id = event_table.nfc_tag_id
        and tag.default_tag_type = 'table'
        and tag.status = 'active'
      where event_table.id = redemption_table_id
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
    select distinct
      leaderboard.event_guest_id
    from public.get_event_leaderboard(target_event_id) as leaderboard
    cross join minimum
    join public.event_guests as guest
      on guest.id = leaderboard.event_guest_id
      and guest.event_id = target_event_id
      and guest.attendance_status = 'checked_in'
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played >= minimum.minimum_hands_played
  )
  select count(*)::integer
  into ranked_player_count
  from ranked_players;

  if ranked_player_count = 0 then
    raise exception 'No prize-eligible players are available for finals.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count = 1 then
    raise exception 'At least 2 prize-eligible players are required for finals.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count >= 6 and redemption_table_id is null then
    raise exception 'A second ready table is required for Table of Redemption.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count between 2 and 5 then
    redemption_table_id := null;
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = target_event_id
    and assignment.status = 'active';

  insert into public.event_bonus_rounds (
    event_id,
    champions_table_id,
    redemption_table_id,
    assignment_round,
    status
  )
  values (
    target_event_id,
    champions_table_id,
    redemption_table_id,
    next_assignment_round,
    'active'
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
    where redemption_table_id is not null
      and ranked_players.seed_rank > ranked_players.player_count - 4
    order by ranked_players.seed_rank asc
  ),
  selected_bonus_players as (
    select
      champions_table_id as event_table_id,
      champions.event_guest_id,
      champions.seat_index,
      'table_of_champions'::text as bonus_table_role,
      champions.seed_rank
    from champions
    union all
    select
      redemption_table_id as event_table_id,
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
  from selected_bonus_players;

  return query
  select *
  from public.get_event_seating_assignments(target_event_id);
end;
$$;

grant execute on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
