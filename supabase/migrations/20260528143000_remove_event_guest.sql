create or replace function public.remove_event_guest(
  target_event_guest_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);

  if guest_row.attendance_status <> 'expected'
    or guest_row.checked_in_at is not null then
    raise exception 'Guests with check-in history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if guest_row.cover_status <> 'unpaid'
    or guest_row.is_comped then
    raise exception 'Guests with cover activity cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if guest_row.has_scored_play then
    raise exception 'Guests with scored play cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.guest_cover_entries as cover_entry
    where cover_entry.event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with cover entries cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_guest_tag_assignments as assignment
    where assignment.event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with tag assignment history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_session_seats as seat
    where seat.event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with table session history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.hand_settlements as settlement
    where settlement.payer_event_guest_id = guest_row.id
      or settlement.payee_event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with hand settlement history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_score_totals as score
    where score.event_guest_id = guest_row.id
      and (
        score.total_points <> 0
        or score.hands_played <> 0
        or score.hands_won <> 0
        or score.self_draw_wins <> 0
        or score.discard_wins <> 0
        or score.sessions_started <> 0
        or score.sessions_completed <> 0
      )
  ) then
    raise exception 'Guests with score history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_score_adjustments as adjustment
    where adjustment.event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with score adjustments cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_seating_assignments as assignment
    where assignment.event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with seating assignment history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.champion_event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with bonus round history cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.prize_awards as award
    where award.event_guest_id = guest_row.id
  ) then
    raise exception 'Guests with prize awards cannot be removed. Withdraw them instead.'
      using errcode = 'P0001';
  end if;

  perform app_private.insert_audit_log(
    guest_row.event_id,
    'event_guest',
    guest_row.id::text,
    'remove',
    to_jsonb(guest_row),
    null,
    jsonb_build_object(
      'display_name', guest_row.display_name,
      'reason', 'accidental_add'
    )
  );

  delete from public.event_guests
  where id = guest_row.id;

  return guest_row;
end;
$$;

grant execute on function public.remove_event_guest(uuid) to authenticated;

select pg_notify('pgrst', 'reload schema');
