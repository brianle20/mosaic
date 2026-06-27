import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_session_projector.dart';

void main() {
  group('OfflineSessionProjector', () {
    test('appends pending win and retains dealer on dealer self draw', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(currentDealerSeatIndex: 0),
        mutations: [
          _mutation(
            id: 'mut_01',
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'win',
              'target_winner_seat_index': 0,
              'target_win_type': 'self_draw',
              'target_fan_count': 5,
            },
          ),
        ],
      );

      final hand = projected.detail.hands.single;
      expect(hand.id, 'pending:mut_01');
      expect(hand.handNumber, 1);
      expect(hand.dealerRotated, isFalse);
      expect(hand.eastSeatIndexBeforeHand, 0);
      expect(hand.eastSeatIndexAfterHand, 0);
      expect(hand.status, HandResultStatus.recorded);
      expect(hand.enteredByUserId, 'offline');
      expect(hand.correctionNote, 'Pending sync');
      expect(projected.detail.session.currentDealerSeatIndex, 0);
      expect(projected.syncSnapshot.pendingHandIds, {'pending:mut_01'});
    });

    test('rotates dealer on second post-cap dealer self draw', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(
          currentDealerSeatIndex: 0,
          completedGamesCount: 1,
          handCount: 1,
          hands: [
            _hand(
              id: 'hand_01',
              handNumber: 1,
              winnerSeatIndex: 0,
              winType: HandWinType.selfDraw,
              eastSeatIndexBeforeHand: 0,
              eastSeatIndexAfterHand: 0,
              enteredAt: DateTime.utc(2026, 5, 19, 14, 1),
            ),
          ],
        ),
        mutations: [
          _mutation(
            id: 'mut_01',
            localHandNumber: 2,
            createdAt: DateTime.utc(2026, 6, 18, 20),
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'win',
              'target_winner_seat_index': 0,
              'target_win_type': 'self_draw',
              'target_fan_count': 5,
            },
          ),
        ],
      );

      final pendingHand = projected.detail.hands.last;
      expect(pendingHand.id, 'pending:mut_01');
      expect(pendingHand.eastSeatIndexBeforeHand, 0);
      expect(pendingHand.eastSeatIndexAfterHand, 1);
      expect(pendingHand.dealerRotated, isTrue);
      expect(projected.detail.session.currentDealerSeatIndex, 1);
      expect(projected.detail.session.dealerPassCount, 1);
    });

    test('rotates dealer for non-dealer win and washout', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(currentDealerSeatIndex: 0),
        mutations: [
          _mutation(
            id: 'mut_02',
            localHandNumber: 2,
            createdAt: DateTime.utc(2026, 6, 18, 20, 2),
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'washout',
            },
          ),
          _mutation(
            id: 'mut_01',
            createdAt: DateTime.utc(2026, 6, 18, 20, 1),
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'win',
              'target_winner_seat_index': 2,
              'target_win_type': 'discard',
              'target_discarder_seat_index': 1,
              'target_fan_count': 3,
            },
          ),
        ],
      );

      expect(projected.detail.hands.map((hand) => hand.handNumber), [1, 2]);
      expect(projected.detail.hands.first.eastSeatIndexAfterHand, 1);
      expect(projected.detail.hands.last.eastSeatIndexBeforeHand, 1);
      expect(projected.detail.hands.last.eastSeatIndexAfterHand, 2);
      expect(projected.detail.session.currentDealerSeatIndex, 2);
      expect(projected.detail.session.dealerPassCount, 2);
      expect(projected.detail.session.completedGamesCount, 2);
      expect(projected.detail.session.handCount, 2);
    });

    test('marks blocked hands separately from pending hands', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(
          currentDealerSeatIndex: 0,
          completedGamesCount: 4,
          dealerPassCount: 1,
          handCount: 4,
        ),
        mutations: [
          _mutation(
            id: 'mut_01',
            status: OfflineMutationStatus.blocked,
            lastError: 'Current last hand has changed.',
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'win',
              'target_winner_seat_index': 2,
              'target_win_type': 'discard',
              'target_discarder_seat_index': 1,
              'target_fan_count': 3,
            },
          ),
        ],
      );

      final blockedHand = projected.detail.hands.single;
      expect(blockedHand.id, 'pending:mut_01');
      expect(blockedHand.eastSeatIndexBeforeHand, 0);
      expect(blockedHand.eastSeatIndexAfterHand, 0);
      expect(blockedHand.dealerRotated, isFalse);
      expect(projected.detail.session.currentDealerSeatIndex, 0);
      expect(projected.detail.session.dealerPassCount, 1);
      expect(projected.detail.session.completedGamesCount, 4);
      expect(projected.detail.session.handCount, 4);
      expect(projected.syncSnapshot.pendingHandIds, isEmpty);
      expect(projected.syncSnapshot.pendingCount, 0);
      expect(projected.syncSnapshot.isBlocked, isTrue);
      expect(projected.syncSnapshot.blockedHandIds, {'pending:mut_01'});
      expect(
        projected.syncSnapshot.blockedReason,
        'Current last hand has changed.',
      );
    });

    test('ignores synced mutations', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(currentDealerSeatIndex: 1),
        mutations: [
          _mutation(
            id: 'mut_01',
            status: OfflineMutationStatus.synced,
          ),
        ],
      );

      expect(projected.detail.hands, isEmpty);
      expect(projected.detail.session.currentDealerSeatIndex, 1);
      expect(projected.detail.session.completedGamesCount, 0);
      expect(projected.detail.session.handCount, 0);
      expect(projected.syncSnapshot.pendingHandIds, isEmpty);
      expect(projected.syncSnapshot.blockedHandIds, isEmpty);
    });

    test('does not duplicate a pending mutation already returned by server',
        () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(
          currentDealerSeatIndex: 1,
          completedGamesCount: 1,
          handCount: 1,
          hands: [
            _hand(
              id: 'hand_01',
              handNumber: 1,
              winnerSeatIndex: 2,
              winType: HandWinType.discard,
              eastSeatIndexBeforeHand: 0,
              eastSeatIndexAfterHand: 1,
              enteredAt: DateTime.utc(2026, 6, 18, 20),
              dealerRotated: true,
              clientMutationId: 'mut_01',
            ),
          ],
        ),
        mutations: [
          _mutation(
            id: 'mut_01',
            localHandNumber: 1,
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'win',
              'target_winner_seat_index': 2,
              'target_win_type': 'discard',
              'target_discarder_seat_index': 1,
              'target_fan_count': 3,
            },
          ),
        ],
      );

      expect(projected.detail.hands.map((hand) => hand.id), ['hand_01']);
      expect(projected.syncSnapshot.pendingHandIds, isEmpty);
      expect(projected.syncSnapshot.pendingCount, 0);
    });

    test('preserves false win penalties from the cached detail', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(
          currentDealerSeatIndex: 1,
          falseWinPenalties: [
            _falseWinPenalty(id: 'penalty_pending'),
            _falseWinPenalty(
              id: 'penalty_attached',
              handResultId: 'hand_01',
              status: FalseWinPenaltyStatus.attached,
            ),
          ],
        ),
        mutations: const [],
      );

      expect(projected.detail.falseWinPenalties.map((penalty) => penalty.id), [
        'penalty_pending',
        'penalty_attached',
      ]);
      expect(projected.detail.pendingFalseWinPenaltySeatIndexes, [2]);
    });

    test('false win penalty projection does not advance hand or dealer', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(
          currentDealerSeatIndex: 1,
          completedGamesCount: 5,
          dealerPassCount: 2,
          handCount: 5,
        ),
        mutations: [
          _mutation(
            id: 'mut_penalty',
            kind: OfflineMutationKind.recordFalseWinPenalty,
            localHandNumber: 6,
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_penalty_seat_index': 3,
              'target_correction_note': 'called too early',
            },
          ),
        ],
      );

      expect(projected.detail.hands, isEmpty);
      expect(projected.detail.session.currentDealerSeatIndex, 1);
      expect(projected.detail.session.dealerPassCount, 2);
      expect(projected.detail.session.completedGamesCount, 5);
      expect(projected.detail.session.handCount, 5);
      expect(projected.detail.pendingFalseWinPenaltySeatIndexes, [3]);
      expect(projected.syncSnapshot.pendingHandIds, {'pending:mut_penalty'});
    });

    test('attaches pending false win penalties to the next projected hand', () {
      final projected = const OfflineSessionProjector().project(
        detail: _detail(currentDealerSeatIndex: 1),
        mutations: [
          _mutation(
            id: 'mut_penalty',
            kind: OfflineMutationKind.recordFalseWinPenalty,
            createdAt: DateTime.utc(2026, 6, 24, 12),
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_penalty_seat_index': 3,
              'target_correction_note': 'called too early',
            },
          ),
          _mutation(
            id: 'mut_hand',
            localHandNumber: 1,
            createdAt: DateTime.utc(2026, 6, 24, 12, 1),
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'win',
              'target_winner_seat_index': 2,
              'target_win_type': 'discard',
              'target_discarder_seat_index': 1,
              'target_fan_count': 3,
            },
          ),
        ],
      );

      expect(projected.detail.hands.single.id, 'pending:mut_hand');
      expect(projected.detail.pendingFalseWinPenaltySeatIndexes, isEmpty);
      expect(projected.detail.falseWinPenalties.single.handResultId,
          'pending:mut_hand');
      expect(projected.detail.falseWinPenalties.single.status,
          FalseWinPenaltyStatus.attached);
      expect(projected.syncSnapshot.pendingHandIds,
          {'pending:mut_penalty', 'pending:mut_hand'});
    });

    test('rejects duplicate false win penalty mutations for same seat', () {
      expect(
        () => const OfflineSessionProjector().project(
          detail: _detail(currentDealerSeatIndex: 1),
          mutations: [
            _mutation(
              id: 'mut_penalty_1',
              kind: OfflineMutationKind.recordFalseWinPenalty,
              createdAt: DateTime.utc(2026, 6, 24, 12),
              payload: const {
                'target_table_session_id': 'ses_01',
                'target_penalty_seat_index': 3,
                'target_correction_note': null,
              },
            ),
            _mutation(
              id: 'mut_penalty_2',
              kind: OfflineMutationKind.recordFalseWinPenalty,
              createdAt: DateTime.utc(2026, 6, 24, 12, 1),
              payload: const {
                'target_table_session_id': 'ses_01',
                'target_penalty_seat_index': 3,
                'target_correction_note': null,
              },
            ),
          ],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('False win caller already has a pending penalty.'),
          ),
        ),
      );
    });
  });
}

