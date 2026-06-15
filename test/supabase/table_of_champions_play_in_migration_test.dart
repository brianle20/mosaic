import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260615130000_table_of_champions_play_in.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('migration adds play-in schema and role constraints', () {
    expect(migration, contains('play_in_status'));
    expect(
      migration,
      contains(
        "play_in_status in ('not_required', 'required', 'active', 'completed')",
      ),
    );
    expect(migration, contains('play_in_table_id'));
    expect(migration, contains('play_in_session_id'));
    expect(migration, contains('play_in_winner_event_guest_id'));
    expect(migration, contains('play_in_winner_seed_rank'));
    expect(migration, contains('table_of_champions_play_in'));
    expect(
      migration,
      contains('event_bonus_rounds_play_in_table_same_event_fk'),
    );
    expect(migration, contains('event_bonus_rounds_play_in_session_fk'));
    expect(
      migration,
      contains('event_bonus_rounds_play_in_winner_same_event_fk'),
    );
  });

  test('bonus round state exposes play-in state and players', () {
    final stateSql =
        _extractFunction(migration, 'public.get_bonus_round_state');

    expect(stateSql, contains("'play_in_status', 'not_required'"));
    expect(
        stateSql, contains("'play_in_status', bonus_round_row.play_in_status"));
    expect(stateSql,
        contains("'play_in_table_id', bonus_round_row.play_in_table_id"));
    expect(stateSql,
        contains("'play_in_session_id', bonus_round_row.play_in_session_id"));
    expect(
      stateSql,
      contains(
        "'play_in_winner_event_guest_id', "
        'bonus_round_row.play_in_winner_event_guest_id',
      ),
    );
    expect(
      stateSql,
      contains(
        "'play_in_winner_seed_rank', bonus_round_row.play_in_winner_seed_rank",
      ),
    );
    expect(stateSql, contains("'play_in_players', play_in_players"));
    expect(stateSql,
        contains("assignment.bonus_table_role = 'table_of_champions_play_in'"));
  });

  test('finals generation requires play-in when tie crosses champions cutoff',
      () {
    final generateSql = _extractFunction(
      migration,
      'public.generate_bonus_round_seating_assignments',
    );
    final candidatesSql = _extractFunction(
      migration,
      'app_private.table_of_champions_play_in_candidates',
    );

    expect(generateSql, contains('cutoff_tie_crosses_champions'));
    expect(generateSql, contains('leaderboard.total_points'));
    expect(generateSql, contains('ranked_players.seed_rank <= 4'));
    expect(generateSql, contains('ranked_players.seed_rank >= 5'));
    expect(candidatesSql, contains('where ranked_players.seed_rank >= 4'));
    expect(generateSql, contains("play_in_status = 'required'"));
    expect(generateSql, contains("'required'"));
    expect(generateSql, contains('assignment.status = \'active\''));
    expect(generateSql,
        contains('do not create Table of Champions or Redemption assignments'));
    expect(
      generateSql,
      contains(
          "selected_bonus_players.bonus_table_role <> 'table_of_champions_play_in'"),
    );
  });

  test('start play-in RPC validates table and seats cutoff candidates', () {
    final startSql = _extractFunction(
      migration,
      'public.start_table_of_champions_play_in',
    );

    expect(
      startSql,
      contains('bonus_round.play_in_status = \'required\''),
    );
    expect(
      startSql,
      contains(
          'Play-in table must be a ready event table with an active table NFC tag.'),
    );
    expect(
      startSql,
      contains(
          'End the active or paused session at this table before starting the play-in.'),
    );
    expect(startSql, contains('cutoff_players'));
    expect(startSql, contains('lower_seed_players'));
    expect(startSql, contains('limit greatest(0, 4 - cutoff_player_count)'));
    expect(
        startSql, contains('assignment.event_id = bonus_round_row.event_id'));
    expect(startSql, contains('play_in_player_count not between 2 and 4'));
    expect(startSql, contains("'table_of_champions_play_in'"));
    expect(startSql, contains("play_in_status = 'active'"));
    expect(startSql, contains('play_in_table_id = selected_play_in_table_id'));
    expect(
      migration,
      contains(
        'grant execute on function public.start_table_of_champions_play_in(uuid, uuid)',
      ),
    );
  });

  test('play-in winner creates final champions and redemption assignments', () {
    final awardSql = _extractFunction(
      migration,
      'app_private.apply_bonus_round_champion_award',
    );
    final recalcSql = _extractFunction(
      migration,
      'app_private.recalculate_session_unowned',
    );

    expect(
        awardSql,
        contains(
            "session_row.bonus_table_role = 'table_of_champions_play_in'"));
    expect(awardSql, contains('play_in_winner_seed_rank_value'));
    expect(awardSql, contains("play_in_status = 'completed'"));
    expect(awardSql, contains('play_in_session_id = session_row.id'));
    expect(awardSql, contains('safe_champions'));
    expect(
      awardSql,
      contains(
        "'table_of_redemption',\n        'table_of_champions_play_in'",
      ),
    );
    expect(awardSql, contains('ranked_players.seed_rank < 4'));
    expect(
      awardSql,
      isNot(
        contains(
            'ranked_players.total_points > play_in_winner_total_points_value'),
      ),
    );
    expect(awardSql, contains('play_in_winner'));
    expect(awardSql, contains('final_champions'));
    expect(awardSql, contains("'table_of_champions'"));
    expect(awardSql, contains("'table_of_redemption'"));
    expect(awardSql,
        contains('ranked_players.seed_rank > ranked_players.player_count - 4'));
    expect(
        recalcSql,
        contains(
            "session_row.bonus_table_role in (\n      'table_of_champions_sudden_death',\n      'table_of_champions_play_in'\n    )"));
    expect(recalcSql, contains('Play-in requires 2 to 4 seated players.'));
    expect(recalcSql,
        contains("coalesce(session_row.end_reason, 'play_in_resolved')"));
  });

  test('migration reloads postgrest schema cache', () {
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
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
