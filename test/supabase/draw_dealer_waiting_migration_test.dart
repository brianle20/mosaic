import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draw dealer waiting migration rotates only explicit future rows', () {
    final migration = File(
      'supabase/migrations/20260519120000_draw_dealer_waiting.sql',
    ).readAsStringSync();

    expect(migration, contains('dealer_was_waiting_at_draw boolean'));
    expect(migration, contains('target_dealer_was_waiting_at_draw boolean'));
    expect(migration, contains('Select whether dealer was waiting.'));
    expect(
      migration,
      contains(
          'Draw hands cannot include winner, win type, discarder, or fan count.'),
    );
    expect(migration, contains("target_result_type = 'washout'"));
    expect(migration, contains('dealer_was_waiting_at_draw is false'));
    expect(migration, contains('east_after := (current_east + 1) % 4'));
    expect(migration, contains('dealer_rotated_flag := true'));
    expect(
      migration,
      isNot(contains('update public.hand_results\nset dealer_was_waiting')),
    );
  });
}
