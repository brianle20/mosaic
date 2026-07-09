alter table public.hand_results
  add column if not exists win_bonuses text[];

create or replace function app_private.validate_win_bonuses(
  target_result_type text,
  target_win_bonuses text[] default null
)
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if target_result_type <> 'win' and target_win_bonuses is not null then
    raise exception 'Only win hands can include win bonuses.'
      using errcode = 'P0001';
  end if;

  if target_win_bonuses is null then
    return;
  end if;

  if exists (
    select 1
    from unnest(target_win_bonuses) as bonus(bonus_id)
    where bonus.bonus_id is null
      or bonus.bonus_id <> all(array[
      'concealed_hand',
      'moon_under_the_sea',
      'robbing_the_kong',
      'win_by_kong_replacement',
      'double_kong_replacement',
      'blessing_of_heaven',
      'blessing_of_earth',
      'blessing_of_man'
    ])
  ) then
    raise exception 'Unknown win bonus.'
      using errcode = 'P0001';
  end if;

  if (
    select count(*) from unnest(target_win_bonuses)
  ) <> (
    select count(distinct bonus_id)
    from unnest(target_win_bonuses) as bonus(bonus_id)
  ) then
    raise exception 'Duplicate win bonuses are not allowed.'
      using errcode = 'P0001';
  end if;
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
  integer,
  uuid,
  integer,
  uuid,
  uuid,
  timestamptz
);

