comment on column public.event_guests.player_id is
  'Cached resolved Mosaic player identity for event-scoped projection hot paths. The canonical saved-profile-to-player bridge lives in public.player_guest_profiles; when an active bridge exists for an event-owned guest_profile_id, this value is aligned to that bridge.';

comment on table public.player_guest_profiles is
  'Canonical saved-profile-to-player bridge used to keep repeated appearances of the same host-owned guest profile attached to one Mosaic player identity.';

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

create or replace function app_private.align_event_guest_player_bridge()
returns trigger
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  bridged_player_id uuid;
begin
  if new.guest_profile_id is null then
    return new;
  end if;

  select bridge.player_id
  into bridged_player_id
  from public.events as event
  join public.guest_profiles as profile
    on profile.id = new.guest_profile_id
   and profile.owner_user_id = event.owner_user_id
  join public.player_guest_profiles as bridge
    on bridge.guest_profile_id = new.guest_profile_id
   and bridge.owner_user_id = event.owner_user_id
   and bridge.status = 'active'
  where event.id = new.event_id
  limit 1;

  if bridged_player_id is not null then
    new.player_id := bridged_player_id;
  end if;

  return new;
end;
$$;

drop trigger if exists event_guests_align_player_bridge
  on public.event_guests;
create trigger event_guests_align_player_bridge
before insert or update of guest_profile_id, player_id
on public.event_guests
for each row execute function app_private.align_event_guest_player_bridge();

select app_private.refresh_mosaic_player_snapshots();

select pg_notify('pgrst', 'reload schema');
