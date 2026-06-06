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

    test('defaults missing scoring phase to tournament', () {
      final session = TableSessionRecord.fromJson(
        _sessionJson()..remove('scoring_phase'),
      );

      expect(session.scoringPhase, EventScoringPhase.tournament);
      expect(session.toJson()['scoring_phase'], 'tournament');
    });
  });

  group('TableSessionRecord tournament round fields', () {
    test('round-trips tournament round metadata from JSON', () {
      final session = TableSessionRecord.fromJson(
        _sessionJson(
          tournamentRoundId: 'rnd_01',
          assignmentRound: 4,
        ),
      );

      expect(session.tournamentRoundId, 'rnd_01');
      expect(session.assignmentRound, 4);
      expect(session.toJson()['tournament_round_id'], 'rnd_01');
      expect(session.toJson()['assignment_round'], 4);
    });
  });
}

Map<String, dynamic> _sessionJson({
  String scoringPhase = 'tournament',
  String? tournamentRoundId,
  int? assignmentRound,
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
    'tournament_round_id': tournamentRoundId,
    'assignment_round': assignmentRound,
  };
}
