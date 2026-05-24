import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/leaderboard/screens/leaderboard_screen.dart';

class _RecordingLeaderboardRepository implements LeaderboardRepository {
  _RecordingLeaderboardRepository({
    required this.entries,
    this.failFirstLoad = false,
  });

  final List<LeaderboardEntry> entries;
  final bool failFirstLoad;
  int loadCount = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async {
    loadCount += 1;
    if (failFirstLoad && loadCount == 1) {
      throw Exception('temporary leaderboard failure');
    }

    return entries;
  }

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      const [];
}

class _LedgerSessionRepository implements SessionRepository {
  const _LedgerSessionRepository({required this.rows});

  final List<EventHandLedgerEntry> rows;

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
          String eventId) async =>
      rows;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
          String eventId) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders an intentional empty state when no scored results exist',
      (tester) async {
    final repository = _RecordingLeaderboardRepository(entries: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No scored results yet'), findsOneWidget);
    expect(
      find.text(
          'Record hands in an active session to populate the leaderboard.'),
      findsOneWidget,
    );
  });

  testWidgets('renders ordered leaderboard standings', (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_west',
          displayName: 'West Guest',
          totalPoints: 16,
          handsPlayed: 3,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_east',
          displayName: 'East Guest',
          totalPoints: 8,
          handsPlayed: 3,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 0,
          rank: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('West Guest'), findsOneWidget);
    expect(find.text('16 pts'), findsOneWidget);
    expect(find.text('Minimum hands to qualify: 2'), findsOneWidget);
    expect(find.text('Hands played 3 • Wins 1'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('East Guest'), findsOneWidget);
  });

  testWidgets('uses local dense placement ranks for prize-eligible players',
      (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_giang',
          displayName: 'Giang Pham',
          totalPoints: 40,
          handsPlayed: 1,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_brian',
          displayName: 'Brian Le',
          totalPoints: 0,
          handsPlayed: 0,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 0,
          rank: 2,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_wen',
          displayName: 'Wen Lee',
          totalPoints: -8,
          handsPlayed: 1,
          handsWon: 0,
          selfDrawWins: 1,
          discardWins: 1,
          rank: 3,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_estevon',
          displayName: 'Estevon Jackson',
          totalPoints: -16,
          handsPlayed: 1,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 4,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_justin',
          displayName: 'Justin Park',
          totalPoints: -16,
          handsPlayed: 1,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 4,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minimum hands to qualify: 1'), findsOneWidget);
    expect(find.text('Prize Placements'), findsOneWidget);
    expect(find.text('Not Prize Eligible'), findsOneWidget);
    expect(find.text('Hands played 1 • Wins 1'), findsOneWidget);
    expect(find.text('Hands played 1 • Wins 0'), findsNWidgets(3));
    expect(find.text('Hands played 0 • Wins 0'), findsOneWidget);
    expect(find.textContaining('Prize #'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Giang Pham'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Wen Lee'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Estevon Jackson'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Justin Park'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Brian Le'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('2'),
      ),
      findsNothing,
    );
  });

  testWidgets('renders bonus round final champion and redemption summary',
      (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
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

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
          sessionRepository: _LedgerSessionRepository(
            rows: [
              _championAwardEntry(),
              _redemptionHandEntry(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonus Round Results'), findsOneWidget);
    expect(find.text('Final champion'), findsOneWidget);
    expect(find.text('Alice Wong'), findsWidgets);
    expect(find.text('121 pts total'), findsOneWidget);
    expect(find.text('Redemption winner'), findsOneWidget);
    expect(find.text('Brian Lee'), findsOneWidget);
    expect(find.text('Score +18'), findsOneWidget);
  });

  testWidgets('retries after a loading error', (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_west',
          displayName: 'West Guest',
          totalPoints: 16,
          handsPlayed: 3,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
      ],
      failFirstLoad: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('temporary leaderboard failure'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(find.text('West Guest'), findsOneWidget);
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
