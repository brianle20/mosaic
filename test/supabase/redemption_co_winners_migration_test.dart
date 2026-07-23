import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Redemption co-winners migration', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/'
        '20260723103000_allow_redemption_co_winners.sql',
      ).readAsStringSync();
    });

    test('replaces standalone winner tiebreaks with co-winners', () {
      expect(
        migration,
        contains(
          'rename to recalculate_finals_state_before_redemption_co_winners',
        ),
      );
      expect(
        migration,
        contains(
          'recalculate_finals_state_before_redemption_co_winners(',
        ),
      );
      expect(
        migration,
        contains(
          'rename to create_finals_tiebreak_before_redemption_co_winners',
        ),
      );
      expect(
        migration,
        contains("if target_type = 'redemption_winner_tiebreak' then"),
      );
      expect(
        migration,
        contains("contest.contest_type = 'redemption_winner_tiebreak'"),
      );
      expect(migration, contains("set status = 'cancelled'"));
      expect(migration, contains("then 'winner'"));
      expect(migration, contains('finish_rank = 1'));
      expect(
        migration,
        contains("redemption_resolution_method = 'table_score_tie'"),
      );
    });

    test('completes Finals from resolved Redemption participant outcomes', () {
      expect(
        migration,
        contains("contest.contest_type = 'table_of_redemption'"),
      );
      expect(migration, contains("participant.outcome = 'winner'"));
      expect(migration, contains('root.champion_event_guest_id is not null'));
      expect(
        migration,
        contains('root.redemption_winner_event_guest_id is not null'),
      );
    });

    test('preserves the advancement tiebreak progression path', () {
      expect(
        migration,
        isNot(contains(
          "contest.contest_type = 'redemption_advancement_tiebreak'",
        )),
      );
      expect(
        migration,
        isNot(contains(
          "contest.contest_type = 'champions_sudden_death'",
        )),
      );
    });
  });
}
