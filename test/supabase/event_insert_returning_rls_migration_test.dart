import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    final migrationFiles = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    migrationsSql = migrationFiles
        .map((file) => '-- ${file.path}\n${file.readAsStringSync()}')
        .join('\n\n');
  });

  test('latest events select policy supports insert returning for owners', () {
    final policySql = _extractLatestEventsSelectPolicy(migrationsSql);

    expect(policySql, contains('owner_user_id = auth.uid()'));
    expect(policySql, contains('app_private.event_staff_role(id)'));
    expect(policySql, isNot(contains('app_private.can_view_event(id)')));
  });
}

String _extractLatestEventsSelectPolicy(String sql) {
  final matches = RegExp(
    r'create policy events_select_owned_or_staff[\s\S]*?;',
    caseSensitive: false,
  ).allMatches(sql).toList();

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
