create table if not exists public.hand_false_win_penalties (
  id uuid primary key default gen_random_uuid(),
  table_session_id uuid not null references public.table_sessions(id) on delete cascade,
  hand_result_id uuid references public.hand_results(id) on delete cascade,
  penalty_seat_index integer not null check (penalty_seat_index between 0 and 3),
  fan_count integer not null default 6 check (fan_count = 6),
  entered_by_user_id uuid not null references public.users(id),
  entered_at timestamptz not null default now(),
  status text not null default 'pending'
    check (status in ('pending', 'attached', 'voided')),
  correction_note text,
  client_mutation_id uuid
);

alter table public.hand_settlements
  alter column hand_result_id drop not null;

alter table public.hand_settlements
  add column if not exists hand_false_win_penalty_id uuid references public.hand_false_win_penalties(id) on delete cascade;

create index if not exists hand_settlements_false_win_penalty_idx
  on public.hand_settlements (hand_false_win_penalty_id)
  where hand_false_win_penalty_id is not null;

create unique index if not exists hand_false_win_penalties_pending_seat_unique
  on public.hand_false_win_penalties (table_session_id, penalty_seat_index)
  where status = 'pending';

create unique index if not exists hand_false_win_penalties_attached_seat_unique
  on public.hand_false_win_penalties (hand_result_id, penalty_seat_index)
  where status = 'attached';

create unique index if not exists hand_false_win_penalties_client_mutation_id_unique
  on public.hand_false_win_penalties (client_mutation_id)
  where client_mutation_id is not null;

create index if not exists hand_false_win_penalties_session_status_idx
  on public.hand_false_win_penalties (table_session_id, status, entered_at);

create index if not exists hand_false_win_penalties_hand_result_idx
  on public.hand_false_win_penalties (hand_result_id)
  where hand_result_id is not null;

alter table public.hand_false_win_penalties enable row level security;

drop policy if exists hand_false_win_penalties_owner_select
  on public.hand_false_win_penalties;
create policy hand_false_win_penalties_owner_select
  on public.hand_false_win_penalties
  for select
  using (
    exists (
      select 1
      from public.table_sessions as session
      where session.id = hand_false_win_penalties.table_session_id
        and app_private.can_view_event(session.event_id)
    )
  );

drop policy if exists hand_settlements_owner_or_staff_read on public.hand_settlements;
create policy hand_settlements_owner_or_staff_read
on public.hand_settlements
for select
to authenticated
using (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_result_id
      and app_private.can_view_event(session.event_id)
  )
  or exists (
    select 1
    from public.hand_false_win_penalties as penalty
    join public.table_sessions as session
      on session.id = penalty.table_session_id
    where penalty.id = hand_false_win_penalty_id
      and app_private.can_view_event(session.event_id)
  )
);

