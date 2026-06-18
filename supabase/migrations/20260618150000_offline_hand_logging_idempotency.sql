alter table public.hand_results
  add column if not exists client_mutation_id uuid;

create unique index if not exists hand_results_client_mutation_id_unique
  on public.hand_results (client_mutation_id)
  where client_mutation_id is not null;

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

select pg_notify('pgrst', 'reload schema');
