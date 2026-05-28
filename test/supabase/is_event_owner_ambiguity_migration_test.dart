import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('latest event owner overloads keep one-argument calls unambiguous', () {
    final oneArgSql = _extractLatestFunction(
      migrationsSql,
      'app_private.is_event_owner',
      parameterCount: 1,
    );
    final twoArgSql = _extractLatestFunction(
      migrationsSql,
      'app_private.is_event_owner',
      parameterCount: 2,
    );

    expect(oneArgSql, contains('target_event_id uuid'));
    expect(oneArgSql, contains('auth.uid()'));
    expect(oneArgSql, contains('app_private.is_event_owner('));
    expect(twoArgSql, contains('target_event_id uuid'));
    expect(twoArgSql, contains('target_user_id uuid'));
    expect(twoArgSql, isNot(contains('default auth.uid()')));
    expect(
      migrationsSql,
      contains('rename to is_event_owner_for_user'),
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

String _extractLatestFunction(
  String sql,
  String functionName, {
  required int parameterCount,
}) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function $escapedName\\s*\\(([\\s\\S]*?)\\)\\s*'
    'returns[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql).where((match) {
    final parameters = match.group(1) ?? '';
    return RegExp(r'target_[a-z_]+ uuid').allMatches(parameters).length ==
        parameterCount;
  }).toList();

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
