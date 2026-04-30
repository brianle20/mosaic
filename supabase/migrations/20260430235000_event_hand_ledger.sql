drop function if exists public.list_event_hand_ledger(uuid);

create or replace function public.list_event_hand_ledger(target_event_id uuid)
returns table (
  event_id uuid,
  table_id uuid,
  table_label text,
  session_id uuid,
  hand_id uuid,
  hand_number integer,
  entered_at timestamptz,
  result_type text,
  status text,
  win_type text,
  fan_count integer,
  has_settlements boolean,
  cells jsonb
)
language sql
security definer
set search_path = public, app_private
as $$
  with authorized_event as (
    select event.id
    from public.events as event
    where event.id = target_event_id
      and app_private.is_event_owner(target_event_id)
  ),
  hand_rows as (
    select
      session.event_id,
      event_table.id as table_id,
      event_table.label as table_label,
      session.id as session_id,
      hand_result.id as hand_id,
      hand_result.hand_number,
      hand_result.entered_at,
      hand_result.result_type,
      hand_result.status,
      hand_result.win_type,
      hand_result.fan_count,
      hand_result.east_seat_index_before_hand,
      exists (
        select 1
        from public.hand_settlements as settlement
        where settlement.hand_result_id = hand_result.id
      ) as has_settlements
    from authorized_event
    join public.table_sessions as session
      on session.event_id = authorized_event.id
    join public.event_tables as event_table
      on event_table.id = session.event_table_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
  )
  select
    hand_row.event_id,
    hand_row.table_id,
    hand_row.table_label,
    hand_row.session_id,
    hand_row.hand_id,
    hand_row.hand_number,
    hand_row.entered_at,
    hand_row.result_type,
    hand_row.status,
    hand_row.win_type,
    hand_row.fan_count,
    hand_row.has_settlements,
    jsonb_agg(
      jsonb_build_object(
        'wind', wind_position.wind,
        'seat_index', seat.seat_index,
        'event_guest_id', seat.event_guest_id,
        'display_name', guest.display_name,
        'points_delta', coalesce(delta.points_delta, 0)
      )
      order by wind_position.sort_order
    ) as cells
  from hand_rows as hand_row
  cross join lateral (
    values
      (0, 'east', hand_row.east_seat_index_before_hand),
      (1, 'south', (hand_row.east_seat_index_before_hand + 1) % 4),
      (2, 'west', (hand_row.east_seat_index_before_hand + 2) % 4),
      (3, 'north', (hand_row.east_seat_index_before_hand + 3) % 4)
  ) as wind_position(sort_order, wind, seat_index)
  join public.table_session_seats as seat
    on seat.table_session_id = hand_row.session_id
   and seat.seat_index = wind_position.seat_index
  join public.event_guests as guest
    on guest.id = seat.event_guest_id
  left join lateral (
    select
      sum(
        case
          when settlement.payee_event_guest_id = seat.event_guest_id
            then settlement.amount_points
          when settlement.payer_event_guest_id = seat.event_guest_id
            then -settlement.amount_points
          else 0
        end
      )::integer as points_delta
    from public.hand_settlements as settlement
    where settlement.hand_result_id = hand_row.hand_id
      and (
        settlement.payee_event_guest_id = seat.event_guest_id
        or settlement.payer_event_guest_id = seat.event_guest_id
      )
  ) as delta on true
  group by
    hand_row.event_id,
    hand_row.table_id,
    hand_row.table_label,
    hand_row.session_id,
    hand_row.hand_id,
    hand_row.hand_number,
    hand_row.entered_at,
    hand_row.result_type,
    hand_row.status,
    hand_row.win_type,
    hand_row.fan_count,
    hand_row.has_settlements
  order by hand_row.entered_at desc, hand_row.session_id desc, hand_row.hand_number desc;
$$;

grant execute on function public.list_event_hand_ledger(uuid)
  to authenticated;
