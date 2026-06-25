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

    test('parses under declared tile review status', () {
      final entry = HandTileEntryRecord.fromJson(const {
        'id': 'tile_01',
        'hand_result_id': 'hand_01',
        'entered_at': '2026-06-25T18:05:00Z',
        'tiles_json': {'schemaVersion': 1, 'tiles': []},
        'calculation_version': 'hk_v1',
        'validation_status': 'valid',
        'review_status': 'under_declared',
      });

      expect(entry.reviewStatus, HandTileReviewStatus.underDeclared);
    });
  });

  group('HandEvidenceReviewRecord', () {
    test('parses combined hand evidence review rows', () {
      final row = HandEvidenceReviewRecord.fromJson(const {
        'photo_id': 'photo_01',
        'hand_result_id': 'hand_01',
        'client_photo_id': 'client_photo_01',
        'captured_at': '2026-06-25T18:00:00Z',
        'photo_capture_status': 'captured',
        'photo_upload_status': 'uploaded',
        'visibility': 'host_admin_only',
        'storage_bucket': 'hand-photos',
        'storage_path': 'events/evt_01/hands/hand_01/client_photo_01.jpg',
        'hand_number': 12,
        'table_label': 'Table 3',
        'winner_name': 'Alice Wong',
        'win_type': 'self_draw',
        'declared_fan_count': 3,
        'seat_wind_tile_id': 'south',
        'round_wind_tile_id': 'east',
        'tile_entry_id': 'tile_01',
        'entered_at': '2026-06-25T18:05:00Z',
        'tiles_json': {'schemaVersion': 1, 'tiles': []},
        'calculated_fan_count': 4,
        'fan_delta': -1,
        'calculation_version': 'hk_v1',
        'validation_status': 'valid',
        'review_status': 'under_declared',
      });

      expect(row.photo.id, 'photo_01');
      expect(row.photo.clientPhotoId, 'client_photo_01');
      expect(row.handResultId, 'hand_01');
      expect(row.handNumber, 12);
      expect(row.tableLabel, 'Table 3');
      expect(row.winnerName, 'Alice Wong');
      expect(row.winType, 'self_draw');
      expect(row.declaredFanCount, 3);
      expect(row.seatWindTileId, 'south');
      expect(row.roundWindTileId, 'east');
      expect(row.tileEntry?.id, 'tile_01');
      expect(
        row.tileEntry?.enteredAt,
        DateTime.parse('2026-06-25T18:05:00Z'),
      );
      expect(row.tileEntry?.calculatedFanCount, 4);
      expect(row.tileEntry?.declaredFanCount, 3);
      expect(row.tileEntry?.fanDelta, -1);
      expect(row.tileEntry?.reviewStatus, HandTileReviewStatus.underDeclared);
    });

    test('falls back to legacy id for combined row photo id', () {
      final row = HandEvidenceReviewRecord.fromJson(const {
        'id': 'photo_legacy_01',
        'hand_result_id': 'hand_01',
        'client_photo_id': 'client_photo_01',
        'captured_at': '2026-06-25T18:00:00Z',
        'photo_capture_status': 'captured',
        'photo_upload_status': 'uploaded',
        'visibility': 'host_admin_only',
      });

      expect(row.photo.id, 'photo_legacy_01');
    });

    test('allows combined review rows without tile entries', () {
      final row = HandEvidenceReviewRecord.fromJson(const {
        'photo_id': 'photo_01',
        'hand_result_id': 'hand_01',
        'client_photo_id': 'client_photo_01',
        'captured_at': '2026-06-25T18:00:00Z',
        'photo_capture_status': 'captured',
        'photo_upload_status': 'uploaded',
        'visibility': 'host_admin_only',
      });

      expect(row.tileEntry, isNull);
    });
  });
}
