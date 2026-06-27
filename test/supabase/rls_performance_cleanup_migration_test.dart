import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260627220000_rls_performance_cleanup.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('hot auth policies evaluate auth uid through initplans', () {
    for (final policyName in [
      'approved_logistics_identities_owner_read',
      'events_insert_owner',
      'events_select_owned_or_staff',
      'guest_profiles_owner_all',
      'hand_photos_scorer_insert',
      'nfc_tags_owner_all',
      'player_guest_profiles_host_select',
      'prize_tiers_owner_all',
      'users_select_own',
      'users_update_own',
    ]) {
      final policySql = _policySql(migration, policyName);

      expect(
        _bareAuthUidPattern.hasMatch(policySql),
        isFalse,
        reason: '$policyName should not call auth.uid() per row',
      );
      expect(
        policySql,
        contains('(select auth.uid())'),
        reason: '$policyName should use an initplan auth.uid lookup',
      );
    }
  });

  test('approved logistics identity read policy joins membership correctly',
      () {
    final policySql = _policySql(
      migration,
      'approved_logistics_identities_owner_read',
    );

    expect(
      policySql,
      contains(
        'membership.approved_identity_id = approved_logistics_identities.id',
      ),
    );
    expect(
      policySql,
      isNot(contains('membership.approved_identity_id = id')),
    );
    expect(
      policySql,
      isNot(contains('membership.approved_identity_id = membership.id')),
    );
  });

  test('owner write policies no longer duplicate staff read policies', () {
    for (final tableName in [
      'event_bonus_rounds',
      'event_guest_tag_assignments',
      'event_guests',
      'event_seating_assignments',
      'event_tables',
      'event_tournament_rounds',
      'guest_cover_entries',
      'table_session_seats',
    ]) {
      expect(
        migration,
        contains('drop policy if exists ${tableName}_owner_manage'),
      );
      expect(
        _policySql(migration, '${tableName}_owner_insert'),
        contains('for insert'),
      );
      expect(
        _policySql(migration, '${tableName}_owner_update'),
        contains('for update'),
      );
      expect(
        _policySql(migration, '${tableName}_owner_delete'),
        contains('for delete'),
      );
      expect(
        migration,
        isNot(contains('create policy ${tableName}_owner_manage')),
      );
    }
  });

  test('score tables keep one policy per command role', () {
    expect(
        migration, contains('drop policy if exists hand_results_owner_manage'));
    expect(
      _policySql(migration, 'hand_results_owner_delete'),
      contains('for delete'),
    );
    expect(
      migration,
      isNot(contains('create policy hand_results_owner_manage')),
    );
    expect(
      migration,
      isNot(contains('create policy hand_results_owner_insert')),
    );
    expect(
      migration,
      isNot(contains('create policy hand_results_owner_update')),
    );

    expect(migration,
        contains('drop policy if exists table_sessions_owner_manage'));
    expect(
      _policySql(migration, 'table_sessions_owner_insert'),
      contains('for insert'),
    );
    expect(
      _policySql(migration, 'table_sessions_owner_delete'),
      contains('for delete'),
    );
    expect(
      migration,
      isNot(contains('create policy table_sessions_owner_update')),
    );
  });

  test('migration reloads the postgrest schema cache', () {
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}

final _bareAuthUidPattern = RegExp(r'(?<!select\s)auth\.uid\(\)');

String _policySql(String source, String policyName) {
  final match = RegExp(
    'create policy $policyName[\\s\\S]*?;',
    caseSensitive: false,
  ).firstMatch(source);

  expect(match, isNotNull, reason: '$policyName should be recreated');
  return match!.group(0)!.toLowerCase();
}
