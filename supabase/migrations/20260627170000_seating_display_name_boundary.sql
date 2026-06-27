comment on function public.get_event_seating_assignments(uuid) is
  'Host/admin seating assignment RPC. guest_display_name returns the event guest full display name for operational seating views; public copy/share surfaces must resolve event_guests.public_display_name instead.';

comment on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid) is
  'Host/admin bonus-round seating generator. Returned guest_display_name values are full display names for staff seating workflows, not public aliases.';

comment on function public.start_table_of_champions_play_in(uuid, uuid) is
  'Host/admin table-of-champions play-in seating generator. Returned guest_display_name values are full display names for staff seating workflows, not public aliases.';

comment on function public.get_bonus_round_state(uuid) is
  'Host/admin bonus-round state RPC. display_name fields are full guest display names for staff operations; public standings snapshots use publicDisplayName/public_display_name instead.';

revoke all on function public.get_event_seating_assignments(uuid) from public;
revoke all on function public.get_event_seating_assignments(uuid) from anon;
grant execute on function public.get_event_seating_assignments(uuid) to authenticated;

revoke all on function public.clear_event_seating_assignments(uuid) from public;
revoke all on function public.clear_event_seating_assignments(uuid) from anon;
grant execute on function public.clear_event_seating_assignments(uuid) to authenticated;

revoke all on function public.generate_random_seating_assignments(uuid) from public;
revoke all on function public.generate_random_seating_assignments(uuid) from anon;
grant execute on function public.generate_random_seating_assignments(uuid) to authenticated;

revoke all on function public.generate_tournament_round(uuid) from public;
revoke all on function public.generate_tournament_round(uuid) from anon;
grant execute on function public.generate_tournament_round(uuid) to authenticated;

revoke all on function public.start_tournament_round(uuid) from public;
revoke all on function public.start_tournament_round(uuid) from anon;
grant execute on function public.start_tournament_round(uuid) to authenticated;

revoke all on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid) from public;
revoke all on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid) from anon;
grant execute on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid) to authenticated;

revoke all on function public.start_bonus_round_sudden_death(uuid, uuid) from public;
revoke all on function public.start_bonus_round_sudden_death(uuid, uuid) from anon;
grant execute on function public.start_bonus_round_sudden_death(uuid, uuid) to authenticated;

revoke all on function public.start_table_of_champions_play_in(uuid, uuid) from public;
revoke all on function public.start_table_of_champions_play_in(uuid, uuid) from anon;
grant execute on function public.start_table_of_champions_play_in(uuid, uuid) to authenticated;

revoke all on function public.get_tournament_round_summary(uuid) from public;
revoke all on function public.get_tournament_round_summary(uuid) from anon;
grant execute on function public.get_tournament_round_summary(uuid) to authenticated;

revoke all on function public.get_bonus_round_state(uuid) from public;
revoke all on function public.get_bonus_round_state(uuid) from anon;
grant execute on function public.get_bonus_round_state(uuid) to authenticated;
