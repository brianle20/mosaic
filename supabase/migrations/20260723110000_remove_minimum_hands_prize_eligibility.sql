-- Prize eligibility is based on participation in a started tournament table
-- session and non-withdrawn status. Hand count is not an eligibility rule.

create or replace function app_private.is_event_guest_prize_eligible(
  target_event_id uuid,
  target_event_guest_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_guests as guest
    join public.table_session_seats as seat
      on seat.event_guest_id = guest.id
    join public.table_sessions as session
      on session.id = seat.table_session_id
      and session.event_id = guest.event_id
    where guest.id = target_event_guest_id
      and guest.event_id = target_event_id
      and guest.tournament_status <> 'withdrawn'
      and session.scoring_phase = 'tournament'
  );
$$;

revoke all on function app_private.is_event_guest_prize_eligible(uuid, uuid)
  from public;

drop function if exists public.get_event_leaderboard(uuid);

create or replace function public.get_event_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  tournament_status text,
  prize_eligible boolean,
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
    app_private.is_event_guest_prize_eligible(
      target_event_id,
      score.event_guest_id
    ) as prize_eligible,
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
  prize_eligible boolean,
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
    coalesce(
      nullif(btrim(guest.public_display_name), ''),
      'Player'
    ) as public_display_name,
    guest.tournament_status,
    app_private.is_event_guest_prize_eligible(
      target_event_id,
      score.event_guest_id
    ) as prize_eligible,
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
    where leaderboard.prize_eligible
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
      when ranked_members.rank_start = ranked_members.rank_end
        then ranked_members.rank_start::text
      else 'T-' || ranked_members.rank_start::text
    end as display_rank,
    (
      ranked_members.pooled_amount_cents / ranked_members.tied_guest_count
      + case
          when ranked_members.alphabetical_tie_order
            <= mod(
              ranked_members.pooled_amount_cents,
              ranked_members.tied_guest_count
            )
          then 1
          else 0
        end
    )::integer as award_amount_cents
  from ranked_members
  where ranked_members.pooled_amount_cents > 0
  order by ranked_members.rank_start, ranked_members.display_name asc;
end;
$$;

create or replace function app_private.finals_standings_snapshot(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  total_points integer,
  hands_played integer,
  standing_rank integer,
  seed_rank integer
)
language sql
stable
security definer
set search_path = public
as $$
  with eligible as (
    select
      guest.id as event_guest_id,
      guest.display_name,
      score.total_points,
      score.hands_played
    from public.event_score_totals as score
    join public.event_guests as guest
      on guest.id = score.event_guest_id
      and guest.event_id = score.event_id
    where score.event_id = target_event_id
      and app_private.is_event_guest_prize_eligible(
        target_event_id,
        guest.id
      )
  )
  select
    eligible.event_guest_id,
    eligible.display_name,
    eligible.total_points,
    eligible.hands_played,
    rank() over (order by eligible.total_points desc)::integer as standing_rank,
    row_number() over (
      order by
        eligible.total_points desc,
        eligible.display_name,
        eligible.event_guest_id
    )::integer as seed_rank
  from eligible
  order by seed_rank;
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
    select
      coalesce(
        nullif(btrim(summary.title), ''),
        'Mosaic tournament'
      ) as event_title
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
          'prizeEligible', leaderboard.prize_eligible,
          'totalPoints', leaderboard.total_points,
          'handsPlayed', leaderboard.hands_played,
          'wins', leaderboard.wins,
          'selfDrawWins', leaderboard.self_draw_wins,
          'discardWins', leaderboard.discard_wins,
          'discardLosses', leaderboard.discard_losses,
          'rank', leaderboard.rank
        )
        order by
          leaderboard.total_points desc,
          leaderboard.public_display_name asc
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
        when 'table_of_champions_sudden_death'
          then 'Table of Champions Sudden Death'
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
          case
            when finals.hands_played > 0 then finals.rank
            else finals.seat_index
          end,
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
        order by
          timeline.hand_index asc,
          timeline.rank asc,
          timeline.public_display_name asc
      ),
      '[]'::jsonb
    ) as rows
    from public.get_public_event_points_timeline(target_event_id) as timeline
  )
  select jsonb_build_object(
    'eventTitle',
    coalesce(
      (select event_title from event_summary),
      'Mosaic tournament'
    ),
    'leaderboard', (select rows from leaderboard_rows),
    'bonusResults', (select rows from bonus_rows),
    'finalsLeaderboards', (select rows from finals_leaderboard_rows),
    'pointsTimeline', (select rows from points_timeline_rows),
    'updatedAt', now()
  );
$$;

grant execute on function public.get_event_leaderboard(uuid) to authenticated;
grant execute on function public.get_public_event_leaderboard(uuid)
  to anon, authenticated;

do $$
declare
  event_row record;
begin
  for event_row in
    select event.id from public.events as event
  loop
    perform app_private.refresh_public_event_standings_snapshot(event_row.id);
  end loop;
end $$;

select pg_notify('pgrst', 'reload schema');
