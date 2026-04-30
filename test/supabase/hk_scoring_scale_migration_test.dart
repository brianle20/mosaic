import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HK scoring scale migration updates buckets and backfills scores', () {
    final migration = File(
      'supabase/migrations/20260430230000_hk_scoring_scale_and_backfill.sql',
    ).readAsStringSync();

    expect(migration, contains('"minimumWinningFan": 3'));
    expect(migration, contains('{ "min": 0, "max": 0, "basePoints": 1 }'));
    expect(migration, contains('{ "min": 5, "max": 5, "basePoints": 24 }'));
    expect(migration, contains('{ "min": 13, "basePoints": 384 }'));
    expect(migration, contains('fan_count >= 3'));
    expect(migration, contains('if hand_row.win_type = ' "'discard'"));
    expect(migration, contains('continue'));
    expect(
      migration,
      isNot(contains("array_append(multiplier_flags, 'self_draw')")),
    );
    expect(migration, contains('east_wins'));
    expect(migration, contains('east_loses'));
    expect(migration, contains('app_private.recalculate_session_unowned'));
    expect(migration, contains('for session_row in'));
    expect(
        migration, contains('perform app_private.refresh_event_score_totals'));
  });
}
