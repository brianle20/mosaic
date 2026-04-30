import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/features/scoring/models/session_detail_view_models.dart';

void main() {
  group('buildSessionDetailViewModel', () {
    test('builds title, context, status, hand count, and current East chip',
        () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.title, 'Table 7');
      expect(viewModel.contextLabel, startsWith('Current session'));
      expect(viewModel.statusLabel, 'Active');
      expect(viewModel.handCountLabel, 'Hand 1');
      expect(viewModel.currentEastLabel, 'East: Giang');
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

      expect(viewModel.hands, hasLength(2));
      expect(viewModel.handCountLabel, 'Hand 1');
    });

    test('builds four seat labels and marks current dealer separately', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(),
        guestNamesById: _guestNamesById,
      );

      expect(viewModel.seats, hasLength(4));
      expect(viewModel.seats[1].seatLabel, 'SOUTH');
      expect(viewModel.seats[1].isCurrentEast, isTrue);
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

    test('summarizes washouts without exchanging points', () {
      final viewModel = buildSessionDetailViewModel(
        detail: _detail(
          hands: [_washoutHand()],
          settlements: const [],
        ),
        guestNamesById: _guestNamesById,
      );

      expect(
        viewModel.hands.single.summaryLabel,
        'Washout · East retained · No points exchanged',
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

      expect(viewModel.hands.single.summaryLabel, 'Voided · Wrong winner');
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
  int currentDealerSeatIndex = 1,
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
      'status': 'active',
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': currentDealerSeatIndex,
      'dealer_pass_count': 1,
      'completed_games_count': 0,
      'hand_count': 1,
      'started_at': '2026-04-24T19:00:00-07:00',
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

Map<String, Object?> _discardWinHand() {
  return {
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
    'entered_at': '2026-04-24T19:05:00-07:00',
  };
}

Map<String, Object?> _washoutHand() {
  return {
    'id': 'hand_02',
    'table_session_id': 'ses_01',
    'hand_number': 1,
    'result_type': 'washout',
    'east_seat_index_before_hand': 1,
    'east_seat_index_after_hand': 1,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:10:00-07:00',
  };
}

Map<String, Object?> _voidedHand({String id = 'hand_01'}) {
  return {
    ..._discardWinHand(),
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
