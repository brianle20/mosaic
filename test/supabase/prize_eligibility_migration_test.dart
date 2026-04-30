import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prize preview uses half of median scored-player hands', () {
    final migrationFiles = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('median_prize_eligibility'))
        .toList();

    expect(migrationFiles, isNotEmpty);

    final migration = migrationFiles.single.readAsStringSync();

    expect(migration, contains('minimum_hands_played'));
    expect(migration, contains('percentile_cont(0.5)'));
    expect(migration, contains('ceil(median_hands_played * 0.5)'));
    expect(migration, contains('greatest(1,'));
    expect(migration, contains('leaderboard.hands_played >='));
    expect(migration, isNot(contains('ceil(total_scored_hands / 2.0)')));
    expect(migration, isNot(contains('guest.has_scored_play = true')));
  });
}
