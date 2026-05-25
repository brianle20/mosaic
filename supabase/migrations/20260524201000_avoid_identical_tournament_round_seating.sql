create or replace function app_private.avoid_identical_tournament_round_seating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
  target_tournament_round_id uuid;
  target_assignment_round integer;
  assignment_count integer;
  new_order uuid[];
  previous_order uuid[];
begin
  if pg_trigger_depth() > 1 then
    return null;
  end if;

  if exists (
    select 1
    from new_assignments as new_assignment
    where new_assignment.tournament_round_id is null
      or new_assignment.assignment_type <> 'random'
  ) then
    return null;
  end if;

  select
    (array_agg(new_assignment.event_id))[1],
    (array_agg(new_assignment.tournament_round_id))[1],
    min(new_assignment.assignment_round),
    count(*)::integer,
    array_agg(
      new_assignment.event_guest_id
      order by event_table.display_order, new_assignment.seat_index,
        new_assignment.id
    )
  into
    target_event_id,
    target_tournament_round_id,
    target_assignment_round,
    assignment_count,
    new_order
  from new_assignments as new_assignment
  join public.event_tables as event_table
    on event_table.id = new_assignment.event_table_id;

  if assignment_count < 2 then
    return null;
  end if;

  if exists (
    select 1
    from new_assignments as new_assignment
    where new_assignment.event_id <> target_event_id
      or new_assignment.tournament_round_id <> target_tournament_round_id
      or new_assignment.assignment_round <> target_assignment_round
  ) then
    return null;
  end if;

  select array_agg(
    previous_assignment.event_guest_id
    order by event_table.display_order, previous_assignment.seat_index,
      previous_assignment.id
  )
  into previous_order
  from public.event_seating_assignments as previous_assignment
  join public.event_tables as event_table
    on event_table.id = previous_assignment.event_table_id
  where previous_assignment.event_id = target_event_id
    and previous_assignment.assignment_round = target_assignment_round - 1
    and previous_assignment.assignment_type = 'random';

  if new_order = previous_order then
    delete from public.event_seating_assignments as assignment
    using new_assignments as new_assignment
    where assignment.id = new_assignment.id;

    insert into public.event_seating_assignments (
      event_id,
      event_table_id,
      event_guest_id,
      seat_index,
      assignment_round,
      assignment_type,
      bonus_round_id,
      bonus_table_role,
      seed_rank,
      status,
      assigned_at,
      assigned_by_user_id,
      created_at,
      updated_at,
      tournament_round_id
    )
    select
      ordered_new.event_id,
      ordered_new.event_table_id,
      case
        when ordered_new.slot_number = 1 then new_order[assignment_count]
        else new_order[ordered_new.slot_number - 1]
      end,
      ordered_new.seat_index,
      ordered_new.assignment_round,
      ordered_new.assignment_type,
      ordered_new.bonus_round_id,
      ordered_new.bonus_table_role,
      ordered_new.seed_rank,
      ordered_new.status,
      ordered_new.assigned_at,
      ordered_new.assigned_by_user_id,
      ordered_new.created_at,
      ordered_new.updated_at,
      ordered_new.tournament_round_id
    from (
      select
        new_assignment.*,
        row_number() over (
          order by event_table.display_order, new_assignment.seat_index,
            new_assignment.id
        )::integer as slot_number
      from new_assignments as new_assignment
      join public.event_tables as event_table
        on event_table.id = new_assignment.event_table_id
    ) as ordered_new
    order by ordered_new.slot_number;
  end if;

  return null;
end;
$$;

drop trigger if exists event_seating_assignments_avoid_identical_tournament_round
  on public.event_seating_assignments;
create trigger event_seating_assignments_avoid_identical_tournament_round
after insert on public.event_seating_assignments
referencing new table as new_assignments
for each statement
execute function app_private.avoid_identical_tournament_round_seating();

select pg_notify('pgrst', 'reload schema');
