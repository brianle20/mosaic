-- Keep the hand evidence review queue limited to reviewable stored photos.

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
    and hand_result.status <> 'voided'
    and photo.photo_upload_status = 'uploaded'
    and nullif(btrim(photo.storage_bucket), '') is not null
    and nullif(btrim(photo.storage_path), '') is not null
  order by photo.created_at asc, photo.id asc;
end;
$$;

grant execute on function public.list_hand_evidence_review(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
