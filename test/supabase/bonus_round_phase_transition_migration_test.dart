import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active finals force the event into bonus scoring phase', () {
    final migrationFile = File(
      'supabase/migrations/20260524234500_bonus_round_sets_event_phase.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains('app_private.set_event_bonus_phase_for_active_bonus_round'),
    );
    expect(migration, contains("new.status = 'active'"));
    expect(migration, contains("current_scoring_phase = 'bonus'"));
    expect(migration, contains('scoring_open = true'));
    expect(migration, contains('row_version = row_version + 1'));
    expect(
      migration,
      contains('after insert or update of status on public.event_bonus_rounds'),
    );
    expect(
      migration,
      contains("bonus_round.status = 'active'"),
    );
  });
}
