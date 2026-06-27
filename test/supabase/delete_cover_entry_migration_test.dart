import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete cover entry migration adds delete RPC and audit summary', () {
    final migration = File(
      'supabase/migrations/20260611120000_delete_cover_entry.sql',
    ).readAsStringSync();

    expect(migration, contains('public.delete_cover_entry'));
    expect(migration, contains('target_cover_entry_id uuid'));
    expect(migration, contains('delete from public.guest_cover_entries'));
    expect(migration, contains('cover_status = next_cover_status'));
    expect(migration, contains("'guest_cover_entry'"));
    expect(migration, contains("'delete'"));
    expect(migration, contains('Deleted cover entry: %s %s'));

    final latestFunction = _latestFunctionBody('public.delete_cover_entry');
    expect(
      latestFunction,
      contains('app_private.refresh_event_guest_cover_status'),
    );
    _expectOrdered(latestFunction, [
      'delete from public.guest_cover_entries',
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
