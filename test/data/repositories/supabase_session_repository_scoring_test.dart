import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/supabase_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseSessionRepository scoring', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads session detail with ordered hands and settlements', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        sessionDetailLoader: (_) async => {
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
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 1,
            'hand_count': 1,
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
          ],
          'hands': [
            {
              'id': 'hand_01',
              'table_session_id': 'ses_01',
              'hand_number': 1,
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
              'entered_at': '2026-04-24T19:10:00-07:00',
            }
          ],
          'settlements': [
            {
              'id': 'set_01',
              'hand_result_id': 'hand_01',
              'payer_event_guest_id': 'gst_east',
              'payee_event_guest_id': 'gst_west',
              'amount_points': 16,
              'multiplier_flags_json': ['discard', 'east_loses'],
            }
          ],
        },
      );

      final detail = await repository.loadSessionDetail('ses_01');

      expect(detail.session.id, 'ses_01');
      expect(detail.seats.first.initialWind, SeatWind.east);
      expect(detail.hands.single.basePoints, 8);
      expect(detail.settlements.single.amountPoints, 16);
    });

    test(
        'loads false win penalties from direct table detail and excludes voided',
        () async {
      final server = await _FakePostgrestServer.start();
      addTearDown(server.close);
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient(server.url, 'publishable-key'),
        cache: cache,
      );

      final detail = await repository.loadSessionDetail('ses_01');

      expect(detail.falseWinPenalties.map((penalty) => penalty.id), [
        'penalty_pending',
        'penalty_attached',
      ]);
      expect(detail.pendingFalseWinPenaltySeatIndexes, [2]);
      expect(
        detail.falseWinPenaltiesForHand('hand_01').single.penaltySeatIndex,
        1,
      );
      expect(
          detail.settlements.map((settlement) => settlement.id),
          unorderedEquals([
            'set_hand_01',
            'set_pending_penalty',
            'set_attached_penalty',
          ]));
      expect(
        detail.settlements
            .singleWhere(
              (settlement) => settlement.id == 'set_pending_penalty',
            )
            .handFalseWinPenaltyId,
        'penalty_pending',
      );
      expect(
        server.requestFor('hand_false_win_penalties')?.queryParameters,
        containsPair('status', 'neq.voided'),
      );
      final settlementRequests = server.requestsFor('hand_settlements');
      expect(settlementRequests, hasLength(2));
      expect(
        _idsFromInFilter(
          settlementRequests.first.queryParameters['hand_result_id']!,
        ),
        {'hand_01'},
      );
      expect(
        _idsFromInFilter(
          settlementRequests.last.queryParameters['hand_false_win_penalty_id']!,
        ),
        {'penalty_pending', 'penalty_attached'},
      );
    });

    test('records a hand and refreshes cached session detail', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'record_hand_result');
          expect(params['target_table_session_id'], 'ses_01');
          expect(params['target_result_type'], 'washout');
          expect(params['target_dealer_was_waiting_at_draw'], isFalse);
          return {
            'id': 'hand_02',
            'table_session_id': 'ses_01',
            'hand_number': 2,
            'result_type': 'washout',
            'winner_seat_index': null,
            'win_type': null,
            'discarder_seat_index': null,
            'fan_count': null,
            'base_points': null,
            'dealer_was_waiting_at_draw': false,
            'east_seat_index_before_hand': 1,
            'east_seat_index_after_hand': 2,
            'dealer_rotated': true,
            'session_completed_after_hand': false,
            'status': 'recorded',
            'entered_by_user_id': 'usr_01',
            'entered_at': '2026-04-24T19:20:00-07:00',
          };
        },
        sessionDetailLoader: (_) async => {
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
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 2,
            'hand_count': 2,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
          },
          'seats': const [],
          'hands': [
            {
              'id': 'hand_02',
              'table_session_id': 'ses_01',
              'hand_number': 2,
              'result_type': 'washout',
              'winner_seat_index': null,
              'win_type': null,
              'discarder_seat_index': null,
              'fan_count': null,
              'base_points': null,
              'dealer_was_waiting_at_draw': false,
              'east_seat_index_before_hand': 1,
              'east_seat_index_after_hand': 2,
              'dealer_rotated': true,
              'session_completed_after_hand': false,
              'status': 'recorded',
              'entered_by_user_id': 'usr_01',
              'entered_at': '2026-04-24T19:20:00-07:00',
            }
          ],
          'settlements': const [],
        },
      );

      final detail = await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
          dealerWasWaitingAtDraw: false,
        ),
      );

      expect(detail.hands.single.handNumber, 2);
      expect(detail.hands.single.dealerWasWaitingAtDraw, isFalse);
      expect(detail.hands.single.dealerRotated, isTrue);

      final cachedDetail = await repository.readCachedSessionDetail('ses_01');
      expect(cachedDetail?.hands.single.resultType, HandResultType.washout);
    });

    test('records same-hand false win penalty through scoring RPC', () async {
      late String rpcName;
      late Map<String, dynamic> rpcParams;
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          rpcName = functionName;
          rpcParams = params;
          return {
            'id': 'penalty-1',
            'table_session_id': 'ses_01',
          };
        },
        sessionDetailLoader: (_) async => _sessionDetailJson(
          hands: const [],
          falseWinPenalties: const [
            {
              'id': 'penalty-1',
              'table_session_id': 'ses_01',
              'hand_result_id': null,
              'penalty_seat_index': 2,
              'fan_count': 6,
              'entered_by_user_id': 'usr_01',
              'entered_at': '2026-06-24T12:00:00Z',
              'status': 'pending',
              'correction_note': null,
            },
          ],
        ),
      );

      final detail = await repository.recordFalseWinPenalty(
        const RecordFalseWinPenaltyInput(
          tableSessionId: 'ses_01',
          penaltySeatIndex: 2,
          correctionNote: 'called too early',
        ),
      );

      expect(rpcName, 'record_false_win_penalty');
      expect(rpcParams['target_table_session_id'], 'ses_01');
      expect(rpcParams['target_penalty_seat_index'], 2);
      expect(rpcParams['target_correction_note'], 'called too early');
      expect(rpcParams['target_client_mutation_id'], isNull);
      expect(rpcParams['target_expected_recorded_hand_count'], isNull);
      expect(rpcParams['target_expected_last_recorded_hand_id'], isNull);
      expect(
          rpcParams.keys,
          unorderedEquals([
            'target_table_session_id',
            'target_penalty_seat_index',
            'target_correction_note',
            'target_client_mutation_id',
            'target_expected_recorded_hand_count',
            'target_expected_last_recorded_hand_id',
          ]));
      expect(detail.pendingFalseWinPenaltySeatIndexes, [2]);
    });

    test('records hand with offline idempotency params when provided',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'record_hand_result');
          expect(
            params['target_client_mutation_id'],
            '11111111-1111-1111-1111-111111111111',
          );
          expect(params['target_expected_recorded_hand_count'], 4);
          expect(params['target_expected_last_recorded_hand_id'], 'hand_04');
          return {
            'id': 'hand_05',
            'table_session_id': 'ses_01',
            'hand_number': 5,
            'result_type': 'win',
            'winner_seat_index': 0,
            'win_type': 'self_draw',
            'discarder_seat_index': null,
            'fan_count': 5,
            'base_points': 16,
            'east_seat_index_before_hand': 0,
            'east_seat_index_after_hand': 0,
            'dealer_rotated': false,
            'session_completed_after_hand': false,
            'status': 'recorded',
            'entered_by_user_id': 'usr_01',
            'entered_at': '2026-04-24T19:40:00-07:00',
          };
        },
        sessionDetailLoader: (_) async => _sessionDetailJson(
          hands: [
            _handJson(
              id: 'hand_05',
              handNumber: 5,
              winnerSeatIndex: 0,
              winType: 'self_draw',
              fanCount: 5,
            ),
          ],
        ),
      );

      final detail = await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.win,
          winnerSeatIndex: 0,
          winType: HandWinType.selfDraw,
          fanCount: 5,
          clientMutationId: '11111111-1111-1111-1111-111111111111',
          expectedRecordedHandCount: 4,
          expectedLastRecordedHandId: 'hand_04',
        ),
      );

      expect(detail.hands.single.id, 'hand_05');
    });

    test('edits and voids a hand through scoring RPCs', () async {
      final rpcCalls = <String>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          rpcCalls.add(functionName);
          return {
            'id': 'hand_01',
            'table_session_id': 'ses_01',
            'hand_number': 1,
            'result_type': params['target_result_type'] ?? 'win',
            'winner_seat_index': params['target_winner_seat_index'],
            'win_type': params['target_win_type'],
            'discarder_seat_index': params['target_discarder_seat_index'],
            'fan_count': params['target_fan_count'],
            'base_points': params['target_fan_count'] == null ? null : 8,
            'east_seat_index_before_hand': 0,
            'east_seat_index_after_hand': 0,
            'dealer_rotated': false,
            'session_completed_after_hand': false,
            'status':
                functionName == 'void_hand_result' ? 'voided' : 'recorded',
            'entered_by_user_id': 'usr_01',
            'entered_at': '2026-04-24T19:05:00-07:00',
            'correction_note': params['target_correction_note'],
          };
        },
        sessionDetailLoader: (_) async => {
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
            'current_dealer_seat_index': 0,
            'dealer_pass_count': 0,
            'completed_games_count': 1,
            'hand_count': 1,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
          },
          'seats': const [],
          'hands': [
            {
              'id': 'hand_01',
              'table_session_id': 'ses_01',
              'hand_number': 1,
              'result_type': 'win',
              'winner_seat_index': 0,
              'win_type': 'self_draw',
              'discarder_seat_index': null,
              'fan_count': 3,
              'base_points': 8,
              'east_seat_index_before_hand': 0,
              'east_seat_index_after_hand': 0,
              'dealer_rotated': false,
              'session_completed_after_hand': false,
              'status':
                  rpcCalls.isNotEmpty && rpcCalls.last == 'void_hand_result'
                      ? 'voided'
                      : 'recorded',
              'entered_by_user_id': 'usr_01',
              'entered_at': '2026-04-24T19:05:00-07:00',
              'correction_note': 'fixed host entry',
            }
          ],
          'settlements': const [],
        },
      );

      final edited = await repository.editHand(
        const EditHandResultInput(
          handResultId: 'hand_01',
          resultType: HandResultType.win,
          winnerSeatIndex: 0,
          winType: HandWinType.selfDraw,
          fanCount: 3,
          correctionNote: 'fixed host entry',
        ),
      );
      final voided = await repository.voidHand(
        const VoidHandResultInput(
          handResultId: 'hand_01',
          correctionNote: 'voiding bad hand',
        ),
      );

      expect(rpcCalls, ['edit_hand_result', 'void_hand_result']);
      expect(edited.hands.single.status, HandResultStatus.recorded);
      expect(voided.hands.single.status, HandResultStatus.voided);
    });
  });
}

