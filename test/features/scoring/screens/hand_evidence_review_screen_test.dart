import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/screens/hand_evidence_review_screen.dart';

void main() {
  testWidgets('renders empty state when no review photos exist',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            photos: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand Evidence Review'), findsOneWidget);
    expect(find.text('No hand evidence to review.'), findsOneWidget);
  });

  testWidgets('renders review rows from repository photos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            photos: [
              _photo(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
              _photo(
                id: 'photo_02',
                handResultId: 'hand_02',
                clientPhotoId: 'client_photo_02',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 45),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('hand_01'), findsOneWidget);
    expect(find.text('hand_02'), findsOneWidget);
    expect(find.text('client_photo_01'), findsOneWidget);
    expect(find.text('Uploaded'), findsNWidgets(2));
  });

  testWidgets('renders error state when review load fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            error: StateError('permission denied'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load hand evidence.'), findsOneWidget);
  });
}

class _FakeMosaicProfileRepository implements MosaicProfileRepository {
  const _FakeMosaicProfileRepository({
    this.photos = const [],
    this.error,
  });

  final List<HandPhotoRecord> photos;
  final Object? error;

  @override
  Future<List<HandPhotoRecord>> listHandEvidenceReview(String eventId) async {
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return photos;
  }

  @override
  Future<HandTileEntryRecord> upsertHandTileEntry({
    required String handResultId,
    required Map<String, dynamic> tilesJson,
    required int? calculatedFanCount,
    required String calculationVersion,
  }) {
    throw UnimplementedError();
  }
}

HandPhotoRecord _photo({
  required String id,
  required String handResultId,
  required String clientPhotoId,
  required DateTime capturedAt,
}) {
  return HandPhotoRecord(
    id: id,
    handResultId: handResultId,
    clientPhotoId: clientPhotoId,
    capturedAt: capturedAt,
    captureStatus: HandPhotoCaptureStatus.captured,
    uploadStatus: HandPhotoUploadStatus.uploaded,
    visibility: HandPhotoVisibility.hostAdminOnly,
    storageBucket: 'hand-photos',
    storagePath: 'events/evt_01/hands/$handResultId/$clientPhotoId.jpg',
  );
}
