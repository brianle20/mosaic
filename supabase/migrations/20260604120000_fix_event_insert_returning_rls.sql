-- Allow event creation through PostgREST insert().select() for owners.
--
-- During INSERT ... RETURNING, a select policy that calls can_view_event(id)
-- cannot prove owner access by looking the new event back up in public.events.
-- Check the row owner directly, and keep staff read access for existing events.

drop policy if exists events_select_owned_or_staff on public.events;
create policy events_select_owned_or_staff
on public.events
for select
to authenticated
using (
  owner_user_id = auth.uid()
  or app_private.event_staff_role(id) is not null
);