Map<String, dynamic> _sessionDetailJson({
  required List<Map<String, dynamic>> hands,
  List<Map<String, dynamic>> falseWinPenalties = const [],
}) {
  return {
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
      'current_dealer_seat_index': 0,
      'dealer_pass_count': 0,
      'completed_games_count': hands.length,
      'hand_count': hands.length,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': const [],
    'hands': hands,
    'settlements': const [],
    'false_win_penalties': falseWinPenalties,
  };
}

class _FakePostgrestServer {
  _FakePostgrestServer._(this._server);

  final HttpServer _server;
  final _requestsByTable = <String, List<Uri>>{};

  String get url => 'http://${_server.address.host}:${_server.port}';

  static Future<_FakePostgrestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakePostgrestServer._(server);
    server.listen(fake._handleRequest);
    return fake;
  }

  Uri? requestFor(String table) {
    final requests = _requestsByTable[table];
    if (requests == null || requests.isEmpty) {
      return null;
    }
    return requests.last;
  }

  List<Uri> requestsFor(String table) {
    return List.unmodifiable(_requestsByTable[table] ?? const []);
  }

  Future<void> close() => _server.close(force: true);

  void _handleRequest(HttpRequest request) {
    final table = request.uri.pathSegments.last;
    _requestsByTable.putIfAbsent(table, () => []).add(request.uri);
    final responseBody = switch (table) {
      'table_sessions' => _sessionRow(),
      'table_session_seats' => [_seatRow(0), _seatRow(1), _seatRow(2)],
      'hand_results' => [_handResultRow()],
      'hand_settlements' => _settlementRows(request.uri),
      'hand_false_win_penalties' => _falseWinPenaltyRows(request.uri),
      'event_tables' => {'label': 'Table 1'},
      _ => <String, dynamic>{},
    };

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseBody));
    unawaited(request.response.close());
  }

  List<Map<String, dynamic>> _falseWinPenaltyRows(Uri uri) {
    final rows = [
      {
        'id': 'penalty_pending',
        'table_session_id': 'ses_01',
        'hand_result_id': null,
        'penalty_seat_index': 2,
        'fan_count': 6,
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-06-24T12:00:00Z',
        'status': 'pending',
        'correction_note': null,
      },
      {
        'id': 'penalty_attached',
        'table_session_id': 'ses_01',
        'hand_result_id': 'hand_01',
        'penalty_seat_index': 1,
        'fan_count': 6,
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-06-24T12:01:00Z',
        'status': 'attached',
        'correction_note': null,
      },
      {
        'id': 'penalty_voided',
        'table_session_id': 'ses_01',
        'hand_result_id': 'hand_01',
        'penalty_seat_index': 3,
        'fan_count': 6,
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-06-24T12:02:00Z',
        'status': 'voided',
        'correction_note': null,
      },
    ];

    if (uri.queryParameters['status'] == 'neq.voided') {
      return rows
          .where((row) => row['status'] != 'voided')
          .toList(growable: false);
    }

    return rows;
  }
}

