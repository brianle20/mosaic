import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dealer multiplier migration changes future east modifiers to 1.5x', () {
    final migration = File(
      'supabase/migrations/20260517090000_dealer_multiplier_1_5.sql',
    ).readAsStringSync();

    expect(migration, contains('dealer multiplier to 1.5x'));
    expect(
      migration,
      contains('amount_points_value := (amount_points_value * 3) / 2;'),
    );
    expect(migration, contains('dealer_multiplier_1_5_effective_at'));
    expect(
      migration,
      contains('hand_row.entered_at >= dealer_multiplier_1_5_effective_at'),
    );
    expect(migration, contains("array_append(multiplier_flags, 'east_wins')"));
    expect(migration, contains("array_append(multiplier_flags, 'east_loses')"));
    expect(migration, contains('app_private.recalculate_session_unowned'));
    expect(migration, isNot(contains('for session_row in')));
    expect(migration, isNot(contains('for event_row in')));
    expect(
      migration,
      isNot(contains('perform app_private.recalculate_session_unowned')),
    );
  });
}
