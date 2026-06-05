import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draws always rotate dealer migration preserves historical draw rules',
      () {
    final migration = File(
      'supabase/migrations/20260605120000_draws_always_rotate_dealer.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
        sql,
        contains(
            'create or replace function app_private.validate_hand_result_input'));
    expect(
        sql,
        contains(
            'create or replace function app_private.recalculate_session_unowned'));
    expect(sql, contains('draws_always_rotate_effective_at'));
    expect(sql, contains('legacy_draw_rotation_event'));
    expect(sql, contains("'fv-mahjong-1'"));
    expect(sql, contains("'fv-mahjong-2'"));
    expect(sql, contains("'fv mahjong 1'"));
    expect(sql, contains("'fv mahjong 2'"));
    expect(
      sql,
      contains("'2026-06-05T12:00:00Z'::timestamptz"),
    );
    expect(
      sql,
      contains(
        "elsif hand_row.result_type = 'washout'\n"
        '      and not legacy_draw_rotation_event\n'
        '      and hand_row.entered_at >= draws_always_rotate_effective_at then',
      ),
    );
    expect(
      sql,
      contains(
        "elsif hand_row.result_type = 'washout'\n"
        '      and hand_row.dealer_was_waiting_at_draw is false then',
      ),
    );
    expect(sql, contains('east_after := (current_east + 1) % 4'));
    expect(sql, contains('dealer_rotated_flag := true'));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
    expect(sql, isNot(contains('Select whether dealer was waiting.')));
  });
}
