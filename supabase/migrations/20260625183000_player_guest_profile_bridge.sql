-- Bridge saved guest profiles to Mosaic player identities.
--
-- guest_profiles are host-owned reusable contact identities.
-- players are competitive/rating identities.
-- This bridge prevents repeated event appearances for the same guest profile
-- from creating fragmented player rows.

create table if not exists public.player_guest_profiles (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  guest_profile_id uuid not null references public.guest_profiles(id) on delete cascade,
  owner_user_id uuid not null references public.users(id) on delete cascade,
  confidence text not null default 'projection_seed',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_guest_profiles_status_check
    check (status in ('active', 'superseded', 'rejected')),
  constraint player_guest_profiles_confidence_check
    check (confidence in ('historical_event_guest', 'projection_seed', 'host_confirmed', 'manual_review'))
);

create unique index if not exists player_guest_profiles_active_profile_unique
  on public.player_guest_profiles (guest_profile_id)
  where status = 'active';

create unique index if not exists player_guest_profiles_pair_unique
  on public.player_guest_profiles (player_id, guest_profile_id);

create index if not exists player_guest_profiles_player_idx
  on public.player_guest_profiles (player_id, status);

create index if not exists player_guest_profiles_owner_idx
  on public.player_guest_profiles (owner_user_id, status);

alter table public.player_guest_profiles enable row level security;

drop policy if exists player_guest_profiles_host_select
  on public.player_guest_profiles;
create policy player_guest_profiles_host_select
on public.player_guest_profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.guest_profiles as profile
    where profile.id = player_guest_profiles.guest_profile_id
      and profile.owner_user_id = auth.uid()
  )
);

drop trigger if exists player_guest_profiles_touch_updated_at
  on public.player_guest_profiles;
create trigger player_guest_profiles_touch_updated_at
before update on public.player_guest_profiles
for each row execute function app_private.touch_updated_at();

insert into public.player_guest_profiles (
  player_id,
  guest_profile_id,
  owner_user_id,
  confidence,
  status
)
select distinct on (guest.guest_profile_id)
  guest.player_id,
  guest.guest_profile_id,
  profile.owner_user_id,
  'historical_event_guest',
  'active'
from public.event_guests as guest
join public.events as event
  on event.id = guest.event_id
join public.guest_profiles as profile
  on profile.id = guest.guest_profile_id
 and profile.owner_user_id = event.owner_user_id
where guest.player_id is not null
  and guest.guest_profile_id is not null
order by guest.guest_profile_id, guest.created_at asc, guest.id asc
on conflict do nothing;

update public.event_guests as guest
set player_id = bridge.player_id
from public.player_guest_profiles as bridge,
  public.events as event,
  public.guest_profiles as profile
where bridge.guest_profile_id = guest.guest_profile_id
  and bridge.owner_user_id = event.owner_user_id
  and bridge.status = 'active'
  and event.id = guest.event_id
  and profile.id = guest.guest_profile_id
  and profile.owner_user_id = event.owner_user_id
  and guest.player_id is distinct from bridge.player_id;

create or replace function app_private.ensure_players_for_event(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  guest_row public.event_guests%rowtype;
  event_owner_user_id uuid;
  bridged_player_id uuid;
  inserted_player_id uuid;
  profile_is_event_owned boolean;
  resolved_player_id uuid;
begin
  select event.owner_user_id
  into event_owner_user_id
  from public.events as event
  where event.id = target_event_id;

  if event_owner_user_id is null then
    raise exception 'Event not found.'
      using errcode = 'P0001';
  end if;

  for guest_row in
    select guest.*
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.player_id is null
    order by guest.created_at asc, guest.id asc
    for update
  loop
    bridged_player_id := null;
    inserted_player_id := null;
    profile_is_event_owned := false;
    resolved_player_id := null;

    if guest_row.guest_profile_id is not null then
      select true
      into profile_is_event_owned
      from public.guest_profiles as profile
      where profile.id = guest_row.guest_profile_id
        and profile.owner_user_id = event_owner_user_id
      for update;

      select bridge.player_id
      into bridged_player_id
      from public.player_guest_profiles as bridge
      where bridge.guest_profile_id = guest_row.guest_profile_id
        and bridge.owner_user_id = event_owner_user_id
        and bridge.status = 'active'
        and profile_is_event_owned
      limit 1;
    end if;

    if bridged_player_id is not null then
      update public.event_guests
      set player_id = bridged_player_id
      where id = guest_row.id
        and player_id is null;
      continue;
    end if;

    insert into public.players (
      display_name,
      rating_state_json,
      profile_state_json
    )
    values (
      guest_row.display_name,
      jsonb_build_object(
        'seededFrom', 'event_guest',
        'eventGuestId', guest_row.id,
        'eventId', guest_row.event_id,
        'guestProfileId', guest_row.guest_profile_id,
        'inputsVersion', 'mosaic_projection_v1'
      ),
      jsonb_build_object(
        'seededFrom', 'event_guest',
        'eventGuestId', guest_row.id,
        'eventId', guest_row.event_id,
        'guestProfileId', guest_row.guest_profile_id,
        'inputsVersion', 'mosaic_projection_v1'
      )
    )
    returning id into inserted_player_id;

    if profile_is_event_owned then
      insert into public.player_guest_profiles (
        player_id,
        guest_profile_id,
        owner_user_id,
        confidence,
        status
      )
      select
        inserted_player_id,
        profile.id,
        profile.owner_user_id,
        'projection_seed',
        'active'
      from public.guest_profiles as profile
      where profile.id = guest_row.guest_profile_id
        and profile.owner_user_id = event_owner_user_id
      on conflict do nothing;

      select bridge.player_id
      into resolved_player_id
      from public.player_guest_profiles as bridge
      where bridge.guest_profile_id = guest_row.guest_profile_id
        and bridge.owner_user_id = event_owner_user_id
        and bridge.status = 'active'
      limit 1;
    end if;

    update public.event_guests
    set player_id = coalesce(resolved_player_id, inserted_player_id)
    where id = guest_row.id
      and player_id is null;
  end loop;
end;
$$;

select app_private.refresh_mosaic_player_snapshots();

select pg_notify('pgrst', 'reload schema');
