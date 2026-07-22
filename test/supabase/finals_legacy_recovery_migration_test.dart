import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines guarded legacy Finals recovery and RPC compatibility', () {
    final sql = File(
      'supabase/migrations/20260711123000_finals_legacy_recovery.sql',
    ).readAsStringSync();
    final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ');
    final finalHelperStart = sql.lastIndexOf(
      'create or replace function app_private.start_assigned_finals_session(',
    );
    final finalHelperEnd = sql.indexOf(
      'create or replace function public.resume_event_finals_start(',
      finalHelperStart,
    );
    final finalHelper = sql.substring(finalHelperStart, finalHelperEnd);
    final compatibilityStart = sql.lastIndexOf(
      'create or replace function public.start_bonus_assigned_table_sessions(',
    );
    final compatibilitySql = sql.substring(compatibilityStart);

    expect(
      sql,
      contains('create or replace function public.resume_event_finals_start('),
    );
    expect(sql, contains('target_event_id uuid'));
    expect(sql, contains('expected_recovery_token text'));
    expect(sql, contains('returns jsonb'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(
      normalizedSql,
      contains('hashtextextended(target_event_id::text, 0)'),
    );
    expect(sql, contains('app_private.can_manage_event(target_event_id)'));
    expect(sql, contains('for update'));
    expect(sql, contains('app_private.start_assigned_finals_session('));
    final tableLock = finalHelper.indexOf(
      'select event_table.* into table_row',
    );
    final tagLock = finalHelper.indexOf('select tag.* into tag_row');
    final sessionLock = finalHelper.indexOf(
      'from public.table_sessions as existing_session',
    );
    expect(tableLock, greaterThanOrEqualTo(0));
    expect(tagLock, greaterThan(tableLock));
    expect(sessionLock, greaterThan(tagLock));
    expect(finalHelper, contains('for update of tag'));
    expect(
      finalHelper,
      contains('order by existing_session.id\n    for update nowait;'),
      reason: 'a table conflict must fail fast instead of deadlocking scoring',
    );
    expect(
      finalHelper,
      contains(
        'Finals tables are currently being scored. Refresh and try again.',
      ),
      reason: 'the shared starter must translate lock_not_available for hosts',
    );
    expect(finalHelper, contains("tag_row.default_tag_type <> 'table'"));
    expect(finalHelper, contains("tag_row.status <> 'active'"));
    expect(
      finalHelper,
      contains('All Finals players must be checked in before starting.'),
    );
    expect(
      finalHelper,
      contains('A Finals player is already playing at another table.'),
    );
    expect(
      finalHelper,
      isNot(contains('All assigned session players must be checked in.')),
    );
    expect(
      finalHelper,
      isNot(contains(
          'An assigned guest is already seated in another active session.')),
    );
    expect(sql, contains('public.get_event_finals_state(target_event_id)'));
    expect(sql, contains('recoverable_missing_sessions'));
    expect(sql, contains('blocked_legacy_state'));
    expect(sql, contains('recovery_token'));
    expect(sql, contains("'default_tag_type', tag.default_tag_type"));
    expect(sql, contains("'tag_status', tag.status"));
    expect(sql, contains("'start_finals_tables'"));
    expect(sql, contains("'resume_finals_start'"));
    expect(
      sql,
      contains(
          'Finals changed since this screen loaded. Refresh and try again.'),
    );
    expect(sql, contains('Finals seating is incomplete.'));
    expect(
      sql,
      contains('A Finals player is already playing at another table.'),
    );
    expect(sql, contains('One of these Finals tables is already active.'));
    expect(
      sql,
      contains(
        'Finals could not be safely recovered. Review the table assignments.',
      ),
    );
    expect(sql, contains("'resume_event_finals_start'"));
    expect(
      sql,
      contains('app_private.legacy_finals_session_matches_assignments('),
      reason: 'existing legacy sessions must match exact durable seats',
    );
    expect(
      sql,
      contains("session.status in ('active', 'paused', 'completed')"),
      reason: 'a completed exact half remains authoritative during recovery',
    );
    expect(
        sql, contains("technical_reason_value := 'ambiguous_overlap_shape'"));
    expect(
      sql,
      contains("bonus_round.status in ('active', 'completed')"),
      reason: 'a legacy root completed before its missing peer must recover',
    );
    expect(
      sql,
      contains('app_private.finals_session_matches_assignments('),
      reason: 'every shared-starter idempotent return must verify exact seats',
    );
    expect(
      sql,
      contains("'flow_version', 'legacy'"),
      reason: 'legacy compatibility starts must be audited',
    );
    expect(
      normalizedSql,
      contains('and app_private.can_manage_event(target_event_id) then'),
      reason: 'read-only Finals viewers must not receive mutation actions',
    );
    expect(
      RegExp(
        r'Finals tables are currently being scored\. Refresh and try again\.',
      ).allMatches(sql),
      hasLength(4),
      reason: 'every recovery/compatibility NOWAIT site must translate 55P03',
    );
    final resumeStart = sql.indexOf(
      'create or replace function public.resume_event_finals_start(',
    );
    final compatibilityStartForScope = sql.indexOf(
      'create or replace function public.start_bonus_assigned_table_sessions(',
      resumeStart,
    );
    final resumeSql = sql.substring(resumeStart, compatibilityStartForScope);
    expect(
      resumeSql,
      contains('session.event_table_id = any(candidate_table_ids)'),
    );
    expect(
      resumeSql,
      contains(
        'Finals tables are currently being scored. Refresh and try again.',
      ),
      reason: 'resume must translate candidate-table lock contention',
    );
    expect(
      resumeSql,
      isNot(contains("or session.status in ('active', 'paused')")),
      reason: 'resume must never lock unrelated live event sessions',
    );

    expect(
      sql,
      contains(
        'create or replace function public.start_bonus_assigned_table_sessions(',
      ),
    );
    expect(sql, contains('returns setof public.table_sessions'));
    for (final branch in <({String marker, String loop})>[
      (
        marker: '-- Prelock the complete legacy compatibility candidate set.',
        loop: 'for candidate_value in',
      ),
      (
        marker:
            '-- Prelock the complete orchestrated compatibility candidate set.',
        loop: 'for contest_row in',
      ),
    ]) {
      final markerIndex = compatibilitySql.indexOf(branch.marker);
      expect(markerIndex, greaterThanOrEqualTo(0));
      final loopIndex = compatibilitySql.indexOf(branch.loop, markerIndex);
      expect(loopIndex, greaterThan(markerIndex));
      final lockBlock = compatibilitySql.substring(markerIndex, loopIndex);
      final tableLock = lockBlock.indexOf(
        'from public.event_tables as event_table',
      );
      final tagLock = lockBlock.indexOf('from public.nfc_tags as tag');
      final sessionLock = lockBlock.indexOf(
        'from public.table_sessions as session',
      );
      expect(tableLock, greaterThanOrEqualTo(0));
      expect(tagLock, greaterThan(tableLock));
      expect(sessionLock, greaterThan(tagLock));
      expect(lockBlock, contains('order by event_table.id for update'));
      expect(lockBlock, contains('order by tag.id for update'));
      expect(lockBlock, contains('order by session.id for update'));
      expect(lockBlock, contains('order by session.id for update nowait'));
      expect(
        lockBlock,
        contains(
          'Finals tables are currently being scored. Refresh and try again.',
        ),
        reason: 'each compatibility prelock must translate lock contention',
      );
    }
    expect(
      sql,
      contains('perform app_private.prepare_finals_contest(contest_row.id);'),
    );
    expect(
      compatibilitySql,
      contains("contest.status = 'ready'"),
      reason:
          'prelocks must exclude active contest sessions returned idempotently',
    );
    expect(compatibilitySql, contains('state_version = state_version + 1'));
    expect(
      compatibilitySql,
      contains("'start_bonus_assigned_table_sessions'"),
    );
    for (final mapping in <String>[
      "when 'direct_qualification_tiebreak' then 'table_of_champions_play_in'",
      "when 'redemption_advancement_tiebreak' then 'table_of_champions_play_in'",
      "when 'redemption_winner_tiebreak' then 'table_of_redemption'",
      "when 'champions_sudden_death' then 'table_of_champions_sudden_death'",
      "when 'table_of_champions' then 'table_of_champions'",
      "when 'table_of_redemption' then 'table_of_redemption'",
    ]) {
      expect(sql, contains(mapping));
    }
    expect(
      sql,
      contains(
        'create or replace function app_private.guard_active_session_guest_conflict()',
      ),
    );
    expect(
      sql,
      contains('table_session_seats_guard_active_guest_conflict'),
    );
    expect(
      normalizedSql,
      contains('hashtextextended(target_session.event_id::text, 1)'),
    );
    expect(sql, contains("target_session.status not in ('active', 'paused')"));
    expect(
      sql,
      contains('A player is already playing at another table.'),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.start_bonus_assigned_table_sessions(uuid, text) to authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.resume_event_finals_start(uuid, text) to authenticated',
      ),
    );

    expect(
      RegExp(
        r'update\s+public\.event_seating_assignments',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
      reason: 'legacy recovery must not mutate durable seating assignments',
    );
    expect(
      RegExp(r'set\s+flow_version\s*=', caseSensitive: false).hasMatch(sql),
      isFalse,
      reason: 'legacy recovery must not convert the Finals root',
    );
  });
}