create or replace function app_private.refresh_event_score_totals(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.event_score_totals
  where event_id = target_event_id;

  insert into public.event_score_totals (
    event_id,
    event_guest_id,
    total_points,
    hands_played,
    hands_won,
    self_draw_wins,
    discard_wins,
    discard_losses,
    sessions_started,
    sessions_completed
  )
  with guest_base as (
    select
      guest.id as event_guest_id,
      guest.event_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
  ),
  points_totals as (
    select
      guest_base.event_guest_id,
      coalesce(sum(case when settlement.payee_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0)
      - coalesce(sum(case when settlement.payer_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0) as total_points
    from guest_base
    left join public.hand_settlements as settlement
      on settlement.payee_event_guest_id = guest_base.event_guest_id
      or settlement.payer_event_guest_id = guest_base.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.id = settlement.hand_result_id
    left join public.table_sessions as hand_session
      on hand_session.id = hand_result.table_session_id
    left join public.hand_false_win_penalties as penalty
      on penalty.id = settlement.hand_false_win_penalty_id
    left join public.table_sessions as penalty_session
      on penalty_session.id = penalty.table_session_id
    where settlement.id is null
      or (
        hand_session.event_id = target_event_id
        and hand_session.scoring_phase = 'tournament'
        and hand_result.status = 'recorded'
      )
      or (
        settlement.hand_result_id is null
        and penalty_session.event_id = target_event_id
        and penalty_session.scoring_phase = 'tournament'
        and penalty.status = 'pending'
      )
    group by guest_base.event_guest_id
  ),
  adjustment_totals as (
    select
      adjustment.event_guest_id,
      sum(adjustment.amount_points)::integer as total_points
    from public.event_score_adjustments as adjustment
    where adjustment.event_id = target_event_id
      and adjustment.adjustment_type = 'finals_champion_award'
    group by adjustment.event_guest_id
  ),
  hand_play_totals as (
    select
      seat.event_guest_id,
      count(hand_result.id) as hands_played
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  ),
  hand_result_totals as (
    select
      seat.event_guest_id,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index) as hands_won,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'self_draw') as self_draw_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'discard') as discard_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.win_type = 'discard' and hand_result.discarder_seat_index = seat.seat_index) as discard_losses
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  ),
  session_counts as (
    select
      seat.event_guest_id,
      count(distinct session.id) as sessions_started,
      count(distinct session.id) filter (where session.status = 'completed') as sessions_completed
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
    group by seat.event_guest_id
  )
  select
    target_event_id,
    guest_base.event_guest_id,
    coalesce(points_totals.total_points, 0)
      + coalesce(adjustment_totals.total_points, 0),
    coalesce(hand_play_totals.hands_played, 0),
    coalesce(hand_result_totals.hands_won, 0),
    coalesce(hand_result_totals.self_draw_wins, 0),
    coalesce(hand_result_totals.discard_wins, 0),
    coalesce(hand_result_totals.discard_losses, 0),
    coalesce(session_counts.sessions_started, 0),
    coalesce(session_counts.sessions_completed, 0)
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join adjustment_totals
    on adjustment_totals.event_guest_id = guest_base.event_guest_id
  left join hand_play_totals
    on hand_play_totals.event_guest_id = guest_base.event_guest_id
  left join hand_result_totals
    on hand_result_totals.event_guest_id = guest_base.event_guest_id
  left join session_counts
    on session_counts.event_guest_id = guest_base.event_guest_id;

  perform app_private.refresh_public_event_standings_snapshot(target_event_id);
end;
$$;

create or replace function app_private.pending_false_win_penalty_count(
  target_table_session_id uuid
)
returns integer
language sql
stable
set search_path = public
as $$
  select count(*)::integer
  from public.hand_false_win_penalties as penalty
  where penalty.table_session_id = target_table_session_id
    and penalty.status = 'pending'
$$;

create or replace function app_private.pending_false_win_penalty_seats(
  target_table_session_id uuid
)
returns integer[]
language sql
stable
set search_path = public
as $$
  select coalesce(
    array_agg(penalty.penalty_seat_index order by penalty.entered_at),
    array[]::integer[]
  )
  from public.hand_false_win_penalties as penalty
  where penalty.table_session_id = target_table_session_id
    and penalty.status = 'pending'
$$;

