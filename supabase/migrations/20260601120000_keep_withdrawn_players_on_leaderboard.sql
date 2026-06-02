-- Keep withdrawn tournament players visible in host standings while excluding
-- them from prize and finals eligibility.

drop function if exists public.get_event_leaderboard(uuid);

create or replace function public.get_event_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  tournament_status text,
  total_points integer,
  hands_played integer,
  hands_won integer,
  self_draw_wins integer,
  discard_wins integer,
  discard_losses integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  select
    score.event_guest_id,
    guest.display_name,
    guest.tournament_status,
    score.total_points,
    score.hands_played,
    score.hands_won,
    score.self_draw_wins,
    score.discard_wins,
    score.discard_losses,
    (rank() over (order by score.total_points desc))::integer as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
    and guest.event_id = target_event_id
  where score.event_id = target_event_id
    and guest.tournament_status in ('qualified', 'withdrawn')
    and app_private.is_event_owner(target_event_id)
  order by score.total_points desc, guest.display_name asc;
$$;

drop function if exists public.get_public_event_leaderboard(uuid);

create or replace function public.get_public_event_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  public_display_name text,
  tournament_status text,
  total_points integer,
  hands_played integer,
  wins integer,
  self_draw_wins integer,
  discard_wins integer,
  discard_losses integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  select
    score.event_guest_id,
    coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
    guest.tournament_status,
    score.total_points,
    score.hands_played,
    score.hands_won as wins,
    score.self_draw_wins,
    score.discard_wins,
    score.discard_losses,
    (rank() over (order by score.total_points desc))::integer as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
    and guest.event_id = target_event_id
  where score.event_id = target_event_id
    and guest.tournament_status in ('qualified', 'withdrawn')
    and guest.attendance_status = 'checked_in'
  order by score.total_points desc, public_display_name asc;
$$;

