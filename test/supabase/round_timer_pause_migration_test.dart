import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round timer pause migration freezes and resumes timer accounting', () {
    final migration = File(
      'supabase/migrations/20260524233000_round_timer_pause_controls.sql',
    ).readAsStringSync();

    expect(migration, contains('round_timer_paused_at'));
    expect(migration, contains('round_timer_paused_seconds'));
    expect(migration, contains('pause_table_session'));
    expect(migration, contains('resume_table_session'));
    expect(
      migration,
      contains('round_timer_paused_seconds + extract(epoch from'),
    );
    expect(
      migration,
      contains('round_timer_paused_at = null'),
    );
    expect(
      migration,
      contains('session_row.started_at + round_time_limit_duration +'),
    );
  });
}
