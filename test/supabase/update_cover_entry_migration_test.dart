import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('update cover entry migration adds edit RPC and audit summary', () {
    final migration = File(
      'supabase/migrations/20260518100000_update_cover_entry.sql',
    ).readAsStringSync();

    expect(migration, contains('public.update_cover_entry'));
    expect(migration, contains('target_cover_entry_id uuid'));
    expect(migration, contains('app_private.require_owned_guest'));
    expect(migration, contains('update public.guest_cover_entries'));
    expect(migration, contains("when target_method = 'refund' then -abs"));
    expect(migration, contains('cover_status = next_cover_status'));
    expect(migration, contains('app_private.insert_audit_log'));
    expect(migration, contains("'guest_cover_entry'"));
    expect(migration, contains("'update'"));
    expect(migration, contains('Updated cover entry: %s %s'));
    expect(migration, contains('select pg_notify'));

    final latestFunction = _latestFunctionBody('public.update_cover_entry');
    expect(
      latestFunction,
      contains('app_private.refresh_event_guest_cover_status'),
    );
    _expectOrdered(latestFunction, [
      'update public.guest_cover_entries',
      'refreshed_guest := app_private.refresh_event_guest_cover_status',
      "'cover_status', refreshed_guest.cover_status",
    ]);
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

void _expectOrdered(String source, List<String> snippets) {
  var previousIndex = -1;
  for (final snippet in snippets) {
    final nextIndex = source.indexOf(snippet, previousIndex + 1);
    expect(
      nextIndex,
      isNot(-1),
      reason: 'Expected to find "$snippet" after index $previousIndex.',
    );
    previousIndex = nextIndex;
  }
}
