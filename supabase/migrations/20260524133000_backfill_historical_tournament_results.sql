-- Historical events predate scoring phases. Any already-logged game should
-- continue to count toward tournament standings after the qualification split.

do $$
declare
  event_row record;
begin
  create temporary table backfill_historical_tournament_results (
    session_id uuid primary key,
    event_id uuid not null
  ) on commit drop;

  insert into backfill_historical_tournament_results (session_id, event_id)
  select distinct
    session.id,
    session.event_id
  from public.table_sessions as session
  where session.created_at < timestamptz '2026-05-24 12:00:00+00'
    and exists (
      select 1
      from public.hand_results as hand_result
      where hand_result.table_session_id = session.id
        and hand_result.status = 'recorded'
    )
  on conflict (session_id) do nothing;

  update public.table_sessions as session
  set scoring_phase = 'tournament'
  from backfill_historical_tournament_results as backfill
  where backfill.session_id = session.id
    and session.scoring_phase = 'qualification';

  update public.event_guests as guest
  set
    tournament_status = 'qualified',
    public_display_name = coalesce(
      nullif(btrim(guest.public_display_name), ''),
      public.default_public_display_name(guest.display_name)
    )
  where guest.tournament_status = 'open_play_only'
    and exists (
      select 1
      from public.table_session_seats as seat
      join backfill_historical_tournament_results as backfill
        on backfill.session_id = seat.table_session_id
      where seat.event_guest_id = guest.id
        and backfill.event_id = guest.event_id
    );

  for event_row in
    select distinct event_id
    from backfill_historical_tournament_results
  loop
    perform app_private.refresh_event_score_totals(event_row.event_id);
  end loop;
end;
$$;
