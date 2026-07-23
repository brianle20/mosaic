import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public Finals scores support legacy and orchestrated sessions',
    () {
      final migrationFile = File(
        'supabase/migrations/'
        '20260723104500_restore_legacy_finals_public_scores.sql',
      );

      expect(migrationFile.existsSync(), isTrue);

      final migration = migrationFile.readAsStringSync();

      expect(
        migration,
        contains(
          'session.finals_contest_id = assignment.finals_contest_id',
        ),
      );
      expect(
        migration,
        contains('assignment.finals_contest_id is not null'),
      );
      expect(
        migration,
        contains('assignment.finals_contest_id is null'),
      );
      expect(
        migration,
        contains('session.event_table_id = assignment.event_table_id'),
      );
      expect(
        migration,
        contains('session.bonus_round_id = assignment.bonus_round_id'),
      );
      expect(
        migration,
        contains(
          'session.bonus_table_role = assignment.bonus_table_role',
        ),
      );
      expect(
        migration,
        contains(
          'perform app_private.refresh_public_event_standings_snapshot(',
        ),
      );
    },
  );
}
