-- Deprecate guest/player tag RPCs for client applications.
-- Historical player tag data remains in place, but future guest workflows use
-- tournament qualification state and assigned seating instead.

revoke all on function public.assign_guest_tag(uuid, text, text) from public;
revoke all on function public.assign_guest_tag(uuid, text, text) from anon;
revoke all on function public.assign_guest_tag(uuid, text, text) from authenticated;

revoke all on function public.replace_guest_tag(uuid, text, text) from public;
revoke all on function public.replace_guest_tag(uuid, text, text) from anon;
revoke all on function public.replace_guest_tag(uuid, text, text) from authenticated;

revoke all on function public.resolve_guest_by_active_tag(uuid, text) from public;
revoke all on function public.resolve_guest_by_active_tag(uuid, text) from anon;
revoke all on function public.resolve_guest_by_active_tag(uuid, text) from authenticated;

grant execute on function public.assign_guest_tag(uuid, text, text) to service_role;
grant execute on function public.replace_guest_tag(uuid, text, text) to service_role;
grant execute on function public.resolve_guest_by_active_tag(uuid, text) to service_role;

select pg_notify('pgrst', 'reload schema');
