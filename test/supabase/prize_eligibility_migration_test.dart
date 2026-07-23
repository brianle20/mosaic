import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFiles = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith(
            '_remove_minimum_hands_prize_eligibility.sql',
          ),
        )
        .toList();

    expect(migrationFiles, hasLength(1));
    migration = migrationFiles.single.readAsStringSync();
  });

  test('defines participation from started tournament table sessions', () {
    final eligibilitySql = _extractFunction(
      migration,
      'app_private.is_event_guest_prize_eligible',
    );

    expect(eligibilitySql, contains('public.table_session_seats'));
    expect(eligibilitySql, contains('public.table_sessions'));
    expect(eligibilitySql, contains("session.scoring_phase = 'tournament'"));
    expect(
      eligibilitySql,
      contains("guest.tournament_status <> 'withdrawn'"),
    );
    expect(eligibilitySql, isNot(contains('hand_results')));
    expect(eligibilitySql, isNot(contains('hands_played')));
  });

  test('leaderboard RPCs expose canonical prize eligibility', () {
    final hostLeaderboardSql = _extractFunction(
      migration,
      'public.get_event_leaderboard',
    );
    final publicLeaderboardSql = _extractFunction(
      migration,
      'public.get_public_event_leaderboard',
    );

    for (final sql in [hostLeaderboardSql, publicLeaderboardSql]) {
      expect(sql, contains('prize_eligible boolean'));
      expect(
        sql,
        contains('app_private.is_event_guest_prize_eligible('),
      );
    }
  });

  test('prize preview has no minimum-hands eligibility rule', () {
    final prizePreviewSql = _extractFunction(
      migration,
      'app_private.build_prize_preview',
    );

    expect(
      prizePreviewSql,
      contains('where leaderboard.prize_eligible'),
    );
    expect(prizePreviewSql, isNot(contains('minimum_hands_played')));
    expect(prizePreviewSql, isNot(contains('median_hands_played')));
    expect(prizePreviewSql, isNot(contains('percentile_cont')));
  });

  test('Finals eligibility uses the same participation rule', () {
    final finalsSql = _extractFunction(
      migration,
      'app_private.finals_standings_snapshot',
    );

    expect(
      finalsSql,
      contains('app_private.is_event_guest_prize_eligible('),
    );
    expect(finalsSql, isNot(contains('minimum_hands_played')));
    expect(finalsSql, isNot(contains('percentile_cont')));
    expect(finalsSql, isNot(contains("attendance_status = 'checked_in'")));
  });

  test('public snapshots expose eligibility and refresh existing rows', () {
    final snapshotSql = _extractFunction(
      migration,
      'app_private.build_public_event_standings_snapshot',
    );

    expect(snapshotSql, contains("'prizeEligible'"));
    expect(snapshotSql, contains('leaderboard.prize_eligible'));
    expect(
      migration,
      contains(
        'perform app_private.refresh_public_event_standings_snapshot(',
      ),
    );
  });
}

String _extractFunction(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function $escapedName[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql);

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