create or replace function app_private.build_prize_preview(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  rank_start integer,
  rank_end integer,
  display_rank text,
  award_amount_cents integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  plan_row public.prize_plans%rowtype;
  median_hands_played numeric;
  minimum_hands_played integer;
begin
  perform app_private.require_owned_event(target_event_id);

  select plan.*
  into plan_row
  from public.prize_plans as plan
  where plan.event_id = target_event_id;

  if not found or plan_row.mode = 'none' then
    return;
  end if;

  if plan_row.mode <> 'fixed' then
    raise exception 'Only fixed prize plans are supported.'
      using errcode = 'P0001';
  end if;

  select percentile_cont(0.5) within group (order by leaderboard.hands_played)
  into median_hands_played
  from public.get_event_leaderboard(target_event_id) as leaderboard
  where leaderboard.tournament_status = 'qualified'
    and leaderboard.hands_played > 0;

  if median_hands_played is null then
    return;
  end if;

  minimum_hands_played :=
    greatest(1, ceil(median_hands_played * 0.5)::integer);

  return query
  with tier_amounts as (
    select
      tier.place,
      coalesce(tier.fixed_amount_cents, 0) as award_amount_cents
    from public.prize_tiers as tier
    where tier.prize_plan_id = plan_row.id
  ),
  eligible_leaderboard as (
    select
      leaderboard.event_guest_id,
      leaderboard.display_name,
      leaderboard.total_points,
      row_number() over (
        order by leaderboard.total_points desc, leaderboard.display_name asc
      )::integer as leaderboard_position,
      dense_rank() over (
        order by leaderboard.total_points desc
      )::integer as dense_rank_position
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.tournament_status = 'qualified'
      and leaderboard.hands_played >= minimum_hands_played
  ),
  rank_groups as (
    select
      eligible_leaderboard.dense_rank_position,
      min(eligible_leaderboard.leaderboard_position)::integer as rank_start,
      max(eligible_leaderboard.leaderboard_position)::integer as rank_end
    from eligible_leaderboard
    group by eligible_leaderboard.dense_rank_position
  ),
  pooled_ranks as (
    select
      rank_groups.dense_rank_position,
      rank_groups.rank_start,
      rank_groups.rank_end,
      coalesce(sum(tier_amounts.award_amount_cents), 0) as pooled_amount_cents
    from rank_groups
    left join tier_amounts
      on tier_amounts.place between rank_groups.rank_start and rank_groups.rank_end
    group by
      rank_groups.dense_rank_position,
      rank_groups.rank_start,
      rank_groups.rank_end
  ),
  ranked_members as (
    select
      eligible_leaderboard.event_guest_id,
      eligible_leaderboard.display_name,
      pooled_ranks.rank_start,
      pooled_ranks.rank_end,
      pooled_ranks.pooled_amount_cents,
      count(*) over (
        partition by eligible_leaderboard.dense_rank_position
      )::integer as tied_guest_count,
      row_number() over (
        partition by eligible_leaderboard.dense_rank_position
        order by eligible_leaderboard.display_name asc
      )::integer as alphabetical_tie_order
    from eligible_leaderboard
    join pooled_ranks
      on pooled_ranks.dense_rank_position = eligible_leaderboard.dense_rank_position
  )
  select
    ranked_members.event_guest_id,
    ranked_members.display_name,
    ranked_members.rank_start,
    ranked_members.rank_end,
    case
      when ranked_members.rank_start = ranked_members.rank_end then ranked_members.rank_start::text
      else 'T-' || ranked_members.rank_start::text
    end as display_rank,
    (
      ranked_members.pooled_amount_cents / ranked_members.tied_guest_count
      + case
          when ranked_members.alphabetical_tie_order
            <= mod(ranked_members.pooled_amount_cents, ranked_members.tied_guest_count)
          then 1
          else 0
        end
    )::integer as award_amount_cents
  from ranked_members
  where ranked_members.pooled_amount_cents > 0
  order by ranked_members.rank_start, ranked_members.display_name asc;
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
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
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
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
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

create or replace function app_private.build_public_event_standings_snapshot(
  target_event_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with event_summary as (
    select coalesce(nullif(btrim(summary.title), ''), 'Mosaic tournament') as event_title
    from public.get_public_event_summary(target_event_id) as summary
    limit 1
  ),
  leaderboard_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'eventGuestId', leaderboard.event_guest_id,
          'publicDisplayName', leaderboard.public_display_name,
          'tournamentStatus', leaderboard.tournament_status,
          'totalPoints', leaderboard.total_points,
          'handsPlayed', leaderboard.hands_played,
          'wins', leaderboard.wins,
          'selfDrawWins', leaderboard.self_draw_wins,
          'discardWins', leaderboard.discard_wins,
          'discardLosses', leaderboard.discard_losses,
          'rank', leaderboard.rank
        )
        order by leaderboard.total_points desc, leaderboard.public_display_name asc
      ),
      '[]'::jsonb
    ) as rows
    from public.get_public_event_leaderboard(target_event_id) as leaderboard
  ),
  bonus_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'eventGuestId', bonus.event_guest_id,
          'publicDisplayName', bonus.public_display_name,
          'resultLabel', bonus.result_label,
          'placement', bonus.placement,
          'pointsDelta', bonus.points_delta
        )
        order by bonus.result_label asc, bonus.public_display_name asc
      ),
      '[]'::jsonb
    ) as rows
    from public.get_public_event_bonus_results(target_event_id) as bonus
  ),
  finals_table_rows as (
    select
      finals.bonus_table_role as table_role,
      case finals.bonus_table_role
        when 'table_of_champions' then 'Table of Champions'
        when 'table_of_redemption' then 'Table of Redemption'
        when 'table_of_champions_sudden_death' then 'Table of Champions Sudden Death'
        else 'Finals Table'
      end as title,
      finals.table_label,
      bool_or(finals.hands_played > 0) as has_scores,
      jsonb_agg(
        jsonb_build_object(
          'eventGuestId', finals.event_guest_id,
          'publicDisplayName', finals.public_display_name,
          'seatIndex', finals.seat_index,
          'totalPoints', finals.total_points,
          'handsPlayed', finals.hands_played,
          'wins', finals.wins,
          'rank', finals.rank
        )
        order by
          case when finals.hands_played > 0 then finals.rank else finals.seat_index end,
          finals.public_display_name asc
      ) as rows
    from public.get_public_event_finals_leaderboard(target_event_id) as finals
    group by finals.bonus_table_role, finals.table_label
  ),
  finals_leaderboard_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'tableRole', finals_table_rows.table_role,
          'title', finals_table_rows.title,
          'tableLabel', finals_table_rows.table_label,
          'hasScores', finals_table_rows.has_scores,
          'rows', finals_table_rows.rows
        )
        order by
          case finals_table_rows.table_role
            when 'table_of_champions' then 0
            when 'table_of_redemption' then 1
            when 'table_of_champions_sudden_death' then 2
            else 3
          end,
          finals_table_rows.table_label asc
      ),
      '[]'::jsonb
    ) as rows
    from finals_table_rows
  ),
  points_timeline_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'handIndex', timeline.hand_index,
          'handResultId', timeline.hand_result_id,
          'recordedAt', timeline.recorded_at,
          'tableLabel', timeline.table_label,
          'eventGuestId', timeline.event_guest_id,
          'publicDisplayName', timeline.public_display_name,
          'pointsDelta', timeline.points_delta,
          'totalPoints', timeline.total_points,
          'rank', timeline.rank
        )
        order by timeline.hand_index asc, timeline.rank asc, timeline.public_display_name asc
      ),
      '[]'::jsonb
    ) as rows
    from public.get_public_event_points_timeline(target_event_id) as timeline
  )
  select jsonb_build_object(
    'eventTitle', coalesce((select event_title from event_summary), 'Mosaic tournament'),
    'leaderboard', (select rows from leaderboard_rows),
    'bonusResults', (select rows from bonus_rows),
    'finalsLeaderboards', (select rows from finals_leaderboard_rows),
    'pointsTimeline', (select rows from points_timeline_rows),
    'updatedAt', now()
  );
$$;

grant execute on function public.get_event_leaderboard(uuid) to authenticated;
grant execute on function public.get_public_event_leaderboard(uuid) to anon, authenticated;
grant execute on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
