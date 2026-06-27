import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest record hand RPC allows one late final hand for timed sessions',
      () {
    final functionBody = _latestFunctionBody('public.record_hand_result');
    final squished = _squishSql(functionBody);

    expect(functionBody, contains('allow_completed_late_hand'));
    expect(
      squished,
      contains(
        "session_row.status = 'completed' and session_row.scoring_phase in ('tournament', 'bonus')",
      ),
    );
    expect(
      squished,
      contains(
        'and not exists ( select 1 from public.hand_results as completion_hand',
      ),
    );
    expect(
      squished,
      contains('and completion_hand.session_completed_after_hand'),
    );
    expect(
      squished,
      contains(
        "if session_row.status <> 'active' and not allow_completed_late_hand then",
      ),
    );
  });
}

String _latestFunctionBody(String functionName) {
  final migrationsDirectory = Directory('supabase/migrations');
  expect(migrationsDirectory.existsSync(), isTrue);

  String? latestBody;
  for (final file in migrationsDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final migration = file.readAsStringSync();
    if (migration.contains('create or replace function $functionName')) {
      latestBody = _functionBody(migration, functionName);
    }
  }

  expect(latestBody, isNotNull, reason: 'Missing $functionName');
  return latestBody!;
}

String _functionBody(String sql, String functionName) {
  final start = sql.indexOf('create or replace function $functionName');
  expect(start, isNot(-1), reason: 'Missing $functionName');

  final end = sql.indexOf('\$\$;', start);
  expect(end, isNot(-1), reason: 'Missing end marker for $functionName');
  return sql.substring(start, end);
}

String _squishSql(String sql) {
  return sql.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
