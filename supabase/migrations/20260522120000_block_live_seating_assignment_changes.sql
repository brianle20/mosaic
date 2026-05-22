create or replace function app_private.event_seating_assignments_block_live_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.table_sessions as session
    where session.event_id = new.event_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End active or paused sessions before changing seating assignments.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trigger_event_seating_assignments_block_live_changes
  on public.event_seating_assignments;
create trigger trigger_event_seating_assignments_block_live_changes
before insert or update
on public.event_seating_assignments
for each row
execute function app_private.event_seating_assignments_block_live_changes();

select pg_notify('pgrst', 'reload schema');
