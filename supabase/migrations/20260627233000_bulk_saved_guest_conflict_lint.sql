-- Resolve PL/pgSQL output-column ambiguity in the bulk saved guest insert RPC.

create or replace function public.add_saved_guests_to_event(
  target_event_id uuid,
  target_guest_profile_ids uuid[],
  target_tournament_status text default 'qualified',
  target_cover_status text default 'unpaid',
  target_cover_amount_cents integer default 0,
  target_is_comped boolean default false
)
returns table (
  id uuid,
  event_id uuid,
  guest_profile_id uuid,
  display_name text,
  normalized_name text,
  public_display_name text,
  player_id uuid,
  phone_e164 text,
  email_lower text,
  instagram_handle text,
  attendance_status text,
  tournament_status text,
  cover_status text,
  cover_amount_cents integer,
  is_comped boolean,
  has_scored_play boolean,
  note text,
  checked_in_at timestamptz,
  row_version integer,
  guest_profile jsonb
)
language plpgsql
security definer
set search_path = public, app_private
as $$
#variable_conflict use_column
declare
  event_row public.events%rowtype;
  inserted_count integer := 0;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found or access denied.'
      using errcode = 'P0001';
  end if;

  if target_guest_profile_ids is null
    or cardinality(target_guest_profile_ids) = 0
  then
    return;
  end if;

  if target_tournament_status not in (
    'open_play_only',
    'qualifying',
    'qualified',
    'withdrawn'
  ) then
    raise exception 'Invalid tournament status: %', target_tournament_status
      using errcode = 'P0001';
  end if;

  if target_cover_status not in (
    'unpaid',
    'paid',
    'partial',
    'comped',
    'refunded'
  ) then
    raise exception 'Invalid cover status: %', target_cover_status
      using errcode = 'P0001';
  end if;

  if target_cover_amount_cents < 0 then
    raise exception 'Cover amount must be zero or more.'
      using errcode = 'P0001';
  end if;

  select *
  into event_row
  from public.events as event_record
  where event_record.id = target_event_id;

  perform set_config('app.bulk_saved_guest_insert', 'on', true);

  return query
  with requested as (
    select distinct on (profile_id)
      profile_id,
      requested_order
    from unnest(target_guest_profile_ids)
      with ordinality as requested_profiles(profile_id, requested_order)
    where profile_id is not null
    order by profile_id, requested_order
  ),
  inserted as (
    insert into public.event_guests (
      event_id,
      guest_profile_id,
      display_name,
      normalized_name,
      public_display_name,
      attendance_status,
      tournament_status,
      cover_status,
      cover_amount_cents,
      is_comped,
      has_scored_play
    )
    select
      target_event_id,
      profile.id,
      profile.display_name,
      profile.normalized_name,
      coalesce(
        nullif(btrim(profile.public_display_name), ''),
        public.default_public_display_name(profile.display_name)
      ),
      'expected',
      target_tournament_status,
      target_cover_status,
      target_cover_amount_cents,
      target_is_comped,
      false
    from requested
    join public.guest_profiles as profile
      on profile.id = requested.profile_id
     and profile.owner_user_id = event_row.owner_user_id
    left join public.event_guests as existing_guest
      on existing_guest.event_id = target_event_id
     and existing_guest.guest_profile_id = profile.id
    where existing_guest.id is null
    order by requested.requested_order
    on conflict (event_id, guest_profile_id) do nothing
    returning *
  ),
  returned_rows as (
    select
      guest.id,
      guest.event_id,
      guest.guest_profile_id,
      guest.display_name,
      guest.normalized_name,
      guest.public_display_name,
      guest.player_id,
      guest.phone_e164,
      guest.email_lower,
      profile.instagram_handle,
      guest.attendance_status,
      guest.tournament_status,
      guest.cover_status,
      guest.cover_amount_cents,
      guest.is_comped,
      guest.has_scored_play,
      guest.note,
      guest.checked_in_at,
      guest.row_version,
      jsonb_build_object(
        'id', profile.id,
        'owner_user_id', profile.owner_user_id,
        'display_name', profile.display_name,
        'normalized_name', profile.normalized_name,
        'public_display_name', profile.public_display_name,
        'phone_e164', profile.phone_e164,
        'email_lower', profile.email_lower,
        'instagram_handle', profile.instagram_handle,
        'row_version', profile.row_version
      ) as guest_profile,
      requested.requested_order
    from inserted as guest
    join public.guest_profiles as profile
      on profile.id = guest.guest_profile_id
    join requested
      on requested.profile_id = guest.guest_profile_id
  )
  select
    returned_rows.id,
    returned_rows.event_id,
    returned_rows.guest_profile_id,
    returned_rows.display_name,
    returned_rows.normalized_name,
    returned_rows.public_display_name,
    returned_rows.player_id,
    returned_rows.phone_e164,
    returned_rows.email_lower,
    returned_rows.instagram_handle,
    returned_rows.attendance_status,
    returned_rows.tournament_status,
    returned_rows.cover_status,
    returned_rows.cover_amount_cents,
    returned_rows.is_comped,
    returned_rows.has_scored_play,
    returned_rows.note,
    returned_rows.checked_in_at,
    returned_rows.row_version,
    returned_rows.guest_profile
  from returned_rows
  order by returned_rows.requested_order;

  get diagnostics inserted_count = row_count;

  if inserted_count > 0 then
    perform app_private.refresh_public_event_standings_snapshot(
      target_event_id
    );
  end if;
end;
$$;

select pg_notify('pgrst', 'reload schema');
