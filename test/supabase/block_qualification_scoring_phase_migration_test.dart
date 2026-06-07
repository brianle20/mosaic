import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('latest scoring phase mutation rejects qualification phase', () {
    final migration = File(
      'supabase/migrations/20260606140000_block_qualification_scoring_phase.sql',
    );

    expect(migration.existsSync(), isTrue);

    final scoringPhaseSql = _extractLatestFunction(
      migrationsSql,
      'public.update_event_scoring_phase',
    );

    expect(
      scoringPhaseSql,
      contains("if target_scoring_phase = 'qualification' then"),
    );
    expect(
      scoringPhaseSql,
      contains('Qualification scoring is no longer available.'),
    );
    expect(
      scoringPhaseSql,
      contains("target_scoring_phase not in ('tournament', 'bonus')"),
    );
    expect(
      scoringPhaseSql,
      contains('Unsupported scoring phase.'),
    );
    expect(
      scoringPhaseSql,
      contains('current_scoring_phase = target_scoring_phase'),
    );
  });
}

String _readAllMigrationSql() {
  final migrationFiles = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return migrationFiles
      .map((file) => '-- ${file.path}\n${file.readAsStringSync()}')
      .join('\n\n');
}

String _extractLatestFunction(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function $escapedName\\s*\\([\\s\\S]*?\\)\\s*'
    'returns[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql).toList();

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