OfflineMutationRecord _mutation({
  required String id,
  OfflineMutationKind kind = OfflineMutationKind.recordHand,
  int localHandNumber = 1,
  DateTime? createdAt,
  OfflineMutationStatus status = OfflineMutationStatus.pending,
  String? lastError,
  Map<String, dynamic> payload = const {
    'target_table_session_id': 'ses_01',
    'target_result_type': 'false_win_penalty',
    'target_penalty_seat_index': 3,
  },
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 6, 18, 20);
  return OfflineMutationRecord(
    id: id,
    kind: kind,
    eventId: 'evt_01',
    sessionId: 'ses_01',
    payload: payload,
    baseRecordedHandCount: 0,
    baseLastRecordedHandId: null,
    localHandNumber: localHandNumber,
    createdAt: timestamp,
    updatedAt: timestamp,
    status: status,
    lastError: lastError,
  );
}

SessionDetailRecord _detail({
  required int currentDealerSeatIndex,
  int completedGamesCount = 0,
  int dealerPassCount = 0,
  int handCount = 0,
  List<HandResultRecord> hands = const [],
  List<FalseWinPenaltyRecord> falseWinPenalties = const [],
}) {
  return SessionDetailRecord.fromJson({
    'table_label': 'Table 1',
    'session': {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD',
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': 'active',
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': currentDealerSeatIndex,
      'dealer_pass_count': dealerPassCount,
      'completed_games_count': completedGamesCount,
      'hand_count': handCount,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': [
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
    'hands': hands.map((hand) => hand.toJson()).toList(growable: false),
    'settlements': const [],
    'false_win_penalties': falseWinPenalties
        .map((penalty) => penalty.toJson())
        .toList(growable: false),
  });
}

FalseWinPenaltyRecord _falseWinPenalty({
  required String id,
  String? handResultId,
  FalseWinPenaltyStatus status = FalseWinPenaltyStatus.pending,
}) {
  return FalseWinPenaltyRecord(
    id: id,
    tableSessionId: 'ses_01',
    handResultId: handResultId,
    penaltySeatIndex: 2,
    fanCount: 6,
    enteredByUserId: 'usr_01',
    enteredAt: DateTime.utc(2026, 6, 24, 12),
    status: status,
  );
}

HandResultRecord _hand({
  required String id,
  required int handNumber,
  required int winnerSeatIndex,
  required HandWinType winType,
  required int eastSeatIndexBeforeHand,
  required int eastSeatIndexAfterHand,
  required DateTime enteredAt,
  bool dealerRotated = false,
  String? clientMutationId,
}) {
  return HandResultRecord(
    id: id,
    tableSessionId: 'ses_01',
    handNumber: handNumber,
    resultType: HandResultType.win,
    winnerSeatIndex: winnerSeatIndex,
    winType: winType,
    fanCount: 5,
    eastSeatIndexBeforeHand: eastSeatIndexBeforeHand,
    eastSeatIndexAfterHand: eastSeatIndexAfterHand,
    dealerRotated: dealerRotated,
    sessionCompletedAfterHand: false,
    status: HandResultStatus.recorded,
    enteredByUserId: 'usr_01',
    enteredAt: enteredAt,
    clientMutationId: clientMutationId,
  );
}
