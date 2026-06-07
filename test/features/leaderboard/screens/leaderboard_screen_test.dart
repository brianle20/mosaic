import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
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
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) {
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

class _SeatingRepository implements SeatingRepository {
  const _SeatingRepository({
    required this.assignments,
    this.bonusRoundState,
  });

  final List<SeatingAssignmentRecord> assignments;
  final BonusRoundState? bonusRoundState;

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      assignments;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) {
    return Future.value(bonusRoundState);
  }

  @override
  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) {
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
    expect(
      find.text('Hands 3 • Wins 1 • Discard wins 1 • Discard losses 0'),
      findsOneWidget,
    );
    expect(find.text('1'), findsWidgets);
    expect(find.text('East Guest'), findsOneWidget);
  });

  testWidgets('shows withdrawn scored players as not prize eligible',
      (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          tournamentStatus: EventTournamentStatus.qualified,
          totalPoints: 64,
          handsPlayed: 8,
          handsWon: 3,
          selfDrawWins: 1,
          discardWins: 2,
          rank: 1,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_brian',
          displayName: 'Brian Le',
          tournamentStatus: EventTournamentStatus.withdrawn,
          totalPoints: 48,
          handsPlayed: 8,
          handsWon: 2,
          selfDrawWins: 0,
          discardWins: 2,
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

    expect(find.text('Prize Placements'), findsOneWidget);
    expect(find.text('Not Prize Eligible'), findsOneWidget);
    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text('Brian Le'), findsOneWidget);
  });

  testWidgets('does not expose qualification standings', (
    tester,
  ) async {
    final leaderboardRepository = _RecordingLeaderboardRepository(
      entries: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: leaderboardRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tournament'), findsOneWidget);
    expect(find.text('Qualification'), findsNothing);
    expect(find.text('Qualification Standings'), findsNothing);
  });

  testWidgets('orders remaining leaderboard tabs by event phase',
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

    final tournamentLeft = tester.getTopLeft(find.text('Tournament')).dx;
    final finalsLeft = tester.getTopLeft(find.text('Finals')).dx;

    expect(tournamentLeft, lessThan(finalsLeft));
  });

  testWidgets(
      'uses local competition placement ranks for prize-eligible players',
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
    expect(
      find.text('Hands 1 • Wins 1 • Discard wins 1 • Discard losses 0'),
      findsOneWidget,
    );
    expect(
      find.text('Hands 1 • Wins 0 • Discard wins 1 • Discard losses 0'),
      findsNWidgets(3),
    );
    expect(
      find.text('Hands 0 • Wins 0 • Discard wins 0 • Discard losses 0'),
      findsOneWidget,
    );
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
    expect(find.text('Brian Lee'), findsWidgets);
    expect(find.text('Score +18'), findsOneWidget);
  });

  testWidgets('renders pending sudden death in bonus round results',
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
          seatingRepository: const _SeatingRepository(
            assignments: [],
            bonusRoundState: BonusRoundState(
              championResolutionMethod: 'sudden_death',
              suddenDeathStatus: 'required',
              tiedTopPlayers: [
                BonusRoundTiedPlayer(
                  eventGuestId: 'gst_alice',
                  displayName: 'Alice Wong',
                  bonusScorePoints: 120,
                  seedRank: 1,
                ),
                BonusRoundTiedPlayer(
                  eventGuestId: 'gst_brian',
                  displayName: 'Brian Lee',
                  bonusScorePoints: 120,
                  seedRank: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonus Round Results'), findsOneWidget);
    expect(find.text('Sudden death required'), findsOneWidget);
    expect(
      find.text('Tied finalists: Alice Wong (120 pts), Brian Lee (120 pts)'),
      findsOneWidget,
    );
  });

  testWidgets('renders active sudden death in bonus round results',
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
          seatingRepository: const _SeatingRepository(
            assignments: [],
            bonusRoundState: BonusRoundState(
              championResolutionMethod: 'sudden_death',
              suddenDeathStatus: 'active',
              tiedTopPlayers: [
                BonusRoundTiedPlayer(
                  eventGuestId: 'gst_alice',
                  displayName: 'Alice Wong',
                  bonusScorePoints: 120,
                  seedRank: 1,
                ),
                BonusRoundTiedPlayer(
                  eventGuestId: 'gst_brian',
                  displayName: 'Brian Lee',
                  bonusScorePoints: 120,
                  seedRank: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonus Round Results'), findsOneWidget);
    expect(find.text('Sudden death active'), findsOneWidget);
    expect(
      find.text('Tied finalists: Alice Wong (120 pts), Brian Lee (120 pts)'),
      findsOneWidget,
    );
  });

  testWidgets('shows finals tables and standings in a Finals tab',
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
              _championsHandEntry(),
              _redemptionHandEntry(),
            ],
          ),
          seatingRepository: _SeatingRepository(
            assignments: [
              _bonusAssignment(
                id: 'asg_alice',
                guestId: 'gst_alice',
                displayName: 'Alice Wong',
                seatIndex: 0,
              ),
              _bonusAssignment(
                id: 'asg_brian',
                guestId: 'gst_brian',
                displayName: 'Brian Lee',
                seatIndex: 1,
              ),
              _bonusAssignment(
                id: 'asg_carla',
                tableId: 'tbl_02',
                tableLabel: 'Table 2',
                guestId: 'gst_carla',
                displayName: 'Carla Park',
                seatIndex: 0,
                bonusTableRole: BonusTableRole.tableOfRedemption,
              ),
              _bonusAssignment(
                id: 'asg_dan',
                tableId: 'tbl_02',
                tableLabel: 'Table 2',
                guestId: 'gst_dan',
                displayName: 'Dan Yu',
                seatIndex: 1,
                bonusTableRole: BonusTableRole.tableOfRedemption,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finals'));
    await tester.pumpAndSettle();

    expect(find.text('Finals Standings'), findsOneWidget);
    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Table of Redemption'), findsOneWidget);
    expect(find.text('Table 2'), findsOneWidget);
    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.text('+24 pts'), findsOneWidget);
    expect(find.text('Brian Lee'), findsWidgets);
    expect(find.text('-24 pts'), findsOneWidget);
    expect(find.text('Carla Park'), findsOneWidget);
    expect(find.text('-6 pts'), findsWidgets);
    expect(find.text('1 hand • 1 win'), findsWidgets);
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

EventHandLedgerEntry _championsHandEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'table_id': 'tbl_01',
    'table_label': 'Table 1',
    'session_id': 'ses_01',
    'session_number_for_table': 1,
    'hand_id': 'hand_champions_01',
    'hand_number': 1,
    'entered_at': '2026-04-24T22:10:00-07:00',
    'result_type': 'win',
    'status': 'recorded',
    'win_type': 'discard',
    'fan_count': 3,
    'has_settlements': true,
    'ledger_row_type': 'hand',
    'bonus_round_id': 'bonus_01',
    'bonus_table_role': 'table_of_champions',
    'cells': const [
      {
        'wind': 'east',
        'seat_index': 0,
        'event_guest_id': 'gst_alice',
        'display_name': 'Alice Wong',
        'points_delta': 24,
      },
      {
        'wind': 'south',
        'seat_index': 1,
        'event_guest_id': 'gst_brian',
        'display_name': 'Brian Lee',
        'points_delta': -24,
      },
      {
        'wind': 'west',
        'seat_index': 2,
        'event_guest_id': 'gst_placeholder_1',
        'display_name': 'Placeholder One',
        'points_delta': 0,
      },
      {
        'wind': 'north',
        'seat_index': 3,
        'event_guest_id': 'gst_placeholder_2',
        'display_name': 'Placeholder Two',
        'points_delta': 0,
      },
    ],
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

SeatingAssignmentRecord _bonusAssignment({
  required String id,
  String tableId = 'tbl_01',
  String tableLabel = 'Table 1',
  required String guestId,
  required String displayName,
  required int seatIndex,
  BonusTableRole bonusTableRole = BonusTableRole.tableOfChampions,
}) {
  return SeatingAssignmentRecord(
    id: id,
    eventId: 'evt_01',
    eventTableId: tableId,
    tableLabel: tableLabel,
    eventGuestId: guestId,
    displayName: displayName,
    seatIndex: seatIndex,
    assignmentRound: 1,
    status: 'active',
    assignmentType: SeatingAssignmentType.bonus,
    bonusRoundId: 'bonus_01',
    bonusTableRole: bonusTableRole,
  );
}
