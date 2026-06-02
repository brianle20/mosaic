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
    expect(leaderboardSql, contains('guest.tournament_status'));
    expect(
      leaderboardSql,
      contains('guest.tournament_status in (\'qualified\', \'withdrawn\')'),
    );
    expect(
      leaderboardSql,
      isNot(contains('guest.tournament_status = \'qualified\'')),
    );
  });

  test('public leaderboard keeps withdrawn scored players visible', () {
    final leaderboardSql = _extractFunction(
      migrationsSql,
      'public.get_public_event_leaderboard',
    );

    expect(leaderboardSql, contains('tournament_status text'));
    expect(leaderboardSql, contains('guest.tournament_status'));
    expect(
      leaderboardSql,
      contains('guest.tournament_status in (\'qualified\', \'withdrawn\')'),
    );
    expect(
        leaderboardSql, contains('guest.attendance_status = \'checked_in\''));
  });

  test('public standings snapshots preserve leaderboard tournament status', () {
    final snapshotSql = _extractFunction(
      migrationsSql,
      'app_private.build_public_event_standings_snapshot',
    );

    expect(snapshotSql, contains('tournamentStatus'));
    expect(snapshotSql, contains('leaderboard.tournament_status'));
  });

  test('prize preview excludes withdrawn players from awards', () {
    final prizePreviewSql = _extractFunction(
      migrationsSql,
      'app_private.build_prize_preview',
    );

    expect(
      prizePreviewSql,
      contains('leaderboard.tournament_status = \'qualified\''),
    );
    expect(
      prizePreviewSql,
      contains('leaderboard.hands_played >= minimum_hands_played'),
    );
  });

  test('finals eligibility excludes withdrawn players after leaderboard widens',
      () {
    final bonusSeatingSql = _extractFunction(
      migrationsSql,
      'public.generate_bonus_round_seating_assignments',
    );

    expect(
      bonusSeatingSql,
      contains('leaderboard.tournament_status = \'qualified\''),
    );
    expect(bonusSeatingSql, contains('leaderboard.hands_played >='));
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
