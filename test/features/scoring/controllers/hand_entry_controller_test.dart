import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/features/scoring/controllers/hand_entry_controller.dart';

import '../../../helpers/repository_fakes.dart';

class _RecordingSessionRepository extends ThrowingSessionRepository {
  RecordFalseWinPenaltyInput? falseWinPenaltyInput;

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) async {
    falseWinPenaltyInput = input;
    return SessionDetailRecord.fromJson(const {
      'session': {
        'id': 'session-1',
        'event_id': 'event-1',
        'event_table_id': 'table-1',
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
        'started_at': '2026-06-24T12:00:00Z',
        'started_by_user_id': 'host-1',
      },
      'seats': [],
      'hands': [],
      'settlements': [],
      'false_win_penalties': [],
    });
  }
}

void main() {
  group('HandEntryController', () {
    test('records false win penalty through repository', () async {
      final repository = _RecordingSessionRepository();
      final controller = HandEntryController(sessionRepository: repository);

      final detail = await controller.recordFalseWinPenalty(
        tableSessionId: 'session-1',
        penaltySeatIndex: 3,
      );

      expect(detail, isNotNull);
      expect(repository.falseWinPenaltyInput?.tableSessionId, 'session-1');
      expect(repository.falseWinPenaltyInput?.penaltySeatIndex, 3);
      expect(controller.submitError, isNull);
    });
  });
}
