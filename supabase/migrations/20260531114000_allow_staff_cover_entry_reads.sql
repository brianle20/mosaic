create or replace function public.list_guest_cover_entries(
  target_event_guest_id uuid
)
returns setof public.guest_cover_entries
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
    and app_private.can_view_event(guest.event_id);

  if not found then
    raise exception 'Guest not found for current Mosaic user.'
      using errcode = 'P0001';
  end if;

  return query
  select entry.*
  from public.guest_cover_entries as entry
  where entry.event_guest_id = guest_row.id
  order by entry.transaction_on desc, entry.created_at desc, entry.id desc;
end;
$$;

grant execute on function public.list_guest_cover_entries(uuid) to authenticated;

select pg_notify('pgrst', 'reload schema');
