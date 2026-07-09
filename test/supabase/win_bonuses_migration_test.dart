import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String squished;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260709200000_win_bonuses.sql',
    );
    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    squished = migration.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('adds nullable win bonuses without defaulting historical hands', () {
    expect(migration, contains('alter table public.hand_results'));
    expect(migration, contains('add column if not exists win_bonuses text[]'));
    expect(
      squished,
      isNot(contains('add column if not exists win_bonuses text[] default')),
    );
  });

  test('validates allowed ids and duplicates', () {
    expect(migration, contains('app_private.validate_win_bonuses'));
    for (final bonusId in [
      'concealed_hand',
      'moon_under_the_sea',
      'robbing_the_kong',
      'win_by_kong_replacement',
      'double_kong_replacement',
      'blessing_of_heaven',
      'blessing_of_earth',
      'blessing_of_man',
    ]) {
      expect(migration, contains("'$bonusId'"));
    }

    expect(migration, contains('Only win hands can include win bonuses.'));
    expect(squished, contains('if target_win_bonuses is null then'));
    expect(squished, contains('return;'));
    expect(squished, contains('count(*) from unnest(target_win_bonuses)'));
    expect(migration, contains('Unknown win bonus.'));
    expect(migration, contains('Duplicate win bonuses are not allowed.'));
  });

  test('record rpc accepts, validates, and stores win bonuses', () {
    final functionBody = _functionBody(migration, 'public.record_hand_result');
    _expectRpcHandlesWinBonuses(functionBody);
    expect(functionBody, contains('win_bonuses,'));
  });

  test('edit rpc accepts, validates, and stores win bonuses', () {
    final functionBody = _functionBody(migration, 'public.edit_hand_result');
    _expectRpcHandlesWinBonuses(functionBody);
    expect(
      functionBody.toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      contains('win_bonuses = case'),
    );
  });

  test('hand evidence review exposes win bonuses', () {
    expect(migration, contains('win_bonuses text[]'));
    expect(migration, contains('hand_result.win_bonuses'));
  });

  test('tile entry upsert accepts app-computed review status', () {
    final functionBody =
        _functionBody(migration, 'public.upsert_hand_tile_entry');
    final squishedBody =
        functionBody.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    expect(functionBody, contains('target_review_status text default null'));
    expect(functionBody, contains('Unknown tile review status.'));
    expect(functionBody, contains('resolved_review_status := coalesce'));
    expect(squishedBody, contains('target_review_status'));
    expect(squishedBody, contains('review_status = excluded.review_status'));
  });
}

String _functionBody(String sql, String functionName) {
  final start = sql.indexOf('create or replace function $functionName');
  expect(start, isNot(-1), reason: 'Missing $functionName');

  final end = sql.indexOf('\$\$;', start);
  expect(end, isNot(-1), reason: 'Missing end marker for $functionName');
  return sql.substring(start, end);
}

void _expectRpcHandlesWinBonuses(String functionBody) {
  final squishedBody =
      functionBody.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  expect(functionBody, contains('target_win_bonuses text[] default null'));
  expect(functionBody, contains('perform app_private.validate_win_bonuses'));
  expect(functionBody, contains('win_bonuses'));
  expect(
    squishedBody,
    contains("when target_result_type = 'win' then target_win_bonuses"),
  );
  expect(squishedBody, contains('else null'));
}
