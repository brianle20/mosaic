import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260528100000_logistics_staff_roles.sql',
    ).readAsStringSync();
  });

  test('users support email or phone auth identities', () {
    expect(sql, contains('alter table public.users'));
    expect(sql, contains('alter column email drop not null'));
    expect(sql, contains('add column if not exists phone_e164 text'));
    expect(sql, contains('add column if not exists updated_at timestamptz'));
    expect(sql, contains('users_phone_e164_unique'));
    expect(sql, contains('handle_auth_user_sync'));
    expect(sql, contains('new.phone'));
    expect(sql, contains('after insert or update of email, phone'));
  });

  test('approved identities and event staff memberships are modeled', () {
    expect(
      sql,
      contains(
        'create table if not exists public.approved_logistics_identities',
      ),
    );
    expect(sql, contains('email text'));
    expect(sql, contains('phone_e164 text'));
    expect(sql, contains('approved_logistics_identities_contact_required'));
    expect(sql, contains('approved_logistics_identities_email_lower_unique'));
    expect(sql, contains('approved_logistics_identities_phone_e164_unique'));
    expect(sql, contains("status text not null default 'active'"));
    expect(
      sql,
      contains('create table if not exists public.event_staff_memberships'),
    );
    expect(sql, contains('approved_identity_id uuid not null'));
    expect(sql, contains('role text not null'));
    expect(sql, contains("role in ('qualification_scorer', 'event_scorer')"));
    expect(sql, contains('event_staff_memberships_event_identity_unique'));
    expect(sql, contains('event_staff_memberships_event_user_unique'));
  });

  test('role helpers enforce owner and scorer boundaries', () {
    expect(sql, contains('app_private.event_staff_role'));
    expect(sql, contains('app_private.can_view_event'));
    expect(sql, contains('app_private.can_manage_event'));
    expect(sql, contains('app_private.can_score_qualification'));
    expect(sql, contains('app_private.can_score_tournament'));
    expect(sql, contains('app_private.can_score_bonus'));
    expect(sql, contains("role = 'qualification_scorer'"));
    expect(sql, contains("role = 'event_scorer'"));
  });

  test('staff management and access RPCs are exposed', () {
    expect(sql, contains('public.get_current_mosaic_access'));
    expect(sql, contains('public.list_event_staff_memberships'));
    expect(sql, contains('public.upsert_event_staff_membership'));
    expect(sql, contains('public.disable_event_staff_membership'));
    expect(
      sql,
      contains(
        'grant execute on function public.get_current_mosaic_access() to authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.upsert_event_staff_membership(uuid, text, text, text, text) to authenticated',
      ),
    );
  });

  test('RLS policies use view and scoring helpers', () {
    expect(sql, contains('events_select_owned_or_staff'));
    expect(sql, contains('event_guests_owner_or_staff_read'));
    expect(sql, contains('guest_cover_entries_owner_or_staff_read'));
    expect(sql, contains('event_guest_tag_assignments_owner_or_staff_read'));
    expect(sql, contains('event_tables_owner_or_staff_read'));
    expect(sql, contains('table_sessions_owner_or_staff_read'));
    expect(sql, contains('table_session_seats_owner_or_staff_read'));
    expect(sql, contains('hand_results_owner_or_staff_read'));
    expect(sql, contains('hand_results_owner_or_staff_score'));
    expect(sql, contains('event_tournament_rounds_owner_or_staff_read'));
    expect(sql, contains('event_bonus_rounds_owner_or_staff_read'));
    expect(sql, contains('event_seating_assignments_owner_or_staff_read'));
  });

  test('scoring guard helpers are role aware for later RPC enforcement', () {
    expect(sql, contains('app_private.require_event_for_scoring'));
    expect(sql, contains('app_private.require_event_for_phase_scoring'));
    expect(sql, contains('app_private.require_table_for_scoring'));
    expect(sql, contains('app_private.require_guest_for_check_in'));
    expect(sql, contains('public.check_in_guest'));
    expect(sql, contains('public.resolve_event_table_by_tag'));
    expect(sql, contains('public.start_table_session'));
    expect(sql, contains('public.start_assigned_table_session'));
    expect(sql, contains('table_row := app_private.require_table_for_scoring'));
    expect(
        sql, contains('guest_row := app_private.require_guest_for_check_in'));
    expect(
        sql,
        contains(
            'grant execute on function public.resolve_event_table_by_tag(uuid, text)'));
    expect(sql, contains('target_scoring_phase text'));
    expect(sql, contains('app_private.can_score_qualification'));
    expect(sql, contains('app_private.can_score_tournament'));
    expect(sql, contains('app_private.can_score_bonus'));
  });
}
