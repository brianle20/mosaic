grant execute on function public.get_tournament_round_summary(uuid)
  to authenticated;
grant execute on function public.generate_tournament_round(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
