import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/mosaic_rating_profile_models.dart';

void main() {
  group('RatingSnapshotRecord', () {
    test('parses provenance fields', () {
      final snapshot = RatingSnapshotRecord.fromJson(const {
        'id': 'rating_01',
        'player_id': 'player_01',
        'event_id': 'event_01',
        'table_session_id': 'session_01',
        'calculation_batch_id': 'batch_01',
        'rating_before': 1000,
        'rating_after': 1024,
        'rating_delta': 24,
        'provisional_state': 'provisional',
        'source_quality': 'mosaic_hand_ledger',
        'inputs_version': 'rating_v1',
        'inputs_json': {'hands': 134},
        'created_at': '2026-06-25T18:00:00Z',
      });

      expect(snapshot.id, 'rating_01');
      expect(snapshot.playerId, 'player_01');
      expect(snapshot.eventId, 'event_01');
      expect(snapshot.tableSessionId, 'session_01');
      expect(snapshot.calculationBatchId, 'batch_01');
      expect(snapshot.ratingBefore, 1000);
      expect(snapshot.ratingAfter, 1024);
      expect(snapshot.ratingDelta, 24);
      expect(
          snapshot.provisionalState, MosaicRatingProvisionalState.provisional);
      expect(snapshot.sourceQuality, MosaicSourceQuality.mosaicHandLedger);
      expect(snapshot.inputsVersion, 'rating_v1');
      expect(snapshot.inputsJson['hands'], 134);
      expect(snapshot.createdAt, DateTime.parse('2026-06-25T18:00:00Z'));
    });

    test('rejects unknown source quality values', () {
      expect(
        () => RatingSnapshotRecord.fromJson(const {
          'id': 'rating_01',
          'player_id': 'player_01',
          'rating_after': 1024,
          'rating_delta': 24,
          'provisional_state': 'provisional',
          'source_quality': 'spreadsheet',
          'inputs_version': 'rating_v1',
          'inputs_json': {},
          'created_at': '2026-06-25T18:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('ProfileSnapshotRecord', () {
    test('parses confidence and source-through timestamps', () {
      final snapshot = ProfileSnapshotRecord.fromJson(const {
        'id': 'profile_01',
        'player_id': 'player_01',
        'event_id': null,
        'profile_dimensions_json': {'attack': 63},
        'style_archetype': 'Efficient Scorer',
        'confidence': 'developing_profile',
        'source_quality': 'mosaic_hand_ledger',
        'tile_derived_confidence': 'none',
        'generated_from_official_data_through': '2026-06-25T18:00:00Z',
        'generated_from_tile_data_through': null,
        'inputs_version': 'profile_v1',
        'private_review_json': {'needs_review': false},
        'created_at': '2026-06-25T18:01:00Z',
      });

      expect(snapshot.id, 'profile_01');
      expect(snapshot.playerId, 'player_01');
      expect(snapshot.eventId, isNull);
      expect(snapshot.profileDimensionsJson['attack'], 63);
      expect(snapshot.styleArchetype, 'Efficient Scorer');
      expect(snapshot.confidence, MosaicProfileConfidence.developingProfile);
      expect(snapshot.sourceQuality, MosaicSourceQuality.mosaicHandLedger);
      expect(snapshot.tileDerivedConfidence, TileDerivedConfidence.none);
      expect(
        snapshot.generatedFromOfficialDataThrough,
        DateTime.parse('2026-06-25T18:00:00Z'),
      );
      expect(snapshot.generatedFromTileDataThrough, isNull);
      expect(snapshot.inputsVersion, 'profile_v1');
      expect(snapshot.privateReviewJson['needs_review'], isFalse);
      expect(snapshot.createdAt, DateTime.parse('2026-06-25T18:01:00Z'));
    });

    test('rejects unknown tile-derived confidence values', () {
      expect(
        () => ProfileSnapshotRecord.fromJson(const {
          'id': 'profile_01',
          'player_id': 'player_01',
          'profile_dimensions_json': {},
          'confidence': 'early_read',
          'source_quality': 'mosaic_hand_ledger',
          'tile_derived_confidence': 'complete',
          'inputs_version': 'profile_v1',
          'private_review_json': {},
          'created_at': '2026-06-25T18:01:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('EventGuestRecord', () {
    test('round-trips nullable player id', () {
      final guest = EventGuestRecord.fromJson(const {
        'id': 'gst_01',
        'event_id': 'evt_01',
        'guest_profile_id': 'prf_01',
        'player_id': 'player_01',
        'display_name': 'Alice Wong',
        'normalized_name': 'alice wong',
        'attendance_status': 'expected',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      });

      expect(guest.playerId, 'player_01');
      expect(guest.toJson()['player_id'], 'player_01');
    });
  });
}
