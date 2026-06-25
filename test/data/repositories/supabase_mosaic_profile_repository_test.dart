import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/supabase_mosaic_profile_repository.dart';

void main() {
  group('SupabaseMosaicProfileRepository', () {
    test('lists hand evidence review rows through the RPC', () async {
      final calls = <String, Map<String, dynamic>>{};
      final repository = SupabaseMosaicProfileRepository.withRpcRunner(
        rpcRunner: (name, params) async {
          calls[name] = params;
          return [
            _reviewRowJson(
              photoId: 'photo_01',
              handResultId: 'hand_01',
              clientPhotoId: 'client_photo_01',
            ),
          ];
        },
      );

      final records = await repository.listHandEvidenceReview('evt_01');

      expect(calls['list_hand_evidence_review'], {
        'target_event_id': 'evt_01',
      });
      expect(records, hasLength(1));
      expect(records.single, isA<HandEvidenceReviewRecord>());
      expect(records.single.photo.id, 'photo_01');
      expect(records.single.handResultId, 'hand_01');
      expect(records.single.handNumber, 7);
      expect(records.single.tableLabel, 'Table 1');
      expect(records.single.winnerName, 'Ada');
      expect(records.single.winType, 'self_draw');
      expect(records.single.declaredFanCount, 3);
      expect(records.single.photo.clientPhotoId, 'client_photo_01');
      expect(records.single.photo.uploadStatus, HandPhotoUploadStatus.uploaded);
      expect(
          records.single.photo.visibility, HandPhotoVisibility.hostAdminOnly);
      expect(records.single.tileEntry, isNotNull);
      expect(records.single.tileEntry!.id, 'tile_01');
      expect(records.single.tileEntry!.calculatedFanCount, 4);
      expect(
          records.single.tileEntry!.reviewStatus, HandTileReviewStatus.flagged);
    });

    test('upserts hand tile entry through the RPC', () async {
      final calls = <String, Map<String, dynamic>>{};
      final repository = SupabaseMosaicProfileRepository.withRpcRunner(
        rpcRunner: (name, params) async {
          calls[name] = params;
          return [
            {
              'id': 'tile_01',
              'hand_result_id': params['target_hand_result_id'],
              'entered_by': 'host_01',
              'entered_at': '2026-06-25T19:00:00Z',
              'tiles_json': params['target_tiles_json'],
              'calculated_fan_count': params['target_calculated_fan_count'],
              'declared_fan_count': 3,
              'fan_delta': 1,
              'calculation_version': params['target_calculation_version'],
              'validation_status': 'valid',
              'review_status': 'unreviewed',
            },
          ];
        },
      );

      final entry = await repository.upsertHandTileEntry(
        handResultId: 'hand_01',
        tilesJson: {
          'concealed': ['bamboo-1', 'bamboo-2'],
          'melds': const [],
        },
        calculatedFanCount: 4,
        calculationVersion: 'hk-v1',
      );

      expect(calls['upsert_hand_tile_entry'], {
        'target_hand_result_id': 'hand_01',
        'target_tiles_json': {
          'concealed': ['bamboo-1', 'bamboo-2'],
          'melds': const [],
        },
        'target_calculated_fan_count': 4,
        'target_calculation_version': 'hk-v1',
      });
      expect(entry.id, 'tile_01');
      expect(entry.handResultId, 'hand_01');
      expect(entry.calculatedFanCount, 4);
      expect(entry.fanDelta, 1);
      expect(entry.calculationVersion, 'hk-v1');
      expect(entry.reviewStatus, HandTileReviewStatus.unreviewed);
    });

    test('returns null signed URL when storage path is missing', () async {
      final repository = SupabaseMosaicProfileRepository.withRpcRunner(
        rpcRunner: (name, params) => throw StateError('RPC not expected.'),
        signedUrlCreator: ({
          required bucket,
          required path,
          required expiresInSeconds,
        }) async {
          throw StateError('Signed URL creator not expected.');
        },
      );

      final url = await repository.createHandPhotoSignedUrl(
        _photo(includeStoragePath: false),
      );

      expect(url, isNull);
    });

    test('uses injected signed URL creator for stored photos', () async {
      final calls = <Map<String, Object?>>[];
      final repository = SupabaseMosaicProfileRepository.withRpcRunner(
        rpcRunner: (name, params) => throw StateError('RPC not expected.'),
        signedUrlCreator: ({
          required bucket,
          required path,
          required expiresInSeconds,
        }) async {
          calls.add({
            'bucket': bucket,
            'path': path,
            'expiresInSeconds': expiresInSeconds,
          });
          return 'https://example.test/signed/photo_01.jpg?token=abc';
        },
      );

      final url = await repository.createHandPhotoSignedUrl(_photo());

      expect(calls, [
        {
          'bucket': 'hand-photos',
          'path': 'events/evt_01/hands/hand_01/client_photo_01.jpg',
          'expiresInSeconds': 600,
        },
      ]);
      expect(
        url,
        Uri.parse('https://example.test/signed/photo_01.jpg?token=abc'),
      );
    });
  });
}

Map<String, dynamic> _reviewRowJson({
  required String photoId,
  required String handResultId,
  required String clientPhotoId,
}) {
  return {
    'photo_id': photoId,
    'hand_result_id': handResultId,
    'hand_number': 7,
    'table_label': 'Table 1',
    'winner_name': 'Ada',
    'win_type': 'self_draw',
    'declared_fan_count': 3,
    'client_photo_id': clientPhotoId,
    'captured_by': 'host_01',
    'captured_at': '2026-06-25T18:30:00Z',
    'local_capture_path': null,
    'storage_bucket': 'hand-photos',
    'storage_path': 'events/evt_01/hands/$handResultId/$clientPhotoId.jpg',
    'photo_capture_status': 'captured',
    'photo_upload_status': 'uploaded',
    'visibility': 'host_admin_only',
    'tile_entry_id': 'tile_01',
    'entered_by': 'host_01',
    'entered_at': '2026-06-25T19:00:00Z',
    'tiles_json': const {
      'concealed': ['bamboo-1', 'bamboo-2'],
      'melds': [],
    },
    'calculated_fan_count': 4,
    'fan_delta': 1,
    'calculation_version': 'hk-v1',
    'validation_status': 'valid',
    'review_status': 'flagged',
  };
}

HandPhotoRecord _photo({bool includeStoragePath = true}) {
  return HandPhotoRecord(
    id: 'photo_01',
    handResultId: 'hand_01',
    clientPhotoId: 'client_photo_01',
    capturedBy: 'host_01',
    capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
    storageBucket: 'hand-photos',
    storagePath: includeStoragePath
        ? 'events/evt_01/hands/hand_01/client_photo_01.jpg'
        : null,
    captureStatus: HandPhotoCaptureStatus.captured,
    uploadStatus: HandPhotoUploadStatus.uploaded,
    visibility: HandPhotoVisibility.hostAdminOnly,
  );
}
