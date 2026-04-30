import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HK Standard ruleset migration removes versioned ruleset shape', () {
    final migration = File(
      'supabase/migrations/20260430200000_hk_standard_ruleset_simplification.sql',
    ).readAsStringSync();

    expect(migration, contains("'HK_STANDARD'"));
    expect(migration, contains('"minimumWinningFan": 3'));
    expect(migration, contains('"fanBuckets"'));
    expect(migration, contains('ruleset_minimum_winning_fan'));
    expect(migration, contains('ruleset_base_points'));
    expect(migration, contains('session_row.ruleset_id'));
    expect(migration, contains('app_private.ruleset_base_points'));
    expect(migration, contains('Win hands require at least'));
    expect(migration, contains('hand_results_win_minimum_fan_check'));
    expect(migration, contains("'HK_STANDARD' || '_V1'"));
    expect(migration, isNot(contains("'HK_STANDARD" "_V1'")));
    expect(migration, isNot(contains('ruleset_' 'version integer')));
  });
}
