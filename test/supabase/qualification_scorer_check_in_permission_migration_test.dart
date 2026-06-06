import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('check-in no longer grants a qualification-only staff role', () {
    final requireGuestSql = _extractLatestFunction(
      migrationsSql,
      'app_private.require_guest_for_check_in',
    );
    final qualificationScoringSql = _extractLatestFunction(
      migrationsSql,
      'app_private.can_score_qualification',
    );
    final tournamentScoringSql = _extractLatestFunction(
      migrationsSql,
      'app_private.can_score_tournament',
    );

    expect(requireGuestSql, contains('app_private.can_manage_event'));
    expect(requireGuestSql, contains('app_private.can_score_tournament'));
    expect(
      requireGuestSql,
      isNot(contains('app_private.can_score_qualification')),
    );
    expect(
      qualificationScoringSql,
      isNot(contains("'qualification_scorer'")),
    );
    expect(
        qualificationScoringSql, contains('app_private.can_score_tournament'));
    expect(
      tournamentScoringSql,
      contains(
          "app_private.event_staff_role(target_event_id, target_user_id) = 'event_scorer'"),
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
