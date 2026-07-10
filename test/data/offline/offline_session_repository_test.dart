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
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';
import 'package:supabase/supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSessionRepository', () {
    late SqliteOfflineStore store;

    setUp(() async {
      store = await SqliteOfflineStore.inMemory();
    });

    tearDown(() async {
      await store.close();
    });

    test(
      'known offline recordHand enqueues mutation and returns projection',
      () async {
        final inner = _FakeSessionRepository(cachedDetail: _detail());
        final repository = OfflineSessionRepository(
          inner: inner,
          store: store,
          reachability: const _FakeReachability(false),
          projector: const OfflineSessionProjector(),
          newMutationId: () => '11111111-1111-1111-1111-111111111111',
          now: () => DateTime.utc(2026, 6, 18, 20),
        );

        final projected = await repository.recordHand(
          const RecordHandResultInput(
            tableSessionId: 'ses_01',
            resultType: HandResultType.win,
            winnerSeatIndex: 0,
            winType: HandWinType.selfDraw,
            fanCount: 5,
            winBonuses: [HandWinBonus.moonUnderTheSea],
          ),
        );

        final mutation = (await store.readPendingMutations()).single;
        expect(inner.recordCallCount, 0);
        expect(projected.hands.single.id, startsWith('pending:'));
        expect(projected.hands.single.handNumber, 1);
        expect(projected.session.handCount, 1);
        expect(mutation.id, '11111111-1111-1111-1111-111111111111');
        expect(mutation.localHandNumber, 1);
        expect(mutation.baseRecordedHandCount, 0);
        expect(mutation.baseLastRecordedHandId, isNull);
        expect(mutation.payload['target_table_session_id'], 'ses_01');
        expect(mutation.payload['target_result_type'], 'win');
        expect(mutation.payload['target_win_bonuses'], ['moon_under_the_sea']);
        expect(
          mutation.payload['target_client_mutation_id'],
          '11111111-1111-1111-1111-111111111111',
        );
        expect(mutation.payload['target_expected_recorded_hand_count'], 0);
        expect(mutation.payload['target_expected_last_recorded_hand_id'], null);
      },
    );

    test('known offline win with photo enqueues mutation and photo upload',
        () async {
      final capturedAt = DateTime.utc(2026, 6, 18, 19, 59);
      final inner = _FakeSessionRepository(cachedDetail: _detail());
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '11111111-1111-1111-1111-111111111111',
        now: () => DateTime.utc(2026, 6, 18, 20),
      );

      await repository.recordHand(
        RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.win,
          winnerSeatIndex: 0,
          winType: HandWinType.selfDraw,
          fanCount: 5,
          photoClientId: 'photo_client_01',
          photoLocalPath: '/local/photo_client_01.jpg',
          photoCapturedAt: capturedAt,
        ),
      );

      final mutation = (await store.readPendingMutations()).single;
      final upload = (await store.readPendingPhotoUploads()).single;
      expect(mutation.id, '11111111-1111-1111-1111-111111111111');
      expect(upload.id, 'photo_client_01');
      expect(upload.mutationId, mutation.id);
      expect(upload.eventId, 'evt_01');
      expect(upload.sessionId, 'ses_01');
      expect(upload.clientPhotoId, 'photo_client_01');
      expect(upload.localPath, '/local/photo_client_01.jpg');
      expect(upload.capturedAt, capturedAt);
      expect(upload.status, OfflinePhotoUploadStatus.pending);
      expect(upload.createdAt, DateTime.utc(2026, 6, 18, 20));
      expect(upload.updatedAt, DateTime.utc(2026, 6, 18, 20));
    });

    test('failed photo enqueue does not leave hand mutation queued', () async {
      await store.insertPhotoUpload(
        OfflinePhotoUploadRecord(
          id: 'photo_client_01',
          mutationId: 'existing_mutation',
          eventId: 'evt_01',
          sessionId: 'ses_01',
          clientPhotoId: 'photo_client_01',
          localPath: '/local/existing.jpg',
          capturedAt: DateTime.utc(2026, 6, 18, 19),
          createdAt: DateTime.utc(2026, 6, 18, 19),
          updatedAt: DateTime.utc(2026, 6, 18, 19),
        ),
      );
      final inner = _FakeSessionRepository(cachedDetail: _detail());
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '11111111-1111-1111-1111-111111111111',
        now: () => DateTime.utc(2026, 6, 18, 20),
      );

      await expectLater(
        repository.recordHand(
          RecordHandResultInput(
            tableSessionId: 'ses_01',
            resultType: HandResultType.win,
            winnerSeatIndex: 0,
            winType: HandWinType.selfDraw,
            fanCount: 5,
            photoClientId: 'photo_client_01',
            photoLocalPath: '/local/photo_client_01.jpg',
            photoCapturedAt: DateTime.utc(2026, 6, 18, 19, 59),
          ),
        ),
        throwsA(anything),
      );

      expect(await store.readPendingMutations(), isEmpty);
      expect(await store.readPendingPhotoUploads(), hasLength(1));
    });

    test('known offline washout with photo metadata does not enqueue photo',
        () async {
      final inner = _FakeSessionRepository(cachedDetail: _detail());
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '11111111-1111-1111-1111-111111111111',
        now: () => DateTime.utc(2026, 6, 18, 20),
      );

      await repository.recordHand(
        RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
          photoClientId: 'photo_client_01',
          photoLocalPath: '/local/photo_client_01.jpg',
          photoCapturedAt: DateTime.utc(2026, 6, 18, 19, 59),
        ),
      );

      expect(await store.readPendingMutations(), hasLength(1));
      expect(await store.readPendingPhotoUploads(), isEmpty);
    });

    test('known offline expected state includes projected pending hands',
        () async {
      await store.insertMutation(
        _mutation(
          id: '00000000-0000-0000-0000-000000000001',
          localHandNumber: 2,
          baseRecordedHandCount: 1,
          baseLastRecordedHandId: 'hand_01',
          createdAt: DateTime.utc(2026, 6, 18, 20),
        ),
      );
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(
          handCount: 1,
          completedGamesCount: 1,
          hands: [
            _hand(id: 'hand_01', handNumber: 1),
          ],
        ),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '22222222-2222-2222-2222-222222222222',
        now: () => DateTime.utc(2026, 6, 18, 20, 1),
      );

      await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
        ),
      );

      final mutations = await store.readMutationsForSession('ses_01');
      final mutation = mutations.last;
      expect(mutation.localHandNumber, 3);
      expect(mutation.baseRecordedHandCount, 2);
      expect(mutation.baseLastRecordedHandId, isNull);
      expect(mutation.payload['target_expected_recorded_hand_count'], 2);
      expect(mutation.payload['target_expected_last_recorded_hand_id'], null);
    });

    test('known offline expected state excludes blocked pending hands',
        () async {
      await store.insertMutation(
        _mutation(
          id: 'blocked_01',
          localHandNumber: 2,
          baseRecordedHandCount: 1,
          baseLastRecordedHandId: 'hand_01',
          status: OfflineMutationStatus.blocked,
          lastError: 'Current last hand has changed.',
        ),
      );
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(
          handCount: 1,
          completedGamesCount: 1,
          hands: [
            _hand(id: 'hand_01', handNumber: 1),
          ],
        ),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '44444444-4444-4444-4444-444444444444',
        now: () => DateTime.utc(2026, 6, 18, 20, 1),
      );

      await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
        ),
      );

      final mutation = (await store.readMutationsForSession('ses_01')).last;
      expect(mutation.localHandNumber, 2);
      expect(mutation.baseRecordedHandCount, 1);
      expect(mutation.baseLastRecordedHandId, 'hand_01');
      expect(mutation.payload['target_expected_recorded_hand_count'], 1);
      expect(
        mutation.payload['target_expected_last_recorded_hand_id'],
        'hand_01',
      );
    });

    test(
        'reachable successful recordHand returns inner result without queueing',
        () async {
      final remoteDetail = _detail(handCount: 1, hands: [_hand()]);
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(),
        recordResult: remoteDetail,
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(true),
        projector: const OfflineSessionProjector(),
      );

      final result = await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
        ),
      );

      expect(result, same(remoteDetail));
      expect(inner.recordCallCount, 1);
      expect(await store.readPendingMutations(), isEmpty);
    });

    test('reachable win with photo queues mutation and schedules sync',
        () async {
      var syncCallCount = 0;
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(true),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '22222222-2222-2222-2222-222222222222',
        now: () => DateTime.utc(2026, 6, 18, 20),
        onMutationQueued: () async {
          syncCallCount += 1;
        },
      );

      final result = await repository.recordHand(
        RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.win,
          winnerSeatIndex: 0,
          winType: HandWinType.selfDraw,
          fanCount: 5,
          photoClientId: 'photo_client_01',
          photoLocalPath: '/local/photo_client_01.jpg',
          photoCapturedAt: DateTime.utc(2026, 6, 18, 19, 59),
        ),
      );

      expect(inner.recordCallCount, 0);
      expect(
        result.hands.single.id,
        'pending:22222222-2222-2222-2222-222222222222',
      );
      final mutation = (await store.readPendingMutations()).single;
      expect(mutation.id, '22222222-2222-2222-2222-222222222222');
      final upload = (await store.readPendingPhotoUploads()).single;
      expect(upload.mutationId, '22222222-2222-2222-2222-222222222222');
      expect(upload.remoteHandResultId, isNull);
      expect(upload.localPath, '/local/photo_client_01.jpg');
      expect(syncCallCount, 1);
    });

    test('reachable recordHand queues behind existing unsynced mutations',
        () async {
      await store.insertMutation(
        _mutation(
          id: '00000000-0000-0000-0000-000000000001',
          localHandNumber: 2,
          baseRecordedHandCount: 1,
          baseLastRecordedHandId: 'hand_01',
          createdAt: DateTime.utc(2026, 6, 18, 20),
        ),
      );
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(
          handCount: 1,
          completedGamesCount: 1,
          hands: [
            _hand(id: 'hand_01', handNumber: 1),
          ],
        ),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(true),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '55555555-5555-5555-5555-555555555555',
        now: () => DateTime.utc(2026, 6, 18, 20, 1),
      );

      await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
        ),
      );

      final mutations = await store.readMutationsForSession('ses_01');
      expect(inner.recordCallCount, 0);
      expect(mutations.map((mutation) => mutation.id), [
        '00000000-0000-0000-0000-000000000001',
        '55555555-5555-5555-5555-555555555555',
      ]);
      final mutation = mutations.last;
      expect(mutation.localHandNumber, 3);
      expect(mutation.baseRecordedHandCount, 2);
      expect(mutation.baseLastRecordedHandId, isNull);
      expect(mutation.payload['target_expected_recorded_hand_count'], 2);
      expect(mutation.payload['target_expected_last_recorded_hand_id'], null);
    });

    test('network failure during online attempt falls back to enqueue',
        () async {
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(),
        recordError: const NetworkUnavailableException('socket closed'),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(true),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '33333333-3333-3333-3333-333333333333',
        now: () => DateTime.utc(2026, 6, 18, 20),
      );

      final projected = await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
        ),
      );

      expect(inner.recordCallCount, 1);
      expect(projected.hands.single.resultType, HandResultType.washout);
      expect(
        (await store.readPendingMutations()).single.id,
        '33333333-3333-3333-3333-333333333333',
      );
    });

    test(
        'offline recordFalseWinPenalty enqueues mutation and returns projection',
        () async {
      final inner = _FakeSessionRepository(cachedDetail: _detail());
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '66666666-6666-6666-6666-666666666666',
        now: () => DateTime.utc(2026, 6, 24, 12),
      );

      final projected = await repository.recordFalseWinPenalty(
        const RecordFalseWinPenaltyInput(
          tableSessionId: 'ses_01',
          penaltySeatIndex: 3,
          correctionNote: 'called too early',
        ),
      );

      final mutation = (await store.readPendingMutations()).single;
      expect(inner.recordFalseWinPenaltyCallCount, 0);
      expect(mutation.kind, OfflineMutationKind.recordFalseWinPenalty);
      expect(mutation.id, '66666666-6666-6666-6666-666666666666');
      expect(mutation.localHandNumber, 1);
      expect(mutation.baseRecordedHandCount, 0);
      expect(mutation.baseLastRecordedHandId, isNull);
      expect(mutation.payload['target_table_session_id'], 'ses_01');
      expect(mutation.payload['target_penalty_seat_index'], 3);
      expect(mutation.payload['target_correction_note'], 'called too early');
      expect(
        mutation.payload['target_client_mutation_id'],
        '66666666-6666-6666-6666-666666666666',
      );
      expect(mutation.payload['target_expected_recorded_hand_count'], 0);
      expect(mutation.payload['target_expected_last_recorded_hand_id'], isNull);
      expect(projected.hands, isEmpty);
      expect(projected.session.handCount, 0);
      expect(projected.pendingFalseWinPenaltySeatIndexes, [3]);
    });

    test('reachable recordFalseWinPenalty queues behind unsynced mutations',
        () async {
      await store.insertMutation(
        _mutation(
          id: '00000000-0000-0000-0000-000000000001',
          localHandNumber: 2,
          baseRecordedHandCount: 1,
          baseLastRecordedHandId: 'hand_01',
          createdAt: DateTime.utc(2026, 6, 18, 20),
        ),
      );
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(
          handCount: 1,
          completedGamesCount: 1,
          hands: [_hand(id: 'hand_01', handNumber: 1)],
        ),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(true),
        projector: const OfflineSessionProjector(),
        newMutationId: () => '77777777-7777-7777-7777-777777777777',
        now: () => DateTime.utc(2026, 6, 24, 12),
      );

      await repository.recordFalseWinPenalty(
        const RecordFalseWinPenaltyInput(
          tableSessionId: 'ses_01',
          penaltySeatIndex: 2,
        ),
      );

      final mutations = await store.readMutationsForSession('ses_01');
      expect(inner.recordFalseWinPenaltyCallCount, 0);
      expect(mutations.map((mutation) => mutation.id), [
        '00000000-0000-0000-0000-000000000001',
        '77777777-7777-7777-7777-777777777777',
      ]);
      final mutation = mutations.last;
      expect(mutation.kind, OfflineMutationKind.recordFalseWinPenalty);
      expect(mutation.localHandNumber, 3);
      expect(mutation.baseRecordedHandCount, 2);
      expect(mutation.baseLastRecordedHandId, isNull);
      expect(mutation.payload['target_expected_recorded_hand_count'], 2);
      expect(mutation.payload['target_expected_last_recorded_hand_id'], isNull);
    });

    test('offline recordFalseWinPenalty rejects duplicate pending seat',
        () async {
      final inner = _FakeSessionRepository(cachedDetail: _detail());
      var nextMutationId = 0;
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
        newMutationId: () {
          nextMutationId += 1;
          return 'mutation_$nextMutationId';
        },
        now: () => DateTime.utc(2026, 6, 24, 12),
      );

      await repository.recordFalseWinPenalty(
        const RecordFalseWinPenaltyInput(
          tableSessionId: 'ses_01',
          penaltySeatIndex: 3,
        ),
      );

      await expectLater(
        repository.recordFalseWinPenalty(
          const RecordFalseWinPenaltyInput(
            tableSessionId: 'ses_01',
            penaltySeatIndex: 3,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('False win caller already has a pending penalty.'),
          ),
        ),
      );

      expect((await store.readPendingMutations()).length, 1);
    });

    test('business errors are rethrown and not enqueued', () async {
      final inner = _FakeSessionRepository(
        cachedDetail: _detail(),
        recordError: StateError(
          'Hands can only be recorded for active sessions.',
        ),
      );
      final repository = OfflineSessionRepository(
        inner: inner,
        store: store,
        reachability: const _FakeReachability(true),
        projector: const OfflineSessionProjector(),
      );

      await expectLater(
        repository.recordHand(
          const RecordHandResultInput(
            tableSessionId: 'ses_01',
            resultType: HandResultType.washout,
          ),
        ),
        throwsStateError,
      );
      expect(await store.readPendingMutations(), isEmpty);
    });

    test('missing cached detail throws clear StateError and does not enqueue',
        () async {
      final repository = OfflineSessionRepository(
        inner: _FakeSessionRepository(cachedDetail: null),
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
      );

      await expectLater(
        repository.recordHand(
          const RecordHandResultInput(
            tableSessionId: 'ses_missing',
            resultType: HandResultType.washout,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('not available offline'),
          ),
        ),
      );
      expect(await store.readPendingMutations(), isEmpty);
    });

    test('offline lifecycle operations throw clear unsupported errors',
        () async {
      final repository = OfflineSessionRepository(
        inner: _FakeSessionRepository(cachedDetail: _detail()),
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
      );

      await expectLater(
        repository.pauseSession('ses_01'),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
      await expectLater(
        repository.resumeSession('ses_01'),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
      await expectLater(
        repository.endSession(sessionId: 'ses_01', reason: 'closed'),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
    });

    test('edit void and start operations are unsupported offline', () async {
      final repository = OfflineSessionRepository(
        inner: _FakeSessionRepository(cachedDetail: _detail()),
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
      );

      await expectLater(
        repository.editHand(
          const EditHandResultInput(
            handResultId: 'hand_01',
            resultType: HandResultType.washout,
          ),
        ),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
      await expectLater(
        repository.voidHand(
          const VoidHandResultInput(handResultId: 'hand_01'),
        ),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
      await expectLater(
        repository.startAssignedSession(
          const StartAssignedTableSessionInput(eventTableId: 'tbl_01'),
        ),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
      await expectLater(
        repository.startCurrentTournamentRoundSessions('evt_01'),
        throwsA(isA<OfflineUnsupportedOperationException>()),
      );
    });

    test('readSessionSyncSnapshot returns pending and blocked metadata',
        () async {
      await store.insertMutation(
        _mutation(id: 'pending_01'),
      );
      await store.insertMutation(
        _mutation(
          id: 'blocked_01',
          status: OfflineMutationStatus.blocked,
          lastError: 'Current last hand has changed.',
        ),
      );
      final repository = OfflineSessionRepository(
        inner: _FakeSessionRepository(cachedDetail: _detail()),
        store: store,
        reachability: const _FakeReachability(false),
        projector: const OfflineSessionProjector(),
      );

      final snapshot = await repository.readSessionSyncSnapshot('ses_01');

      expect(snapshot.pendingHandIds, {'pending:pending_01'});
      expect(snapshot.blockedHandIds, {'pending:blocked_01'});
      expect(snapshot.pendingCount, 1);
      expect(snapshot.isBlocked, isTrue);
      expect(snapshot.blockedReason, 'Current last hand has changed.');
    });
  });

  group('DefaultNetworkReachability', () {
    test('classifies explicit offline and timeout errors as network errors',
        () {
      final reachability = _reachabilityClassifier();

      expect(
        reachability.isNetworkException(
          const NetworkUnavailableException('socket closed'),
        ),
        isTrue,
      );
      expect(reachability.isNetworkException(TimeoutException('timed out')),
          isTrue);
    });

    test('does not classify PostgREST exceptions as network errors', () {
      final reachability = _reachabilityClassifier();

      expect(
        reachability.isNetworkException(
          const PostgrestException(
            message: 'Business rule failed after network timeout validation.',
            code: 'P0001',
          ),
        ),
        isFalse,
      );
    });
  });
}

DefaultNetworkReachability _reachabilityClassifier() {
  return DefaultNetworkReachability(
    client: SupabaseClient('https://example.test', 'anon-key'),
  );
}

class _FakeReachability implements NetworkReachability {
  const _FakeReachability(this.reachable);

  final bool reachable;

  @override
  Stream<void> get onReachable => const Stream.empty();

  @override
  Future<bool> isReachable() async => reachable;

  @override
  bool isNetworkException(Object error) => error is NetworkUnavailableException;
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    required this.cachedDetail,
    this.recordResult,
    this.recordError,
  });

  final SessionDetailRecord? cachedDetail;
  final SessionDetailRecord? recordResult;
  final Object? recordError;
  final List<RecordHandResultInput> recordedInputs = [];
  int recordCallCount = 0;
  int recordFalseWinPenaltyCallCount = 0;

  SessionDetailRecord get _requiredDetail {
    final detail = cachedDetail;
    if (detail == null) {
      throw StateError('Fake repository has no cached detail.');
    }
    return detail;
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      cachedDetail;

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async =>
      _requiredDetail;

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    recordedInputs.add(input);
    recordCallCount += 1;
    final error = recordError;
    if (error != null) {
      throw error;
    }
    return recordResult ?? _requiredDetail;
  }

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) async {
    recordFalseWinPenaltyCallCount += 1;
    final error = recordError;
    if (error != null) {
      throw error;
    }
    return recordResult ?? _requiredDetail;
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) async =>
      _requiredDetail;

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) async =>
      _requiredDetail;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) async =>
      _requiredDetail;

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) async =>
      _requiredDetail;

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async =>
      _requiredDetail;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
          String eventId) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) async =>
      StartedTableSessionRecord(
          session: _requiredDetail.session, seats: const []);

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
}

