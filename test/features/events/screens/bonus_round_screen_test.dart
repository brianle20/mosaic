import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/bonus_round_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

void main() {
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
      'Create Bonus Round',
    );
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(seatingRepository.generatedChampionsTableId, 'tbl_1');
    expect(seatingRepository.generatedRedemptionTableId, 'tbl_2');
  });
}

List<LeaderboardEntry> _leaderboard() {
  return List.generate(
    8,
    (index) => LeaderboardEntry(
      eventGuestId: 'guest_${index + 1}',
      displayName: 'Player ${index + 1}',
      totalPoints: 80 - index,
      handsPlayed: 4,
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
  Future<TagScanResult?> scanPlayerTagForAssignment(
    BuildContext context,
  ) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async =>
      null;

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
  const _LeaderboardRepository(this.entries);

  final List<LeaderboardEntry> entries;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      entries;

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      entries;
}

class _TableRepository implements TableRepository {
  const _TableRepository({
    required this.tables,
    required this.resolvedTablesByUid,
  });

  final List<EventTableRecord> tables;
  final Map<String, EventTableRecord> resolvedTablesByUid;

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
  Future<List<EventTableRecord>> listTables(String eventId) async => tables;

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      tables;

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
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
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
    required String redemptionTableId,
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
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      const [];
}
