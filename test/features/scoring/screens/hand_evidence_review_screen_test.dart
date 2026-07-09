import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/screens/hand_evidence_review_screen.dart';
import 'package:mosaic/widgets/status_chip.dart';

void main() {
  testWidgets('renders empty state when no review photos exist',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand Review'), findsOneWidget);
    expect(find.text('No hand evidence to review.'), findsOneWidget);
  });

  testWidgets('renders queue rows with metadata and status labels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
                handNumber: 7,
                tableLabel: 'Table A',
                winnerName: 'Ava',
                declaredFanCount: 3,
              ),
              _reviewRecord(
                id: 'photo_02',
                handResultId: 'hand_02',
                clientPhotoId: 'client_photo_02',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 45),
                winnerName: 'Ben',
                tileEntry: _tileEntry(
                  handResultId: 'hand_02',
                  reviewStatus: HandTileReviewStatus.unreviewed,
                ),
              ),
              _reviewRecord(
                id: 'photo_03',
                handResultId: 'hand_03',
                clientPhotoId: 'client_photo_03',
                capturedAt: DateTime.utc(2026, 6, 25, 19),
                winnerName: 'Cam',
                tileEntry: _tileEntry(
                  handResultId: 'hand_03',
                  reviewStatus: HandTileReviewStatus.matched,
                ),
              ),
              _reviewRecord(
                id: 'photo_04',
                handResultId: 'hand_04',
                clientPhotoId: 'client_photo_04',
                capturedAt: DateTime.utc(2026, 6, 25, 19, 15),
                winnerName: 'Dee',
                tileEntry: _tileEntry(
                  handResultId: 'hand_04',
                  reviewStatus: HandTileReviewStatus.underDeclared,
                ),
              ),
              _reviewRecord(
                id: 'photo_05',
                handResultId: 'hand_05',
                clientPhotoId: 'client_photo_05',
                capturedAt: DateTime.utc(2026, 6, 25, 19, 30),
                winnerName: 'Eli',
                tileEntry: _tileEntry(
                  handResultId: 'hand_05',
                  reviewStatus: HandTileReviewStatus.flagged,
                ),
              ),
              _reviewRecord(
                id: 'photo_06',
                handResultId: 'hand_06',
                clientPhotoId: 'client_photo_06',
                capturedAt: DateTime.utc(2026, 6, 25, 19, 45),
                winnerName: 'Fran',
                tileEntry: _tileEntry(
                  handResultId: 'hand_06',
                  reviewStatus: HandTileReviewStatus.resolved,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand 7'), findsOneWidget);
    expect(find.text("Ben's winning hand"), findsOneWidget);
    expect(find.textContaining('Table A'), findsOneWidget);
    expect(find.textContaining('Ava'), findsOneWidget);
    expect(find.textContaining('Declared 3 fan'), findsOneWidget);
    expect(find.text('Needs tiles'), findsOneWidget);
    expect(find.text('Unreviewed'), findsOneWidget);
    expect(find.text('Matched'), findsOneWidget);
    expect(find.text('Under-declared'), findsOneWidget);
    expect(find.text('Flagged'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Resolved'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.byType(StatusChip), findsWidgets);
  });

  testWidgets('uses user-friendly labels when review metadata is missing',
      (tester) async {
    const handResultId = 'ed4a21bd-4a68-473b-a123-7d23513f1c4f';
    const clientPhotoId = 'ab121f44-24d5-49a3-ba69-94872cde1959';

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: handResultId,
                clientPhotoId: clientPhotoId,
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Captured winning hand'), findsOneWidget);
    expect(find.textContaining('Captured Jun 25, 2026 at 6:30 PM'),
        findsOneWidget);
    expect(find.textContaining(handResultId), findsNothing);
    expect(find.textContaining(clientPhotoId), findsNothing);
  });

  testWidgets('opens editor when tapping queue row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
                handNumber: 7,
                tableLabel: 'Table A',
                winnerName: 'Ava',
                declaredFanCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Hand 7'));
    await tester.pumpAndSettle();

    expect(find.text('Review Hand 7'), findsOneWidget);
    expect(find.text('Save Tiles'), findsOneWidget);
    expect(find.text('Selected tiles (0)'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pump();
    expect(find.text('Characters'), findsOneWidget);
  });

  testWidgets('caps long editor metadata on short mobile viewports',
      (tester) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
                handNumber: 7,
                tableLabel: List.filled(10, 'Long Table Name').join(' '),
                winnerName: List.filled(10, 'Long Winner Name').join(' '),
                declaredFanCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand 7'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save Tiles'), findsOneWidget);
    expect(find.text('Selected tiles (0)'), findsOneWidget);
  });

  testWidgets('keeps compact landscape editor usable with long metadata',
      (tester) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
                handNumber: 7,
                tableLabel: List.filled(10, 'Long Table Name').join(' '),
                winnerName: List.filled(10, 'Long Winner Name').join(' '),
                declaredFanCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand 7'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save Tiles'), findsOneWidget);

    final editorScrollable = find.byType(Scrollable).at(1);
    await tester.drag(editorScrollable, const Offset(0, -380));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '1M'));
    await tester.pumpAndSettle();

    await tester.drag(editorScrollable, const Offset(0, 260));
    await tester.pumpAndSettle();
    expect(find.text('Selected tiles (1)'), findsOneWidget);
  });

  testWidgets('hydrates existing tile entry and preserves it when saved',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          tileEntry: _tileEntry(
            handResultId: 'hand_01',
            reviewStatus: HandTileReviewStatus.unreviewed,
            tilesJson: const {
              'schemaVersion': 1,
              'tiles': ['man_1', 'man_2', 'man_3'],
              'flowers': ['plum_1'],
              'winningTileId': 'man_3',
              'winningTileKnown': true,
              'groups': [],
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();

    expect(find.text('Selected tiles (4)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '1M'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '2M'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '3M'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Plum 1'), findsOneWidget);
    final winningChip =
        tester.widget<InputChip>(find.widgetWithText(InputChip, '3M'));
    expect(winningChip.selected, isTrue);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedTilesJson?['tiles'], ['man_1', 'man_2', 'man_3']);
    expect(repository.savedTilesJson?['flowers'], ['plum_1']);
    expect(repository.savedTilesJson?['winningTile'], 'man_3');
    expect(repository.savedTilesJson?['winningTileKnown'], isTrue);
  });

  testWidgets('hydrates legacy array tile entry and preserves it when saved',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          tileEntry: _tileEntry(
            handResultId: 'hand_01',
            reviewStatus: HandTileReviewStatus.unreviewed,
            tilesJson: const ['man_1', 'east'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();

    expect(find.text('Selected tiles (2)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '1M'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'East'), findsOneWidget);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedTilesJson?['tiles'], ['man_1', 'east']);
  });

  testWidgets('splits legacy array flowers when hydrating and saving',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          tileEntry: _tileEntry(
            handResultId: 'hand_01',
            reviewStatus: HandTileReviewStatus.unreviewed,
            tilesJson: const ['man_1', 'plum_1'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();

    expect(find.text('Selected tiles (2)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '1M'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Plum 1'), findsOneWidget);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedTilesJson?['tiles'], ['man_1']);
    expect(repository.savedTilesJson?['flowers'], ['plum_1']);
  });

  testWidgets('requests and renders signed hand photo when row is selected',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      signedPhotoUrl: Uri.parse('https://example.com/photo.jpg'),
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          handNumber: 7,
          tableLabel: 'Table A',
          winnerName: 'Ava',
          declaredFanCount: 3,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand 7'));
    await tester.pumpAndSettle();

    expect(repository.requestedPhotoIds, ['photo_01']);
    expect(find.text('Winning hand photo'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, 'https://example.com/photo.jpg');
  });

  testWidgets('renders photo unavailable panel when signed URL is null',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();

    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(
      find.text('The captured photo could not be opened.'),
      findsOneWidget,
    );
    expect(find.text('client_photo_01'), findsNothing);
  });

  testWidgets('keeps tile entry usable while photo URL is pending',
      (tester) async {
    final pendingPhotoUrl = Completer<Uri?>();
    final repository = _FakeMosaicProfileRepository(
      pendingPhotoUrl: pendingPhotoUrl,
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pump();

    expect(find.text('Loading photo'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '1M'));
    await tester.pump();

    await _showSelectedTileCount(tester, 1, settle: false);
    expect(find.text('Selected tiles (1)'), findsOneWidget);

    pendingPhotoUrl.complete(Uri.parse('https://example.com/photo.jpg'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders photo error panel when signed URL lookup fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            photoUrlError: StateError('signed URL denied'),
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();

    expect(find.text('Photo could not be loaded'), findsOneWidget);
    expect(find.textContaining('signed URL denied'), findsOneWidget);
  });

  testWidgets('saves under-declared tile entry and updates queue status',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          winnerName: 'Ava',
          declaredFanCount: 3,
          winType: 'self_draw',
        ),
      ],
      savedEntry: _tileEntry(
        handResultId: 'hand_01',
        reviewStatus: HandTileReviewStatus.underDeclared,
        calculatedFanCount: 5,
        declaredFanCount: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ava's winning hand"));
    await tester.pumpAndSettle();

    for (final label in [
      '1M',
      '2M',
      '3M',
      '4D',
      '5D',
      '6D',
      'East',
      'East',
      'East',
      'South',
      'South',
      'Red',
      'Red',
      'Red',
      'Plum 1',
    ]) {
      await _tapTile(tester, label);
    }

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedHandResultId, 'hand_01');
    expect(repository.savedTilesJson?['schemaVersion'], 1);
    expect(repository.savedTilesJson?['tiles'], hasLength(14));
    expect(repository.savedTilesJson?['flowers'], ['plum_1']);
    final savedGroups = repository.savedTilesJson?['groups'];
    expect(savedGroups, isA<List<dynamic>>());
    expect(savedGroups as List<dynamic>, isNotEmpty);
    expect(repository.savedCalculatedFanCount, 5);
    expect(repository.savedCalculationVersion, handTileCalculationVersion);
    expect(find.text('Under-declared'), findsWidgets);
  });

  testWidgets('uses review row wind context when saving calculated fan',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          declaredFanCount: 1,
          seatWindTileId: 'south',
          roundWindTileId: 'east',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();

    for (final label in [
      'South',
      'South',
      'South',
      '1M',
      '2M',
      '3M',
      '4M',
      '5M',
      '6M',
      '1D',
      '2D',
      '3D',
      '1B',
      '1B',
    ]) {
      await _tapTile(tester, label);
    }

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedCalculatedFanCount, 1);
  });

  testWidgets('ignores tile edits while save is pending', (tester) async {
    final pendingSave = Completer<HandTileEntryRecord>();
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
        ),
      ],
      pendingSave: pendingSave,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();
    await _tapTile(tester, '1M');
    await _showSelectedTileCount(tester, 1);

    await tester.tap(find.text('Save Tiles'));
    await tester.pump();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '2M'));
    await tester.pump();
    await _showSelectedTileCount(tester, 1, settle: false);
    expect(find.text('Selected tiles (1)'), findsOneWidget);

    pendingSave.complete(_tileEntry(
      handResultId: 'hand_01',
      reviewStatus: HandTileReviewStatus.unreviewed,
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('ignores row selection while save is pending', (tester) async {
    final pendingSave = Completer<HandTileEntryRecord>();
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          handNumber: 1,
        ),
        _reviewRecord(
          id: 'photo_02',
          handResultId: 'hand_02',
          clientPhotoId: 'client_photo_02',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 45),
          handNumber: 2,
        ),
      ],
      pendingSave: pendingSave,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand 1'));
    await tester.pumpAndSettle();
    await _tapTile(tester, '1M');
    await _showSelectedTileCount(tester, 1);

    await tester.tap(find.text('Save Tiles'));
    await tester.pump();

    await tester.tap(find.text('Hand 2'));
    await tester.pump();

    expect(find.text('Review Hand 1'), findsOneWidget);
    expect(find.text('Selected tiles (1)'), findsOneWidget);

    pendingSave.complete(_tileEntry(
      handResultId: 'hand_01',
      reviewStatus: HandTileReviewStatus.unreviewed,
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('surfaces save errors without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
            ],
            saveError: StateError('save denied'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captured winning hand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to save tiles.'), findsOneWidget);
    expect(find.textContaining('save denied'), findsOneWidget);
    expect(find.text('Review Captured winning hand'), findsOneWidget);
  });

  testWidgets('selecting another row resets draft and clears save error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_01',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
                handNumber: 1,
              ),
              _reviewRecord(
                id: 'photo_02',
                handResultId: 'hand_02',
                clientPhotoId: 'client_photo_02',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 45),
                handNumber: 2,
              ),
            ],
            saveError: StateError('save denied'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand 1'));
    await tester.pumpAndSettle();
    await _tapTile(tester, '1M');
    await _showSelectedTileCount(tester, 1);
    expect(find.text('Selected tiles (1)'), findsOneWidget);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to save tiles.'), findsOneWidget);

    await tester.tap(find.text('Hand 2'));
    await tester.pumpAndSettle();

    expect(find.text('Review Hand 2'), findsOneWidget);
    expect(find.textContaining('Unable to save tiles.'), findsNothing);
    await _showSelectedTileCount(tester, 0);
    expect(find.text('Selected tiles (0)'), findsOneWidget);
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
  _FakeMosaicProfileRepository({
    this.records = const [],
    this.error,
    this.saveError,
    this.savedEntry,
    this.pendingSave,
    this.signedPhotoUrl,
    this.photoUrlError,
    this.pendingPhotoUrl,
  });

  final List<HandEvidenceReviewRecord> records;
  final Object? error;
  final Object? saveError;
  final HandTileEntryRecord? savedEntry;
  final Completer<HandTileEntryRecord>? pendingSave;
  final Uri? signedPhotoUrl;
  final Object? photoUrlError;
  final Completer<Uri?>? pendingPhotoUrl;
  final requestedPhotoIds = <String>[];
  String? savedHandResultId;
  Map<String, dynamic>? savedTilesJson;
  int? savedCalculatedFanCount;
  String? savedCalculationVersion;

  @override
  Future<List<HandEvidenceReviewRecord>> listHandEvidenceReview(
    String eventId,
  ) async {
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return records;
  }

  @override
  Future<Uri?> createHandPhotoSignedUrl(HandPhotoRecord photo) async {
    requestedPhotoIds.add(photo.id);
    final thrown = photoUrlError;
    if (thrown != null) {
      throw thrown;
    }

    final pending = pendingPhotoUrl;
    if (pending != null) {
      return pending.future;
    }

    return signedPhotoUrl;
  }

  @override
  Future<HandTileEntryRecord> upsertHandTileEntry({
    required String handResultId,
    required Map<String, dynamic> tilesJson,
    required int? calculatedFanCount,
    required String calculationVersion,
  }) async {
    savedHandResultId = handResultId;
    savedTilesJson = tilesJson;
    savedCalculatedFanCount = calculatedFanCount;
    savedCalculationVersion = calculationVersion;
    final thrown = saveError;
    if (thrown != null) {
      throw thrown;
    }

    final pending = pendingSave;
    if (pending != null) {
      return pending.future;
    }

    final entry = savedEntry;
    if (entry != null) {
      return entry;
    }

    return _tileEntry(
      handResultId: handResultId,
      reviewStatus: HandTileReviewStatus.unreviewed,
      calculatedFanCount: calculatedFanCount,
    );
  }
}

