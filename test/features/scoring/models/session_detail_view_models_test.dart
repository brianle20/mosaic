import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/features/scoring/models/session_detail_view_models.dart';

void main() {
  group('buildSessionDetailViewModel', () {
    test('builds title, context, status, hand count, and wind chips', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.title, 'Table 7');
      expect(viewModel.contextLabel, startsWith('Current session'));
      expect(viewModel.statusLabel, 'Active');
      expect(viewModel.handCountLabel, 'Hand 1');
      expect(viewModel.roundWindLabel, 'Round Wind: East');
      expect(viewModel.dealerLabel, 'Dealer: Giang');
    });

    test('advances round wind after each full dealer rotation cycle', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          currentDealerSeatIndex: 0,
          hands: [
            for (var index = 0; index < 4; index += 1)
              _washoutHand(
                id: 'hand_${index + 1}',
                handNumber: index + 1,
                dealerRotated: true,
              ),
          ],
          settlements: const [],
        ),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.roundWindLabel, 'Round Wind: South');
      expect(viewModel.dealerLabel, 'Dealer: Estevon');
    });

    test('uses tournament assignment round before local hand rotations', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.tournament,
          assignmentRound: 4,
          hands: const [],
          settlements: const [],
        ),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.roundWindLabel, 'Round Wind: North');
    });

    test('labels table of champions sudden death session distinctly', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.bonus,
          bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
        ),
        guestNamesById: _guestNamesById,
      );

      expect(
        viewModel.contextLabel,
        'Table of Champions Sudden Death · Session 1',
      );
    });

    test('labels table of champions play-in session distinctly', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.bonus,
          bonusTableRole: BonusTableRole.tableOfChampionsPlayIn,
        ),
        guestNamesById: _guestNamesById,
      );

      expect(
        viewModel.contextLabel,
        'Table of Champions Play-In · Session 1',
      );
    });

    test('falls back to default table session title without a table label', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(tableLabel: null),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.title, 'Table Session');
    });

    test('excludes voided hands from hand count label', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          hands: [_discardWinHand(), _voidedHand(id: 'hand_02')],
          settlements: _discardSettlements(),
        ),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.hands, hasLength(1));
      expect(viewModel.archivedHands, hasLength(1));
      expect(viewModel.handCountLabel, 'Hand 1');
    });

    test('archives voided hands outside the main hand sequence', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          hands: [
            _discardWinHand(id: 'hand_01', handNumber: 1),
            _voidedHand(id: 'hand_02', handNumber: 2),
            _washoutHand(id: 'hand_03', handNumber: 2),
          ],
          settlements: _discardSettlements(),
        ),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.hands.map((hand) => hand.title), ['Hand 1', 'Hand 2']);
      expect(viewModel.archivedHands.map((hand) => hand.title), [
        'Voided Hand 2',
      ]);
      expect(viewModel.handCountLabel, 'Hands 2');
    });

    test('builds rotated wind labels and marks current dealer separately', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.seats, hasLength(4));
      expect(viewModel.seats[0].seatLabel, 'NORTH');
      expect(viewModel.seats[1].seatLabel, 'EAST');
      expect(viewModel.seats[2].seatLabel, 'SOUTH');
      expect(viewModel.seats[3].seatLabel, 'WEST');
      expect(viewModel.seats[1].isCurrentEast, isTrue);
    });

    test('builds round timer label with countdown time', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.tournament,
          startedAt: '2026-05-20T12:20:00Z',
        ),
        guestNamesById: _guestNamesById,
        now: DateTime.parse('2026-05-20T13:00:00Z'),
      );

      expect(viewModel.showRoundTimer, isTrue);
      expect(viewModel.roundTimeLabel, '20:00');
      expect(viewModel.isRoundExpired, isFalse);
      expect(viewModel.isRoundEndingSoon, isFalse);
    });

    test('hides round timer for qualification sessions', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.qualification,
          startedAt: '2026-05-20T12:00:00Z',
        ),
        guestNamesById: _guestNamesById,
        now: DateTime.parse('2026-05-20T13:01:00Z'),
      );

      expect(viewModel.showRoundTimer, isFalse);
      expect(viewModel.roundTimeLabel, isEmpty);
      expect(viewModel.isRoundExpired, isFalse);
      expect(viewModel.isRoundEndingSoon, isFalse);
    });

    test('builds ending soon timer label under five minutes', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.tournament,
          startedAt: '2026-05-20T12:55:30Z',
        ),
        guestNamesById: _guestNamesById,
        now: DateTime.parse('2026-05-20T13:51:00Z'),
      );

      expect(viewModel.roundTimeLabel, '04:30');
      expect(viewModel.isRoundExpired, isFalse);
      expect(viewModel.isRoundEndingSoon, isTrue);
    });

    test('builds expired timer label after one hour', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.tournament,
          startedAt: '2026-05-20T12:00:00Z',
        ),
        guestNamesById: _guestNamesById,
        now: DateTime.parse('2026-05-20T13:01:00Z'),
      );

      expect(viewModel.roundTimeLabel, 'Time expired');
      expect(viewModel.isRoundExpired, isTrue);
      expect(viewModel.isRoundEndingSoon, isFalse);
    });

    test('freezes round timer label when a session ended early', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          scoringPhase: EventScoringPhase.tournament,
          status: 'ended_early',
          startedAt: '2026-05-20T12:00:00Z',
          endedAt: '2026-05-20T12:25:00Z',
        ),
        guestNamesById: _guestNamesById,
        now: DateTime.parse('2026-05-20T12:50:00Z'),
      );

      expect(viewModel.roundTimeLabel, '35:00');
      expect(viewModel.isRoundExpired, isFalse);
      expect(viewModel.isRoundEndingSoon, isFalse);
    });

    test('keeps east seat label plain when east is current dealer', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(currentDealerSeatIndex: 0),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.seats[0].seatLabel, 'EAST');
      expect(viewModel.seats[0].isCurrentEast, isTrue);
    });

    test('summarizes discard wins with persisted winner point impact', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(),
        guestNamesById: _guestNamesById,
      );

      expect(
        viewModel.hands.first.summaryLabel,
        'Justin Park won by discard · 3 fan · Estevon Jackson discarded · '
        'East rotated · Justin Park +16',
      );
    });

    test('summarizes draws without exchanging points', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          hands: [_washoutHand()],
          settlements: const [],
        ),
        guestNamesById: _guestNamesById,
      );

      expect(
        viewModel.hands.single.summaryLabel,
        'Draw · East retained · No points exchanged',
      );
    });

    test('summarizes false win penalties from persisted settlements', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          hands: [_falseWinPenaltyHand()],
          settlements: _falseWinPenaltySettlements(),
        ),
        guestNamesById: _guestNamesById,
      );

      expect(
        viewModel.hands.single.summaryLabel,
        'Giang Tran false win penalty · 6 fan to each player · '
        'East retained · Giang Tran -96',
      );
    });

    test('summarizes voided hands with correction note', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          hands: [_voidedHand()],
          settlements: const [],
        ),
        guestNamesById: _guestNamesById,
      );

      expect(
          viewModel.archivedHands.single.summaryLabel, 'Voided · Wrong winner');
    });

    test('exposes no-hand empty state', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(hands: const [], settlements: const []),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.hands, isEmpty);
      expect(viewModel.emptyHandHistoryLabel, 'No hands recorded yet.');
    });
  });
}