create or replace function app_private.attach_pending_false_win_penalties(
  target_table_session_id uuid,
  target_hand_result_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.hand_false_win_penalties
  set status = 'attached',
    hand_result_id = target_hand_result_id
  where table_session_id = target_table_session_id
    and status = 'pending';
end;
$$;

create or replace function public.record_false_win_penalty(
  target_table_session_id uuid,
  target_penalty_seat_index integer,
  target_correction_note text default null,
  target_client_mutation_id uuid default null,
  target_expected_recorded_hand_count integer default null,
  target_expected_last_recorded_hand_id uuid default null
)
returns public.hand_false_win_penalties
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  inserted_penalty public.hand_false_win_penalties%rowtype;
  existing_idempotent_penalty public.hand_false_win_penalties%rowtype;
  caller_guest_id uuid;
  base_points_value integer;
  current_recorded_hand_count integer;
  current_last_recorded_hand_id uuid;
  settlement_seat record;
begin
  session_row := app_private.require_owned_session(target_table_session_id);

  select *
  into session_row
  from public.table_sessions
  where id = session_row.id
  for update;

  perform app_private.require_event_for_scoring(session_row.event_id);

  if target_client_mutation_id is not null then
    select *
    into existing_idempotent_penalty
    from public.hand_false_win_penalties
    where client_mutation_id = target_client_mutation_id;

    if found then
      if existing_idempotent_penalty.table_session_id <> session_row.id then
        raise exception 'Client mutation id belongs to a different session.'
          using errcode = 'P0001',
                hint = 'offline_sync_conflict';
      end if;

      return existing_idempotent_penalty;
    end if;
  end if;

  if session_row.status <> 'active' then
    raise exception 'False win penalties can only be recorded for active sessions.'
      using errcode = 'P0001';
  end if;

  select
    count(*)::integer,
    (array_agg(id order by hand_number desc))[1]
  into current_recorded_hand_count, current_last_recorded_hand_id
  from public.hand_results
  where table_session_id = session_row.id
    and status = 'recorded';

  if target_expected_recorded_hand_count is not null
    and current_recorded_hand_count <> target_expected_recorded_hand_count then
    raise exception 'Current session hand count has changed.'
      using errcode = 'P0001',
            hint = 'offline_sync_conflict';
  end if;

  if target_expected_last_recorded_hand_id is not null
    and current_last_recorded_hand_id is distinct from target_expected_last_recorded_hand_id then
    raise exception 'Current last hand has changed.'
      using errcode = 'P0001',
            hint = 'offline_sync_conflict';
  end if;

  if target_expected_last_recorded_hand_id is null
    and target_expected_recorded_hand_count = 0
    and current_last_recorded_hand_id is not null then
    raise exception 'Current last hand has changed.'
      using errcode = 'P0001',
            hint = 'offline_sync_conflict';
  end if;

  if target_penalty_seat_index is null
    or target_penalty_seat_index not between 0 and 3 then
    raise exception 'False win penalties require a valid caller seat.'
      using errcode = 'P0001';
  end if;

  select seat.event_guest_id
  into caller_guest_id
  from public.table_session_seats as seat
  where seat.table_session_id = session_row.id
    and seat.seat_index = target_penalty_seat_index;

  if not found or caller_guest_id is null then
    raise exception 'False win caller seat must be occupied.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.hand_false_win_penalties as penalty
    where penalty.table_session_id = session_row.id
      and penalty.penalty_seat_index = target_penalty_seat_index
      and penalty.status = 'pending'
  ) then
    raise exception 'False win caller already has a pending penalty.'
      using errcode = 'P0001';
  end if;

  begin
    insert into public.hand_false_win_penalties (
      table_session_id,
      penalty_seat_index,
      fan_count,
      entered_by_user_id,
      entered_at,
      correction_note,
      client_mutation_id
    )
    values (
      session_row.id,
      target_penalty_seat_index,
      6,
      auth.uid(),
      now(),
      target_correction_note,
      target_client_mutation_id
    )
    returning *
    into inserted_penalty;
  exception when unique_violation then
    if target_client_mutation_id is null then
      raise;
    end if;

    select *
    into existing_idempotent_penalty
    from public.hand_false_win_penalties
    where client_mutation_id = target_client_mutation_id;

    if not found then
      raise;
    end if;

    if existing_idempotent_penalty.table_session_id <> session_row.id then
      raise exception 'Client mutation id belongs to a different session.'
        using errcode = 'P0001',
              hint = 'offline_sync_conflict';
    end if;

    return existing_idempotent_penalty;
  end;

  base_points_value := app_private.ruleset_base_points(session_row.ruleset_id, 6);

  for settlement_seat in
    select seat.event_guest_id
    from public.table_session_seats as seat
    where seat.table_session_id = session_row.id
      and seat.seat_index <> target_penalty_seat_index
      and seat.event_guest_id is not null
    order by seat.seat_index
  loop
    insert into public.hand_settlements (
      hand_result_id,
      hand_false_win_penalty_id,
      payer_event_guest_id,
      payee_event_guest_id,
      amount_points,
      multiplier_flags_json
    )
    values (
      null,
      inserted_penalty.id,
      caller_guest_id,
      settlement_seat.event_guest_id,
      base_points_value,
      to_jsonb(array['false_win_penalty']::text[])
    );
  end loop;

  perform app_private.refresh_event_score_totals(session_row.event_id);

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_false_win_penalty',
    inserted_penalty.id::text,
    'create',
    null,
    to_jsonb(inserted_penalty)
  );

  return inserted_penalty;
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
  penalty_row public.hand_false_win_penalties%rowtype;
  seat_guest_ids uuid[];
  initial_east integer;
  current_east integer;
  east_after integer;
  next_pass_count integer;
  dealer_rotated_flag boolean;
  completion_flag boolean;
  base_points_value integer;
  penalty_base_points_value integer;
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
          hand_false_win_penalty_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          null,
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

    for penalty_row in
      select *
      from public.hand_false_win_penalties as penalty
      where penalty.hand_result_id = hand_row.id
        and penalty.status = 'attached'
      order by penalty.entered_at asc
    loop
      penalty_base_points_value :=
        app_private.ruleset_base_points(session_row.ruleset_id, penalty_row.fan_count);
      payer_guest_id := seat_guest_ids[penalty_row.penalty_seat_index + 1];

      for seat_index in 0..3 loop
        if seat_index = penalty_row.penalty_seat_index then
          continue;
        end if;

        payee_guest_id := seat_guest_ids[seat_index + 1];

        insert into public.hand_settlements (
          hand_result_id,
          hand_false_win_penalty_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          penalty_row.id,
          payer_guest_id,
          payee_guest_id,
          penalty_base_points_value,
          to_jsonb(array['false_win_penalty']::text[])
        );
      end loop;
    end loop;

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

