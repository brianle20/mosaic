-- Keep tournament round wind independent from pre-tournament assignment history.

create or replace function app_private.set_tournament_session_round_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tournament_round_number integer;
begin
  if new.scoring_phase = 'tournament'
    and new.tournament_round_id is not null
  then
    select tournament_round.round_number
    into tournament_round_number
    from public.event_tournament_rounds as tournament_round
    where tournament_round.id = new.tournament_round_id
      and tournament_round.event_id = new.event_id
      and tournament_round.scoring_phase = 'tournament';

    if tournament_round_number is null then
      raise exception 'Tournament round not found for tournament session.'
        using errcode = 'P0001';
    end if;

    new.assignment_round := tournament_round_number;
  end if;

  return new;
end;
$$;

drop trigger if exists table_sessions_set_tournament_round_number
  on public.table_sessions;
create trigger table_sessions_set_tournament_round_number
before insert or update of event_id, scoring_phase, tournament_round_id, assignment_round
on public.table_sessions
for each row
execute function app_private.set_tournament_session_round_number();

update public.table_sessions as session
set assignment_round = tournament_round.round_number
from public.event_tournament_rounds as tournament_round
where session.tournament_round_id = tournament_round.id
  and session.event_id = tournament_round.event_id
  and session.scoring_phase = 'tournament'
  and tournament_round.scoring_phase = 'tournament'
  and session.assignment_round is distinct from tournament_round.round_number;

select pg_notify('pgrst', 'reload schema');
