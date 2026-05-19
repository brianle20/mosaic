import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voided hand archive migration numbers only recorded hands', () {
    final migrationFile = File(
      'supabase/migrations/20260519130000_voided_hand_numbering.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains(
        'drop constraint if exists hand_results_table_session_id_hand_number_key',
      ),
    );
    expect(
      migration,
      contains('create unique index hand_results_recorded_hand_number_unique'),
    );
    expect(migration, contains("where status = 'recorded'"));
    expect(
      migration,
      contains('and status = \'recorded\''),
    );
  });
}
