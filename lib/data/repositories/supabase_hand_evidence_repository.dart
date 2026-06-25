import 'dart:io';
import 'dart:typed_data';

import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef StorageUploader = Future<void> Function({
  required String bucket,
  required String path,
  required Uint8List bytes,
  required String contentType,
});

typedef HandPhotoRecorder = Future<void> Function(Map<String, dynamic> params);
typedef FileBytesReader = Future<Uint8List> Function(String path);

class SupabaseHandEvidenceRepository implements HandEvidenceRepository {
  SupabaseHandEvidenceRepository({
    SupabaseClient? client,
    StorageUploader? storageUploader,
    HandPhotoRecorder? handPhotoRecorder,
    FileBytesReader? readFileBytes,
  })  : _client = client,
        _storageUploader = storageUploader,
        _handPhotoRecorder = handPhotoRecorder,
        _readFileBytes = readFileBytes ?? _defaultReadFileBytes;

  static const bucketName = 'hand-photos';

  final SupabaseClient? _client;
  final StorageUploader? _storageUploader;
  final HandPhotoRecorder? _handPhotoRecorder;
  final FileBytesReader _readFileBytes;

  static String storagePathFor({
    required String eventId,
    required String handResultId,
    required String clientPhotoId,
  }) {
    return 'events/$eventId/hands/$handResultId/$clientPhotoId.jpg';
  }

  @override
  Future<void> uploadAndAttachHandPhoto({
    required String eventId,
    required String handResultId,
    required String clientPhotoId,
    required String localPath,
    required DateTime capturedAt,
  }) async {
    final storagePath = storagePathFor(
      eventId: eventId,
      handResultId: handResultId,
      clientPhotoId: clientPhotoId,
    );
    final bytes = await _readFileBytes(localPath);
    await _upload(
      bucket: bucketName,
      path: storagePath,
      bytes: bytes,
      contentType: 'image/jpeg',
    );
    await _record({
      'target_hand_result_id': handResultId,
      'target_client_photo_id': clientPhotoId,
      'target_captured_at': capturedAt.toUtc().toIso8601String(),
      'target_storage_bucket': bucketName,
      'target_storage_path': storagePath,
    });
  }

  Future<void> _upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uploader = _storageUploader;
    try {
      if (uploader != null) {
        await uploader(
          bucket: bucket,
          path: path,
          bytes: bytes,
          contentType: contentType,
        );
        return;
      }
      await _client!.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
    } on StorageException catch (error) {
      if (error.error == 'Duplicate') {
        return;
      }
      rethrow;
    }
  }

  Future<void> _record(Map<String, dynamic> params) async {
    final recorder = _handPhotoRecorder;
    if (recorder != null) {
      return recorder(params);
    }
    await _client!.rpc('record_hand_photo', params: params);
  }

  static Future<Uint8List> _defaultReadFileBytes(String path) {
    return File(path).readAsBytes();
  }
}
