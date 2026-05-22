import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round time completion migration completes after first expired hand',
      () {
    final migrationFile = File(
      'supabase/migrations/20260521120000_round_time_completion.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('round_time_limit_effective_at'));
    expect(
        migration,
        contains(
            "round_time_limit_duration constant interval := interval '1 hour'"));
    expect(migration, contains('round_time_completed boolean := false'));
    expect(
      migration,
      contains(
          'hand_row.entered_at >= session_row.started_at + round_time_limit_duration'),
    );
    expect(migration, contains('round_time_completed := true'));
    expect(migration, contains('when round_time_completed then \'completed\''));
    expect(
        migration, contains('select pg_notify(\'pgrst\', \'reload schema\');'));
  });
}