drop function if exists public.record_hand_result(
  uuid,
  text,
  integer,
  text,
  integer,
  integer,
  text,
  boolean,
  integer
);

create or replace function public.record_hand_result(
  target_table_session_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null,
  target_client_mutation_id uuid default null,
  target_expected_recorded_hand_count integer default null,
  target_expected_last_recorded_hand_id uuid default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  inserted_hand public.hand_results%rowtype;
  existing_idempotent_hand public.hand_results%rowtype;
  next_hand_number integer;
  current_recorded_hand_count integer;
  current_last_recorded_hand_id uuid;
begin
  session_row := app_private.require_owned_session(target_table_session_id);

  select *
  into session_row
  from public.table_sessions
  where id = session_row.id
  for update;

  perform app_private.require_event_for_scoring(session_row.event_id);

  if target_client_mutation_id is not null then
    select *
    into existing_idempotent_hand
    from public.hand_results
    where client_mutation_id = target_client_mutation_id;

    if found then
      if existing_idempotent_hand.table_session_id <> session_row.id then
        raise exception 'Client mutation id belongs to a different session.'
          using errcode = 'P0001',
                hint = 'offline_sync_conflict';
      end if;

      return existing_idempotent_hand;
    end if;
  end if;

  if session_row.status <> 'active' then
    raise exception 'Hands can only be recorded for active sessions.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    session_row.ruleset_id,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    target_dealer_was_waiting_at_draw,
    target_penalty_seat_index
  );

  if target_result_type = 'win'
    and target_winner_seat_index = any(
      app_private.pending_false_win_penalty_seats(session_row.id)
    ) then
    raise exception 'False win callers cannot win this hand.'
      using errcode = 'P0001';
  end if;

  select
    count(*)::integer,
    (array_agg(id order by hand_number desc))[1]
  into current_recorded_hand_count, current_last_recorded_hand_id
  from public.hand_results
  where table_session_id = session_row.id
    and status = 'recorded';

  if target_expected_recorded_hand_count is not null
    and current_recorded_hand_count <> target_expected_recorded_hand_count then
    raise exception 'Current session hand count has changed.'
      using errcode = 'P0001',
            hint = 'offline_sync_conflict';
  end if;

  if target_expected_last_recorded_hand_id is not null
    and current_last_recorded_hand_id is distinct from target_expected_last_recorded_hand_id then
    raise exception 'Current last hand has changed.'
      using errcode = 'P0001',
            hint = 'offline_sync_conflict';
  end if;

  if target_expected_last_recorded_hand_id is null
    and target_expected_recorded_hand_count = 0
    and current_last_recorded_hand_id is not null then
    raise exception 'Current last hand has changed.'
      using errcode = 'P0001',
            hint = 'offline_sync_conflict';
  end if;

  select coalesce(max(hand_number), 0) + 1
  into next_hand_number
  from public.hand_results
  where
    table_session_id = session_row.id
    and status = 'recorded';

  begin
    insert into public.hand_results (
      table_session_id,
      hand_number,
      result_type,
      winner_seat_index,
      win_type,
      discarder_seat_index,
      penalty_seat_index,
      fan_count,
      base_points,
      dealer_was_waiting_at_draw,
      east_seat_index_before_hand,
      east_seat_index_after_hand,
      dealer_rotated,
      session_completed_after_hand,
      status,
      entered_by_user_id,
      entered_at,
      correction_note,
      client_mutation_id
    )
    values (
      session_row.id,
      next_hand_number,
      target_result_type,
      target_winner_seat_index,
      target_win_type,
      target_discarder_seat_index,
      target_penalty_seat_index,
      case
        when target_result_type = 'false_win_penalty' then 6
        else target_fan_count
      end,
      null,
      case
        when target_result_type = 'washout' then target_dealer_was_waiting_at_draw
        else null
      end,
      session_row.current_dealer_seat_index,
      session_row.current_dealer_seat_index,
      false,
      false,
      'recorded',
      auth.uid(),
      now(),
      target_correction_note,
      target_client_mutation_id
    )
    returning *
    into inserted_hand;
  exception when unique_violation then
    if target_client_mutation_id is null then
      raise;
    end if;

    select *
    into existing_idempotent_hand
    from public.hand_results
    where client_mutation_id = target_client_mutation_id;

    if not found then
      raise;
    end if;

    if existing_idempotent_hand.table_session_id <> session_row.id then
      raise exception 'Client mutation id belongs to a different session.'
        using errcode = 'P0001',
              hint = 'offline_sync_conflict';
    end if;

    return existing_idempotent_hand;
  end;

  if target_result_type in ('win', 'washout') then
    perform app_private.attach_pending_false_win_penalties(
      session_row.id,
      inserted_hand.id
    );

    update public.hand_settlements
    set hand_result_id = inserted_hand.id
    where hand_result_id is null
      and hand_false_win_penalty_id in (
        select penalty.id
        from public.hand_false_win_penalties as penalty
        where penalty.hand_result_id = inserted_hand.id
          and penalty.status = 'attached'
      );
  end if;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into inserted_hand
  from public.hand_results
  where id = inserted_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    inserted_hand.id::text,
    'create',
    null,
    to_jsonb(inserted_hand)
  );

  return inserted_hand;
