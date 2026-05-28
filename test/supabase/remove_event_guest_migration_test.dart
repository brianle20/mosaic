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
    expect(migration, contains('guest_cover_entries'));
    expect(migration, contains('event_guest_tag_assignments'));
    expect(migration, contains('table_session_seats'));
    expect(migration, contains('hand_settlements'));
    expect(migration, contains('event_score_totals'));
    expect(migration, contains('event_seating_assignments'));
    expect(migration, contains('prize_awards'));
    expect(migration, contains('delete from public.event_guests'));
    expect(migration, contains('app_private.insert_audit_log'));
    expect(migration, contains('grant execute'));
  });
}
