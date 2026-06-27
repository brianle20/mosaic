import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260627230000_hot_fk_covering_indexes.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync().toLowerCase();
  });

  test('adds advisor-confirmed hot foreign key covering indexes', () {
    for (final expectedSql in [
      'create index if not exists event_score_totals_event_guest_idx\n'
          '  on public.event_score_totals (event_guest_id)',
      'create index if not exists table_session_seats_event_guest_idx\n'
          '  on public.table_session_seats (event_guest_id)',
      'create index if not exists table_sessions_tournament_round_event_idx\n'
          '  on public.table_sessions (tournament_round_id, event_id)',
      'create index if not exists event_seating_assignments_event_guest_event_idx\n'
          '  on public.event_seating_assignments (event_guest_id, event_id)',
      'create index if not exists event_seating_assignments_event_table_event_idx\n'
          '  on public.event_seating_assignments (event_table_id, event_id)',
      'create index if not exists event_seating_assignments_round_event_idx\n'
          '  on public.event_seating_assignments (tournament_round_id, event_id)',
      'create index if not exists event_guest_tag_assignments_event_guest_idx\n'
          '  on public.event_guest_tag_assignments (event_guest_id)',
      'create index if not exists event_guest_tag_assignments_nfc_tag_idx\n'
          '  on public.event_guest_tag_assignments (nfc_tag_id)',
      'create index if not exists event_tables_nfc_tag_idx\n'
          '  on public.event_tables (nfc_tag_id)',
      'create index if not exists prize_awards_event_guest_idx\n'
          '  on public.prize_awards (event_guest_id)',
      'create index if not exists rating_snapshots_table_session_idx\n'
          '  on public.rating_snapshots (table_session_id)',
      'create index if not exists event_staff_memberships_approved_identity_idx\n'
          '  on public.event_staff_memberships (approved_identity_id)',
    ]) {
      expect(migration, contains(expectedSql));
    }
  });

  test('does not drop unused indexes in this additive pass', () {
    expect(migration, isNot(contains('drop index')));
    expect(migration, isNot(contains('hand_tile_entries_review_status_idx')));
    expect(migration, isNot(contains('event_guests_event_phone_idx')));
    expect(migration, isNot(contains('events_owner_unarchived_created_idx')));
    expect(
      migration,
      isNot(contains('hand_settlements_false_win_penalty_idx')),
    );
    expect(migration, isNot(contains('hand_photos_upload_status_idx')));
  });
}
