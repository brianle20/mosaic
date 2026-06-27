drop function if exists public.record_hand_result(
  uuid,
  text,
  integer,
  text,
  integer,
  integer,
  text,
  boolean,
  integer,
  uuid,
  integer,
  uuid
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
  target_expected_last_recorded_hand_id uuid default null,
  target_photo_client_id uuid default null,
  target_photo_captured_at timestamptz default null
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
  allow_completed_late_hand boolean := false;
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

  allow_completed_late_hand :=
    session_row.status = 'completed'
    and session_row.scoring_phase in ('tournament', 'bonus')
    and not exists (
      select 1
      from public.hand_results as completion_hand
      where completion_hand.table_session_id = session_row.id
        and completion_hand.status = 'recorded'
        and completion_hand.session_completed_after_hand
    );

  if session_row.status <> 'active' and not allow_completed_late_hand then
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
    and (target_photo_client_id is null or target_photo_captured_at is null)
  then
    raise exception 'Winning hand photo is required.'
      using errcode = 'P0001';
  end if;

  if target_result_type <> 'win'
    and (target_photo_client_id is not null or target_photo_captured_at is not null)
  then
    raise exception 'Only winning hands can include photo metadata.'
      using errcode = 'P0001';
  end if;

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

  if target_result_type = 'win' then
    insert into public.hand_photos (
      hand_result_id,
      client_photo_id,
      captured_by,
      captured_at,
      photo_capture_status,
      photo_upload_status,
      visibility
    )
    values (
      inserted_hand.id,
      target_photo_client_id,
      auth.uid(),
      target_photo_captured_at,
      'captured',
      'pending',
      'host_admin_only'
    );
  end if;

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

select pg_notify('pgrst', 'reload schema');