end;
$$;

create or replace function public.edit_hand_result(
  target_hand_result_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_hand public.hand_results%rowtype;
  updated_hand public.hand_results%rowtype;
  session_row public.table_sessions%rowtype;
begin
  existing_hand := app_private.require_owned_hand_result(target_hand_result_id);
  session_row := app_private.require_owned_session(existing_hand.table_session_id);
  perform app_private.require_event_for_hand_correction(session_row.event_id);

  if existing_hand.status <> 'recorded' then
    raise exception 'Only recorded hands can be edited.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    session_row.ruleset_id,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    target_dealer_was_waiting_at_draw,
    target_penalty_seat_index
  );

  if target_result_type = 'win'
    and exists (
      select 1
      from public.hand_false_win_penalties as penalty
      where penalty.hand_result_id = existing_hand.id
        and penalty.status = 'attached'
        and penalty.penalty_seat_index = target_winner_seat_index
    ) then
    raise exception 'False win callers cannot win this hand.'
      using errcode = 'P0001';
  end if;

  update public.hand_results
  set
    result_type = target_result_type,
    winner_seat_index = target_winner_seat_index,
    win_type = target_win_type,
    discarder_seat_index = target_discarder_seat_index,
    penalty_seat_index = target_penalty_seat_index,
    fan_count = case
      when target_result_type = 'false_win_penalty' then 6
      else target_fan_count
    end,
    dealer_was_waiting_at_draw = case
      when target_result_type = 'washout' then target_dealer_was_waiting_at_draw
      else null
    end,
    correction_note = target_correction_note
  where id = existing_hand.id
  returning *
  into updated_hand;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into updated_hand
  from public.hand_results
  where id = updated_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    updated_hand.id::text,
    'edit',
    to_jsonb(existing_hand),
    to_jsonb(updated_hand)
  );

  return updated_hand;
end;
$$;

create or replace function public.void_hand_result(
  target_hand_result_id uuid,
  target_correction_note text default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_hand public.hand_results%rowtype;
  updated_hand public.hand_results%rowtype;
  session_row public.table_sessions%rowtype;
begin
  existing_hand := app_private.require_owned_hand_result(target_hand_result_id);
  session_row := app_private.require_owned_session(existing_hand.table_session_id);
  perform app_private.require_event_for_hand_correction(session_row.event_id);

  if existing_hand.status = 'voided' then
    return existing_hand;
  end if;

  update public.hand_results
  set
    status = 'voided',
    correction_note = coalesce(target_correction_note, correction_note)
  where id = existing_hand.id
  returning *
  into updated_hand;

  update public.hand_false_win_penalties
  set status = 'voided'
  where hand_result_id = existing_hand.id
    and status = 'attached';

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into updated_hand
  from public.hand_results
  where id = updated_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    updated_hand.id::text,
    'void',
    to_jsonb(existing_hand),
    to_jsonb(updated_hand)
  );

  return updated_hand;
end;
$$;

drop function if exists public.list_event_hand_ledger(uuid);

