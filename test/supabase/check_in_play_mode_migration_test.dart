import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('latest tournament seating generation does not require player tags', () {
    final generateRoundSql = _extractLatestFunction(
      migrationsSql,
      'public.generate_tournament_round',
    );

    expect(
        generateRoundSql,
        contains(
            'create or replace function public.generate_tournament_round'));
    expect(
        generateRoundSql, contains('guest.tournament_status = \'qualified\''));
    expect(
        generateRoundSql, contains('guest.attendance_status = \'checked_in\''));
    expect(
      generateRoundSql,
      contains('At least 2 qualified, checked-in players are required.'),
    );
    expect(generateRoundSql, isNot(contains('event_guest_tag_assignments')));
    expect(generateRoundSql, isNot(contains('tag_assignment')));
    expect(
        generateRoundSql, isNot(contains("tag.default_tag_type = 'player'")));
    expect(generateRoundSql, isNot(contains("tag.status = 'active'")));
    expect(generateRoundSql, isNot(contains('tagged players')));
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
    'create or replace function $escapedName[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql).toList();

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
