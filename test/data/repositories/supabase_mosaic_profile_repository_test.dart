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
            _photoJson(
              id: 'photo_01',
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
      expect(records.single.id, 'photo_01');
      expect(records.single.handResultId, 'hand_01');
      expect(records.single.clientPhotoId, 'client_photo_01');
      expect(records.single.uploadStatus, HandPhotoUploadStatus.uploaded);
      expect(records.single.visibility, HandPhotoVisibility.hostAdminOnly);
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
  });
}

Map<String, dynamic> _photoJson({
  required String id,
  required String handResultId,
  required String clientPhotoId,
}) {
  return {
    'id': id,
    'hand_result_id': handResultId,
    'client_photo_id': clientPhotoId,
    'captured_by': 'host_01',
    'captured_at': '2026-06-25T18:30:00Z',
    'local_capture_path': null,
    'storage_bucket': 'hand-photos',
    'storage_path': 'events/evt_01/hands/$handResultId/$clientPhotoId.jpg',
    'photo_capture_status': 'captured',
    'photo_upload_status': 'uploaded',
    'visibility': 'host_admin_only',
  };
}
