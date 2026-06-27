import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest cover status helper derives event guest aggregate from ledger',
      () {
    final helper = _latestFunctionBody(
      'app_private.refresh_event_guest_cover_status',
    );

    _expectOrdered(helper, [
      'coalesce(sum(entry.amount_cents), 0)',
      "coalesce(bool_or(entry.method = 'comp'), false)",
      "coalesce(bool_or(entry.method = 'refund'), false)",
      'from public.guest_cover_entries as entry',
      'where entry.event_guest_id = guest_row.id',
      'next_is_comped := has_comp_entry;',
      'next_cover_status := case',
      "when next_is_comped then 'comped'",
      "when paid_total_cents < 0 then 'refunded'",
      "when paid_total_cents = 0 and has_refund_entry then 'refunded'",
      "when paid_total_cents = 0 then 'unpaid'",
      "when guest_row.cover_amount_cents = 0 then 'paid'",
      "when paid_total_cents >= guest_row.cover_amount_cents then 'paid'",
      "else 'partial'",
      'update public.event_guests',
      'cover_status = next_cover_status',
      'is_comped = next_is_comped',
      'cover_status is distinct from next_cover_status',
      'or is_comped is distinct from next_is_comped',
      'returning *',
    ]);
  });

  test('latest cover entry mutations refresh aggregate after ledger writes',
      () {
    final recordFunction = _latestFunctionBody('public.record_cover_entry');
    _expectOrdered(recordFunction, [
      "when target_method = 'refund' then -abs(target_amount_cents)",
      'insert into public.guest_cover_entries',
      'refreshed_guest := app_private.refresh_event_guest_cover_status',
      "'cover_status', refreshed_guest.cover_status",
    ]);

    final updateFunction = _latestFunctionBody('public.update_cover_entry');
    _expectOrdered(updateFunction, [
      "when target_method = 'refund' then -abs(target_amount_cents)",
      'update public.guest_cover_entries',
      'refreshed_guest := app_private.refresh_event_guest_cover_status',
      "'cover_status', refreshed_guest.cover_status",
    ]);

    final deleteFunction = _latestFunctionBody('public.delete_cover_entry');
    _expectOrdered(deleteFunction, [
      'delete from public.guest_cover_entries',
      'refreshed_guest := app_private.refresh_event_guest_cover_status',
      "'cover_status', refreshed_guest.cover_status",
    ]);
  });

  test('cover aggregate invariant migration backfills existing guests', () {
    final migration = _readMigration(
      '20260627130000_cover_ledger_aggregate_invariant.sql',
    );

    _expectOrdered(migration, [
      r'do $$',
      'for guest_row in',
      'select distinct event_guest_id as id',
      'from public.guest_cover_entries',
      'perform app_private.refresh_event_guest_cover_status(guest_row.id);',
    ]);
  });
}

String _readMigration(String fileName) {
  final file = File('supabase/migrations/$fileName');
  expect(file.existsSync(), isTrue, reason: 'Missing $fileName');
  return file.readAsStringSync();
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
