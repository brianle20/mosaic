import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public Redemption results preserve co-winners and singular results',
    () {
      final migrationFile = File(
        'supabase/migrations/'
        '20260723101500_public_redemption_tie_results.sql',
      );

      expect(migrationFile.existsSync(), isTrue);

      final migration = migrationFile.readAsStringSync();

      expect(
        migration,
        contains(
          'create or replace function public.get_public_event_bonus_results',
        ),
      );
      expect(migration, contains('authoritative_redemption_winner'));
      expect(
        migration,
        contains(
          'guest.id = bonus_round.redemption_winner_event_guest_id',
        ),
      );
      expect(migration, contains('ranked_redemption_points'));
      expect(migration, contains('redemption_leaders'));
      expect(
        migration,
        contains('where ranked_redemption_points.finish_rank = 1'),
      );
      expect(
        migration,
        contains('bonus_round.redemption_winner_event_guest_id is not null'),
      );
      expect(migration, isNot(contains('limit 1')));
      expect(
        migration,
        contains(
          'perform app_private.refresh_public_event_standings_snapshot(',
        ),
      );
    },
  );
}
