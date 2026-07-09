import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/offline/network_reachability.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/offline_session_projector.dart';
import 'package:mosaic/data/offline/offline_session_repository.dart';
import 'package:mosaic/data/offline/sqlite_offline_store.dart';
import 'package:mosaic/data/offline/sync_coordinator.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase/supabase.dart';

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
        expect(
          repository.recordedInputs.last.photoClientId,
          'photo_client_01',
        );
        expect(
          repository.recordedInputs.last.photoCapturedAt,
          DateTime.parse('2026-06-25T18:00:00Z'),
        );
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

    test('attaches remote hand id and uploads queued photo after hand sync',
        () async {
      final evidence = _FakeHandEvidenceRepository();
      coordinator = SyncCoordinator(
        store: store,
        reachability: reachability,
        sessionRepository: repository,
        handEvidenceRepository: evidence,
        now: () => DateTime.utc(2026, 6, 18, 20, 30),
      );
      repository.detail = _detailWithHand(
        id: 'remote_hand_01',
        clientMutationId: 'mut_01',
      );
      await store.insertMutation(_mutation(id: 'mut_01'));
      await store.insertPhotoUpload(_photoUpload(mutationId: 'mut_01'));

      await coordinator.syncNow();

      final uploads = await store.readPhotoUploadsForSession('ses_01');
      expect(uploads.single.remoteHandResultId, 'remote_hand_01');
      expect(uploads.single.status, OfflinePhotoUploadStatus.uploaded);
      expect(
        uploads.single.storagePath,
        'events/evt_01/hands/remote_hand_01/photo_client_01.jpg',
      );
      expect(evidence.uploads.single.handResultId, 'remote_hand_01');
      expect(evidence.uploads.single.clientPhotoId, 'photo_client_01');
      expect(evidence.uploads.single.localPath, '/local/photo.jpg');
    });

    test('skips photo uploads without remote hand id', () async {
      final evidence = _FakeHandEvidenceRepository();
      coordinator = SyncCoordinator(
        store: store,
        reachability: reachability,
        sessionRepository: repository,
        handEvidenceRepository: evidence,
      );
      await store.insertPhotoUpload(_photoUpload(mutationId: 'mut_01'));

      await coordinator.syncNow();

      final uploads = await store.readPhotoUploadsForSession('ses_01');
      expect(uploads.single.status, OfflinePhotoUploadStatus.pending);
      expect(evidence.uploads, isEmpty);
    });

    test('network upload failures mark photo upload failed and stop', () async {
      final evidence = _FakeHandEvidenceRepository()
        ..errors.add(const NetworkUnavailableException('socket closed'));
      coordinator = SyncCoordinator(
        store: store,
        reachability: reachability,
        sessionRepository: repository,
        handEvidenceRepository: evidence,
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_upload_01',
          mutationId: 'mut_01',
          remoteHandResultId: 'remote_hand_01',
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_upload_02',
          mutationId: 'mut_02',
          remoteHandResultId: 'remote_hand_02',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
        ),
      );

      await coordinator.syncNow();

      final uploads = await store.readPhotoUploadsForSession('ses_01');
      expect(uploads.first.status, OfflinePhotoUploadStatus.failed);
      expect(uploads.first.lastError, contains('socket closed'));
      expect(uploads.last.status, OfflinePhotoUploadStatus.pending);
      expect(evidence.uploads.single.handResultId, 'remote_hand_01');
    });

    test('business upload failures mark photo upload blocked and stop',
        () async {
      final evidence = _FakeHandEvidenceRepository()
        ..errors.add(StateError('Photo row not found.'));
      coordinator = SyncCoordinator(
        store: store,
        reachability: reachability,
        sessionRepository: repository,
        handEvidenceRepository: evidence,
      );
      await store.insertPhotoUpload(
        _photoUpload(
          mutationId: 'mut_01',
          remoteHandResultId: 'remote_hand_01',
        ),
      );

      await coordinator.syncNow();

      final uploads = await store.readPhotoUploadsForSession('ses_01');
      expect(uploads.single.status, OfflinePhotoUploadStatus.blocked);
      expect(uploads.single.lastError, 'Bad state: Photo row not found.');
    });

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

    test('sync sends false win penalty mutations to false win RPC path',
        () async {
      await store.insertMutation(
        _mutation(
          id: 'mut_penalty',
          kind: OfflineMutationKind.recordFalseWinPenalty,
          payload: const {
            'target_table_session_id': 'ses_01',
            'target_penalty_seat_index': 2,
            'target_correction_note': null,
          },
          baseRecordedHandCount: 4,
          baseLastRecordedHandId: 'hand_04',
          createdAt: DateTime.utc(2026, 6, 24, 12),
        ),
      );

      await coordinator.syncNow();

      expect(repository.recordedInputs, isEmpty);
      expect(repository.recordedFalseWinPenalty?.tableSessionId, 'ses_01');
      expect(repository.recordedFalseWinPenalty?.penaltySeatIndex, 2);
      expect(repository.recordedFalseWinPenalty?.correctionNote, isNull);
      expect(
          repository.recordedFalseWinPenalty?.clientMutationId, 'mut_penalty');
      expect(
        repository.recordedFalseWinPenalty?.expectedRecordedHandCount,
        4,
      );
      expect(
        repository.recordedFalseWinPenalty?.expectedLastRecordedHandId,
        'hand_04',
      );
      expect(
        (await store.readMutation('mut_penalty'))!.status,
        OfflineMutationStatus.synced,
      );
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
      'score total duplicate refresh errors are retryable instead of blocked',
      () async {
        repository.errors.add(_scoreTotalDuplicateException());
        await store.insertMutation(_mutation(id: 'mut_01'));

        await coordinator.syncNow();

        final mutation = await store.readMutation('mut_01');
        expect(mutation!.status, OfflineMutationStatus.failed);
        expect(mutation.lastError, contains('event_score_totals'));

        final mutations = await store.readMutationsForSession('ses_01');
        expect(
          mutations.map((mutation) => mutation.status).toSet(),
          {OfflineMutationStatus.failed},
        );
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

    test('initialize retries blocked score total duplicate rows', () async {
      await store.insertMutation(
        _mutation(
          id: 'mut_01',
          status: OfflineMutationStatus.blocked,
          lastError: _scoreTotalDuplicateException().toString(),
        ),
      );

      await coordinator.initialize();

      expect(repository.recordedInputs.single.clientMutationId, 'mut_01');
      final mutation = await store.readMutation('mut_01');
      expect(mutation!.status, OfflineMutationStatus.synced);
      expect(mutation.lastError, isNull);
    });

    test('initialize resets uploading photos to pending then uploads',
        () async {
      final evidence = _FakeHandEvidenceRepository();
      coordinator = SyncCoordinator(
        store: store,
        reachability: reachability,
        sessionRepository: repository,
        handEvidenceRepository: evidence,
        now: () => DateTime.utc(2026, 6, 18, 20, 30),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          mutationId: 'mut_01',
          remoteHandResultId: 'remote_hand_01',
          status: OfflinePhotoUploadStatus.uploading,
        ),
      );

      await coordinator.initialize();

      final upload = (await store.readPhotoUploadsForSession('ses_01')).single;
      expect(upload.status, OfflinePhotoUploadStatus.uploaded);
      expect(upload.attemptCount, 1);
      expect(evidence.uploads.single.handResultId, 'remote_hand_01');
    });

    test('sync requested during active sync runs another pass', () async {
      final completer = Completer<SessionDetailRecord>();
      repository.nextResultCompleter = completer;
      await store.insertMutation(_mutation(id: 'mut_01'));

      final firstSync = coordinator.syncNow();
      await Future<void>.delayed(Duration.zero);
      await store.insertMutation(
        _mutation(
          id: 'mut_02',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
        ),
      );

      await coordinator.syncNow();
      completer.complete(_detail());
      await firstSync;

      expect(repository.recordedInputs.map((input) => input.clientMutationId), [
        'mut_01',
        'mut_02',
      ]);
      expect(
        (await store.readMutation('mut_01'))!.status,
        OfflineMutationStatus.synced,
      );
      expect(
        (await store.readMutation('mut_02'))!.status,
        OfflineMutationStatus.synced,
      );
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
  RecordFalseWinPenaltyInput? recordedFalseWinPenalty;
  final List<Object> errors = [];
  Completer<SessionDetailRecord>? nextResultCompleter;
  SessionDetailRecord? detail;

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
    return detail ?? _detail();
  }

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) async {
    recordedFalseWinPenalty = input;
    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
    return detail ?? _detail();
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
  Future<List<TableSessionRecord>> startBonusAssignedTableSessions({
    required String eventId,
    required BonusTableRole? bonusTableRole,
  }) async =>
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

class _FakeHandEvidenceRepository implements HandEvidenceRepository {
  final List<_UploadedHandPhoto> uploads = [];
  final List<Object> errors = [];

  @override
  Future<void> uploadAndAttachHandPhoto({
    required String eventId,
    required String handResultId,
    required String clientPhotoId,
    required String localPath,
    required DateTime capturedAt,
  }) async {
    uploads.add(
      _UploadedHandPhoto(
        eventId: eventId,
        handResultId: handResultId,
        clientPhotoId: clientPhotoId,
        localPath: localPath,
        capturedAt: capturedAt,
      ),
    );
    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
  }
}

class _UploadedHandPhoto {
  const _UploadedHandPhoto({
    required this.eventId,
    required this.handResultId,
    required this.clientPhotoId,
    required this.localPath,
    required this.capturedAt,
  });

  final String eventId;
  final String handResultId;
  final String clientPhotoId;
  final String localPath;
  final DateTime capturedAt;
}

OfflineMutationRecord _mutation({
  required String id,
  OfflineMutationKind kind = OfflineMutationKind.recordHand,
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
    'target_photo_client_id': 'photo_client_01',
    'target_photo_captured_at': '2026-06-25T18:00:00Z',
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
    kind: kind,
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

PostgrestException _scoreTotalDuplicateException() {
  return const PostgrestException(
    message:
        'duplicate key value violates unique constraint "event_score_totals_event_id_event_guest_id_key"',
    code: '23505',
    details:
        'Key (event_id, event_guest_id)=(evt_01, guest_01) already exists.',
  );
}

OfflinePhotoUploadRecord _photoUpload({
  String id = 'photo_upload_01',
  required String mutationId,
  String? remoteHandResultId,
  DateTime? createdAt,
  OfflinePhotoUploadStatus status = OfflinePhotoUploadStatus.pending,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 6, 18, 20);
  return OfflinePhotoUploadRecord(
    id: id,
    mutationId: mutationId,
    eventId: 'evt_01',
    sessionId: 'ses_01',
    clientPhotoId: 'photo_client_01',
    localPath: '/local/photo.jpg',
    capturedAt: DateTime.utc(2026, 6, 25, 18),
    status: status,
    remoteHandResultId: remoteHandResultId,
    createdAt: timestamp,
    updatedAt: timestamp,
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

SessionDetailRecord _detailWithHand({
  required String id,
  required String clientMutationId,
}) {
  return SessionDetailRecord.fromJson({
    ..._detail().toJson(),
    'hands': [
      {
        'id': id,
        'table_session_id': 'ses_01',
        'hand_number': 1,
        'result_type': 'win',
        'winner_seat_index': 2,
        'win_type': 'discard',
        'discarder_seat_index': 1,
        'penalty_seat_index': null,
        'fan_count': 5,
        'base_points': 8,
        'dealer_was_waiting_at_draw': null,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 0,
        'dealer_rotated': false,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-06-25T18:00:00Z',
        'correction_note': null,
        'row_version': 1,
        'client_mutation_id': clientMutationId,
      },
    ],
  });
}
