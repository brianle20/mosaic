import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines Finals contest progression without bypassing scoring sources',
      () {
    final sql = File(
      'supabase/migrations/20260711122000_finals_contest_progression.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.start_finals_contest('),
    );
    for (final parameter in <String>[
      'target_contest_id uuid',
      'selected_table_id uuid',
      'expected_state_version bigint',
    ]) {
      expect(sql, contains(parameter));
    }
    expect(sql, contains('returns jsonb'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('for update'));
    expect(sql, contains('bonus_round_row.state_version'));
    expect(sql, contains('original_table_id'));
    expect(sql, contains('original_table_label'));
    expect(sql, contains('replacement_table_label'));
    final startFunctionStart = sql.indexOf(
      'create or replace function public.start_finals_contest(',
    );
    final startFunctionEnd = sql.indexOf(
      'create or replace function app_private.assert_finals_eligible_snapshot_complete(',
    );
    final startFunction = sql.substring(startFunctionStart, startFunctionEnd);
    final advisoryLock = startFunction.indexOf('pg_advisory_xact_lock');
    final rootLock = startFunction.indexOf('select * into bonus_round_row');
    final tableLock = startFunction.indexOf('order by event_table.id');
    final contestLock = startFunction.lastIndexOf(
      'select * into contest_row',
      tableLock,
    );
    final tagLock = startFunction.indexOf('order by tag.id');
    final sessionLock = startFunction.indexOf(
      'order by session.event_table_id, session.id',
    );
    expect(advisoryLock, greaterThanOrEqualTo(0));
    expect(rootLock, greaterThan(advisoryLock));
    expect(contestLock, greaterThan(rootLock));
    expect(tableLock, greaterThan(contestLock));
    expect(tagLock, greaterThan(tableLock));
    expect(sessionLock, greaterThan(tagLock));
    expect(
      startFunction,
      contains('for update nowait'),
      reason: 'contest start must fail fast when scoring owns a session row',
    );
    expect(
      startFunction,
      contains(
        'Selected Finals table is currently being scored. Refresh and try again.',
      ),
    );
    expect(
      startFunction,
      contains('app_private.finals_session_matches_assignments('),
      reason: 'active contest retries must validate their linked session seats',
    );
    expect(
      startFunction,
      contains(
        'Existing Finals session seats do not match the durable assignments.',
      ),
    );
    expect(
      startFunction,
      contains('for update of tag'),
    );
    expect(sql, contains('app_private.start_assigned_finals_session('));
    expect(sql, contains('state_version = state_version + 1'));
    expect(sql, contains('public.get_event_finals_state'));

    expect(
      sql,
      contains(
        'create or replace function app_private.recalculate_finals_state(',
      ),
    );
    expect(sql, contains('target_table_session_id uuid'));
    expect(sql, contains('public.hand_results'));
    expect(sql, contains('public.hand_settlements'));
    expect(sql, contains('public.table_sessions'));
    expect(
      sql,
      contains("end_reason = 'finals_tiebreak_resolved'"),
      reason: 'every decisive Finals tiebreak must complete its session',
    );
    expect(
      sql,
      contains('app_private.resolve_finals_tiebreak_participant_outcomes('),
      reason: 'child and source participant outcomes must resolve together',
    );
    for (final contestType in <String>[
      "'direct_qualification_tiebreak'",
      "'table_of_redemption'",
      "'redemption_advancement_tiebreak'",
      "'redemption_winner_tiebreak'",
      "'table_of_champions'",
      "'champions_sudden_death'",
    ]) {
      expect(sql, contains(contestType));
    }

    expect(
      sql,
      contains('rename to apply_legacy_bonus_round_champion_award'),
    );
    expect(
      sql,
      contains(
        'create or replace function app_private.apply_bonus_round_champion_award(',
      ),
    );
    expect(sql, contains("bonus_round_row.flow_version = 'orchestrated'"));
    expect(sql, contains('app_private.recalculate_finals_state('));
    expect(
      sql,
      contains('app_private.apply_legacy_bonus_round_champion_award('),
    );

    expect(sql, contains('app_private.refresh_event_score_totals('));
    expect(sql, contains('public.event_finals_eligible_snapshot'));
    expect(
      sql,
      contains('Finals eligible snapshot is incomplete for this root.'),
    );
    expect(
      sql,
      isNot(contains('coalesce(snapshot.seed_rank, slot.slot_index)')),
      reason: 'missing frozen seeds must fail closed instead of changing order',
    );
    expect(
      sql,
      isNot(contains('app_private.finals_standings_snapshot(')),
      reason: 'progression membership must use the durable Begin snapshot',
    );
    expect(sql, contains("'start_finals_contest'"));
    expect(sql, contains("flow_version = 'orchestrated'"));
    expect(sql, contains("status <> 'completed'"));
    expect(
      sql,
      contains(
        'grant execute on function public.start_finals_contest(uuid, uuid, bigint)',
      ),
    );

    expect(
      RegExp(
        r'(insert\s+into|update|delete\s+from)\s+public\.event_score_totals',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
      reason: 'progression must use the authoritative score refresh path',
    );
    expect(
      RegExp(
        r'(insert\s+into|update|delete\s+from)\s+'
        r'public\.public_event_standings_snapshots',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
      reason: 'progression must use the existing snapshot refresh path',
    );
  });
}
