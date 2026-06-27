import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('score total refresh recomputes has_scored_play from recorded hands',
      () {
    final refreshFunction = _latestFunctionBody(
      'app_private.refresh_event_score_totals',
    );

    _expectOrdered(refreshFunction, [
      'insert into public.event_score_totals',
      'perform app_private.refresh_event_guest_scored_play(target_event_id);',
      'perform app_private.refresh_public_event_standings_snapshot(target_event_id);',
    ]);

    final helperFunction = _latestFunctionBody(
      'app_private.refresh_event_guest_scored_play',
    );

    _expectOrdered(helperFunction, [
      'with computed as (',
      'exists (',
      'from public.table_session_seats as seat',
      'join public.table_sessions as session',
      'join public.hand_results as hand_result',
      'where session.event_id = guest.event_id',
      'and seat.event_guest_id = guest.id',
      "and hand_result.status = 'recorded'",
      'or exists (',
      'from public.hand_settlements as settlement',
      'join public.hand_false_win_penalties as penalty',
      'where settlement.hand_result_id is null',
      "and penalty.status = 'pending'",
      'settlement.payer_event_guest_id = guest.id',
      'or settlement.payee_event_guest_id = guest.id',
      'update public.event_guests as guest',
      'set has_scored_play = computed.has_scored_play',
      'from computed',
      'and guest.has_scored_play is distinct from computed.has_scored_play',
    ]);
  });

  test('migration backfills existing event guest scored play state', () {
    final migration = _readMigration(
      '20260627120000_has_scored_play_invariant.sql',
    );

    _expectOrdered(migration, [
      r'do $$',
      'for event_row in',
      'select id from public.events',
      'perform app_private.refresh_event_guest_scored_play(event_row.id);',
    ]);
  });

  test('latest record_hand_result refreshes scored play after hand writes', () {
    final migration = _readMigration(
      '20260625170000_mosaic_rating_profile_foundation.sql',
    );
    final functionBody = _functionBody(migration, 'public.record_hand_result');

    _expectOrdered(functionBody, [
      'insert into public.hand_results',
      'perform app_private.attach_pending_false_win_penalties',
      'perform public.recalculate_session(session_row.id);',
    ]);
  });

  test('edit and void hand corrections refresh scored play after mutations',
      () {
    final migration = _readMigration(
      '20260624120000_same_hand_false_win_penalties.sql',
    );

    final editFunction = _functionBody(migration, 'public.edit_hand_result');
    _expectOrdered(editFunction, [
      'update public.hand_results',
      'perform public.recalculate_session(session_row.id);',
    ]);

    final voidFunction = _functionBody(migration, 'public.void_hand_result');
    _expectOrdered(voidFunction, [
      'update public.hand_results',
      "status = 'voided'",
      'update public.hand_false_win_penalties',
      "set status = 'voided'",
      'perform public.recalculate_session(session_row.id);',
    ]);
  });

  test('standalone false-win penalties refresh score totals after settlements',
      () {
    final migration = _readMigration(
      '20260624120000_same_hand_false_win_penalties.sql',
    );
    final functionBody = _functionBody(
      migration,
      'public.record_false_win_penalty',
    );

    _expectOrdered(functionBody, [
      'insert into public.hand_false_win_penalties',
      'insert into public.hand_settlements',
      'perform app_private.refresh_event_score_totals(session_row.event_id);',
    ]);
  });

  test('event copy migrations explicitly preserve has_scored_play', () {
    const copyMigrations = [
      '20260524220000_copy_event_for_testing.sql',
      '20260530093000_copy_event_without_table_tags.sql',
      '20260606120000_remove_future_qualification_scoring.sql',
      '20260613120000_preserve_copied_event_tournament_status.sql',
    ];

    for (final fileName in copyMigrations) {
      final migration = _readMigration(fileName);
      expect(
        migration,
        contains('has_scored_play'),
        reason: '$fileName must copy the scored-play cache explicitly.',
      );
    }
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

String _readMigration(String fileName) {
  final file = File('supabase/migrations/$fileName');
  expect(file.existsSync(), isTrue, reason: 'Missing $fileName');
  return file.readAsStringSync();
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
