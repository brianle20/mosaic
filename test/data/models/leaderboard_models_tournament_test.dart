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
