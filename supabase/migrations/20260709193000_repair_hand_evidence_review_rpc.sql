-- Repair hand evidence review RPCs after the original applied migration drifted
-- from the local migration file.

alter table public.hand_tile_entries
  drop constraint if exists hand_tile_entries_review_check;

alter table public.hand_tile_entries
  add constraint hand_tile_entries_review_check
  check (
    review_status in (
      'unreviewed',
      'matched',
      'under_declared',
      'flagged',
      'resolved'
    )
  );

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

create or replace function public.upsert_hand_tile_entry(
  target_hand_result_id uuid,
  target_tiles_json jsonb,
  target_calculated_fan_count integer,
  target_calculation_version text
)
returns public.hand_tile_entries
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  hand_row public.hand_results%rowtype;
  upserted public.hand_tile_entries%rowtype;
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
    case
      when target_calculated_fan_count is null or hand_row.fan_count is null then 'unreviewed'
      when target_calculated_fan_count = hand_row.fan_count then 'matched'
      when target_calculated_fan_count > hand_row.fan_count then 'under_declared'
      when target_calculated_fan_count < hand_row.fan_count then 'flagged'
      else 'unreviewed'
    end
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

grant execute on function public.upsert_hand_tile_entry(uuid, jsonb, integer, text)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
