import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/features/scoring/models/event_hand_ledger_view_models.dart';

void main() {
  group('buildEventHandLedgerViewModels', () {
    test('formats discard row with four wind-ordered cells', () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 4,
          tableLabel: 'Table 1',
          sessionNumberForTable: 2,
          enteredAt: '2026-04-24T13:26:00-07:00',
          winType: 'discard',
          fanCount: 4,
          deltas: [0, 32, -32, 0],
        )),
      ]);

      expect(rows.single.handLabel, 'Table 1 · Session 2 · Hand 4');
      expect(rows.single.loggedTimeLabel, '1:26 PM');
      expect(rows.single.resultSummary, '4 fan discard');
      expect(rows.single.cells.map((cell) => cell.pointsLabel), [
        '0',
        '+32',
        '-32',
        '0',
      ]);
      expect(rows.single.cells.map((cell) => cell.displayName), [
        'Estevon',
        'Giang',
        'Justin',
        'Wen',
      ]);
    });

    test('formats self-draw, draw, and voided summaries', () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 8,
          winType: 'self_draw',
          fanCount: 3,
          deltas: [-16, 40, -8, -16],
        )),
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 5,
          resultType: 'washout',
          winType: null,
          fanCount: null,
          hasSettlements: false,
          deltas: [0, 0, 0, 0],
        )),
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 4,
          status: 'voided',
          deltas: [0, 0, 0, 0],
        )),
      ]);

      expect(rows[0].resultSummary, '3 fan self-draw');
      expect(rows[1].resultSummary, 'draw');
      expect(rows[2].resultSummary, 'voided');
      expect(rows[2].isVoided, isTrue);
    });

    test('formats attached false win penalties on final hand summaries', () {
      final entry = EventHandLedgerEntry.fromJson(_rowJson(
        handNumber: 12,
        winType: 'self_draw',
        fanCount: 4,
        falseWinPenaltiesJson: const [
          {
            'penaltySeatIndex': 1,
            'fanCount': 6,
          },
          {
            'penaltySeatIndex': 2,
            'fanCount': 6,
          },
        ],
      ));

      final rows = buildEventHandLedgerViewModels([entry]);

      expect(entry.falseWinPenalties, hasLength(2));
      expect(entry.falseWinPenalties.first.penaltySeatIndex, 1);
      expect(
          rows.single.resultSummary, '4 fan self-draw · 2 false win penalties');
    });

    test('marks draw with false win penalties and no settlements as invalid',
        () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 13,
          resultType: 'washout',
          winType: null,
          fanCount: null,
          hasSettlements: false,
          deltas: [0, 0, 0, 0],
          falseWinPenaltiesJson: const [
            {
              'penaltySeatIndex': 1,
              'fanCount': 6,
            },
          ],
        )),
      ]);

      expect(rows.single.hasDataIssue, isTrue);
      expect(rows.single.resultSummary, 'needs review');
    });

    test('formats false win penalty summary and points', () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 10,
          resultType: 'false_win_penalty',
          winType: null,
          fanCount: 6,
          penaltySeatIndex: 1,
          deltas: [32, -96, 32, 32],
        )),
      ]);

      expect(rows.single.resultSummary, '6 fan false win penalty');
      expect(rows.single.cells.map((cell) => cell.pointsLabel), [
        '+32',
        '-96',
        '+32',
        '+32',
      ]);
    });

    test('marks scored win without settlements as invalid', () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 9,
          hasSettlements: false,
        )),
      ]);

      expect(rows.single.hasDataIssue, isTrue);
      expect(rows.single.resultSummary, 'needs review');
    });

    test('keeps hand summary and marks bonus round hand rows', () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson(_rowJson(
          handNumber: 11,
          bonusRoundId: 'bonus_01',
          bonusTableRole: 'table_of_champions',
        )),
      ]);

      expect(rows.single.resultSummary, '7 fan discard');
      expect(rows.single.isBonusRound, isTrue);
      expect(rows.single.cells.map((cell) => cell.pointsLabel), [
        '-96',
        '0',
        '0',
        '+96',
      ]);
    });

    test('formats finals champion adjustment rows', () {
      final rows = buildEventHandLedgerViewModels([
        EventHandLedgerEntry.fromJson({
          'event_id': 'evt_01',
          'entered_at': '2026-04-24T22:15:00-07:00',
          'ledger_row_type': 'adjustment',
          'adjustment_id': 'adj_01',
          'adjustment_type': 'finals_champion_award',
          'adjustment_amount_points': 37,
          'adjustment_event_guest_id': 'gst_01',
          'adjustment_display_name': 'Alice Wong',
          'adjustment_context_json': {
            'champion_bonus_score_points': 24,
            'champion_top_up_points': 13,
          },
          'cells': const [],
        }),
      ]);

      expect(rows.single.handLabel, 'Champion award');
      expect(
        rows.single.resultSummary,
        'Bonus +24 · Top +13',
      );
      expect(rows.single.cells.single.displayName, 'Alice');
      expect(rows.single.cells.single.pointsLabel, '+37');
    });
  });

  test(
      'hand ledger row carries correction target metadata and full guest names',
      () {
    final rows = buildEventHandLedgerViewModels([_handEntry()]);

    expect(rows.single.isHandRow, isTrue);
    expect(rows.single.sessionId, 'ses_01');
    expect(rows.single.handId, 'hand_01');
    expect(rows.single.guestNamesById, {
      'gst_east': 'Alice Wong',
      'gst_south': 'Bob Lee',
      'gst_west': 'Carol Ng',
      'gst_north': 'Dee Wu',
    });
    expect(rows.single.cells.first.eventGuestId, 'gst_east');
    expect(rows.single.cells.first.fullDisplayName, 'Alice Wong');
    expect(rows.single.cells.first.displayName, 'Alice');
  });

  test('adjustment ledger row is not a hand correction target', () {
    final rows = buildEventHandLedgerViewModels([_adjustmentEntry()]);

    expect(rows.single.isHandRow, isFalse);
    expect(rows.single.sessionId, isEmpty);
    expect(rows.single.guestNamesById, isEmpty);
  });
}

