import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_session_projector.dart';
import 'package:mosaic/data/offline/offline_session_repository.dart';
import 'package:mosaic/data/offline/sqlite_offline_store.dart';
import 'package:mosaic/data/offline/sync_coordinator.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncCoordinator', () {
    late SqliteOfflineStore store;
    late _FakeReachability reachability;
    late _FakeSessionRepository repository;
    late SyncCoordinator coordinator;

    setUp(() async {
      store = await SqliteOfflineStore.inMemory();
      reachability = _FakeReachability(reachable: true);
      repository = _FakeSessionRepository();
      coordinator = SyncCoordinator(
        store: store,
        reachability: reachability,
        sessionRepository: repository,
        now: () => DateTime.utc(2026, 6, 18, 20, 30),
      );
    });

    tearDown(() async {
      await store.close();
    });

    test('syncNow does nothing when unreachable', () async {
      reachability.reachable = false;
      await store.insertMutation(_mutation(id: 'mut_01'));

      await coordinator.syncNow();

      expect(repository.recordedInputs, isEmpty);
      final mutation = await store.readMutation('mut_01');
      expect(mutation!.status, OfflineMutationStatus.pending);
      expect(mutation.attemptCount, 0);
    });

    test('constructor rejects OfflineSessionRepository wrapper', () {
      final offlineRepository = OfflineSessionRepository(
        inner: repository,
        store: store,
        reachability: reachability,
        projector: const OfflineSessionProjector(),
      );

      expect(
        () => SyncCoordinator(
          store: store,
          reachability: reachability,
          sessionRepository: offlineRepository,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'SyncCoordinator requires the canonical online SessionRepository.',
          ),
        ),
      );
      expect(repository.recordedInputs, isEmpty);
    });

    test(
      'syncNow drains pending hand mutations fifo and marks them synced',
      () async {
        await store.insertMutation(
          _mutation(
            id: 'mut_02',
            sessionId: 'ses_01',
            createdAt: DateTime.utc(2026, 6, 18, 20, 2),
            baseRecordedHandCount: 1,
            baseLastRecordedHandId: 'hand_01',
          ),
        );
        await store.insertMutation(
          _mutation(
            id: 'mut_01',
            sessionId: 'ses_01',
            createdAt: DateTime.utc(2026, 6, 18, 20, 1),
            payload: const {
              'target_table_session_id': 'ses_01',
              'target_result_type': 'washout',
            },
            baseRecordedHandCount: 0,
          ),
        );

        await coordinator.syncNow();

        expect(repository.recordedInputs.map((input) => input.clientMutationId),
            ['mut_01', 'mut_02']);
        expect(repository.recordedInputs.first.tableSessionId, 'ses_01');
        expect(
            repository.recordedInputs.first.resultType, HandResultType.washout);
        expect(repository.recordedInputs.first.expectedRecordedHandCount, 0);
        expect(
            repository.recordedInputs.first.expectedLastRecordedHandId, isNull);
        expect(repository.recordedInputs.last.resultType, HandResultType.win);
        expect(repository.recordedInputs.last.winnerSeatIndex, 2);
        expect(repository.recordedInputs.last.winType, HandWinType.discard);
        expect(repository.recordedInputs.last.discarderSeatIndex, 1);
        expect(repository.recordedInputs.last.fanCount, 5);
        expect(repository.recordedInputs.last.clientMutationId, 'mut_02');
        expect(repository.recordedInputs.last.expectedRecordedHandCount, 1);
        expect(repository.recordedInputs.last.expectedLastRecordedHandId,
            'hand_01');
        expect((await store.readMutation('mut_01'))!.status,
            OfflineMutationStatus.synced);
        expect((await store.readMutation('mut_02'))!.status,
            OfflineMutationStatus.synced);
      },
    );

    test('failed mutations are retried', () async {
      await store.insertMutation(
        _mutation(
          id: 'mut_failed',
          status: OfflineMutationStatus.failed,
          lastError: 'socket closed',
        ),
      );

      await coordinator.syncNow();

      expect(repository.recordedInputs.single.clientMutationId, 'mut_failed');
      final mutation = await store.readMutation('mut_failed');
      expect(mutation!.status, OfflineMutationStatus.synced);
      expect(mutation.attemptCount, 1);
    });

    test(
      'network failures mark current mutation failed and stop later mutations',
      () async {
        repository.errors.add(
          const NetworkUnavailableException('socket closed'),
        );
        await store.insertMutation(_mutation(id: 'mut_01'));
        await store.insertMutation(
          _mutation(
            id: 'mut_02',
            createdAt: DateTime.utc(2026, 6, 18, 20, 1),
          ),
        );

        await coordinator.syncNow();

        expect(repository.recordedInputs.map((input) => input.clientMutationId),
            ['mut_01']);
        final failed = await store.readMutation('mut_01');
        final later = await store.readMutation('mut_02');
        expect(failed!.status, OfflineMutationStatus.failed);
        expect(failed.lastError, contains('socket closed'));
        expect(later!.status, OfflineMutationStatus.pending);
      },
    );

    test(
      'OfflineSyncConflictException blocks all unsynced mutations for session',
      () async {
        repository.errors.add(
          const OfflineSyncConflictException(
            'Current session hand count has changed.',
          ),
        );
        await store.insertMutation(_mutation(id: 'mut_01'));
        await store.insertMutation(
          _mutation(
            id: 'mut_02',
            createdAt: DateTime.utc(2026, 6, 18, 20, 1),
          ),
        );

        await coordinator.syncNow();

        final mutations = await store.readMutationsForSession('ses_01');
        expect(
          mutations.map((mutation) => mutation.status).toSet(),
          {OfflineMutationStatus.blocked},
        );
        expect(
          mutations.map((mutation) => mutation.lastError).toSet(),
          {'Current session hand count has changed.'},
        );
      },
    );

    test('business errors block all unsynced mutations for session', () async {
      repository.errors.add(StateError('Hands can only be recorded active.'));
      await store.insertMutation(_mutation(id: 'mut_01'));
      await store.insertMutation(
        _mutation(
          id: 'mut_02',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
        ),
      );

      await coordinator.syncNow();

      final mutations = await store.readMutationsForSession('ses_01');
      expect(
        mutations.map((mutation) => mutation.status).toSet(),
        {OfflineMutationStatus.blocked},
      );
      expect(
        mutations.map((mutation) => mutation.lastError).toSet(),
        {'Bad state: Hands can only be recorded active.'},
      );
    });

    test('initialize resets syncing rows to pending then attempts sync',
        () async {
      await store.insertMutation(
        _mutation(id: 'mut_01', status: OfflineMutationStatus.syncing),
      );

      await coordinator.initialize();

      expect(repository.recordedInputs.single.clientMutationId, 'mut_01');
      final mutation = await store.readMutation('mut_01');
      expect(mutation!.status, OfflineMutationStatus.synced);
      expect(mutation.attemptCount, 1);
    });

    test('concurrent syncNow calls do not double submit a mutation', () async {
      final completer = Completer<SessionDetailRecord>();
      repository.nextResultCompleter = completer;
      await store.insertMutation(_mutation(id: 'mut_01'));

      final firstSync = coordinator.syncNow();
      final secondSync = coordinator.syncNow();
      await Future<void>.delayed(Duration.zero);

      expect(repository.recordedInputs.single.clientMutationId, 'mut_01');
      completer.complete(_detail());
      await Future.wait([firstSync, secondSync]);

      expect(repository.recordedInputs.length, 1);
      expect((await store.readMutation('mut_01'))!.status,
          OfflineMutationStatus.synced);
    });
  });
}

