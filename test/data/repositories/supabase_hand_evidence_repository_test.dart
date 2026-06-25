import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/repositories/supabase_hand_evidence_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('builds deterministic storage path for hand photo', () {
    final path = SupabaseHandEvidenceRepository.storagePathFor(
      eventId: 'event_01',
      handResultId: 'hand_01',
      clientPhotoId: 'photo_01',
    );

    expect(path, 'events/event_01/hands/hand_01/photo_01.jpg');
  });

  test('uploads photo bytes then records hand photo row', () async {
    final storage = _FakeStorageUploader();
    final rpc = _FakeHandPhotoRecorder();
    final repository = SupabaseHandEvidenceRepository(
      storageUploader: storage.upload,
      handPhotoRecorder: rpc.record,
      readFileBytes: (_) async => Uint8List.fromList([1, 2, 3]),
    );

    await repository.uploadAndAttachHandPhoto(
      eventId: 'event_01',
      handResultId: 'hand_01',
      clientPhotoId: 'photo_01',
      localPath: '/local/photo.jpg',
      capturedAt: DateTime.utc(2026, 6, 25, 18),
    );

    expect(storage.bucket, SupabaseHandEvidenceRepository.bucketName);
    expect(storage.path, 'events/event_01/hands/hand_01/photo_01.jpg');
    expect(storage.bytes, [1, 2, 3]);
    expect(storage.contentType, 'image/jpeg');
    expect(rpc.params['target_hand_result_id'], 'hand_01');
    expect(rpc.params['target_storage_bucket'], storage.bucket);
    expect(rpc.params['target_storage_path'], storage.path);
    expect(rpc.params['target_client_photo_id'], 'photo_01');
    expect(rpc.params['target_captured_at'], '2026-06-25T18:00:00.000Z');
  });

  test('records hand photo row when deterministic object already exists',
      () async {
    final storage = _FakeStorageUploader()
      ..error = const StorageException(
        'The resource already exists',
        error: 'Duplicate',
      );
    final rpc = _FakeHandPhotoRecorder();
    final repository = SupabaseHandEvidenceRepository(
      storageUploader: storage.upload,
      handPhotoRecorder: rpc.record,
      readFileBytes: (_) async => Uint8List.fromList([1, 2, 3]),
    );

    await repository.uploadAndAttachHandPhoto(
      eventId: 'event_01',
      handResultId: 'hand_01',
      clientPhotoId: 'photo_01',
      localPath: '/local/photo.jpg',
      capturedAt: DateTime.utc(2026, 6, 25, 18),
    );

    expect(rpc.params['target_storage_path'], storage.path);
  });
}

class _FakeStorageUploader {
  String? bucket;
  String? path;
  Uint8List? bytes;
  String? contentType;
  Object? error;

  Future<void> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    this.bucket = bucket;
    this.path = path;
    this.bytes = bytes;
    this.contentType = contentType;
    final error = this.error;
    if (error != null) {
      throw error;
    }
  }
}

class _FakeHandPhotoRecorder {
  Map<String, dynamic> params = const {};

  Future<void> record(Map<String, dynamic> params) async {
    this.params = Map.unmodifiable(params);
  }
}
