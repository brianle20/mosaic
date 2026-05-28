-- Restrict guest check-in to event owners/managers, not scoring-only staff.

create or replace function app_private.can_check_in_guests(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.can_manage_event(target_event_id, target_user_id)
$$;

create or replace function app_private.require_guest_for_check_in(
  target_event_guest_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
begin
  select guest.*
  into guest_row
  from public.event_guests as guest
  where guest.id = target_event_guest_id
    and app_private.can_check_in_guests(guest.event_id)
  for update;

  if not found then
    raise exception 'Guest not found for current check-in operator.'
      using errcode = 'P0001';
  end if;

  return guest_row;
end;
$$;
