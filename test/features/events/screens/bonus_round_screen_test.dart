import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/offline/offline_recovery_signal.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/bonus_round_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

void main() {
  testWidgets('recovery refresh keeps cached finals tables visible',
      (tester) async {
    final leaderboardRepository = _LeaderboardRepository(_leaderboard());
    final tableRepository = _TableRepository(
      tables: [_table(id: 'tbl_1', label: 'Table 1')],
      resolvedTablesByUid: const {},
    );
    final signal = _FakeOfflineRecoverySignal();

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineRecoveryScope(
          signal: signal,
          child: BonusRoundScreen(
            eventId: 'evt_01',
            leaderboardRepository: leaderboardRepository,
            tableRepository: tableRepository,
            sessionRepository: const _SessionRepository(),
            seatingRepository: _SeatingRepository(),
            nfcService: _NfcService(const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('#1 Player 1'), findsOneWidget);
    final initialLoadCount = leaderboardRepository.loadCount;

    tableRepository.cachedTablesOverride = const [];
    leaderboardRepository.remoteError = StateError('offline');
    signal.emit();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(leaderboardRepository.loadCount, initialLoadCount + 1);
    expect(find.text('#1 Player 1'), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);
    await signal.dispose();
  });

  testWidgets('scans two tables and creates bonus round seating',
      (tester) async {
    final seatingRepository = _SeatingRepository();
    final tableRepository = _TableRepository(
      tables: [
        _table(id: 'tbl_1', label: 'Table 1'),
        _table(id: 'tbl_2', label: 'Table 2'),
      ],
      resolvedTablesByUid: {
        'table-1': _table(id: 'tbl_1', label: 'Table 1'),
        'table-2': _table(id: 'tbl_2', label: 'Table 2'),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BonusRoundScreen(
          eventId: 'evt_01',
          leaderboardRepository: _LeaderboardRepository(_leaderboard()),
          tableRepository: tableRepository,
          sessionRepository: const _SessionRepository(),
          seatingRepository: seatingRepository,
          nfcService: _NfcService(['table-1', 'table-2']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('Table of Redemption'), findsOneWidget);
    expect(find.text('#4 Player 4'), findsOneWidget);
    expect(find.text('#1 Player 1'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('scanRedemptionTable')));
    await tester.tap(find.byKey(const ValueKey('scanRedemptionTable')));
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(
      FilledButton,
      'Begin Finals',
    );
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(seatingRepository.generatedChampionsTableId, 'tbl_1');
    expect(seatingRepository.generatedRedemptionTableId, 'tbl_2');
  });

  testWidgets('creates champions-only finals for five eligible players',
      (tester) async {
    final seatingRepository = _SeatingRepository();

    await tester.pumpWidget(
      _bonusRoundApp(
        leaderboardRepository: _LeaderboardRepository(
          _leaderboard(count: 5, handsPlayed: 10),
        ),
        seatingRepository: seatingRepository,
        tableRepository: _TableRepository(
          tables: [_table(id: 'tbl_1', label: 'Table 1')],
          resolvedTablesByUid: {
            'table-1': _table(id: 'tbl_1', label: 'Table 1'),
          },
        ),
        nfcService: _NfcService(['table-1']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Begin Finals'), findsWidgets);
    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('Table of Redemption'), findsNothing);
    expect(find.text('#5 Player 5'), findsNothing);

    await tester
        .ensureVisible(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(FilledButton, 'Begin Finals');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(seatingRepository.generatedChampionsTableId, 'tbl_1');
    expect(seatingRepository.generatedRedemptionTableId, isNull);
  });

  testWidgets('returns to previous screen after finals seating is created',
      (tester) async {
    final seatingRepository = _SeatingRepository();

    await tester.pumpWidget(
      _BonusRoundLauncher(
        leaderboardRepository: _LeaderboardRepository(
          _leaderboard(count: 5, handsPlayed: 10),
        ),
        seatingRepository: seatingRepository,
        tableRepository: _TableRepository(
          tables: [_table(id: 'tbl_1', label: 'Table 1')],
          resolvedTablesByUid: {
            'table-1': _table(id: 'tbl_1', label: 'Table 1'),
          },
        ),
        nfcService: _NfcService(['table-1']),
      ),
    );

    await tester.tap(find.text('Open Finals Setup'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(FilledButton, 'Begin Finals');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(seatingRepository.generatedChampionsTableId, 'tbl_1');
    expect(find.text('Host Home'), findsOneWidget);
    expect(find.text('Finals created'), findsOneWidget);
    expect(find.byType(BonusRoundScreen), findsNothing);
  });

  testWidgets('requires redemption table for six eligible players',
      (tester) async {
    final seatingRepository = _SeatingRepository();

    await tester.pumpWidget(
      _bonusRoundApp(
        leaderboardRepository: _LeaderboardRepository(
          _leaderboard(count: 6, handsPlayed: 10),
        ),
        seatingRepository: seatingRepository,
        tableRepository: _TableRepository(
          tables: [
            _table(id: 'tbl_1', label: 'Table 1'),
            _table(id: 'tbl_2', label: 'Table 2'),
          ],
          resolvedTablesByUid: {
            'table-1': _table(id: 'tbl_1', label: 'Table 1'),
          },
        ),
        nfcService: _NfcService(['table-1']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('Table of Redemption'), findsOneWidget);
    expect(find.text('#3 Player 3'), findsNWidgets(2));
    expect(find.text('#4 Player 4'), findsNWidgets(2));
    expect(find.text('#5 Player 5'), findsOneWidget);
    expect(find.text('#6 Player 6'), findsOneWidget);
    expect(find.text('#1 Player 1'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();

    final beginFinalsButton = find.widgetWithText(FilledButton, 'Begin Finals');
    await tester.scrollUntilVisible(beginFinalsButton, 300);
    final createButton = tester.widget<FilledButton>(beginFinalsButton);
    expect(createButton.onPressed, isNull);
    expect(seatingRepository.generatedChampionsTableId, isNull);
  });

  testWidgets('creates four-seat redemption finals for six eligible players',
      (tester) async {
    final seatingRepository = _SeatingRepository();

    await tester.pumpWidget(
      _bonusRoundApp(
        leaderboardRepository: _LeaderboardRepository(
          _leaderboard(count: 6, handsPlayed: 10),
        ),
        seatingRepository: seatingRepository,
        tableRepository: _TableRepository(
          tables: [
            _table(id: 'tbl_1', label: 'Table 1'),
            _table(id: 'tbl_2', label: 'Table 2'),
          ],
          resolvedTablesByUid: {
            'table-1': _table(id: 'tbl_1', label: 'Table 1'),
            'table-2': _table(id: 'tbl_2', label: 'Table 2'),
          },
        ),
        nfcService: _NfcService(['table-1', 'table-2']),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.tap(find.byKey(const ValueKey('scanChampionsTable')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('scanRedemptionTable')));
    await tester.tap(find.byKey(const ValueKey('scanRedemptionTable')));
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(FilledButton, 'Begin Finals');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(seatingRepository.generatedChampionsTableId, 'tbl_1');
    expect(seatingRepository.generatedRedemptionTableId, 'tbl_2');
  });
}

Widget _bonusRoundApp({
  required LeaderboardRepository leaderboardRepository,
  required SeatingRepository seatingRepository,
  required TableRepository tableRepository,
  required NfcService nfcService,
}) {
  return MaterialApp(
    home: BonusRoundScreen(
      eventId: 'evt_01',
      leaderboardRepository: leaderboardRepository,
      tableRepository: tableRepository,
      sessionRepository: const _SessionRepository(),
      seatingRepository: seatingRepository,
      nfcService: nfcService,
    ),
  );
}

class _BonusRoundLauncher extends StatefulWidget {
  const _BonusRoundLauncher({
    required this.leaderboardRepository,
    required this.seatingRepository,
    required this.tableRepository,
    required this.nfcService,
  });

  final LeaderboardRepository leaderboardRepository;
  final SeatingRepository seatingRepository;
  final TableRepository tableRepository;
  final NfcService nfcService;

  @override
  State<_BonusRoundLauncher> createState() => _BonusRoundLauncherState();
}

class _BonusRoundLauncherState extends State<_BonusRoundLauncher> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _BonusRoundLauncherHome(
        leaderboardRepository: widget.leaderboardRepository,
        seatingRepository: widget.seatingRepository,
        tableRepository: widget.tableRepository,
        nfcService: widget.nfcService,
      ),
    );
  }
}

class _BonusRoundLauncherHome extends StatefulWidget {
  const _BonusRoundLauncherHome({
    required this.leaderboardRepository,
    required this.seatingRepository,
    required this.tableRepository,
    required this.nfcService,
  });

  final LeaderboardRepository leaderboardRepository;
  final SeatingRepository seatingRepository;
  final TableRepository tableRepository;
  final NfcService nfcService;

  @override
  State<_BonusRoundLauncherHome> createState() =>
      _BonusRoundLauncherHomeState();
}

class _BonusRoundLauncherHomeState extends State<_BonusRoundLauncherHome> {
  String _resultLabel = 'No result';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Host Home'),
          Text(_resultLabel),
          ElevatedButton(
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => BonusRoundScreen(
                    eventId: 'evt_01',
                    leaderboardRepository: widget.leaderboardRepository,
                    tableRepository: widget.tableRepository,
                    sessionRepository: const _SessionRepository(),
                    seatingRepository: widget.seatingRepository,
                    nfcService: widget.nfcService,
                  ),
                ),
              );
              if (!mounted) {
                return;
              }
              setState(() {
                _resultLabel = created == true ? 'Finals created' : 'No result';
              });
            },
            child: const Text('Open Finals Setup'),
          ),
        ],
      ),
    );
  }
}

List<LeaderboardEntry> _leaderboard({
  int count = 8,
  int handsPlayed = 4,
}) {
  return List.generate(
    count,
    (index) => LeaderboardEntry(
      eventGuestId: 'guest_${index + 1}',
      displayName: 'Player ${index + 1}',
      totalPoints: 80 - index,
      handsPlayed: handsPlayed,
      handsWon: 1,
      selfDrawWins: 0,
      discardWins: 1,
      rank: index + 1,
    ),
  );
}

EventTableRecord _table({
  required String id,
  required String label,
}) {
  return EventTableRecord(
    id: id,
    eventId: 'evt_01',
    label: label,
    displayOrder: 1,
    nfcTagId: 'tag_$id',
    defaultRulesetId: 'HK_STANDARD',
    defaultRotationPolicyType:
        RotationPolicyType.dealerCycleReturnToInitialEast,
    defaultRotationPolicyConfig: const {},
  );
}

class _NfcService implements NfcService {
  _NfcService(this.scannedUids);

  final List<String> scannedUids;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    final uid = scannedUids.removeAt(0);
    return TagScanResult(
      rawUid: uid,
      normalizedUid: uid,
      isManualEntry: true,
    );
  }
}

class _LeaderboardRepository implements LeaderboardRepository {
  _LeaderboardRepository(this.entries);

  final List<LeaderboardEntry> entries;
  Object? remoteError;
  int loadCount = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async {
    loadCount += 1;
    if (remoteError != null) {
      throw remoteError!;
    }
    return entries;
  }

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      entries;
}

class _TableRepository implements TableRepository {
  _TableRepository({
    required this.tables,
    required this.resolvedTablesByUid,
  });

  final List<EventTableRecord> tables;
  final Map<String, EventTableRecord> resolvedTablesByUid;
  Object? remoteError;
  List<EventTableRecord>? cachedTablesOverride;

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    return tables;
  }

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      cachedTablesOverride ?? tables;

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) async =>
      resolvedTablesByUid[scannedUid] ?? (throw StateError('Missing table'));

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeOfflineRecoverySignal implements OfflineRecoverySignal {
  final _controller = StreamController<int>.broadcast();
  int _generation = 0;

  @override
  int get generation => _generation;

  @override
  Stream<int> get generations => _controller.stream;

  void emit() {
    _generation += 1;
    _controller.add(_generation);
  }

  Future<void> dispose() => _controller.close();
}

class _SessionRepository implements SessionRepository {
  const _SessionRepository();

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
          String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      null;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
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
  Future<List<TableSessionRecord>> startBonusAssignedTableSessions({
    required String eventId,
    required BonusTableRole? bonusTableRole,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _SeatingRepository implements SeatingRepository {
  String? generatedChampionsTableId;
  String? generatedRedemptionTableId;

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(
          String eventId) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  }) async {
    generatedChampionsTableId = championsTableId;
    generatedRedemptionTableId = redemptionTableId;
    return const [];
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      const [];

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async =>
      TournamentRoundSummary.empty();

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async => null;

  @override
  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  }) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> startTableOfChampionsPlayIn({
    required String eventId,
    required String tableId,
  }) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      const [];

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      null;
}
