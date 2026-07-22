import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines atomic Finals begin orchestration and assigned session start',
      () {
    final sql = File(
      'supabase/migrations/20260711121000_begin_finals_orchestration.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.begin_event_finals('),
    );
    expect(sql, contains('target_event_id uuid'));
    expect(sql, contains('selected_champions_table_id uuid'));
    expect(sql, contains('selected_redemption_table_id uuid'));
    expect(sql, contains('expected_state_version bigint'));
    expect(sql, contains('expected_preview_token text'));
    expect(sql, contains('app_private.finals_preview_token'));
    expect(sql, contains('expected_preview_token is distinct from'));
    expect(sql, contains('standings_snapshot_value jsonb'));
    expect(sql, contains('into standings_snapshot_value'));
    expect(sql, contains('md5(standings_snapshot_value::text)'));
    expect(sql, contains('jsonb_to_recordset(standings_snapshot_value)'));
    expect(
      sql,
      contains('insert into public.event_finals_eligible_snapshot'),
    );
    expect(sql, contains('from jsonb_to_recordset(standings_snapshot_value)'));
    expect(
      RegExp(
        r'app_private\.finals_standings_snapshot\(target_event_id\)',
      ).allMatches(sql),
      hasLength(1),
    );
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(
      sql,
      contains('hashtextextended(target_event_id::text, 0)'),
    );
    expect(
        sql,
        contains(
            'from public.events as event\n  where event.id = target_event_id\n  for update'));
    expect(
      sql,
      contains(
        'from public.event_bonus_rounds as bonus_round\n'
        '  where bonus_round.event_id = target_event_id',
      ),
    );
    expect(sql, contains('locked_assignments as ('));
    expect(sql, contains('for update\n  )'));
    expect(sql, contains('app_private.refresh_event_score_totals'));
    expect(sql, contains('app_private.start_assigned_finals_session'));
    expect(sql, contains('public.get_event_finals_state(target_event_id)'));
    final primaryBeginStart = sql.indexOf(
      'create or replace function public.begin_event_finals(',
    );
    final compatibilityBeginStart = sql.indexOf(
      'create or replace function public.begin_event_finals(',
      primaryBeginStart + 1,
    );
    final primaryBegin = sql.substring(
      primaryBeginStart,
      compatibilityBeginStart,
    );
    final candidateDiscovery = primaryBegin.indexOf(
      'selected_champions_table_id,\n      selected_redemption_table_id',
    );
    final tableSetLock = primaryBegin.indexOf(
      'from public.event_tables as event_table\n  where event_table.id in',
    );
    final tagSetLock = primaryBegin.indexOf(
      'from public.nfc_tags as tag\n  where tag.id in',
    );
    final sessionSetLock = primaryBegin.indexOf(
      'from public.table_sessions as session\n    where session.event_table_id in',
      tableSetLock,
    );
    final firstSessionStart = primaryBegin.indexOf(
      'started_session := app_private.start_assigned_finals_session(',
    );
    expect(candidateDiscovery, greaterThanOrEqualTo(0));
    expect(tableSetLock, greaterThan(candidateDiscovery));
    expect(tagSetLock, greaterThan(tableSetLock));
    expect(sessionSetLock, greaterThan(tagSetLock));
    expect(firstSessionStart, greaterThan(sessionSetLock));
    expect(primaryBegin, contains('order by event_table.id for update'));
    expect(primaryBegin, contains('order by tag.id for update'));
    expect(primaryBegin, contains('order by session.id for update nowait'));
    expect(
      primaryBegin,
      contains(
        'Selected Finals tables are currently being scored. Refresh and try again.',
      ),
    );
    expect(
      RegExp(
        r'Selected Finals tables must not have active or paused sessions\.',
      ).allMatches(primaryBegin),
      hasLength(2),
      reason: 'Begin must revalidate table occupancy after its NOWAIT lock',
    );

    expect(
      sql,
      contains(
        'create or replace function app_private.start_assigned_finals_session(',
      ),
    );
    for (final parameter in <String>[
      'target_event_id uuid',
      'target_bonus_round_id uuid',
      'target_bonus_table_role text',
      'target_finals_contest_id uuid',
      'target_started_at timestamptz',
    ]) {
      expect(sql, contains(parameter));
    }
    expect(sql, contains('between 2 and 4'));
    expect(sql,
        contains('Assigned seating must fill seats contiguously from East.'));
    expect(sql, contains('All assigned session players must be checked in.'));
    expect(
        sql,
        contains(
            'An assigned guest is already seated in another active session.'));
    expect(sql,
        contains('Default ruleset not found for the selected Finals table.'));
    expect(sql, contains('finals_contest_id'));

    for (final format in <String>[
      "'champions_only'",
      "'automatic_redemption'",
      "'redemption_advancement'",
      "'parallel_finals'",
    ]) {
      expect(sql, contains(format));
    }
    for (final contest in <String>[
      "'direct_qualification_tiebreak'",
      "'table_of_redemption'",
      "'table_of_champions'",
    ]) {
      expect(sql, contains(contest));
    }
    expect(sql, contains('cutoff_tie_count > 4'));
    expect(sql, contains("flow_version = 'orchestrated'"));
    expect(sql, contains('Active Finals already exist for this event.'));
    expect(
        sql,
        contains(
            'Selected Finals tables must not have active or paused sessions.'));
    expect(sql, contains('event_bonus_rounds_set_event_phase'));
    expect(sql, contains('state_version = state_version + 1'));
    expect(sql, contains("'begin_event_finals'"));
    expect(
      sql,
      contains(
        'grant execute on function public.begin_event_finals(uuid, uuid, uuid, bigint, text)',
      ),
    );
    final compatibilityWrapper = sql.substring(
      sql.lastIndexOf('create or replace function public.begin_event_finals('),
    );
    final compatibilityRefreshIndex =
        compatibilityWrapper.indexOf('refresh_event_score_totals');
    final compatibilityAuthorizationIndex =
        compatibilityWrapper.indexOf('app_private.can_manage_event');
    final compatibilityIdempotencyIndex =
        compatibilityWrapper.indexOf("flow_version = 'orchestrated'");
    expect(compatibilityAuthorizationIndex, greaterThanOrEqualTo(0));
    expect(compatibilityIdempotencyIndex, greaterThanOrEqualTo(0));
    expect(
        compatibilityAuthorizationIndex, lessThan(compatibilityRefreshIndex));
    expect(compatibilityIdempotencyIndex, lessThan(compatibilityRefreshIndex));
    expect(
      sql,
      contains(
        'revoke all on function app_private.start_assigned_finals_session(uuid, uuid, text, uuid, timestamptz) from public',
      ),
    );
  });
}
