-- Reduce per-row RLS work on hot authenticated paths.
--
-- Supabase's performance advisor flags direct auth.uid() calls in policies
-- because they are re-evaluated per row. Wrapping them in scalar subqueries
-- lets Postgres initialize the value once for the statement. The broad owner
-- FOR ALL policies also duplicated staff-facing SELECT policies, so this
-- migration keeps SELECT in the owner-or-staff policies and narrows owner
-- policies to the write commands they actually need to cover.

drop policy if exists approved_logistics_identities_owner_read
  on public.approved_logistics_identities;
create policy approved_logistics_identities_owner_read
on public.approved_logistics_identities
for select
to authenticated
using (
  approved_by_user_id = (select auth.uid())
  or exists (
    select 1
    from public.event_staff_memberships as membership
    where membership.approved_identity_id = approved_logistics_identities.id
      and app_private.can_manage_event(
        membership.event_id,
        (select auth.uid())
      )
  )
);

drop policy if exists events_select_owned_or_staff on public.events;
create policy events_select_owned_or_staff
on public.events
for select
to authenticated
using (
  owner_user_id = (select auth.uid())
  or app_private.event_staff_role(id, (select auth.uid())) is not null
);

drop policy if exists events_insert_owner on public.events;
create policy events_insert_owner
on public.events
for insert
to authenticated
with check (owner_user_id = (select auth.uid()));

drop policy if exists guest_profiles_owner_all on public.guest_profiles;
create policy guest_profiles_owner_all
on public.guest_profiles
for all
to authenticated
using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));

drop policy if exists nfc_tags_owner_all on public.nfc_tags;
create policy nfc_tags_owner_all
on public.nfc_tags
for all
to authenticated
using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));

drop policy if exists player_guest_profiles_host_select
  on public.player_guest_profiles;
create policy player_guest_profiles_host_select
on public.player_guest_profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.guest_profiles as profile
    where profile.id = player_guest_profiles.guest_profile_id
      and profile.owner_user_id = (select auth.uid())
  )
);

drop policy if exists prize_tiers_owner_all on public.prize_tiers;
create policy prize_tiers_owner_all
on public.prize_tiers
for all
to authenticated
using (
  exists (
    select 1
    from public.prize_plans as prize_plan
    join public.events as event
      on event.id = prize_plan.event_id
    where prize_plan.id = prize_tiers.prize_plan_id
      and event.owner_user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.prize_plans as prize_plan
    join public.events as event
      on event.id = prize_plan.event_id
    where prize_plan.id = prize_tiers.prize_plan_id
      and event.owner_user_id = (select auth.uid())
  )
);

drop policy if exists users_select_own on public.users;
create policy users_select_own
on public.users
for select
to authenticated
using (id = (select auth.uid()));

drop policy if exists users_update_own on public.users;
create policy users_update_own
on public.users
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists hand_photos_scorer_insert on public.hand_photos;
create policy hand_photos_scorer_insert
on public.hand_photos
for insert
to authenticated
with check (
  visibility = 'host_admin_only'
  and captured_by = (select auth.uid())
  and exists (
    select 1
    from public.hand_results as hand_result
    where hand_result.id = hand_photos.hand_result_id
      and app_private.can_score_session(
        hand_result.table_session_id,
        (select auth.uid())
      )
  )
);

drop policy if exists event_bonus_rounds_owner_manage
  on public.event_bonus_rounds;
create policy event_bonus_rounds_owner_insert
on public.event_bonus_rounds
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_bonus_rounds_owner_update
on public.event_bonus_rounds
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_bonus_rounds_owner_delete
on public.event_bonus_rounds
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists event_guest_tag_assignments_owner_manage
  on public.event_guest_tag_assignments;
create policy event_guest_tag_assignments_owner_insert
on public.event_guest_tag_assignments
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_guest_tag_assignments_owner_update
on public.event_guest_tag_assignments
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_guest_tag_assignments_owner_delete
on public.event_guest_tag_assignments
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists event_guests_owner_manage on public.event_guests;
create policy event_guests_owner_insert
on public.event_guests
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_guests_owner_update
on public.event_guests
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_guests_owner_delete
on public.event_guests
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists event_seating_assignments_owner_manage
  on public.event_seating_assignments;
create policy event_seating_assignments_owner_insert
on public.event_seating_assignments
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_seating_assignments_owner_update
on public.event_seating_assignments
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_seating_assignments_owner_delete
on public.event_seating_assignments
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists event_tables_owner_manage on public.event_tables;
create policy event_tables_owner_insert
on public.event_tables
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_tables_owner_update
on public.event_tables
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_tables_owner_delete
on public.event_tables
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists event_tournament_rounds_owner_manage
  on public.event_tournament_rounds;
create policy event_tournament_rounds_owner_insert
on public.event_tournament_rounds
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_tournament_rounds_owner_update
on public.event_tournament_rounds
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy event_tournament_rounds_owner_delete
on public.event_tournament_rounds
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists guest_cover_entries_owner_manage
  on public.guest_cover_entries;
create policy guest_cover_entries_owner_insert
on public.guest_cover_entries
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy guest_cover_entries_owner_update
on public.guest_cover_entries
for update
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())))
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy guest_cover_entries_owner_delete
on public.guest_cover_entries
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists table_session_seats_owner_manage
  on public.table_session_seats;
create policy table_session_seats_owner_insert
on public.table_session_seats
for insert
to authenticated
with check (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_seats.table_session_id
      and app_private.can_manage_event(session.event_id, (select auth.uid()))
  )
);
create policy table_session_seats_owner_update
on public.table_session_seats
for update
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_seats.table_session_id
      and app_private.can_manage_event(session.event_id, (select auth.uid()))
  )
)
with check (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_seats.table_session_id
      and app_private.can_manage_event(session.event_id, (select auth.uid()))
  )
);
create policy table_session_seats_owner_delete
on public.table_session_seats
for delete
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_seats.table_session_id
      and app_private.can_manage_event(session.event_id, (select auth.uid()))
  )
);

drop policy if exists hand_results_owner_manage on public.hand_results;
create policy hand_results_owner_delete
on public.hand_results
for delete
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = hand_results.table_session_id
      and app_private.can_manage_event(session.event_id, (select auth.uid()))
  )
);

drop policy if exists hand_results_owner_or_staff_score
  on public.hand_results;
create policy hand_results_owner_or_staff_score
on public.hand_results
for insert
to authenticated
with check (
  app_private.can_score_session(table_session_id, (select auth.uid()))
);

drop policy if exists hand_results_owner_or_staff_update_score
  on public.hand_results;
create policy hand_results_owner_or_staff_update_score
on public.hand_results
for update
to authenticated
using (
  app_private.can_score_session(table_session_id, (select auth.uid()))
)
with check (
  app_private.can_score_session(table_session_id, (select auth.uid()))
);

drop policy if exists table_sessions_owner_manage on public.table_sessions;
create policy table_sessions_owner_insert
on public.table_sessions
for insert
to authenticated
with check (app_private.can_manage_event(event_id, (select auth.uid())));
create policy table_sessions_owner_delete
on public.table_sessions
for delete
to authenticated
using (app_private.can_manage_event(event_id, (select auth.uid())));

drop policy if exists table_sessions_owner_or_staff_score
  on public.table_sessions;
create policy table_sessions_owner_or_staff_score
on public.table_sessions
for update
to authenticated
using (app_private.can_score_session(id, (select auth.uid())))
with check (app_private.can_score_session(id, (select auth.uid())));

select pg_notify('pgrst', 'reload schema');