const _guestNamesById = {
  'gst_east': 'Estevon Jackson',
  'gst_south': 'Giang Tran',
  'gst_west': 'Justin Park',
  'gst_north': 'Nina Patel',
};

SessionDetailRecord _detail({
  String? tableLabel = 'Table 7',
  String status = 'active',
  int currentDealerSeatIndex = 1,
  EventScoringPhase scoringPhase = EventScoringPhase.qualification,
  BonusTableRole? bonusTableRole,
  int? assignmentRound,
  String startedAt = '2026-04-24T19:00:00-07:00',
  String? endedAt,
  List<Map<String, Object?>>? hands,
  List<Map<String, Object?>>? settlements,
}) {
  return SessionDetailRecord.fromJson({
    'table_label': tableLabel,
    'session': {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD',
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': status,
      'scoring_phase': eventScoringPhaseToJson(scoringPhase),
      'bonus_table_role': bonusTableRole == null
          ? null
          : switch (bonusTableRole) {
              BonusTableRole.tableOfChampions => 'table_of_champions',
              BonusTableRole.tableOfRedemption => 'table_of_redemption',
              BonusTableRole.tableOfChampionsSuddenDeath =>
                'table_of_champions_sudden_death',
              BonusTableRole.tableOfChampionsPlayIn =>
                'table_of_champions_play_in',
            },
      'assignment_round': assignmentRound,
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': currentDealerSeatIndex,
      'dealer_pass_count': 1,
      'completed_games_count': 0,
      'hand_count': 1,
      'started_at': startedAt,
      'ended_at': endedAt,
      'started_by_user_id': 'usr_01',
    },
    'seats': const [
      {
        'id': 'seat_01',
        'table_session_id': 'ses_01',
        'seat_index': 0,
        'initial_wind': 'east',
        'event_guest_id': 'gst_east',
      },
      {
        'id': 'seat_02',
        'table_session_id': 'ses_01',
        'seat_index': 1,
        'initial_wind': 'south',
        'event_guest_id': 'gst_south',
      },
      {
        'id': 'seat_03',
        'table_session_id': 'ses_01',
        'seat_index': 2,
        'initial_wind': 'west',
        'event_guest_id': 'gst_west',
      },
      {
        'id': 'seat_04',
        'table_session_id': 'ses_01',
        'seat_index': 3,
        'initial_wind': 'north',
        'event_guest_id': 'gst_north',
      },
    ],
    'hands': hands ?? [_discardWinHand()],
    'settlements': settlements ?? _discardSettlements(),
  });
}

