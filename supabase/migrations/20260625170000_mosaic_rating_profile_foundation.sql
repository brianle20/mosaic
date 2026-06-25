-- Mosaic Rating/Profile database foundation.

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  public_profile_slug text unique,
  rating_state_json jsonb not null default '{}'::jsonb,
  profile_state_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint players_display_name_nonempty
    check (length(btrim(display_name)) > 0)
);

drop trigger if exists players_touch_updated_at on public.players;
create trigger players_touch_updated_at
before update on public.players
for each row
execute function app_private.touch_updated_at();

alter table public.event_guests
  add column if not exists player_id uuid references public.players(id);

create index if not exists event_guests_player_idx
  on public.event_guests (player_id)
  where player_id is not null;

create table if not exists public.hand_photos (
  id uuid primary key default gen_random_uuid(),
  hand_result_id uuid not null references public.hand_results(id) on delete cascade,
  client_photo_id uuid not null,
  captured_by uuid references public.users(id) on delete set null,
  captured_at timestamptz not null,
  local_capture_path text,
  storage_bucket text,
  storage_path text,
  photo_capture_status text not null default 'captured',
  photo_upload_status text not null default 'pending',
  upload_error text,
  visibility text not null default 'host_admin_only',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hand_photos_client_photo_unique unique (client_photo_id),
  constraint hand_photos_one_per_hand unique (hand_result_id),
  constraint hand_photos_capture_status_check
    check (photo_capture_status in ('captured')),
  constraint hand_photos_upload_status_check
    check (photo_upload_status in ('pending', 'uploaded', 'failed')),
  constraint hand_photos_visibility_check
    check (visibility = 'host_admin_only'),
  constraint hand_photos_uploaded_storage_check
    check (
      photo_upload_status <> 'uploaded'
      or (
        nullif(btrim(storage_bucket), '') is not null
        and nullif(btrim(storage_path), '') is not null
      )
    )
);

create index if not exists hand_photos_hand_result_idx
  on public.hand_photos (hand_result_id);

create index if not exists hand_photos_upload_status_idx
  on public.hand_photos (photo_upload_status, created_at);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('hand-photos', 'hand-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists hand_photos_host_admin_storage_insert
  on storage.objects;
create policy hand_photos_host_admin_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'hand-photos'
  and split_part(name, '/', 1) = 'events'
  and split_part(name, '/', 3) = 'hands'
  and (app_private.can_manage_event(split_part(name, '/', 2)::uuid) or app_private.can_score_qualification(split_part(name, '/', 2)::uuid) or app_private.can_score_tournament(split_part(name, '/', 2)::uuid) or app_private.can_score_bonus(split_part(name, '/', 2)::uuid))
);

drop policy if exists hand_photos_host_admin_storage_update
  on storage.objects;
create policy hand_photos_host_admin_storage_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'hand-photos'
  and split_part(name, '/', 1) = 'events'
  and split_part(name, '/', 3) = 'hands'
  and app_private.can_manage_event(split_part(name, '/', 2)::uuid)
)
with check (
  bucket_id = 'hand-photos'
  and split_part(name, '/', 1) = 'events'
  and split_part(name, '/', 3) = 'hands'
  and app_private.can_manage_event(split_part(name, '/', 2)::uuid)
);

drop policy if exists hand_photos_host_admin_storage_select
  on storage.objects;
create policy hand_photos_host_admin_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'hand-photos'
  and split_part(name, '/', 1) = 'events'
  and split_part(name, '/', 3) = 'hands'
  and app_private.can_manage_event(split_part(name, '/', 2)::uuid)
);

drop trigger if exists hand_photos_touch_updated_at on public.hand_photos;
create trigger hand_photos_touch_updated_at
before update on public.hand_photos
for each row
execute function app_private.touch_updated_at();

create table if not exists public.hand_tile_entries (
  id uuid primary key default gen_random_uuid(),
  hand_result_id uuid not null references public.hand_results(id) on delete cascade,
  entered_by uuid references public.users(id) on delete set null,
  entered_at timestamptz not null default now(),
  tiles_json jsonb not null,
  calculated_fan_count integer,
  declared_fan_count integer,
  fan_delta integer generated always as (
    case
      when calculated_fan_count is null or declared_fan_count is null then null
      else declared_fan_count - calculated_fan_count
    end
  ) stored,
  calculation_version text not null,
  validation_status text not null default 'valid',
  review_status text not null default 'unreviewed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hand_tile_entries_one_per_hand unique (hand_result_id),
  constraint hand_tile_entries_tiles_json_shape_check
    check (jsonb_typeof(tiles_json) in ('object', 'array')),
  constraint hand_tile_entries_calculated_fan_nonnegative_check
    check (calculated_fan_count is null or calculated_fan_count >= 0),
  constraint hand_tile_entries_declared_fan_nonnegative_check
    check (declared_fan_count is null or declared_fan_count >= 0),
  constraint hand_tile_entries_calculation_version_nonempty
    check (length(btrim(calculation_version)) > 0),
  constraint hand_tile_entries_validation_check
    check (validation_status in ('valid', 'invalid')),
  constraint hand_tile_entries_review_check
    check (review_status in ('unreviewed', 'matched', 'under_declared', 'flagged', 'resolved'))
);

