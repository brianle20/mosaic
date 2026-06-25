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

      await upgraded.insertPhotoUpload(_photoUpload(id: 'photo_01'));
      expect((await upgraded.readPendingPhotoUploads()).single.id, 'photo_01');
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

OfflinePhotoUploadRecord _photoUpload({
  String id = 'photo_01',
  String mutationId = 'mut_01',
  String sessionId = 'ses_01',
  DateTime? createdAt,
  OfflinePhotoUploadStatus status = OfflinePhotoUploadStatus.pending,
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
  );
}
