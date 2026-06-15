import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hand correction migration separates correction permission from recording', () {
    final migration = File(
      'supabase/migrations/20260615120000_tournament_hand_corrections.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function app_private.require_event_for_hand_correction',
      ),
    );
    expect(sql, contains('app_private.can_score_tournament(event.id)'));
    expect(sql, contains("event_row.lifecycle_status not in ('active', 'completed')"));
    expect(
      sql,
      contains(
        'Hand corrections are only available for active or completed events.',
      ),
    );

    final editSql = _extractFunction(sql, 'public.edit_hand_result');
    final voidSql = _extractFunction(sql, 'public.void_hand_result');
    final recordSql = _extractFunction(sql, 'public.record_hand_result');

    expect(
      editSql,
      contains('perform app_private.require_event_for_hand_correction(session_row.event_id);'),
    );
    expect(
      voidSql,
      contains('perform app_private.require_event_for_hand_correction(session_row.event_id);'),
    );
    expect(recordSql, contains('perform app_private.require_event_for_scoring(session_row.event_id);'));
    expect(recordSql, isNot(contains('require_event_for_hand_correction')));

    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}

String _extractFunction(String sql, String functionName) {
  final start = sql.indexOf('create or replace function $functionName');
  expect(start, isNonNegative, reason: 'missing $functionName');
  final rest = sql.substring(start);
  final end = rest.indexOf('\n\$\$;');
  expect(end, isNonNegative, reason: 'unterminated $functionName');
  return rest.substring(0, end);
}