create index if not exists hand_tile_entries_hand_result_idx
  on public.hand_tile_entries (hand_result_id);

create index if not exists hand_tile_entries_review_status_idx
  on public.hand_tile_entries (review_status, entered_at);

drop trigger if exists hand_tile_entries_touch_updated_at
  on public.hand_tile_entries;
create trigger hand_tile_entries_touch_updated_at
before update on public.hand_tile_entries
for each row
execute function app_private.touch_updated_at();

create table if not exists public.rating_snapshots (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  event_id uuid references public.events(id) on delete set null,
  table_session_id uuid references public.table_sessions(id) on delete set null,
  calculation_batch_id uuid not null default gen_random_uuid(),
  rating_before integer,
  rating_after integer not null,
  rating_delta integer not null default 0,
  provisional_state text not null,
  source_quality text not null,
  inputs_version text not null,
  inputs_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint rating_snapshots_provisional_check
    check (provisional_state in ('provisional', 'semi_provisional', 'established')),
  constraint rating_snapshots_source_quality_check
    check (source_quality in ('legacy_standings', 'mosaic_hand_ledger', 'photo_evidence', 'tile_enriched')),
  constraint rating_snapshots_inputs_version_nonempty
    check (length(btrim(inputs_version)) > 0)
);

create index if not exists rating_snapshots_player_created_idx
  on public.rating_snapshots (player_id, created_at desc);

create index if not exists rating_snapshots_event_idx
  on public.rating_snapshots (event_id)
  where event_id is not null;

create table if not exists public.profile_snapshots (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  event_id uuid references public.events(id) on delete set null,
  profile_dimensions_json jsonb not null,
  style_archetype text,
  confidence text not null,
  source_quality text not null,
  tile_derived_confidence text not null,
  generated_from_official_data_through timestamptz,
  generated_from_tile_data_through timestamptz,
  inputs_version text not null,
  private_review_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint profile_snapshots_dimensions_shape_check
    check (jsonb_typeof(profile_dimensions_json) = 'object'),
  constraint profile_snapshots_confidence_check
    check (confidence in ('early_read', 'developing_profile', 'established_profile')),
  constraint profile_snapshots_source_quality_check
    check (source_quality in ('legacy_standings', 'mosaic_hand_ledger', 'photo_evidence', 'tile_enriched')),
  constraint profile_snapshots_tile_confidence_check
    check (tile_derived_confidence in ('none', 'partial', 'full')),
  constraint profile_snapshots_inputs_version_nonempty
    check (length(btrim(inputs_version)) > 0)
);

create index if not exists profile_snapshots_player_created_idx
  on public.profile_snapshots (player_id, created_at desc);

create index if not exists profile_snapshots_event_idx
  on public.profile_snapshots (event_id)
  where event_id is not null;

alter table public.players enable row level security;
alter table public.hand_photos enable row level security;
alter table public.hand_tile_entries enable row level security;
alter table public.rating_snapshots enable row level security;
alter table public.profile_snapshots enable row level security;

drop policy if exists hand_photos_host_admin_select on public.hand_photos;
create policy hand_photos_host_admin_select
on public.hand_photos
for select
to authenticated
using (
  visibility = 'host_admin_only'
  and exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_photos.hand_result_id
      and app_private.can_manage_event(session.event_id)
  )
);

drop policy if exists hand_photos_scorer_insert on public.hand_photos;
create policy hand_photos_scorer_insert
on public.hand_photos
for insert
to authenticated
with check (
  visibility = 'host_admin_only'
  and captured_by = auth.uid()
  and exists (
    select 1
    from public.hand_results as hand_result
    where hand_result.id = hand_photos.hand_result_id
      and app_private.can_score_session(hand_result.table_session_id)
  )
);

drop policy if exists hand_photos_host_admin_update on public.hand_photos;
create policy hand_photos_host_admin_update
on public.hand_photos
for update
to authenticated
using (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_photos.hand_result_id
      and app_private.can_manage_event(session.event_id)
  )
)
with check (
  visibility = 'host_admin_only'
  and exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_photos.hand_result_id
      and app_private.can_manage_event(session.event_id)
  )
);

drop policy if exists hand_tile_entries_host_admin_select
  on public.hand_tile_entries;
create policy hand_tile_entries_host_admin_select
on public.hand_tile_entries
for select
to authenticated
using (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_tile_entries.hand_result_id
      and app_private.can_manage_event(session.event_id)
  )
);

drop policy if exists hand_tile_entries_host_admin_insert
  on public.hand_tile_entries;
create policy hand_tile_entries_host_admin_insert
on public.hand_tile_entries
for insert
to authenticated
with check (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_tile_entries.hand_result_id
      and app_private.can_manage_event(session.event_id)
  )
);

drop policy if exists hand_tile_entries_host_admin_update
  on public.hand_tile_entries;
