import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dealer compound cap migration rotates after two dealer wins', () {
    final migrationFile = File(
      'supabase/migrations/20260519140000_dealer_compound_cap.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('dealer_win_count integer := 0'));
    expect(migration, contains('dealer_compound_cap_effective_at'));
    expect(migration, contains('dealer_win_count := dealer_win_count + 1'));
    expect(migration, contains('if dealer_win_count >= 2 then'));
    expect(migration, contains('dealer_win_count := 0'));
    expect(migration, contains('dealer_was_waiting_at_draw is false'));
    expect(
      migration,
      contains(
        'elsif hand_row.result_type = \'washout\'\n'
        '      and hand_row.dealer_was_waiting_at_draw is false then',
      ),
    );
    expect(
      migration,
      isNot(contains('dealer_win_count := dealer_win_count + 1;\n'
          '    elsif hand_row.result_type = \'washout\'')),
    );
    expect(migration, contains('dealer_multiplier_1_5_effective_at'));
    expect(
      migration,
      contains('amount_points_value := (amount_points_value * 3) / 2;'),
    );
    expect(migration, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