Map<String, Object?> _rowJson({
  required int handNumber,
  String tableLabel = 'Table 3',
  int sessionNumberForTable = 1,
  String enteredAt = '2026-04-24T20:15:00-07:00',
  String resultType = 'win',
  String status = 'recorded',
  String? winType = 'discard',
  int? fanCount = 7,
  int? penaltySeatIndex,
  bool hasSettlements = true,
  List<int> deltas = const [-96, 0, 0, 96],
  String? bonusRoundId,
  String? bonusTableRole,
  List<Map<String, Object?>> falseWinPenaltiesJson = const [],
}) {
  return {
    'event_id': 'evt_01',
    'table_id': 'tbl_03',
    'table_label': tableLabel,
    'session_id': 'ses_03',
    'session_number_for_table': sessionNumberForTable,
    'hand_id': 'hand_$handNumber',
    'hand_number': handNumber,
    'entered_at': enteredAt,
    'result_type': resultType,
    'status': status,
    'win_type': winType,
    'fan_count': fanCount,
    'penalty_seat_index': penaltySeatIndex,
    'has_settlements': hasSettlements,
    'ledger_row_type': 'hand',
    'bonus_round_id': bonusRoundId,
    'bonus_table_role': bonusTableRole,
    'false_win_penalties_json': falseWinPenaltiesJson,
    'cells': [
      _cellJson('east', 0, 'gst_east', 'Estevon Jackson', deltas[0]),
      _cellJson('south', 1, 'gst_south', 'Giang Pham', deltas[1]),
      _cellJson('west', 2, 'gst_west', 'Justin Park', deltas[2]),
      _cellJson('north', 3, 'gst_north', 'Wen Lee', deltas[3]),
    ],
  };
}

Map<String, Object?> _cellJson(
  String wind,
  int seatIndex,
  String guestId,
  String displayName,
  int pointsDelta,
) {
  return {
    'wind': wind,
    'seat_index': seatIndex,
    'event_guest_id': guestId,
    'display_name': displayName,
    'points_delta': pointsDelta,
  };
}

EventHandLedgerEntry _handEntry() {
  return EventHandLedgerEntry(
    eventId: 'evt_01',
    tableId: 'tbl_01',
    tableLabel: 'Table 1',
    sessionId: 'ses_01',
    sessionNumberForTable: 1,
    handId: 'hand_01',
    handNumber: 1,
    enteredAt: DateTime.parse('2026-04-24T19:05:00-07:00'),
    resultType: HandResultType.win,
    status: HandResultStatus.recorded,
    winType: HandWinType.selfDraw,
    fanCount: 3,
    hasSettlements: true,
    cells: const [
      EventHandLedgerCell(
        wind: SeatWind.east,
        seatIndex: 0,
        eventGuestId: 'gst_east',
        displayName: 'Alice Wong',
        pointsDelta: 24,
      ),
      EventHandLedgerCell(
        wind: SeatWind.south,
        seatIndex: 1,
        eventGuestId: 'gst_south',
        displayName: 'Bob Lee',
        pointsDelta: -8,
      ),
      EventHandLedgerCell(
        wind: SeatWind.west,
        seatIndex: 2,
        eventGuestId: 'gst_west',
        displayName: 'Carol Ng',
        pointsDelta: -8,
      ),
      EventHandLedgerCell(
        wind: SeatWind.north,
        seatIndex: 3,
        eventGuestId: 'gst_north',
        displayName: 'Dee Wu',
        pointsDelta: -8,
      ),
    ],
  );
}

EventHandLedgerEntry _adjustmentEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'entered_at': '2026-04-24T22:15:00-07:00',
    'ledger_row_type': 'adjustment',
    'adjustment_id': 'adj_01',
    'adjustment_type': 'finals_champion_award',
    'adjustment_amount_points': 37,
    'adjustment_event_guest_id': 'gst_01',
    'adjustment_display_name': 'Alice Wong',
    'adjustment_context_json': {
      'champion_bonus_score_points': 24,
      'champion_top_up_points': 13,
    },
    'cells': const [],
  });
}