Map<String, Object?> _discardWinHand({
  String id = 'hand_01',
  int handNumber = 1,
}) {
  return {
    'id': id,
    'table_session_id': 'ses_01',
    'hand_number': handNumber,
    'result_type': 'win',
    'winner_seat_index': 2,
    'win_type': 'discard',
    'discarder_seat_index': 0,
    'fan_count': 3,
    'base_points': 8,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': 1,
    'dealer_rotated': true,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:05:00-07:00',
  };
}

Map<String, Object?> _washoutHand({
  String id = 'hand_02',
  int handNumber = 1,
  bool dealerRotated = false,
}) {
  return {
    'id': id,
    'table_session_id': 'ses_01',
    'hand_number': handNumber,
    'result_type': 'washout',
    'east_seat_index_before_hand': 1,
    'east_seat_index_after_hand': dealerRotated ? 2 : 1,
    'dealer_rotated': dealerRotated,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:10:00-07:00',
  };
}

Map<String, Object?> _falseWinPenaltyHand({
  String id = 'hand_04',
  int handNumber = 2,
}) {
  return {
    'id': id,
    'table_session_id': 'ses_01',
    'hand_number': handNumber,
    'result_type': 'false_win_penalty',
    'winner_seat_index': null,
    'win_type': null,
    'discarder_seat_index': null,
    'penalty_seat_index': 1,
    'fan_count': 6,
    'base_points': 32,
    'east_seat_index_before_hand': 1,
    'east_seat_index_after_hand': 1,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:15:00-07:00',
  };
}

Map<String, Object?> _voidedHand({
  String id = 'hand_01',
  int handNumber = 1,
}) {
  return {
    ..._discardWinHand(id: id, handNumber: handNumber),
    'id': id,
    'status': 'voided',
    'correction_note': 'Wrong winner',
  };
}

List<Map<String, Object?>> _discardSettlements() {
  return const [
    {
      'id': 'set_01',
      'hand_result_id': 'hand_01',
      'payer_event_guest_id': 'gst_east',
      'payee_event_guest_id': 'gst_west',
      'amount_points': 8,
      'multiplier_flags_json': ['discard'],
    },
    {
      'id': 'set_02',
      'hand_result_id': 'hand_01',
      'payer_event_guest_id': 'gst_south',
      'payee_event_guest_id': 'gst_west',
      'amount_points': 8,
      'multiplier_flags_json': ['discard'],
    },
  ];
}

List<Map<String, Object?>> _falseWinPenaltySettlements() {
  return const [
    {
      'id': 'set_03',
      'hand_result_id': 'hand_04',
      'payer_event_guest_id': 'gst_south',
      'payee_event_guest_id': 'gst_east',
      'amount_points': 32,
      'multiplier_flags_json': ['false_win_penalty'],
    },
    {
      'id': 'set_04',
      'hand_result_id': 'hand_04',
      'payer_event_guest_id': 'gst_south',
      'payee_event_guest_id': 'gst_west',
      'amount_points': 32,
      'multiplier_flags_json': ['false_win_penalty'],
    },
    {
      'id': 'set_05',
      'hand_result_id': 'hand_04',
      'payer_event_guest_id': 'gst_south',
      'payee_event_guest_id': 'gst_north',
      'amount_points': 32,
      'multiplier_flags_json': ['false_win_penalty'],
    },
  ];
}
