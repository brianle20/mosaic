import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('false win penalty migration adds result type and settlement flow', () {
    final migration = File(
      'supabase/migrations/20260520120000_false_win_penalty.sql',
    ).readAsStringSync();

    expect(migration, contains('hand_results_result_shape_check'));
    expect(migration, contains('penalty_seat_index'));
    expect(migration, contains('false_win_penalty'));
    expect(migration, contains('target_penalty_seat_index'));
    expect(
      migration,
      contains('app_private.ruleset_base_points(session_row.ruleset_id, 6)'),
    );
    expect(migration, contains("'false_win_penalty'"));
    expect(migration, contains('public.list_event_hand_ledger'));
    expect(
      migration,
      contains('select pg_notify(\'pgrst\', \'reload schema\');'),
    );
  });

  test('constraint fix migration replaces old result shape constraint', () {
    final migration = File(
      'supabase/migrations/20260520123000_fix_false_win_result_shape_constraint.sql',
    ).readAsStringSync();

    expect(migration,
        contains('drop constraint if exists hand_results_result_shape_check'));
    expect(migration,
        contains('drop constraint if exists hand_results_shape_check'));
    expect(
        migration, contains('add constraint hand_results_result_shape_check'));
    expect(migration, contains("result_type = 'false_win_penalty'"));
    expect(migration, contains('penalty_seat_index is not null'));
    expect(migration, contains('fan_count = 6'));
  });
}
