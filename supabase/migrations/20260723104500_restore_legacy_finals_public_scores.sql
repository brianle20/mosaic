-- Preserve scored Finals sessions in public standings for both the legacy
-- bonus-round flow and the durable Finals contest orchestration flow.

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
      assignment.event_table_id,
      event_table.label as table_label,
      assignment.event_guest_id,
      assignment.seat_index,
      assignment.bonus_round_id,
      assignment.bonus_table_role,
      assignment.finals_contest_id
    from public.event_seating_assignments as assignment
    join public.event_tables as event_table
      on event_table.id = assignment.event_table_id
      and event_table.event_id = assignment.event_id
    left join public.event_finals_contests as contest
      on contest.id = assignment.finals_contest_id
    where assignment.event_id = target_event_id
      and assignment.assignment_type = 'bonus'
      and (
        assignment.status = 'active'
        or (
          assignment.status = 'cleared'
          and contest.status = 'complete'
        )
      )
      and assignment.bonus_round_id is not null
      and assignment.bonus_table_role is not null
  ),
  finals_scores as (
    select
      assignment.bonus_table_role,
      assignment.table_label,
      assignment.event_guest_id,
      coalesce(
        nullif(btrim(guest.public_display_name), ''),
        'Player'
      ) as public_display_name,
      assignment.seat_index,
      coalesce(
        sum(
          case
            when settlement.payee_event_guest_id = assignment.event_guest_id
              then settlement.amount_points
            when settlement.payer_event_guest_id = assignment.event_guest_id
              then -settlement.amount_points
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
      on session.scoring_phase = 'bonus'
      and (
        (
          assignment.finals_contest_id is not null
          and session.finals_contest_id = assignment.finals_contest_id
        )
        or (
          assignment.finals_contest_id is null
          and session.finals_contest_id is null
          and session.event_id = target_event_id
          and session.event_table_id = assignment.event_table_id
          and session.bonus_round_id = assignment.bonus_round_id
          and session.bonus_table_role = assignment.bonus_table_role
        )
      )
    left join public.table_session_seats as seat
      on seat.table_session_id = session.id
      and seat.event_guest_id = assignment.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
      and hand_result.status = 'recorded'
      and seat.id is not null
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and assignment.event_guest_id in (
        settlement.payee_event_guest_id,
        settlement.payer_event_guest_id
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
    rank() over (
      partition by finals_scores.bonus_table_role,
        finals_scores.table_label
      order by finals_scores.total_points desc
    )::integer
  from finals_scores
  order by
    case finals_scores.bonus_table_role
      when 'table_of_champions' then 0
      when 'table_of_champions_sudden_death' then 1
      when 'table_of_redemption' then 2
      else 3
    end,
    finals_scores.table_label,
    rank,
    finals_scores.seat_index;
$$;

grant execute on function public.get_public_event_finals_leaderboard(uuid)
  to anon, authenticated;

do $$
declare
  event_row record;
begin
  for event_row in
    select distinct assignment.event_id
    from public.event_seating_assignments as assignment
    join public.event_bonus_rounds as bonus_round
      on bonus_round.id = assignment.bonus_round_id
    where assignment.assignment_type = 'bonus'
      and assignment.finals_contest_id is null
      and bonus_round.status = 'completed'
  loop
    perform app_private.refresh_public_event_standings_snapshot(
      event_row.event_id
    );
  end loop;
end;
$$;

select pg_notify('pgrst', 'reload schema');
