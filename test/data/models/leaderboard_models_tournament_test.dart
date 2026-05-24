import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';

void main() {
  group('QualificationLeaderboardRow', () {
    test('parses a host-only qualification leaderboard row', () {
      final row = QualificationLeaderboardRow.fromJson(const {
        'event_guest_id': 'gst_01',
        'guest_profile_id': 'prf_01',
        'full_name': 'Alice Wong Chen',
        'tournament_status': 'qualified',
        'qualification_points': 64,
        'hands_played': 8,
        'wins': 3,
        'self_draw_wins': 1,
        'discard_wins': 2,
        'rank': 1,
      });

      expect(row.eventGuestId, 'gst_01');
      expect(row.guestProfileId, 'prf_01');
      expect(row.fullName, 'Alice Wong Chen');
      expect(row.tournamentStatus, EventTournamentStatus.qualified);
      expect(row.qualificationPoints, 64);
      expect(row.handsPlayed, 8);
      expect(row.wins, 3);
      expect(row.selfDrawWins, 1);
      expect(row.discardWins, 2);
      expect(row.rank, 1);
      expect(row.toJson()['tournament_status'], 'qualified');
    });
  });
}
