import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260618150000_offline_hand_logging_idempotency.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('adds client mutation id to hand results', () {
    expect(migration, contains('client_mutation_id uuid'));
    expect(
      migration,
      contains('hand_results_client_mutation_id_unique'),
    );
    expect(
      migration,
      contains('where client_mutation_id is not null'),
    );
  });

  test('record hand RPC accepts offline sync parameters', () {
    final functionSql = _extractFunction(migration, 'public.record_hand_result');

    expect(functionSql, contains('target_client_mutation_id uuid default null'));
    expect(
      functionSql,
      contains('target_expected_recorded_hand_count integer default null'),
    );
    expect(
      functionSql,
      contains('target_expected_last_recorded_hand_id uuid default null'),
    );
  });

  test('record hand RPC returns existing hand for duplicate mutation id', () {
    final functionSql = _extractFunction(migration, 'public.record_hand_result');

    expect(functionSql, contains('existing_idempotent_hand'));
    expect(
      functionSql,
      contains('client_mutation_id = target_client_mutation_id'),
    );
    expect(functionSql, contains('return existing_idempotent_hand'));
  });

  test('record hand RPC serializes each session hand stream', () {
    final functionSql = _extractFunction(migration, 'public.record_hand_result');

    expect(
      _squishSql(functionSql),
      contains(
        'from public.table_sessions where id = session_row.id for update',
      ),
    );
  });

  test('record hand RPC handles duplicate mutation insert races', () {
    final functionSql = _extractFunction(migration, 'public.record_hand_result');

    expect(functionSql, contains('exception when unique_violation then'));
    expect(functionSql, contains('if target_client_mutation_id is null then'));
    expect(functionSql, contains('raise;'));
    expect(
      _squishSql(functionSql),
      contains(
        'where client_mutation_id = target_client_mutation_id',
      ),
    );
    expect(
      functionSql,
      contains('return existing_idempotent_hand'),
    );
  });

  test('record hand RPC rejects mutation ids from other sessions', () {
    final functionSql = _extractFunction(migration, 'public.record_hand_result');

    expect(
      functionSql,
      contains('Client mutation id belongs to a different session.'),
    );
    expect(functionSql, contains('offline_sync_conflict'));
  });

  test('record hand RPC rejects expected-state conflicts', () {
    final functionSql = _extractFunction(migration, 'public.record_hand_result');

    expect(functionSql, contains('offline_sync_conflict'));
    expect(functionSql, contains('target_expected_recorded_hand_count'));
    expect(functionSql, contains('target_expected_last_recorded_hand_id'));
    expect(functionSql, contains('Current session hand count has changed.'));
    expect(functionSql, contains('Current last hand has changed.'));
  });

  test('migration reloads postgrest schema cache', () {
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}

String _extractFunction(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function $escapedName[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql);

  return matches.isEmpty ? '' : matches.last.group(0)!;
}

String _squishSql(String sql) {
  return sql.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
