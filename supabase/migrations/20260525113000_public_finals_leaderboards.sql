-- Publish table-scoped finals leaderboards for public standings pages.

drop function if exists public.get_public_event_finals_leaderboard(uuid);

create or replace function public.get_public_event_finals_leaderboard(
  target_event_id uuid
)
returns table (
  bonus_table_role text,
  table_label text,
  event_guest_id uuid,
  public_display_name text,
  seat_index integer,
  total_points integer,
  hands_played integer,
  wins integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  with bonus_assignments as (
    select
      assignment.id as assignment_id,
      assignment.event_table_id,
      event_table.label as table_label,
      assignment.event_guest_id,
      assignment.seat_index,
      assignment.bonus_round_id,
      assignment.bonus_table_role
    from public.event_seating_assignments as assignment
    join public.event_tables as event_table
      on event_table.id = assignment.event_table_id
      and event_table.event_id = assignment.event_id
    where assignment.event_id = target_event_id
      and assignment.assignment_type = 'bonus'
      and assignment.status = 'active'
      and assignment.bonus_round_id is not null
      and assignment.bonus_table_role is not null
  ),
  finals_scores as (
    select
      assignment.bonus_table_role,
      assignment.table_label,
      assignment.event_guest_id,
      coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
      assignment.seat_index,
      coalesce(
        sum(
          case
            when settlement.payee_event_guest_id = assignment.event_guest_id then settlement.amount_points
            when settlement.payer_event_guest_id = assignment.event_guest_id then -settlement.amount_points
            else 0
          end
        ),
        0
      )::integer as total_points,
      count(distinct hand_result.id)::integer as hands_played,
      count(distinct hand_result.id) filter (
        where hand_result.result_type = 'win'
          and hand_result.winner_seat_index = seat.seat_index
      )::integer as wins
    from bonus_assignments as assignment
    join public.event_guests as guest
      on guest.id = assignment.event_guest_id
      and guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
    left join public.table_sessions as session
      on session.event_id = target_event_id
      and session.event_table_id = assignment.event_table_id
      and session.bonus_round_id = assignment.bonus_round_id
      and session.bonus_table_role = assignment.bonus_table_role
      and session.scoring_phase = 'bonus'
    left join public.table_session_seats as seat
      on seat.table_session_id = session.id
      and seat.event_guest_id = assignment.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
      and hand_result.status = 'recorded'
      and seat.id is not null
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and (
        settlement.payee_event_guest_id = assignment.event_guest_id
        or settlement.payer_event_guest_id = assignment.event_guest_id
      )
    group by
      assignment.bonus_table_role,
      assignment.table_label,
      assignment.event_guest_id,
      guest.public_display_name,
      assignment.seat_index
  )
  select
    finals_scores.bonus_table_role,
    finals_scores.table_label,
    finals_scores.event_guest_id,
    finals_scores.public_display_name,
    finals_scores.seat_index,
    finals_scores.total_points,
    finals_scores.hands_played,
    finals_scores.wins,
    (
      rank() over (
        partition by finals_scores.bonus_table_role, finals_scores.table_label
        order by finals_scores.total_points desc
      )
    )::integer as rank
  from finals_scores
  order by
    case finals_scores.bonus_table_role
      when 'table_of_champions' then 0
      when 'table_of_redemption' then 1
      else 2
    end,
    finals_scores.table_label asc,
    rank asc,
    finals_scores.seat_index asc;
$$;

grant execute on function public.get_public_event_finals_leaderboard(uuid) to anon, authenticated;

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
            when 'table_of_redemption' then 1
            else 2
          end,
          finals_table_rows.table_label asc
      ),
      '[]'::jsonb
    ) as rows
    from finals_table_rows
  )
  select jsonb_build_object(
    'eventTitle', coalesce((select event_title from event_summary), 'Mosaic tournament'),
    'leaderboard', (select rows from leaderboard_rows),
    'bonusResults', (select rows from bonus_rows),
    'finalsLeaderboards', (select rows from finals_leaderboard_rows),
    'updatedAt', now()
  );
$$;

create or replace function app_private.insert_public_event_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  if tg_table_name = 'hand_results' then
    select session.event_id
    into target_event_id
    from public.table_sessions as session
    where session.id = case
      when tg_op = 'DELETE' then old.table_session_id
      else new.table_session_id
    end;
  else
    target_event_id := case
      when tg_op = 'DELETE' then old.event_id
      else new.event_id
    end;
  end if;

  if target_event_id is not null then
    if tg_table_name = 'hand_results' then
      perform app_private.refresh_public_event_standings_snapshot(target_event_id);
    elsif tg_table_name not in (
      'event_score_totals',
      'event_score_adjustments',
      'hand_results',
      'table_sessions'
    ) then
      perform app_private.refresh_public_event_standings_snapshot(target_event_id);
    end if;

    insert into public.public_event_updates (event_id, topic)
    values (target_event_id, tg_table_name);
  end if;

  return coalesce(new, old);
end;
$$;

do $$
declare
  event_row record;
begin
  for event_row in select id from public.events loop
    perform app_private.refresh_public_event_standings_snapshot(event_row.id);
  end loop;
end;
$$;
