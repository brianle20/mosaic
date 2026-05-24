import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/session_models.dart';

void main() {
  group('TableSessionRecord scoring phase', () {
    test('round-trips scoring phase from JSON', () {
      final session = TableSessionRecord.fromJson(
        _sessionJson(scoringPhase: 'bonus'),
      );

      expect(session.scoringPhase, EventScoringPhase.bonus);
      expect(session.toJson()['scoring_phase'], 'bonus');
    });

    test('defaults missing scoring phase to qualification', () {
      final session = TableSessionRecord.fromJson(
        _sessionJson()..remove('scoring_phase'),
      );

      expect(session.scoringPhase, EventScoringPhase.qualification);
      expect(session.toJson()['scoring_phase'], 'qualification');
    });
  });
}

Map<String, dynamic> _sessionJson({
  String scoringPhase = 'tournament',
}) {
  return {
    'id': 'ses_01',
    'event_id': 'evt_01',
    'event_table_id': 'tbl_01',
    'session_number_for_table': 1,
    'ruleset_id': 'HK_STANDARD',
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': {},
    'status': 'active',
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': 0,
    'dealer_pass_count': 0,
    'completed_games_count': 0,
    'hand_count': 0,
    'started_at': '2026-04-24T19:00:00-07:00',
    'started_by_user_id': 'usr_01',
    'scoring_phase': scoringPhase,
  };
}