Map<String, dynamic> _sessionRow() {
  return {
    'id': 'ses_01',
    'event_id': 'evt_01',
    'event_table_id': 'tbl_01',
    'session_number_for_table': 1,
    'ruleset_id': 'HK_STANDARD',
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': <String, dynamic>{},
    'status': 'active',
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': 0,
    'dealer_pass_count': 0,
    'completed_games_count': 1,
    'hand_count': 1,
    'started_at': '2026-04-24T19:00:00-07:00',
    'started_by_user_id': 'usr_01',
  };
}

Map<String, dynamic> _seatRow(int seatIndex) {
  return {
    'id': 'seat_$seatIndex',
    'table_session_id': 'ses_01',
    'seat_index': seatIndex,
    'initial_wind': switch (seatIndex) {
      0 => 'east',
      1 => 'south',
      2 => 'west',
      _ => 'north',
    },
    'event_guest_id': 'gst_$seatIndex',
  };
}

Map<String, dynamic> _handResultRow() {
  return {
    'id': 'hand_01',
    'table_session_id': 'ses_01',
    'hand_number': 1,
    'result_type': 'win',
    'winner_seat_index': 0,
    'win_type': 'self_draw',
    'discarder_seat_index': null,
    'fan_count': 3,
    'base_points': 8,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': 0,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:10:00-07:00',
  };
}

