import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/bonus_round_controller.dart';

void main() {
  test('loads champions and redemption seats from the leaderboard', () async {
    final controller = BonusRoundController(
      leaderboardRepository: _LeaderboardRepository(_leaderboard()),
      tableRepository: _TableRepository([_table(id: 'tbl_1')]),
      sessionRepository: const _SessionRepository(),
      seatingRepository: _SeatingRepository(),
    );

    await controller.load('evt_01');

    expect(controller.hasLiveSessions, isFalse);
    expect(controller.championSeats.map((seat) => seat.windLabel), [
      'East',
      'South',
      'West',
      'North',
    ]);
    expect(controller.championSeats.map((seat) => seat.seedLabel), [
      '#4',
      '#3',
      '#2',
      '#1',
    ]);
    expect(controller.redemptionSeats.map((seat) => seat.seedLabel), [
      '#5',
      '#6',
      '#7',
      '#8',
    ]);
  });

  test('selects scanned tables and creates bonus round seating', () async {
    final seatingRepository = _SeatingRepository();
    final controller = BonusRoundController(
      leaderboardRepository: _LeaderboardRepository(_leaderboard()),
      tableRepository: _TableRepository(
        [
          _table(id: 'tbl_champions', label: 'Table 1'),
          _table(id: 'tbl_redemption', label: 'Table 2'),
        ],
        resolvedTablesByUid: {
          'champions': _table(id: 'tbl_champions', label: 'Table 1'),
          'redemption': _table(id: 'tbl_redemption', label: 'Table 2'),
        },
      ),
      sessionRepository: const _SessionRepository(),
      seatingRepository: seatingRepository,
    );
    await controller.load('evt_01');

    await controller.resolveScannedTable(
      eventId: 'evt_01',
      role: BonusRoundTableRole.champions,
      normalizedUid: 'champions',
    );
    await controller.resolveScannedTable(
      eventId: 'evt_01',
      role: BonusRoundTableRole.redemption,
      normalizedUid: 'redemption',
    );
    final created = await controller.createBonusRound('evt_01');

    expect(created, isTrue);
    expect(controller.canCreateBonusRound, isFalse);
    expect(seatingRepository.generatedEventId, 'evt_01');
    expect(seatingRepository.generatedChampionsTableId, 'tbl_champions');
    expect(seatingRepository.generatedRedemptionTableId, 'tbl_redemption');
  });

  test('blocks creation while any session is active or paused', () async {
    final seatingRepository = _SeatingRepository();
    final controller = BonusRoundController(
      leaderboardRepository: _LeaderboardRepository(_leaderboard()),
      tableRepository: _TableRepository([
        _table(id: 'tbl_champions'),
        _table(id: 'tbl_redemption'),
      ]),
      sessionRepository: _SessionRepository(
        sessions: [_session(status: SessionStatus.paused)],
      ),
      seatingRepository: seatingRepository,
    );
    await controller.load('evt_01');
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table(id: 'tbl_champions'),
    );
    controller.selectTable(
      role: BonusRoundTableRole.redemption,
      table: _table(id: 'tbl_redemption'),
    );

    final created = await controller.createBonusRound('evt_01');

    expect(created, isFalse);
    expect(controller.actionError, 'End active or paused sessions first.');
    expect(seatingRepository.generatedEventId, isNull);
  });

  test('requires at least eight ranked players before enabling creation',
      () async {
    final controller = BonusRoundController(
      leaderboardRepository: _LeaderboardRepository(
        _leaderboard().take(7).toList(growable: false),
      ),
      tableRepository: _TableRepository([
        _table(id: 'tbl_champions'),
        _table(id: 'tbl_redemption'),
      ]),
      sessionRepository: const _SessionRepository(),
      seatingRepository: _SeatingRepository(),
    );
    await controller.load('evt_01');
    controller.selectTable(
      role: BonusRoundTableRole.champions,
      table: _table(id: 'tbl_champions'),
    );
    controller.selectTable(
      role: BonusRoundTableRole.redemption,
      table: _table(id: 'tbl_redemption'),
    );

    final created = await controller.createBonusRound('evt_01');

    expect(controller.championSeats, isEmpty);
    expect(controller.redemptionSeats, isEmpty);
    expect(controller.canCreateBonusRound, isFalse);
    expect(created, isFalse);
    expect(
      controller.actionError,
      'At least eight ranked players are required.',
    );
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
  String label = 'Table',
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

TableSessionRecord _session({
  SessionStatus status = SessionStatus.active,
}) {
  return TableSessionRecord(
    id: 'sess_01',
    eventId: 'evt_01',
    eventTableId: 'tbl_01',
    sessionNumberForTable: 1,
    rulesetId: 'HK_STANDARD',
    rotationPolicyType: RotationPolicyType.dealerCycleReturnToInitialEast,
    rotationPolicyConfig: const {},
    status: status,
    initialEastSeatIndex: 0,
    currentDealerSeatIndex: 0,
    dealerPassCount: 0,
    completedGamesCount: 0,
    handCount: 0,
    startedAt: DateTime.parse('2026-05-22T12:00:00Z'),
    startedByUserId: 'usr_01',
  );
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
  _TableRepository(
    this.tables, {
    this.resolvedTablesByUid = const {},
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
  const _SessionRepository({this.sessions = const []});

  final List<TableSessionRecord> sessions;

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
      sessions;

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
      sessions;

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
  String? generatedEventId;
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
    generatedEventId = eventId;
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
