import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/offline/offline_models.dart';
import 'package:mosaic/data/offline/sqlite_offline_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

    test('inserts and reads pending photo uploads fifo', () async {
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_02',
          createdAt: DateTime.utc(2026, 6, 18, 20, 2),
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_01',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_uploaded',
          createdAt: DateTime.utc(2026, 6, 18, 20, 3),
          status: OfflinePhotoUploadStatus.uploaded,
        ),
      );

      final pending = await store.readPendingPhotoUploads();

      expect(pending.map((upload) => upload.id), ['photo_01', 'photo_02']);
    });

    test('mutation and photo transaction emits one committed session change',
        () async {
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      await store.insertMutationWithPhotoUpload(
        _mutation(id: 'mut_01'),
        _photoUpload(id: 'photo_01', mutationId: 'mut_01'),
      );

      expect(changes, hasLength(1));
      expect(changes.single.sessionId, 'ses_01');
      expect(
        changes.single.kinds,
        {OfflineStoreChangeKind.mutation, OfflineStoreChangeKind.photoUpload},
      );
      await subscription.cancel();
    });

    test('failed mutation and photo transaction emits no session change',
        () async {
      await store.insertPhotoUpload(_photoUpload(id: 'photo_01'));
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      await expectLater(
        store.insertMutationWithPhotoUpload(
          _mutation(id: 'mut_01'),
          _photoUpload(id: 'photo_01', mutationId: 'mut_01'),
        ),
        throwsA(anything),
      );

      expect(changes, isEmpty);
      expect(await store.readMutation('mut_01'), isNull);
      await subscription.cancel();
    });

    test('photo reset and mutation-link failure publish photo changes',
        () async {
      await store.insertPhotoUpload(_photoUpload(id: 'photo_01'));
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      await store.markPhotoUploadBlockedForMutation(
        'mut_01',
        'Winning hand saved, but its photo could not be linked.',
      );
      expect((await store.readPhotoUpload('photo_01'))!.status,
          OfflinePhotoUploadStatus.blocked);

      await store.resetPhotoUploadToPending('photo_01');
      expect((await store.readPhotoUploadForMutation('mut_01'))!.status,
          OfflinePhotoUploadStatus.pending);
      expect(changes, hasLength(2));
      await subscription.cancel();
    });

    test('photo reset only changes failed or blocked uploads', () async {
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_failed',
          mutationId: 'mut_failed',
          status: OfflinePhotoUploadStatus.failed,
          lastError: 'socket closed',
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(id: 'photo_pending', mutationId: 'mut_pending'),
      );
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      await store.resetPhotoUploadToPending('photo_failed');
      await store.resetPhotoUploadToPending('photo_pending');

      final failed = await store.readPhotoUpload('photo_failed');
      expect(failed!.status, OfflinePhotoUploadStatus.pending);
      expect(failed.lastError, isNull);
      expect(changes, hasLength(1));
      expect(changes.single.kinds, {OfflineStoreChangeKind.photoUpload});
      await subscription.cancel();
    });

    test('bulk photo recovery emits once per unique affected session',
        () async {
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_01',
          mutationId: 'mut_01',
          status: OfflinePhotoUploadStatus.uploading,
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_02',
          mutationId: 'mut_02',
          status: OfflinePhotoUploadStatus.uploading,
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_other',
          mutationId: 'mut_other',
          sessionId: 'ses_02',
          status: OfflinePhotoUploadStatus.uploading,
        ),
      );
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      await store.resetPhotoUploadsUploadingToPending();
      await store.resetPhotoUploadsUploadingToPending();

      expect(changes, hasLength(2));
      expect(changes.map((change) => change.sessionId).toSet(), {
        'ses_01',
        'ses_02',
      });
      expect(
        changes.every(
          (change) =>
              change.kinds.length == 1 &&
              change.kinds.contains(OfflineStoreChangeKind.photoUpload),
        ),
        isTrue,
      );
      await subscription.cancel();
    });

    test('concurrent writes publish changes in committed order', () async {
      await store.insertPhotoUpload(
        _photoUpload(status: OfflinePhotoUploadStatus.uploading),
      );
      final changes = <OfflineStoreChange>[];
      final observedStatuses = <Future<OfflinePhotoUploadStatus>>[];
      final subscription = store.changes.listen((change) {
        changes.add(change);
        observedStatuses.add(
          store.readPhotoUpload('photo_01').then((upload) => upload!.status),
        );
      });

      final recovery = store.resetPhotoUploadsUploadingToPending();
      final upload = store.markPhotoUploadUploaded(
        'photo_01',
        storagePath: 'events/evt_01/hands/photo_01.jpg',
      );
      await Future.wait([recovery, upload]);

      expect(
        (await store.readPhotoUpload('photo_01'))!.status,
        OfflinePhotoUploadStatus.uploaded,
      );
      expect(changes, hasLength(2));
      expect(await Future.wait(observedStatuses), [
        OfflinePhotoUploadStatus.pending,
        OfflinePhotoUploadStatus.uploaded,
      ]);
      await subscription.cancel();
    });

    test('bulk mutation recovery emits once per unique affected session',
        () async {
      await store.insertMutation(
        _mutation(id: 'mut_sync_01', status: OfflineMutationStatus.syncing),
      );
      await store.insertMutation(
        _mutation(id: 'mut_sync_02', status: OfflineMutationStatus.syncing),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_sync_other',
          sessionId: 'ses_02',
          status: OfflineMutationStatus.syncing,
        ),
      );
      await store.insertMutation(
        _mutation(
          id: 'mut_blocked_01',
          status: OfflineMutationStatus.blocked,
          lastError: 'App restarted during sync.',
        ),
      );
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      await store.resetSyncingToPending();
      await store.resetSyncingToPending();
      await store.resetBlockedMutationsToPending(
        lastErrorContains: 'restarted during sync',
      );
      await store.resetBlockedMutationsToPending(
        lastErrorContains: 'restarted during sync',
      );

      expect(changes, hasLength(3));
      expect(
        changes.map((change) => change.sessionId),
        containsAll(<String>['ses_01', 'ses_02']),
      );
      expect(
        changes.every(
          (change) =>
              change.kinds.length == 1 &&
              change.kinds.contains(OfflineStoreChangeKind.mutation),
        ),
        isTrue,
      );
      await subscription.cancel();
    });

    test('store close closes the change stream', () async {
      var isDone = false;
      final subscription = store.changes.listen(
        (_) {},
        onDone: () => isDone = true,
      );

      await store.close();

      expect(isDone, isTrue);
      await subscription.cancel();
    });

    test('write racing close is rejected before backend mutation', () async {
      final changes = <OfflineStoreChange>[];
      final subscription = store.changes.listen(changes.add);

      final admittedWrite = store.insertMutation(
        _mutation(id: 'mut_admitted'),
      );
      final closing = store.close();
      final lateWrite = store.insertMutation(_mutation(id: 'mut_late'));

      await expectLater(lateWrite, throwsA(isA<StateError>()));
      await admittedWrite;
      await closing;
      expect(changes, hasLength(1));
      expect(changes.single.sessionId, 'ses_01');
      expect(changes.single.kinds, {OfflineStoreChangeKind.mutation});
      await subscription.cancel();
    });

    test('updates photo upload status and remote attachment metadata',
        () async {
      final attemptedAt = DateTime.utc(2026, 6, 18, 20, 30);
      await store.insertPhotoUpload(_photoUpload(id: 'photo_01'));

      await store.markPhotoUploadUploading(
        'photo_01',
        attemptedAt: attemptedAt,
      );
      var upload = (await store.readPhotoUploadsForSession('ses_01')).single;
      expect(upload.status, OfflinePhotoUploadStatus.uploading);
      expect(upload.attemptCount, 1);
      expect(upload.lastAttemptedAt, attemptedAt);

      await store.attachRemoteHandResultToPhotoUpload(
        'mut_01',
        'hand_remote_01',
      );
      await store.markPhotoUploadUploaded(
        'photo_01',
        storagePath: 'events/evt_01/hands/photo_01.jpg',
      );

      upload = (await store.readPhotoUploadsForSession('ses_01')).single;
      expect(upload.status, OfflinePhotoUploadStatus.uploaded);
      expect(upload.remoteHandResultId, 'hand_remote_01');
      expect(upload.storagePath, 'events/evt_01/hands/photo_01.jpg');
      expect(upload.lastError, isNull);
    });

    test('includes failed photo uploads in pending fifo reads', () async {
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_failed',
          createdAt: DateTime.utc(2026, 6, 18, 20, 1),
          status: OfflinePhotoUploadStatus.failed,
        ),
      );
      await store.insertPhotoUpload(
        _photoUpload(
          id: 'photo_pending',
          createdAt: DateTime.utc(2026, 6, 18, 20, 2),
        ),
      );

      final pending = await store.readPendingPhotoUploads();

      expect(
        pending.map((upload) => upload.id),
        ['photo_failed', 'photo_pending'],
      );
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

    test('upgrades v1 sqlite database while preserving mutations', () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('mosaic_v1_db_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final databasePath = p.join(directory.path, 'offline.db');
      final v1 = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              create table offline_mutations (
                id text primary key,
                kind text not null,
                event_id text not null,
                session_id text not null,
                payload_json text not null,
                base_recorded_hand_count integer not null,
                base_last_recorded_hand_id text,
                local_hand_number integer not null,
                created_at text not null,
                updated_at text not null,
                status text not null,
                attempt_count integer not null default 0,
                last_error text,
                last_attempted_at text
              )
            ''');
            await db.insert('offline_mutations', {
              'id': 'mut_01',
              'kind': 'record_hand',
              'event_id': 'evt_01',
              'session_id': 'ses_01',
              'payload_json': '{"target_result_type":"washout"}',
              'base_recorded_hand_count': 0,
              'base_last_recorded_hand_id': null,
              'local_hand_number': 1,
              'created_at': '2026-06-18T20:00:00.000Z',
              'updated_at': '2026-06-18T20:00:00.000Z',
              'status': 'pending',
              'attempt_count': 0,
              'last_error': null,
              'last_attempted_at': null,
            });
          },
        ),
      );
      await v1.close();

      final upgraded = await SqliteOfflineStore.openForTesting(
        databasePath: databasePath,
        databaseFactory: databaseFactoryFfi,
      );
      addTearDown(upgraded.close);

      final mutation = await upgraded.readMutation('mut_01');
      expect(mutation, isNotNull);
      expect(mutation!.payload['target_result_type'], 'washout');

      final changes = <OfflineStoreChange>[];
      final subscription = upgraded.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      await upgraded.insertPhotoUpload(_photoUpload(id: 'photo_01'));
      expect((await upgraded.readPendingPhotoUploads()).single.id, 'photo_01');
      expect(changes, hasLength(1));

      await expectLater(
        upgraded.insertMutationWithPhotoUpload(
          _mutation(id: 'mut_rollback'),
          _photoUpload(id: 'photo_01', mutationId: 'mut_rollback'),
        ),
        throwsA(anything),
      );
      expect(await upgraded.readMutation('mut_rollback'), isNull);
      expect(changes, hasLength(1));
    });
  });
}

OfflineMutationRecord _mutation({
  String id = 'mut_01',
  String sessionId = 'ses_01',
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
    lastError: lastError,
  );
}

OfflinePhotoUploadRecord _photoUpload({
  String id = 'photo_01',
  String mutationId = 'mut_01',
  String sessionId = 'ses_01',
  DateTime? createdAt,
  OfflinePhotoUploadStatus status = OfflinePhotoUploadStatus.pending,
  String? lastError,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 6, 18, 20);
  return OfflinePhotoUploadRecord(
    id: id,
    mutationId: mutationId,
    eventId: 'evt_01',
    sessionId: sessionId,
    clientPhotoId: id,
    localPath: '/local/$id.jpg',
    capturedAt: DateTime.utc(2026, 6, 18, 19, 55),
    createdAt: timestamp,
    updatedAt: timestamp,
    status: status,
    lastError: lastError,
  );
}
