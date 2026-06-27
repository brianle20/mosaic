import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remove event guest migration adds guarded owner-only RPC', () {
    final migrationFile = File(
      'supabase/migrations/20260528143000_remove_event_guest.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('public.remove_event_guest'));
    expect(migration, contains('app_private.require_owned_guest'));
    expect(migration, contains("attendance_status <> 'expected'"));
    expect(migration, contains("cover_status <> 'unpaid'"));
    expect(migration, contains('if guest_row.has_scored_play then'));
    expect(
      migration,
      contains(
          'Guests with scored play cannot be removed. Withdraw them instead.'),
    );
    _expectOrdered(migration, [
      'if guest_row.has_scored_play then',
      'guest_cover_entries',
      'event_guest_tag_assignments',
      'table_session_seats',
      'hand_settlements',
      'event_score_totals',
      'event_score_adjustments',
    ]);
    expect(migration, contains('guest_cover_entries'));
    expect(migration, contains('event_guest_tag_assignments'));
    expect(migration, contains('table_session_seats'));
    expect(migration, contains('hand_settlements'));
    expect(migration, contains('event_score_totals'));
    expect(migration, contains('event_score_adjustments'));
    expect(migration, contains('event_seating_assignments'));
    expect(migration, contains('prize_awards'));
    expect(migration, contains('delete from public.event_guests'));
    expect(migration, contains('app_private.insert_audit_log'));
    expect(migration, contains('grant execute'));
  });
}

void _expectOrdered(String source, List<String> snippets) {
  var previousIndex = -1;
  for (final snippet in snippets) {
    final nextIndex = source.indexOf(snippet, previousIndex + 1);
    expect(
      nextIndex,
      isNot(-1),
      reason: 'Expected to find "$snippet" after index $previousIndex.',
    );
    previousIndex = nextIndex;
  }
}
