-- Remove the final client-callable player-tag table start surface.
-- The app uses assigned seating via start_assigned_table_session; keep this
-- guarded legacy wrapper available only to service_role for emergency/history.

revoke all on function public.start_table_session(uuid, text, text, text, text, text) from public;

revoke all on function public.start_table_session(uuid, text, text, text, text, text) from anon;

revoke all on function public.start_table_session(uuid, text, text, text, text, text) from authenticated;

grant execute on function public.start_table_session(uuid, text, text, text, text, text) to service_role;

select pg_notify('pgrst', 'reload schema');
