create or replace function public.void_false_win_penalty(
  target_hand_false_win_penalty_id uuid,
  target_correction_note text default null
)
returns public.hand_false_win_penalties
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_penalty public.hand_false_win_penalties%rowtype;
  updated_penalty public.hand_false_win_penalties%rowtype;
  session_row public.table_sessions%rowtype;
begin
  select *
  into existing_penalty
  from public.hand_false_win_penalties
  where id = target_hand_false_win_penalty_id;

  if not found then
    raise exception 'False win penalty not found.'
      using errcode = 'P0001';
  end if;

  session_row :=
    app_private.require_owned_session(existing_penalty.table_session_id);

  select *
  into session_row
  from public.table_sessions
  where id = session_row.id
  for update;

  perform app_private.require_event_for_hand_correction(session_row.event_id);

  if existing_penalty.status = 'voided' then
    return existing_penalty;
  end if;

  update public.hand_false_win_penalties
  set
    status = 'voided',
    correction_note = coalesce(target_correction_note, correction_note)
  where id = existing_penalty.id
  returning *
  into updated_penalty;

  delete from public.hand_settlements
  where hand_false_win_penalty_id = existing_penalty.id;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into updated_penalty
  from public.hand_false_win_penalties
  where id = updated_penalty.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_false_win_penalty',
    updated_penalty.id::text,
    'void',
    to_jsonb(existing_penalty),
    to_jsonb(updated_penalty)
  );

  return updated_penalty;
end;
$$;

grant execute on function public.void_false_win_penalty(uuid, text)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
