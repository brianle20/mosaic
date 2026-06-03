import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round deadline completion migration reconciles timed rounds', () {
    final migration = File(
      'supabase/migrations/20260603120000_round_deadline_completion.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function app_private.complete_finished_tournament_rounds',
      ),
    );
    expect(sql, contains("status = 'complete'"));
    expect(
      sql,
      contains(
        'create or replace function app_private.complete_finished_tournament_rounds(\n'
        '  target_event_id uuid default null\n'
        ')\n'
        'returns void',
      ),
    );
    expect(sql, contains("round.status in ('seating', 'active')"));
    final completeFinishedRoundsSql = sql.substring(
      sql.indexOf(
        'create or replace function app_private.complete_finished_tournament_rounds',
      ),
      sql.indexOf(
        'create or replace function public.get_tournament_round_summary',
      ),
    );
    expect(
      completeFinishedRoundsSql,
      contains("session.status in ('active', 'paused')"),
    );
    expect(
      completeFinishedRoundsSql,
      contains("session.status in ('completed', 'ended_early', 'aborted')"),
    );

    expect(sql, isNot(contains('complete_expired_round_timer_sessions')));
    expect(sql, isNot(contains('for update skip locked')));

    expect(
      sql,
      contains(
        'create or replace function public.get_tournament_round_summary',
      ),
    );
    expect(
      sql,
      contains(
        'perform app_private.complete_finished_tournament_rounds(target_event_id);',
      ),
    );
    expect(
      sql,
      contains("tournament_round.status in ('seating', 'active', 'complete')"),
    );
    expect(
      sql,
      contains(
        'case tournament_round.status\n'
        "      when 'seating' then 0\n"
        "      when 'active' then 1\n"
        "      when 'complete' then 2",
      ),
    );

    expect(
        sql, contains('create or replace function public.record_hand_result'));
    expect(sql, contains('create or replace function public.edit_hand_result'));
    expect(sql, contains('create or replace function public.void_hand_result'));
    expect(
        sql, contains('perform public.recalculate_session(session_row.id);'));
    expect(
      sql,
      contains(
        'perform app_private.complete_finished_tournament_rounds(session_row.event_id);',
      ),
    );

    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
