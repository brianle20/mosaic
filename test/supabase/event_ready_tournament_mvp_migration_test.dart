import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('event guests use open_play_only tournament statuses', () {
    expect(migrationsSql, contains('tournament_status'));
    expect(migrationsSql, contains('open_play_only'));
    expect(migrationsSql, contains('qualifying'));
    expect(migrationsSql, contains('qualified'));
    expect(migrationsSql, contains('withdrawn'));
    expect(migrationsSql, isNot(contains('not_' 'interested')));
  });

  test('guest and event guest public display names are stored', () {
    expect(
      migrationsSql,
      contains('alter table public.guest_profiles'),
    );
    expect(
      migrationsSql,
      contains('add column if not exists public_display_name text'),
    );
    expect(
      migrationsSql,
      contains('alter table public.event_guests'),
    );
    expect(migrationsSql, contains('default_public_display_name'));
  });

  test('events and table sessions track scoring phase defaults', () {
    expect(migrationsSql, contains('current_scoring_phase'));
    expect(migrationsSql, contains('scoring_phase'));
    expect(migrationsSql, contains("default 'qualification'"));
    expect(migrationsSql, contains('events_current_scoring_phase_check'));
    expect(migrationsSql, contains('table_sessions_scoring_phase_check'));
    expect(migrationsSql, contains('qualification'));
    expect(migrationsSql, contains('tournament'));
    expect(migrationsSql, contains('bonus'));
  });

  test('historical recorded games are backfilled into tournament standings',
      () {
    expect(
      migrationsSql,
      contains('backfill_historical_tournament_results'),
    );
    expect(
      migrationsSql,
      contains("session.scoring_phase = 'qualification'"),
    );
    expect(
      migrationsSql,
      contains("set scoring_phase = 'tournament'"),
    );
    expect(
      migrationsSql,
      contains("guest.tournament_status = 'open_play_only'"),
    );
    expect(
      migrationsSql,
      contains("tournament_status = 'qualified'"),
    );
    expect(
      migrationsSql,
      contains('app_private.refresh_event_score_totals(event_row.event_id)'),
    );
  });

  test('starting a table session stamps the event scoring phase', () {
    final startSessionSql = _extractFunction(
      migrationsSql,
      'public.start_table_session',
    );

    expect(startSessionSql, contains('current_scoring_phase'));
    expect(startSessionSql, contains('effective_scoring_phase'));
    expect(startSessionSql, contains('scoring_phase'));
    expect(
      startSessionSql,
      contains(
        'case when bonus_assignment_row.id is null then effective_scoring_phase else',
      ),
    );
  });

  test('event score totals exclude qualification and raw bonus sessions', () {
    final refreshTotalsSql = _extractFunction(
      migrationsSql,
      'app_private.refresh_event_score_totals',
    );

    expect(refreshTotalsSql, contains("session.scoring_phase = 'tournament'"));
    expect(refreshTotalsSql, isNot(contains('session.bonus_round_id is null')));
    expect(refreshTotalsSql, contains('finals_champion_award'));
  });

  test('official leaderboard uses qualified tournament participants', () {
    final leaderboardSql = _extractFunction(
      migrationsSql,
      'public.get_event_leaderboard',
    );

    expect(leaderboardSql, contains("guest.tournament_status = 'qualified'"));
    expect(leaderboardSql, contains('discard_losses'));
    expect(
      leaderboardSql,
      contains('rank() over (order by score.total_points desc)'),
    );
  });

  test('host qualification leaderboard filters qualification sessions', () {
    final qualificationSql = _extractFunction(
      migrationsSql,
      'public.get_event_qualification_leaderboard',
    );

    expect(
      qualificationSql,
      contains(
        'create or replace function public.get_event_qualification_leaderboard',
      ),
    );
    expect(qualificationSql, contains('app_private.is_event_owner'));
    expect(
        qualificationSql, contains("session.scoring_phase = 'qualification'"));
    expect(qualificationSql, contains('qualification_points'));
    expect(qualificationSql, contains('full_name text'));
  });

  test('host mutation RPCs update tournament status and scoring phase', () {
    final tournamentStatusSql = _extractFunction(
      migrationsSql,
      'public.update_event_guest_tournament_status',
    );
    final scoringPhaseSql = _extractFunction(
      migrationsSql,
      'public.update_event_scoring_phase',
    );

    expect(
      tournamentStatusSql,
      contains(
          'create or replace function public.update_event_guest_tournament_status'),
    );
    expect(tournamentStatusSql, contains('app_private.require_owned_guest'));
    expect(tournamentStatusSql, contains('target_tournament_status'));
    expect(tournamentStatusSql,
        contains('tournament_status = target_tournament_status'));

    expect(
      scoringPhaseSql,
      contains('create or replace function public.update_event_scoring_phase'),
    );
    expect(scoringPhaseSql, contains('app_private.require_owned_event'));
    expect(scoringPhaseSql, contains('target_scoring_phase'));
    expect(scoringPhaseSql,
        contains('current_scoring_phase = target_scoring_phase'));
    expect(scoringPhaseSql, contains("session.status in ('active', 'paused')"));
  });

  test('public realtime uses a public-safe update table', () {
    expect(migrationsSql, contains('public.public_event_updates'));
    expect(migrationsSql, contains('public_event_updates_public_read'));
    expect(migrationsSql, contains('to anon, authenticated'));
    expect(migrationsSql, contains('alter publication supabase_realtime'));
    expect(migrationsSql, contains('insert_public_event_update'));
  });

  test('public realtime streams a cached standings snapshot row', () {
    final publicUpdateSql = _extractFunction(
      migrationsSql,
      'app_private.insert_public_event_update',
    );
    final refreshTotalsSql = _extractFunction(
      migrationsSql,
      'app_private.refresh_event_score_totals',
    );

    expect(
      migrationsSql,
      contains('public.public_event_standings_snapshots'),
    );
    expect(migrationsSql, contains('payload jsonb not null'));
    expect(
      migrationsSql,
      contains('public_event_standings_snapshots_public_read'),
    );
    expect(migrationsSql, contains('to anon, authenticated'));
    expect(migrationsSql, contains('alter publication supabase_realtime'));
    expect(
      migrationsSql,
      contains('app_private.build_public_event_standings_snapshot'),
    );
    expect(
      migrationsSql,
      contains('app_private.refresh_public_event_standings_snapshot'),
    );
    expect(migrationsSql, contains('on conflict (event_id) do update'));
    expect(
      migrationsSql,
      contains(
        'perform app_private.refresh_public_event_standings_snapshot(target_event_id)',
      ),
    );
    expect(
      publicUpdateSql,
      contains('tg_table_name not in'),
    );
    expect(publicUpdateSql, contains("'event_score_totals'"));
    expect(publicUpdateSql, contains("'hand_results'"));
    expect(publicUpdateSql, contains("'table_sessions'"));
    expect(
      refreshTotalsSql,
      contains(
        'perform app_private.refresh_public_event_standings_snapshot(target_event_id);',
      ),
    );
  });

  test('public event summary exposes public-safe event title', () {
    final eventSummarySql = _extractFunction(
      migrationsSql,
      'public.get_public_event_summary',
    );

    expect(
      eventSummarySql,
      contains('create or replace function public.get_public_event_summary'),
    );
    expect(eventSummarySql, contains('event.title'));
    expect(
      migrationsSql,
      contains(
        'grant execute on function public.get_public_event_summary(uuid) to anon, authenticated',
      ),
    );
  });

  test('public leaderboard RPC exposes only public display names', () {
    final publicLeaderboardSql = _extractFunction(
      migrationsSql,
      'public.get_public_event_leaderboard',
    );

    expect(
      publicLeaderboardSql,
      contains(
          'create or replace function public.get_public_event_leaderboard'),
    );
    expect(publicLeaderboardSql, contains('public_display_name'));
    expect(publicLeaderboardSql,
        contains("guest.tournament_status = 'qualified'"));
    expect(publicLeaderboardSql,
        contains("guest.attendance_status = 'checked_in'"));
    expect(publicLeaderboardSql, contains('discard_losses'));
    expect(
      publicLeaderboardSql,
      contains('rank() over (order by score.total_points desc)'),
    );
    expect(
      migrationsSql,
      contains(
        'grant execute on function public.get_public_event_leaderboard(uuid) to anon, authenticated',
      ),
    );
    expect(publicLeaderboardSql, _doesNotExposePrivateGuestData);
  });

  test('public bonus results RPC exposes only public display names', () {
    final publicBonusSql = _extractFunction(
      migrationsSql,
      'public.get_public_event_bonus_results',
    );

    expect(
      publicBonusSql,
      contains(
          'create or replace function public.get_public_event_bonus_results'),
    );
    expect(publicBonusSql, contains('public_display_name'));
    expect(publicBonusSql, contains('result_label'));
    expect(publicBonusSql, contains('placement'));
    expect(publicBonusSql, contains('champion_result'));
    expect(publicBonusSql, contains('redemption_winner'));
    expect(publicBonusSql, isNot(contains('assignment.seed_rank')));
    expect(
      migrationsSql,
      contains(
        'grant execute on function public.get_public_event_bonus_results(uuid) to anon, authenticated',
      ),
    );
    expect(publicBonusSql, _doesNotExposePrivateGuestData);
  });

  test('bonus ranking uses qualified tournament participants', () {
    final bonusSeatingSql = _extractFunction(
      migrationsSql,
      'public.generate_bonus_round_seating_assignments',
    );

    expect(bonusSeatingSql, contains("guest.tournament_status = 'qualified'"));
    expect(bonusSeatingSql, contains("session.scoring_phase = 'tournament'"));
  });

  test('random tournament seating uses qualified players only', () {
    final randomSeatingSql = _extractFunction(
      migrationsSql,
      'public.generate_random_seating_assignments',
    );

    expect(randomSeatingSql, contains("guest.tournament_status = 'qualified'"));
    expect(
        randomSeatingSql, contains("guest.attendance_status = 'checked_in'"));
  });
}

final Matcher _doesNotExposePrivateGuestData = allOf([
  isNot(contains('full_name')),
  isNot(contains('guest.display_name')),
  isNot(contains('email')),
  isNot(contains('phone')),
  isNot(contains('instagram')),
  isNot(contains('notes')),
  isNot(contains('qualification_points')),
  isNot(contains('cover')),
  isNot(contains('payment')),
]);

String _readAllMigrationSql() {
  final migrationFiles = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return migrationFiles
      .map((file) => '-- ${file.path}\n${file.readAsStringSync()}')
      .join('\n\n');
}

String _extractFunction(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function $escapedName[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql);

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
