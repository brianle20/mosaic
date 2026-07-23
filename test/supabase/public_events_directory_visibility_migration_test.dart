import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public events directory hides archived and cancelled events', () {
    final migrationFile = File(
      'supabase/migrations/20260722230000_hide_cancelled_public_events.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('public.get_public_events'));
    expect(migration, contains('event.archived_at is null'));
    expect(
      migration,
      contains("event.lifecycle_status <> 'cancelled'"),
    );
  });
}
