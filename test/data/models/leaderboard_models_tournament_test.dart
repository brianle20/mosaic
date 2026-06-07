import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';

void main() {
  group('LeaderboardEntry', () {
    test('parses tournament status and preserves legacy qualified rows', () {
      final withdrawnEntry = LeaderboardEntry.fromJson(const {
        'event_guest_id': 'gst_01',
        'display_name': 'Alice Wong',
        'tournament_status': 'withdrawn',
        'total_points': 64,
        'hands_played': 8,
        'hands_won': 3,
        'self_draw_wins': 1,
        'discard_wins': 2,
        'rank': 1,
      });
      final legacyEntry = LeaderboardEntry.fromJson(const {
        'event_guest_id': 'gst_02',
        'display_name': 'Brian Le',
        'total_points': 32,
        'hands_played': 8,
        'hands_won': 2,
        'self_draw_wins': 0,
        'discard_wins': 2,
        'rank': 2,
      });

      expect(withdrawnEntry.tournamentStatus, EventTournamentStatus.withdrawn);
      expect(withdrawnEntry.toJson()['tournament_status'], 'withdrawn');
      expect(legacyEntry.tournamentStatus, EventTournamentStatus.qualified);
    });
  });
}