class _FakeReachability implements NetworkReachability {
  _FakeReachability({required this.reachable});

  bool reachable;

  @override
  Future<bool> isReachable() async => reachable;

  @override
  bool isNetworkException(Object error) => error is NetworkUnavailableException;
}

class _FakeSessionRepository implements SessionRepository {
  final List<RecordHandResultInput> recordedInputs = [];
  final List<Object> errors = [];
  Completer<SessionDetailRecord>? nextResultCompleter;

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    recordedInputs.add(input);
    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
    final completer = nextResultCompleter;
    if (completer != null) {
      nextResultCompleter = null;
      return completer.future;
    }
    return _detail();
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      _detail();

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async =>
      _detail();

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) async =>
      StartedTableSessionRecord(session: _detail().session, seats: const []);

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async =>
      const [];

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) async => _detail();

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) async =>
      _detail();

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) async =>
      _detail();

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) async =>
      _detail();

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async =>
      _detail();
}

OfflineMutationRecord _mutation({
  required String id,
  String sessionId = 'ses_01',
  Map<String, dynamic> payload = const {
    'target_table_session_id': 'ses_01',
    'target_result_type': 'win',
    'target_winner_seat_index': 2,
    'target_win_type': 'discard',
    'target_discarder_seat_index': 1,
    'target_fan_count': 5,
    'target_dealer_was_waiting_at_draw': false,
    'target_correction_note': 'offline note',
  },
  int baseRecordedHandCount = 0,
  String? baseLastRecordedHandId,
  DateTime? createdAt,
  OfflineMutationStatus status = OfflineMutationStatus.pending,
  String? lastError,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 6, 18, 20);
  return OfflineMutationRecord(
    id: id,
    kind: OfflineMutationKind.recordHand,
    eventId: 'evt_01',
    sessionId: sessionId,
    payload: payload,
    baseRecordedHandCount: baseRecordedHandCount,
    baseLastRecordedHandId: baseLastRecordedHandId,
    localHandNumber: baseRecordedHandCount + 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    status: status,
    lastError: lastError,
  );
}

SessionDetailRecord _detail() {
  return SessionDetailRecord.fromJson(const {
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
      'current_dealer_seat_index': 0,
      'dealer_pass_count': 0,
      'completed_games_count': 0,
      'hand_count': 0,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': [],
    'hands': [],
    'settlements': [],
  });
}
