-- Preserve Table of Redemption co-winners on public results while honoring
-- an authoritative singular result in Finals formats that must select one.

create or replace function public.get_public_event_bonus_results(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  public_display_name text,
  result_label text,
  placement integer,
  points_delta integer
)
language sql
security definer
set search_path = public
as $$
  with completed_bonus_rounds as (
    select bonus_round.*
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'completed'
  ),
  champion_result as (
    select
      guest.id as event_guest_id,
      coalesce(
        nullif(btrim(guest.public_display_name), ''),
        'Player'
      ) as public_display_name,
      case bonus_round.champion_resolution_method
        when 'sudden_death' then 'Table of Champions Sudden Death'
        else 'Table of Champions'
      end as result_label,
      1::integer as placement,
      coalesce(bonus_round.champion_award_points, 0)::integer as points_delta
    from completed_bonus_rounds as bonus_round
    join public.event_guests as guest
      on guest.id = bonus_round.champion_event_guest_id
      and guest.event_id = bonus_round.event_id
      and guest.tournament_status = 'qualified'
  ),
  redemption_points as (
    select
      bonus_round.id as bonus_round_id,
      seat.event_guest_id,
      coalesce(
        sum(
          case
            when settlement.payee_event_guest_id = seat.event_guest_id
              then settlement.amount_points
            else 0
          end
        ),
        0
      ) - coalesce(
        sum(
          case
            when settlement.payer_event_guest_id = seat.event_guest_id
              then settlement.amount_points
            else 0
          end
        ),
        0
      ) as total_points
    from completed_bonus_rounds as bonus_round
    join public.table_sessions as session
      on session.bonus_round_id = bonus_round.id
      and session.scoring_phase = 'bonus'
      and session.bonus_table_role = 'table_of_redemption'
    join public.table_session_seats as seat
      on seat.table_session_id = session.id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
      and hand_result.status = 'recorded'
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and (
        settlement.payee_event_guest_id = seat.event_guest_id
        or settlement.payer_event_guest_id = seat.event_guest_id
      )
    group by bonus_round.id, seat.event_guest_id
  ),
  ranked_redemption_points as (
    select
      redemption_points.*,
      rank() over (
        partition by redemption_points.bonus_round_id
        order by redemption_points.total_points desc
      )::integer as finish_rank
    from redemption_points
  ),
  authoritative_redemption_winner as (
    select
      guest.id as event_guest_id,
      coalesce(
        nullif(btrim(guest.public_display_name), ''),
        'Player'
      ) as public_display_name,
      'Table of Redemption'::text as result_label,
      1::integer as placement,
      0::integer as points_delta
    from completed_bonus_rounds as bonus_round
    join public.event_guests as guest
      on guest.id = bonus_round.redemption_winner_event_guest_id
      and guest.event_id = bonus_round.event_id
      and guest.tournament_status = 'qualified'
    where bonus_round.redemption_winner_event_guest_id is not null
  ),
  redemption_leaders as (
    select
      guest.id as event_guest_id,
      coalesce(
        nullif(btrim(guest.public_display_name), ''),
        'Player'
      ) as public_display_name,
      'Table of Redemption'::text as result_label,
      1::integer as placement,
      0::integer as points_delta
    from ranked_redemption_points
    join completed_bonus_rounds as bonus_round
      on bonus_round.id = ranked_redemption_points.bonus_round_id
    join public.event_guests as guest
      on guest.id = ranked_redemption_points.event_guest_id
      and guest.event_id = bonus_round.event_id
      and guest.tournament_status = 'qualified'
    where ranked_redemption_points.finish_rank = 1
      and bonus_round.redemption_winner_event_guest_id is null
  ),
  redemption_results as (
    select *
    from authoritative_redemption_winner
    union all
    select *
    from redemption_leaders
  )
  select *
  from champion_result
  union all
  select *
  from redemption_results
  order by result_label asc, public_display_name asc, event_guest_id asc;
$$;

grant execute on function public.get_public_event_bonus_results(uuid)
  to anon, authenticated;

do $$
declare
  event_row record;
begin
  for event_row in
    select distinct bonus_round.event_id
    from public.event_bonus_rounds as bonus_round
    where bonus_round.status = 'completed'
  loop
    perform app_private.refresh_public_event_standings_snapshot(
      event_row.event_id
    );
  end loop;
end;
$$;

select pg_notify('pgrst', 'reload schema');