OfflineMutationRecord _mutation({
  required String id,
  int localHandNumber = 1,
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
    sessionId: 'ses_01',
    payload: const {
      'target_table_session_id': 'ses_01',
      'target_result_type': 'win',
      'target_winner_seat_index': 2,
      'target_win_type': 'discard',
      'target_discarder_seat_index': 1,
      'target_fan_count': 5,
    },
    baseRecordedHandCount: baseRecordedHandCount,
    baseLastRecordedHandId: baseLastRecordedHandId,
    localHandNumber: localHandNumber,
    createdAt: timestamp,
    updatedAt: timestamp,
    status: status,
    lastError: lastError,
  );
}

SessionDetailRecord _detail({
  int completedGamesCount = 0,
  int dealerPassCount = 0,
  int handCount = 0,
  List<HandResultRecord> hands = const [],
}) {
  return SessionDetailRecord.fromJson({
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
      'current_dealer_seat_index': dealerPassCount % 4,
      'dealer_pass_count': dealerPassCount,
      'completed_games_count': completedGamesCount,
      'hand_count': handCount,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': const [],
    'hands': hands.map((hand) => hand.toJson()).toList(growable: false),
    'settlements': const [],
  });
}

HandResultRecord _hand({
  String id = 'hand_01',
  int handNumber = 1,
  String? clientMutationId,
}) {
  return HandResultRecord(
    id: id,
    tableSessionId: 'ses_01',
    handNumber: handNumber,
    resultType: HandResultType.win,
    winnerSeatIndex: 1,
    winType: HandWinType.discard,
    discarderSeatIndex: 0,
    fanCount: 5,
    eastSeatIndexBeforeHand: 0,
    eastSeatIndexAfterHand: 1,
    dealerRotated: true,
    sessionCompletedAfterHand: false,
    status: HandResultStatus.recorded,
    enteredByUserId: 'usr_01',
    enteredAt: DateTime.utc(2026, 6, 18, 19),
    clientMutationId: clientMutationId,
  );
}
