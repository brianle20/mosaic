import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaderboard migration computes per-player hands played', () {
    final migration = File(
      'supabase/migrations/20260430210000_leaderboard_hands_played.sql',
    ).readAsStringSync();

    expect(migration, contains('hands_played integer not null default 0'));
    expect(migration, contains('hand_play_totals'));
    expect(migration, contains('count(hand_result.id) as hands_played'));
    expect(migration,
        contains('drop function if exists public.get_event_leaderboard(uuid)'));
    expect(migration, contains("column_name = 'score_total_points'"));
    expect(migration, contains('score.hands_played'));
  });
}
