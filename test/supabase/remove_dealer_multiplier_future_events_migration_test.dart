import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('future events do not apply dealer win or loss multipliers', () {
    final migration = File(
      'supabase/migrations/20260605130000_remove_dealer_multiplier_future_events.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
          'create or replace function app_private.recalculate_session_unowned'),
    );
    expect(sql, contains('dealer_multiplier_removed_for_events_created_at'));
    expect(sql, contains("'2026-06-05T13:00:00Z'::timestamptz"));
    expect(sql, contains('dealer_multiplier_free_event boolean := false'));
    expect(
      sql,
      contains(
        'event.created_at >= dealer_multiplier_removed_for_events_created_at',
      ),
    );
    expect(
      sql,
      contains(
        'if hand_row.winner_seat_index = current_east\n'
        '          and not dealer_multiplier_free_event then',
      ),
    );
    expect(
      sql,
      contains(
        'if seat_index = current_east\n'
        '          and hand_row.winner_seat_index <> current_east\n'
        '          and not dealer_multiplier_free_event then',
      ),
    );
    expect(sql, contains('dealer_multiplier_1_5_effective_at'));
    expect(
        sql, contains('amount_points_value := (amount_points_value * 3) / 2;'));
    expect(sql, contains("array_append(multiplier_flags, 'east_wins')"));
    expect(sql, contains("array_append(multiplier_flags, 'east_loses')"));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
