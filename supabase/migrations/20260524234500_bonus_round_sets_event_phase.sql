create or replace function app_private.set_event_bonus_phase_for_active_bonus_round()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'active' then
    update public.events
    set current_scoring_phase = 'bonus',
      scoring_open = true,
      updated_at = now(),
      row_version = row_version + 1
    where id = new.event_id
      and lifecycle_status = 'active'
      and (
        current_scoring_phase <> 'bonus'
        or scoring_open is distinct from true
      );
  end if;

  return new;
end;
$$;

drop trigger if exists event_bonus_rounds_set_event_phase
  on public.event_bonus_rounds;

create trigger event_bonus_rounds_set_event_phase
after insert or update of status on public.event_bonus_rounds
for each row
execute function app_private.set_event_bonus_phase_for_active_bonus_round();

update public.events as event
set current_scoring_phase = 'bonus',
  scoring_open = true,
  updated_at = now(),
  row_version = row_version + 1
where event.lifecycle_status = 'active'
  and (
    event.current_scoring_phase <> 'bonus'
    or event.scoring_open is distinct from true
  )
  and exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = event.id
      and bonus_round.status = 'active'
  );

select pg_notify('pgrst', 'reload schema');