List<Map<String, dynamic>> _settlementRows(Uri uri) {
  final rows = [
    {
      'id': 'set_hand_01',
      'hand_result_id': 'hand_01',
      'hand_false_win_penalty_id': null,
      'payer_event_guest_id': 'gst_1',
      'payee_event_guest_id': 'gst_0',
      'amount_points': 16,
      'multiplier_flags_json': ['self_draw'],
    },
    {
      'id': 'set_pending_penalty',
      'hand_result_id': null,
      'hand_false_win_penalty_id': 'penalty_pending',
      'payer_event_guest_id': 'gst_2',
      'payee_event_guest_id': 'gst_0',
      'amount_points': 32,
      'multiplier_flags_json': ['false_win_penalty'],
    },
    {
      'id': 'set_attached_penalty',
      'hand_result_id': 'hand_01',
      'hand_false_win_penalty_id': 'penalty_attached',
      'payer_event_guest_id': 'gst_1',
      'payee_event_guest_id': 'gst_0',
      'amount_points': 32,
      'multiplier_flags_json': ['false_win_penalty'],
    },
  ];

  final handResultFilter = uri.queryParameters['hand_result_id'];
  if (handResultFilter != null) {
    final handResultIds = _idsFromInFilter(handResultFilter);
    return rows.where((row) {
      final handResultId = row['hand_result_id'] as String?;
      return handResultId != null && handResultIds.contains(handResultId);
    }).toList(growable: false);
  }

  final penaltyFilter = uri.queryParameters['hand_false_win_penalty_id'];
  if (penaltyFilter != null) {
    final penaltyIds = _idsFromInFilter(penaltyFilter);
    return rows.where((row) {
      final penaltyId = row['hand_false_win_penalty_id'] as String?;
      return penaltyId != null && penaltyIds.contains(penaltyId);
    }).toList(growable: false);
  }

  return rows;
}

Set<String> _idsFromInFilter(String filter) {
  if (!filter.startsWith('in.(') || !filter.endsWith(')')) {
    return const {};
  }

  final rawIds = filter.substring(4, filter.length - 1);
  if (rawIds.isEmpty) {
    return const {};
  }

  return rawIds
      .split(',')
      .map(_normalizeInFilterId)
      .where((id) => id.isNotEmpty)
      .toSet();
}

String _normalizeInFilterId(String rawId) {
  final trimmed = rawId.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

Map<String, dynamic> _handJson({
  required String id,
  required int handNumber,
  required int? winnerSeatIndex,
  required String? winType,
  required int? fanCount,
}) {
  return {
    'id': id,
    'table_session_id': 'ses_01',
    'hand_number': handNumber,
    'result_type': 'win',
    'winner_seat_index': winnerSeatIndex,
    'win_type': winType,
    'discarder_seat_index': null,
    'fan_count': fanCount,
    'base_points': 16,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': 0,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:40:00-07:00',
  };
}
