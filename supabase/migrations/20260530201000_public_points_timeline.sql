drop function if exists public.get_public_event_points_timeline(uuid);

create or replace function public.get_public_event_points_timeline(
  target_event_id uuid
)
returns table (
  hand_index integer,
  hand_result_id uuid,
  recorded_at timestamptz,
  table_label text,
  event_guest_id uuid,
  public_display_name text,
  points_delta integer,
  total_points integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  with ranked_players as (
    select
      leaderboard.event_guest_id,
      leaderboard.public_display_name
    from public.get_public_event_leaderboard(target_event_id) as leaderboard
  ),
  recorded_hands as (
    select
      row_number() over (
        order by hand_result.entered_at asc, session.id asc, hand_result.hand_number asc, hand_result.id asc
      )::integer as hand_index,
      hand_result.id as hand_result_id,
      hand_result.entered_at as recorded_at,
      event_table.label as table_label
    from public.table_sessions as session
    join public.event_tables as event_table
      on event_table.id = session.event_table_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.bonus_round_id is null
      and hand_result.status = 'recorded'
  ),
  timeline_points as (
    select
      recorded_hands.hand_index,
      recorded_hands.hand_result_id,
      recorded_hands.recorded_at,
      recorded_hands.table_label,
      ranked_players.event_guest_id,
      ranked_players.public_display_name,
      coalesce(delta.points_delta, 0)::integer as points_delta
    from recorded_hands
    cross join ranked_players
    left join lateral (
      select
        sum(
          case
            when settlement.payee_event_guest_id = ranked_players.event_guest_id
              then settlement.amount_points
            when settlement.payer_event_guest_id = ranked_players.event_guest_id
              then -settlement.amount_points
            else 0
          end
        )::integer as points_delta
      from public.hand_settlements as settlement
      where settlement.hand_result_id = recorded_hands.hand_result_id
        and (
          settlement.payee_event_guest_id = ranked_players.event_guest_id
          or settlement.payer_event_guest_id = ranked_players.event_guest_id
        )
    ) as delta on true
  ),
  cumulative_points as (
    select
      timeline_points.hand_index,
      timeline_points.hand_result_id,
      timeline_points.recorded_at,
      timeline_points.table_label,
      timeline_points.event_guest_id,
      timeline_points.public_display_name,
      timeline_points.points_delta,
      sum(timeline_points.points_delta) over (
        partition by timeline_points.event_guest_id
        order by timeline_points.hand_index
        rows between unbounded preceding and current row
      )::integer as total_points
    from timeline_points
  )
  select
    cumulative_points.hand_index,
    cumulative_points.hand_result_id,
    cumulative_points.recorded_at,
    cumulative_points.table_label,
    cumulative_points.event_guest_id,
    cumulative_points.public_display_name,
    cumulative_points.points_delta,
    cumulative_points.total_points,
    rank() over (
      partition by cumulative_points.hand_index
      order by cumulative_points.total_points desc, cumulative_points.public_display_name asc, cumulative_points.event_guest_id asc
    )::integer as rank
  from cumulative_points
  order by
    cumulative_points.hand_index asc,
    rank asc,
    cumulative_points.public_display_name asc,
    cumulative_points.event_guest_id asc;
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
      finals.bonus_table_role,
      case finals.bonus_table_role
        when 'table_of_champions' then 'Table of Champions'
        when 'table_of_champions_sudden_death' then 'Table of Champions Sudden Death'
        when 'table_of_redemption' then 'Table of Redemption'
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
          'tableRole', finals_table_rows.bonus_table_role,
          'title', finals_table_rows.title,
          'tableLabel', finals_table_rows.table_label,
          'hasScores', finals_table_rows.has_scores,
          'rows', finals_table_rows.rows
        )
        order by
          case finals_table_rows.bonus_table_role
            when 'table_of_champions' then 0
            when 'table_of_champions_sudden_death' then 1
            when 'table_of_redemption' then 2
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

grant execute on function public.get_public_event_points_timeline(uuid) to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
