import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/sqlite_offline_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteOfflineStore', () {
    late SqliteOfflineStore store;

    setUp(() async {
      store = await SqliteOfflineStore.inMemory();
    });

    tearDown(() async {
      await store.close();
    });

    test('inserts and reads pending mutations fifo', () async {
      await store.insertMutation(
        _mutation(
          id: 'mut_02',
          createdAt: DateTime.utc(2026, 6, 18, 20, 2),
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_01',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_synced',
          createdAt: DateTime.utc(2026, 6, 18, 20, 3),
          status: OfflineMutationStatus.synced,
        ),
      );

      final pending = await store.readPendingMutations();

      expect(pending.map((mutation) => mutation.id), ['mut_01', 'mut_02']);
    });

    test('includes failed mutations in pending fifo reads', () async {
      await store.insertMutation(
        _mutation(
          id: 'mut_failed',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
          status: OfflineMutationStatus.failed,
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_pending',
          createdAt: DateTime.utc(2026, 6, 18, 20, 2),
        ),
      );

      final pending = await store.readPendingMutations();

      expect(
        pending.map((mutation) => mutation.id),
        ['mut_failed', 'mut_pending'],
      );
    });

    test('updates status and attempt metadata', () async {
      final attemptedAt = DateTime.utc(2026, 6, 18, 20, 30);
      await store.insertMutation(_mutation(id: 'mut_01'));

      await store.markSyncing('mut_01', attemptedAt: attemptedAt);
      var mutation = await store.readMutation('mut_01');
      expect(mutation!.status, OfflineMutationStatus.syncing);
      expect(mutation.attemptCount, 1);
      expect(mutation.lastAttemptedAt, attemptedAt);

      await store.markFailed('mut_01', 'socket closed');
      mutation = await store.readMutation('mut_01');
      expect(mutation!.status, OfflineMutationStatus.failed);
      expect(mutation.lastError, 'socket closed');
      expect(mutation.attemptCount, 1);
    });

    test('resets stale syncing rows to pending', () async {
      await store.insertMutation(_mutation(id: 'mut_01'));
      await store.markSyncing(
        'mut_01',
        attemptedAt: DateTime.utc(2026, 6, 18),
      );

      await store.resetSyncingToPending();

      final mutation = await store.readMutation('mut_01');
      expect(mutation!.status, OfflineMutationStatus.pending);
    });

    test('blocks only the target session', () async {
      await store.insertMutation(_mutation(id: 'mut_01'));
      await store.insertMutation(_mutation(id: 'mut_02'));
      await store.insertMutation(
        _mutation(id: 'mut_other', sessionId: 'ses_02'),
      );

      await store.markSessionBlocked(
        'ses_01',
        'Current last hand has changed.',
      );

      final blocked = await store.readMutationsForSession('ses_01');
      expect(blocked.map((mutation) => mutation.status).toSet(), {
        OfflineMutationStatus.blocked,
      });
      expect(
        blocked.map((mutation) => mutation.lastError).toSet(),
        {'Current last hand has changed.'},
      );
      expect(
        (await store.readMutation('mut_other'))!.status,
        OfflineMutationStatus.pending,
      );
    });

    test('reads mutations for a session in created order', () async {
      await store.insertMutation(
        _mutation(
          id: 'mut_03',
          createdAt: DateTime.utc(2026, 6, 18, 20, 3),
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_other',
          sessionId: 'ses_02',
          createdAt: DateTime.utc(2026, 6, 18, 20),
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_01',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_02',
          createdAt: DateTime.utc(2026, 6, 18, 20, 2),
        ),
      );

      final sessionMutations = await store.readMutationsForSession('ses_01');

      expect(
        sessionMutations.map((mutation) => mutation.id),
        ['mut_01', 'mut_02', 'mut_03'],
      );
    });

    test('throws after close', () async {
      await store.insertMutation(_mutation(id: 'mut_01'));
      await store.close();

      await expectLater(
        store.insertMutation(_mutation(id: 'mut_02')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.readMutation('mut_01'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.markFailed('mut_01', 'socket closed'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

OfflineMutationRecord _mutation({
  String id = 'mut_01',
  String sessionId = 'ses_01',
  DateTime? createdAt,
  OfflineMutationStatus status = OfflineMutationStatus.pending,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 6, 18, 20);
  return OfflineMutationRecord(
    id: id,
    kind: OfflineMutationKind.recordHand,
    eventId: 'evt_01',
    sessionId: sessionId,
    payload: const {
      'target_table_session_id': 'ses_01',
      'target_result_type': 'win',
      'target_winner_seat_index': 0,
      'target_win_type': 'self_draw',
      'target_fan_count': 5,
    },
    baseRecordedHandCount: 0,
    baseLastRecordedHandId: null,
    localHandNumber: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
    status: status,
  );
}
