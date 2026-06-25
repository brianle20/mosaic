import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';

void main() {
  group('HandPhotoRecord', () {
    test('parses upload status and visibility', () {
      final photo = HandPhotoRecord.fromJson(const {
        'id': 'photo_01',
        'hand_result_id': 'hand_01',
        'client_photo_id': 'client_01',
        'captured_by': 'user_01',
        'captured_at': '2026-06-25T18:00:00Z',
        'local_capture_path': '/local/hand.jpg',
        'storage_bucket': 'hand-photos',
        'storage_path': 'events/event_01/hand_01.jpg',
        'photo_capture_status': 'captured',
        'photo_upload_status': 'pending',
        'visibility': 'host_admin_only',
      });

      expect(photo.id, 'photo_01');
      expect(photo.handResultId, 'hand_01');
      expect(photo.clientPhotoId, 'client_01');
      expect(photo.capturedBy, 'user_01');
      expect(photo.capturedAt, DateTime.parse('2026-06-25T18:00:00Z'));
      expect(photo.localCapturePath, '/local/hand.jpg');
      expect(photo.storageBucket, 'hand-photos');
      expect(photo.storagePath, 'events/event_01/hand_01.jpg');
      expect(photo.captureStatus, HandPhotoCaptureStatus.captured);
      expect(photo.uploadStatus, HandPhotoUploadStatus.pending);
      expect(photo.visibility, HandPhotoVisibility.hostAdminOnly);
    });

    test('rejects unknown upload status values', () {
      expect(
        () => HandPhotoRecord.fromJson(const {
          'id': 'photo_01',
          'hand_result_id': 'hand_01',
          'client_photo_id': 'client_01',
          'captured_at': '2026-06-25T18:00:00Z',
          'photo_capture_status': 'captured',
          'photo_upload_status': 'queued',
          'visibility': 'host_admin_only',
        }),
        throwsFormatException,
      );
    });
  });

  group('HandTileEntryRecord', () {
    test('parses fan mismatch and review status', () {
      final entry = HandTileEntryRecord.fromJson(const {
        'id': 'tile_01',
        'hand_result_id': 'hand_01',
        'entered_by': 'user_01',
        'entered_at': '2026-06-25T18:05:00Z',
        'tiles_json': {
          'tiles': ['bamboo_1'],
        },
        'calculated_fan_count': 7,
        'declared_fan_count': 5,
        'fan_delta': -2,
        'calculation_version': 'hk_v1',
        'validation_status': 'valid',
        'review_status': 'flagged',
      });

      expect(entry.id, 'tile_01');
      expect(entry.handResultId, 'hand_01');
      expect(entry.enteredBy, 'user_01');
      expect(entry.enteredAt, DateTime.parse('2026-06-25T18:05:00Z'));
      expect(
        entry.tilesJson,
        {
          'tiles': ['bamboo_1'],
        },
      );
      expect(entry.calculatedFanCount, 7);
      expect(entry.declaredFanCount, 5);
      expect(entry.fanDelta, -2);
      expect(entry.calculationVersion, 'hk_v1');
      expect(entry.validationStatus, HandTileValidationStatus.valid);
      expect(entry.reviewStatus, HandTileReviewStatus.flagged);
    });

    test('parses array tile json', () {
      final entry = HandTileEntryRecord.fromJson(const {
        'id': 'tile_01',
        'hand_result_id': 'hand_01',
        'entered_at': '2026-06-25T18:05:00Z',
        'tiles_json': ['bamboo_1'],
        'calculation_version': 'hk_v1',
        'validation_status': 'valid',
        'review_status': 'unreviewed',
      });

      expect(entry.tilesJson, ['bamboo_1']);
    });
  });
}
