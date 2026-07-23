import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('host leaderboard keeps withdrawn scored players visible', () {
    final leaderboardSql = _extractFunction(
      migrationsSql,
      'public.get_event_leaderboard',
    );

    expect(leaderboardSql, contains('tournament_status text'));
    expect(leaderboardSql, contains('prize_eligible boolean'));
    expect(leaderboardSql, contains('guest.tournament_status'));
    expect(
      leaderboardSql,
      contains('guest.tournament_status in (\'qualified\', \'withdrawn\')'),
    );
    expect(
      leaderboardSql,
      isNot(contains('guest.tournament_status = \'qualified\'')),
    );
    expect(
      leaderboardSql,
      contains('app_private.is_event_guest_prize_eligible('),
    );
  });

  test('public leaderboard keeps withdrawn scored players visible', () {
    final leaderboardSql = _extractFunction(
      migrationsSql,
      'public.get_public_event_leaderboard',
    );

    expect(leaderboardSql, contains('tournament_status text'));
    expect(leaderboardSql, contains('prize_eligible boolean'));
    expect(leaderboardSql, contains('guest.tournament_status'));
    expect(
      leaderboardSql,
      contains('guest.tournament_status in (\'qualified\', \'withdrawn\')'),
    );
    expect(
        leaderboardSql, contains('guest.attendance_status = \'checked_in\''));
    expect(
      leaderboardSql,
      contains('app_private.is_event_guest_prize_eligible('),
    );
  });

  test('public standings snapshots preserve status and prize eligibility', () {
    final snapshotSql = _extractFunction(
      migrationsSql,
      'app_private.build_public_event_standings_snapshot',
    );

    expect(snapshotSql, contains('tournamentStatus'));
    expect(snapshotSql, contains('leaderboard.tournament_status'));
    expect(snapshotSql, contains('prizeEligible'));
    expect(snapshotSql, contains('leaderboard.prize_eligible'));
  });

  test('prize preview excludes withdrawn players from awards', () {
    final prizePreviewSql = _extractFunction(
      migrationsSql,
      'app_private.build_prize_preview',
    );

    expect(
      prizePreviewSql,
      contains('where leaderboard.prize_eligible'),
    );
    expect(
      prizePreviewSql,
      isNot(contains('minimum_hands_played')),
    );
  });

  test('finals eligibility excludes withdrawn players after leaderboard widens',
      () {
    final finalsStandingsSql = _extractFunction(
      migrationsSql,
      'app_private.finals_standings_snapshot',
    );

    expect(
      finalsStandingsSql,
      contains('app_private.is_event_guest_prize_eligible('),
    );
    expect(finalsStandingsSql, isNot(contains('minimum_hands_played')));
    expect(finalsStandingsSql, isNot(contains('percentile_cont')));
  });

  test('finals eligibility does not require player tags', () {
    final bonusSeatingSql = _extractFunction(
      migrationsSql,
      'public.generate_bonus_round_seating_assignments',
    );

    expect(
      bonusSeatingSql,
      contains('guest.attendance_status = \'checked_in\''),
    );
    expect(bonusSeatingSql, isNot(contains('event_guest_tag_assignments')));
    expect(bonusSeatingSql, isNot(contains('tag_assignment')));
    expect(
      bonusSeatingSql,
      isNot(contains('tag.default_tag_type = \'player\'')),
    );
  });
}

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