HandEvidenceReviewRecord _reviewRecord({
  required String id,
  required String handResultId,
  required String clientPhotoId,
  required DateTime capturedAt,
  int? handNumber,
  String? tableLabel,
  String? winnerName,
  String? winType,
  int? declaredFanCount,
  String? seatWindTileId,
  String? roundWindTileId,
  HandTileEntryRecord? tileEntry,
}) {
  return HandEvidenceReviewRecord(
    handResultId: handResultId,
    handNumber: handNumber,
    tableLabel: tableLabel,
    winnerName: winnerName,
    winType: winType,
    declaredFanCount: declaredFanCount,
    seatWindTileId: seatWindTileId,
    roundWindTileId: roundWindTileId,
    tileEntry: tileEntry,
    photo: HandPhotoRecord(
      id: id,
      handResultId: handResultId,
      clientPhotoId: clientPhotoId,
      capturedAt: capturedAt,
      captureStatus: HandPhotoCaptureStatus.captured,
      uploadStatus: HandPhotoUploadStatus.uploaded,
      visibility: HandPhotoVisibility.hostAdminOnly,
      storageBucket: 'hand-photos',
      storagePath: 'events/evt_01/hands/$handResultId/$clientPhotoId.jpg',
    ),
  );
}

HandTileEntryRecord _tileEntry({
  required String handResultId,
  required HandTileReviewStatus reviewStatus,
  int? calculatedFanCount,
  int? declaredFanCount,
  Object? tilesJson,
}) {
  return HandTileEntryRecord(
    id: 'tile_entry_$handResultId',
    handResultId: handResultId,
    enteredAt: DateTime.utc(2026, 6, 25, 19),
    tilesJson: tilesJson ??
        const {
          'schemaVersion': 1,
          'tiles': [],
          'flowers': [],
          'winningTileKnown': false,
          'groups': [],
        },
    calculatedFanCount: calculatedFanCount,
    declaredFanCount: declaredFanCount,
    calculationVersion: 'hk_tile_review_v1',
    validationStatus: HandTileValidationStatus.valid,
    reviewStatus: reviewStatus,
  );
}

Future<void> _tapTile(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(OutlinedButton, label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _showSelectedTileCount(
  WidgetTester tester,
  int count, {
  bool settle = true,
}) async {
  final finder = find.text('Selected tiles ($count)');
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      -200,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