create policy hand_tile_entries_host_admin_update
on public.hand_tile_entries
for update
to authenticated
using (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_tile_entries.hand_result_id
      and app_private.can_manage_event(session.event_id)
  )
)
with check (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_tile_entries.hand_result_id
      and app_private.can_manage_event(session.event_id)
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

create or replace function public.get_player_mosaic_profile(target_player_id uuid)
returns jsonb
language sql
security definer
set search_path = public, app_private
as $$
  with public_player as (
    select
      player.id,
      player.display_name,
      player.public_profile_slug
    from public.players as player
    where player.id = target_player_id
      and player.public_profile_slug is not null
  ),
  latest_rating as (
    select rating.*
    from public.rating_snapshots as rating
    join public_player as player
      on player.id = rating.player_id
    order by rating.created_at desc, rating.id desc
    limit 1
  ),
  latest_profile as (
    select profile.*
    from public.profile_snapshots as profile
    join public_player as player
      on player.id = profile.player_id
    order by profile.created_at desc, profile.id desc
    limit 1
  )
  select jsonb_build_object(
    'playerId', player.id,
    'player', jsonb_build_object(
        'id', player.id,
        'displayName', player.display_name,
        'publicProfileSlug', player.public_profile_slug
    ),
    'rating', (
      select jsonb_build_object(
        'ratingBefore', rating.rating_before,
        'ratingAfter', rating.rating_after,
        'ratingDelta', rating.rating_delta,
        'provisionalState', rating.provisional_state,
        'createdAt', rating.created_at
      )
      from latest_rating as rating
    ),
    'profile', (
      select jsonb_build_object(
        'profileDimensions', profile.profile_dimensions_json,
        'styleArchetype', profile.style_archetype,
        'confidence', profile.confidence,
        'tileDerivedConfidence', profile.tile_derived_confidence,
        'createdAt', profile.created_at
      )
      from latest_profile as profile
    )
  )
  from public_player as player;
$$;

create or replace function app_private.refresh_mosaic_player_snapshots(
  target_player_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, app_private
as $$
begin
  -- Initial snapshot projection is implemented in a later task.
  return;
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

drop function if exists public.record_hand_photo(uuid, uuid, timestamptz, text, text);

create or replace function public.record_hand_photo(
  target_hand_result_id uuid,
  target_client_photo_id uuid,
  target_captured_at timestamptz,
  target_storage_bucket text,
  target_storage_path text
)
returns public.hand_photos
language plpgsql
security definer
set search_path = public
as $$
declare
  photo_row public.hand_photos%rowtype;
  event_id uuid;
  expected_storage_path text;
begin
  if nullif(btrim(target_storage_bucket), '') is null then
    raise exception 'Storage bucket is required.'
      using errcode = 'P0001';
  end if;

  if nullif(btrim(target_storage_path), '') is null then
    raise exception 'Storage path is required.'
      using errcode = 'P0001';
  end if;

  select photo.*
  into photo_row
  from public.hand_photos as photo
  join public.hand_results as hand_result
    on hand_result.id = photo.hand_result_id
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  where photo.hand_result_id = target_hand_result_id
    and photo.client_photo_id = target_client_photo_id
    and photo.visibility = 'host_admin_only'
    and app_private.can_score_session(hand_result.table_session_id)
  for update of photo;

  if not found then
    raise exception 'Hand photo not found for current host.'
      using errcode = 'P0001';
  end if;

  select session.event_id
  into event_id
  from public.hand_results as hand_result
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  where hand_result.id = photo_row.hand_result_id;

  if photo_row.photo_upload_status = 'uploaded' then
    return photo_row;
  end if;

  if photo_row.photo_upload_status <> 'pending' then
    raise exception 'Hand photo is not pending upload.'
      using errcode = 'P0001';
  end if;

  if target_storage_bucket <> 'hand-photos' then
    raise exception 'Invalid hand photo storage bucket.'
      using errcode = 'P0001';
  end if;

  expected_storage_path :=
    'events/' || event_id::text ||
    '/hands/' || target_hand_result_id::text ||
    '/' || target_client_photo_id::text || '.jpg';
  if target_storage_path <> expected_storage_path then
    raise exception 'Invalid hand photo storage path.'
      using errcode = 'P0001';
  end if;

  update public.hand_photos
  set captured_at = target_captured_at,
      storage_bucket = target_storage_bucket,
      storage_path = target_storage_path,
      photo_upload_status = 'uploaded',
      upload_error = null,
      updated_at = now()
  where id = photo_row.id
    and photo_upload_status = 'pending'
    and visibility = 'host_admin_only'
  returning *
  into photo_row;

  return photo_row;
end;
$$;

grant execute on function public.list_hand_evidence_review(uuid) to authenticated;
grant execute on function public.upsert_hand_tile_entry(uuid, jsonb, integer, text) to authenticated;
grant execute on function public.get_player_mosaic_profile(uuid) to anon, authenticated;
grant execute on function public.record_hand_photo(uuid, uuid, timestamptz, text, text) to authenticated;

select pg_notify('pgrst', 'reload schema');
