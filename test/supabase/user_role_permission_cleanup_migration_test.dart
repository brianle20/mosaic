import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String cleanupSql;
  late String migrationsSql;

  setUpAll(() {
    cleanupSql = File(
      'supabase/migrations/20260625190000_user_role_permission_cleanup.sql',
    ).readAsStringSync();
    migrationsSql = _readAllMigrationSql();
  });

  test('cleanup migration reasserts the single active staff role', () {
    expect(cleanupSql, contains('event_staff_memberships_role_check'));
    expect(cleanupSql, contains("check (role = 'event_scorer')"));
    expect(
      cleanupSql,
      contains("if staff_role is distinct from 'event_scorer' then"),
    );
    expect(
      cleanupSql,
      isNot(contains("in ('qualification_scorer', 'event_scorer')")),
    );
  });

  test('latest check-in helpers are owner-only', () {
    final canCheckInSql = _extractLatestFunction(
      migrationsSql,
      'app_private.can_check_in_guests',
    );
    final requireGuestSql = _extractLatestFunction(
      migrationsSql,
      'app_private.require_guest_for_check_in',
    );

    expect(
      canCheckInSql,
      contains('app_private.can_manage_event(target_event_id, target_user_id)'),
    );
    expect(requireGuestSql, contains('app_private.can_check_in_guests'));
    expect(
        requireGuestSql, isNot(contains('app_private.can_score_tournament')));
    expect(
      requireGuestSql,
      isNot(contains('app_private.can_score_qualification')),
    );
  });

  test('latest access RPC normalizes legacy qualification staff rows', () {
    final accessSql = _extractLatestFunction(
      migrationsSql,
      'public.get_current_mosaic_access',
    );

    expect(
        accessSql, contains("when 'qualification_scorer' then 'event_scorer'"));
    expect(accessSql, contains('else membership.role'));
    expect(accessSql, contains("membership.status = 'active'"));
    expect(accessSql, contains("identity.status = 'active'"));
  });

  test('latest qualification scoring helper is only compatibility', () {
    final qualificationSql = _extractLatestFunction(
      migrationsSql,
      'app_private.can_score_qualification',
    );

    expect(
      qualificationSql,
      contains(
          'app_private.can_score_tournament(target_event_id, target_user_id)'),
    );
    expect(qualificationSql, isNot(contains("'qualification_scorer'")));
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
