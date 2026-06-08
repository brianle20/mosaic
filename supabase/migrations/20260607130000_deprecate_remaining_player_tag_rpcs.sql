-- Deprecate remaining public player-tag helper RPCs for client applications.
-- Historical tag rows remain readable only through service-role maintenance.

revoke all on function public.get_guest_tag_assignment_summary(uuid) from public;
revoke all on function public.get_guest_tag_assignment_summary(uuid) from anon;
revoke all on function public.get_guest_tag_assignment_summary(uuid) from authenticated;
grant execute on function public.get_guest_tag_assignment_summary(uuid) to service_role;

revoke all on function public.register_nfc_tag(text, text, text) from public;
revoke all on function public.register_nfc_tag(text, text, text) from anon;
revoke all on function public.register_nfc_tag(text, text, text) from authenticated;
grant execute on function public.register_nfc_tag(text, text, text) to service_role;

select pg_notify('pgrst', 'reload schema');