create or replace function public.record_hand_result(
  target_table_session_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_win_bonuses text[] default null,
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

  perform app_private.validate_win_bonuses(
    target_result_type,
    target_win_bonuses
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
      win_bonuses,
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
      case
        when target_result_type = 'win' then target_win_bonuses
        else null
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

drop function if exists public.edit_hand_result(
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

create or replace function public.edit_hand_result(
  target_hand_result_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_win_bonuses text[] default null,
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

  perform app_private.validate_win_bonuses(
    target_result_type,
    target_win_bonuses
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
    win_bonuses = case
      when target_result_type = 'win' then target_win_bonuses
      else null
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

drop function if exists public.upsert_hand_tile_entry(
  uuid,
  jsonb,
  integer,
  text
);

drop function if exists public.upsert_hand_tile_entry(
  uuid,
  jsonb,
  integer,
  text,
  text
);

create or replace function public.upsert_hand_tile_entry(
  target_hand_result_id uuid,
  target_tiles_json jsonb,
  target_calculated_fan_count integer,
  target_calculation_version text,
  target_review_status text default null
)
returns public.hand_tile_entries
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  hand_row public.hand_results%rowtype;
  upserted public.hand_tile_entries%rowtype;
  resolved_review_status text;
begin
  select hand_result.*
  into hand_row
  from public.hand_results as hand_result
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  where hand_result.id = target_hand_result_id
    and app_private.can_manage_event(session.event_id);

  if hand_row.id is null then
    raise exception 'Hand result not found for current host.'
      using errcode = 'P0001';
  end if;

  if hand_row.result_type <> 'win' then
    raise exception 'Tile entry is only available for winning hands.'
      using errcode = 'P0001';
  end if;

  if jsonb_typeof(target_tiles_json) not in ('object', 'array') then
    raise exception 'Tile entry must be a JSON object or array.'
      using errcode = 'P0001';
  end if;

  if target_calculated_fan_count is not null
    and target_calculated_fan_count < 0 then
    raise exception 'Calculated fan count cannot be negative.'
      using errcode = 'P0001';
  end if;

  if nullif(btrim(target_calculation_version), '') is null then
    raise exception 'Calculation version is required.'
      using errcode = 'P0001';
  end if;

  if target_review_status is not null
    and target_review_status <> all(array[
      'unreviewed',
      'matched',
      'flagged',
      'under_declared',
      'resolved'
    ]) then
    raise exception 'Unknown tile review status.'
      using errcode = 'P0001';
  end if;

  resolved_review_status := coalesce(
    target_review_status,
    case
      when target_calculated_fan_count is null or hand_row.fan_count is null then 'unreviewed'
      when target_calculated_fan_count = hand_row.fan_count then 'matched'
      when target_calculated_fan_count > hand_row.fan_count then 'under_declared'
      when target_calculated_fan_count < hand_row.fan_count then 'flagged'
      else 'unreviewed'
    end
  );

  insert into public.hand_tile_entries (
    hand_result_id,
    entered_by,
    tiles_json,
    calculated_fan_count,
    declared_fan_count,
    calculation_version,
    review_status
  )
  values (
    target_hand_result_id,
    auth.uid(),
    target_tiles_json,
    target_calculated_fan_count,
    hand_row.fan_count,
    target_calculation_version,
    resolved_review_status
  )
  on conflict (hand_result_id) do update
    set entered_by = excluded.entered_by,
        entered_at = now(),
        tiles_json = excluded.tiles_json,
        calculated_fan_count = excluded.calculated_fan_count,
        declared_fan_count = excluded.declared_fan_count,
        calculation_version = excluded.calculation_version,
        review_status = excluded.review_status,
        updated_at = now()
  returning * into upserted;

  return upserted;
end;
$$;

grant execute on function public.upsert_hand_tile_entry(uuid, jsonb, integer, text, text)
  to authenticated;

drop function if exists public.list_hand_evidence_review(uuid);

create or replace function public.list_hand_evidence_review(target_event_id uuid)
returns table (
  photo_id uuid,
  hand_result_id uuid,
  client_photo_id uuid,
  captured_by uuid,
  captured_at timestamptz,
  local_capture_path text,
  storage_bucket text,
  storage_path text,
  photo_capture_status text,
  photo_upload_status text,
  visibility text,
  hand_number integer,
  table_label text,
  winner_name text,
  win_type text,
  declared_fan_count integer,
  win_bonuses text[],
  seat_wind_tile_id text,
  round_wind_tile_id text,
  tile_entry_id uuid,
  entered_by uuid,
  entered_at timestamptz,
  tiles_json jsonb,
  calculated_fan_count integer,
  fan_delta integer,
  calculation_version text,
  validation_status text,
  review_status text
)
language plpgsql
security definer
set search_path = public, app_private
as $$
begin
  if not app_private.can_manage_event(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  return query
  select
    photo.id as photo_id,
    photo.hand_result_id,
    photo.client_photo_id,
    photo.captured_by,
    photo.captured_at,
    photo.local_capture_path,
    photo.storage_bucket,
    photo.storage_path,
    photo.photo_capture_status,
    photo.photo_upload_status,
    photo.visibility,
    hand_result.hand_number,
    event_table.label as table_label,
    winner_guest.display_name as winner_name,
    hand_result.win_type,
    hand_result.fan_count as declared_fan_count,
    hand_result.win_bonuses,
    case (hand_result.winner_seat_index - hand_result.east_seat_index_before_hand + 4) % 4
      when 0 then 'east'
      when 1 then 'south'
      when 2 then 'west'
      when 3 then 'north'
      else null
    end as seat_wind_tile_id,
    event_record.prevailing_wind as round_wind_tile_id,
    tile_entry.id as tile_entry_id,
    tile_entry.entered_by,
    tile_entry.entered_at,
    tile_entry.tiles_json,
    tile_entry.calculated_fan_count,
    tile_entry.fan_delta,
    tile_entry.calculation_version,
    tile_entry.validation_status,
    tile_entry.review_status
  from public.hand_photos as photo
  join public.hand_results as hand_result
    on hand_result.id = photo.hand_result_id
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  join public.events as event_record
    on event_record.id = session.event_id
  left join public.event_tables as event_table
    on event_table.id = session.event_table_id
  left join public.table_session_seats as winner_seat
    on winner_seat.table_session_id = session.id
    and winner_seat.seat_index = hand_result.winner_seat_index
  left join public.event_guests as winner_guest
    on winner_guest.id = winner_seat.event_guest_id
  left join public.hand_tile_entries as tile_entry
    on tile_entry.hand_result_id = hand_result.id
  where session.event_id = target_event_id
    and hand_result.result_type = 'win'
  order by photo.created_at asc, photo.id asc;
end;
$$;

grant execute on function public.list_hand_evidence_review(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
