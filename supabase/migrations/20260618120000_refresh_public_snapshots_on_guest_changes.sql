-- Keep cached public standings in sync when guest display data changes.

drop trigger if exists public_event_updates_event_guests
  on public.event_guests;
create trigger public_event_updates_event_guests
after insert or update or delete on public.event_guests
for each row execute function app_private.insert_public_event_update();

do $$
declare
  event_row record;
begin
  for event_row in select id from public.events loop
    perform app_private.refresh_public_event_standings_snapshot(event_row.id);
  end loop;
end;
$$;