create or replace function public.list_event_hand_ledger(target_event_id uuid)
returns table (
  event_id uuid,
  table_id uuid,
  table_label text,
  session_id uuid,
  session_number_for_table integer,
  hand_id uuid,
  hand_number integer,
  entered_at timestamptz,
  result_type text,
  status text,
  win_type text,
  fan_count integer,
  penalty_seat_index integer,
  false_win_penalties_json jsonb,
  bonus_round_id uuid,
  bonus_table_role text,
  has_settlements boolean,
  cells jsonb,
  ledger_row_type text,
  adjustment_id uuid,
  adjustment_type text,
  adjustment_amount_points integer,
  adjustment_event_guest_id uuid,
  adjustment_display_name text,
  adjustment_context_json jsonb
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
      session.session_number_for_table,
      hand_result.id as hand_id,
      hand_result.hand_number,
      hand_result.entered_at,
      hand_result.result_type,
      hand_result.status,
      hand_result.win_type,
      hand_result.fan_count,
      hand_result.penalty_seat_index,
      false_win_penalty_summary.false_win_penalties_json,
      session.bonus_round_id,
      session.bonus_table_role,
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
    left join lateral (
      select jsonb_agg(
        jsonb_build_object(
          'penaltySeatIndex', penalty.penalty_seat_index,
          'fanCount', penalty.fan_count
        )
        order by penalty.entered_at
      ) as false_win_penalties_json
      from public.hand_false_win_penalties as penalty
      where penalty.hand_result_id = hand_result.id
        and penalty.status = 'attached'
    ) as false_win_penalty_summary on true
  ),
  ledger_hand_rows as (
    select
      hand_row.event_id,
      hand_row.table_id,
      hand_row.table_label,
      hand_row.session_id,
      hand_row.session_number_for_table,
      hand_row.hand_id,
      hand_row.hand_number,
      hand_row.entered_at,
      hand_row.result_type,
      hand_row.status,
      hand_row.win_type,
      hand_row.fan_count,
      hand_row.penalty_seat_index,
      coalesce(hand_row.false_win_penalties_json, '[]'::jsonb)
        as false_win_penalties_json,
      hand_row.bonus_round_id,
      hand_row.bonus_table_role,
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
      ) as cells,
      'hand'::text as ledger_row_type,
      null::uuid as adjustment_id,
      null::text as adjustment_type,
      null::integer as adjustment_amount_points,
      null::uuid as adjustment_event_guest_id,
      null::text as adjustment_display_name,
      null::jsonb as adjustment_context_json
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
      hand_row.session_number_for_table,
      hand_row.hand_id,
      hand_row.hand_number,
      hand_row.entered_at,
      hand_row.result_type,
      hand_row.status,
      hand_row.win_type,
      hand_row.fan_count,
      hand_row.penalty_seat_index,
      hand_row.false_win_penalties_json,
      hand_row.bonus_round_id,
      hand_row.bonus_table_role,
      hand_row.has_settlements
  ),
  ledger_adjustment_rows as (
    select
      adjustment.event_id,
      null::uuid as table_id,
      null::text as table_label,
      adjustment.source_table_session_id as session_id,
      null::integer as session_number_for_table,
      null::uuid as hand_id,
      null::integer as hand_number,
      adjustment.created_at as entered_at,
      null::text as result_type,
      'recorded'::text as status,
      null::text as win_type,
      null::integer as fan_count,
      null::integer as penalty_seat_index,
      '[]'::jsonb as false_win_penalties_json,
      source_session.bonus_round_id,
      source_session.bonus_table_role,
      false as has_settlements,
      '[]'::jsonb as cells,
      'adjustment'::text as ledger_row_type,
      adjustment.id as adjustment_id,
      adjustment.adjustment_type,
      adjustment.amount_points as adjustment_amount_points,
      adjustment.event_guest_id as adjustment_event_guest_id,
      guest.display_name as adjustment_display_name,
      adjustment.context_json as adjustment_context_json
    from authorized_event
    join public.event_score_adjustments as adjustment
      on adjustment.event_id = authorized_event.id
    join public.event_guests as guest
      on guest.id = adjustment.event_guest_id
    left join public.table_sessions as source_session
      on source_session.id = adjustment.source_table_session_id
    where adjustment.adjustment_type = 'finals_champion_award'
  )
  select *
  from ledger_hand_rows
  union all
  select *
  from ledger_adjustment_rows
  order by entered_at desc, session_id desc, hand_number desc nulls last;
$$;

grant execute on function public.record_false_win_penalty(uuid, integer, text, uuid, integer, uuid)
  to authenticated;

grant execute on function public.list_event_hand_ledger(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
