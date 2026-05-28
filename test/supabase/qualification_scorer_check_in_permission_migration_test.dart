import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('qualification scorers cannot check in guests', () {
    final checkInHelperSql = _extractLatestFunction(
      migrationsSql,
      'app_private.can_check_in_guests',
    );
    final requireGuestSql = _extractLatestFunction(
      migrationsSql,
      'app_private.require_guest_for_check_in',
    );
    final qualificationScoringSql = _extractLatestFunction(
      migrationsSql,
      'app_private.can_score_qualification',
    );

    expect(checkInHelperSql, contains('app_private.can_manage_event'));
    expect(
      checkInHelperSql,
      isNot(contains('app_private.can_score_qualification')),
    );
    expect(requireGuestSql, contains('app_private.can_check_in_guests'));
    expect(
      requireGuestSql,
      isNot(contains('app_private.can_score_qualification')),
    );
    expect(
      qualificationScoringSql,
      contains("in ('qualification_scorer', 'event_scorer')"),
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
