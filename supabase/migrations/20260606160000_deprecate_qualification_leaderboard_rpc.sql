-- The app no longer exposes qualification leaderboard surfaces. Keep the
-- historical RPC definition for admin recovery, but remove client execution.

revoke all on function public.get_event_qualification_leaderboard(uuid) from public;

revoke all on function public.get_event_qualification_leaderboard(uuid) from anon;

revoke all on function public.get_event_qualification_leaderboard(uuid) from authenticated;

select pg_notify('pgrst', 'reload schema');
