import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/features/events/models/bonus_round_results_summary.dart';

void main() {
  test('surfaces required sudden death as pending results with tied players',
      () {
    final summary = buildBonusRoundResultsSummary(
      ledgerEntries: const [],
      leaderboardEntries: const [],
      bonusRoundState: const BonusRoundState(
        suddenDeathStatus: 'required',
        championResolutionMethod: 'sudden_death',
        tiedTopPlayers: [
          BonusRoundTiedPlayer(
            eventGuestId: 'gst_alice',
            displayName: 'Alice Wong',
            bonusScorePoints: 120,
            seedRank: 1,
          ),
          BonusRoundTiedPlayer(
            eventGuestId: 'gst_bob',
            displayName: 'Bob Lee',
            bonusScorePoints: 120,
            seedRank: 2,
          ),
        ],
      ),
    );

    expect(summary.hasResults, isTrue);
    expect(summary.finalChampion, isNull);
    expect(summary.suddenDeathStatus?.statusLabel, 'Sudden death required');
    expect(summary.suddenDeathStatus?.detailLabel, contains('Alice Wong'));
    expect(summary.suddenDeathStatus?.detailLabel, contains('Bob Lee'));
    expect(summary.suddenDeathStatus?.detailLabel, contains('120 pts'));
  });

  test('surfaces active sudden death as pending results', () {
    final summary = buildBonusRoundResultsSummary(
      ledgerEntries: const [],
      leaderboardEntries: const [],
      bonusRoundState: const BonusRoundState(
        suddenDeathStatus: 'active',
        championResolutionMethod: 'sudden_death',
        tiedTopPlayers: [
          BonusRoundTiedPlayer(
            eventGuestId: 'gst_alice',
            displayName: 'Alice Wong',
            bonusScorePoints: 120,
            seedRank: 1,
          ),
          BonusRoundTiedPlayer(
            eventGuestId: 'gst_bob',
            displayName: 'Bob Lee',
            bonusScorePoints: 120,
            seedRank: 2,
          ),
        ],
      ),
    );

    expect(summary.hasResults, isTrue);
    expect(summary.finalChampion, isNull);
    expect(summary.suddenDeathStatus?.statusLabel, 'Sudden death active');
    expect(summary.suddenDeathStatus?.detailLabel, contains('Alice Wong'));
    expect(summary.suddenDeathStatus?.detailLabel, contains('Bob Lee'));
  });

  test('keeps final champion result and notes sudden death resolution', () {
    final summary = buildBonusRoundResultsSummary(
      ledgerEntries: [_championAwardEntry()],
      leaderboardEntries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          totalPoints: 121,
          handsPlayed: 6,
          handsWon: 2,
          selfDrawWins: 1,
          discardWins: 1,
          rank: 1,
        ),
      ],
      bonusRoundState: const BonusRoundState(
        suddenDeathStatus: 'completed',
        championResolutionMethod: 'sudden_death',
        championEventGuestId: 'gst_alice',
      ),
    );

    expect(summary.hasResults, isTrue);
    expect(summary.suddenDeathStatus, isNull);
    expect(summary.finalChampion?.displayName, 'Alice Wong');
    expect(summary.finalChampion?.detailLabel, contains('121 pts total'));
    expect(summary.finalChampion?.detailLabel, contains('sudden death'));
  });

  test('uses resolved champion state when no award adjustment was needed', () {
    final summary = buildBonusRoundResultsSummary(
      ledgerEntries: const [],
      leaderboardEntries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          totalPoints: 121,
          handsPlayed: 6,
          handsWon: 2,
          selfDrawWins: 1,
          discardWins: 1,
          rank: 1,
        ),
      ],
      bonusRoundState: const BonusRoundState(
        suddenDeathStatus: 'completed',
        championResolutionMethod: 'sudden_death',
        championEventGuestId: 'gst_alice',
        championAwardPoints: 0,
      ),
    );

    expect(summary.hasResults, isTrue);
    expect(summary.suddenDeathStatus, isNull);
    expect(summary.finalChampion?.displayName, 'Alice Wong');
    expect(summary.finalChampion?.detailLabel, '121 pts total, sudden death');
  });

  test('does not change standard champion or redemption winner behavior', () {
    final summary = buildBonusRoundResultsSummary(
      ledgerEntries: [_championAwardEntry(), _redemptionHandEntry()],
      leaderboardEntries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          totalPoints: 121,
          handsPlayed: 6,
          handsWon: 2,
          selfDrawWins: 1,
          discardWins: 1,
          rank: 1,
        ),
      ],
    );

    expect(summary.hasResults, isTrue);
    expect(summary.suddenDeathStatus, isNull);
    expect(summary.finalChampion?.displayName, 'Alice Wong');
    expect(summary.finalChampion?.detailLabel, '121 pts total');
    expect(summary.redemptionWinner?.displayName, 'Brian Lee');
    expect(summary.redemptionWinner?.detailLabel, 'Score +18');
  });
}

EventHandLedgerEntry _championAwardEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'entered_at': '2026-04-24T22:15:00-07:00',
    'ledger_row_type': 'adjustment',
    'adjustment_id': 'adj_01',
    'adjustment_type': 'finals_champion_award',
    'adjustment_amount_points': 37,
    'adjustment_event_guest_id': 'gst_alice',
    'adjustment_display_name': 'Alice Wong',
    'adjustment_context_json': {
      'champion_bonus_score_points': 24,
      'champion_top_up_points': 13,
    },
    'cells': const [],
  });
}

EventHandLedgerEntry _redemptionHandEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'table_id': 'tbl_02',
    'table_label': 'Table 2',
    'session_id': 'ses_02',
    'session_number_for_table': 1,
    'hand_id': 'hand_01',
    'hand_number': 1,
    'entered_at': '2026-04-24T22:20:00-07:00',
    'result_type': 'win',
    'status': 'recorded',
    'win_type': 'discard',
    'fan_count': 3,
    'has_settlements': true,
    'ledger_row_type': 'hand',
    'bonus_round_id': 'bonus_01',
    'bonus_table_role': 'table_of_redemption',
    'cells': const [
      {
        'wind': 'east',
        'seat_index': 0,
        'event_guest_id': 'gst_brian',
        'display_name': 'Brian Lee',
        'points_delta': 18,
      },
      {
        'wind': 'south',
        'seat_index': 1,
        'event_guest_id': 'gst_carla',
        'display_name': 'Carla Park',
        'points_delta': -6,
      },
      {
        'wind': 'west',
        'seat_index': 2,
        'event_guest_id': 'gst_dan',
        'display_name': 'Dan Yu',
        'points_delta': -6,
      },
      {
        'wind': 'north',
        'seat_index': 3,
        'event_guest_id': 'gst_emi',
        'display_name': 'Emi Chen',
        'points_delta': -6,
      },
    ],
  });
}
