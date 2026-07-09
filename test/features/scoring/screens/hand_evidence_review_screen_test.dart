import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';
import 'package:mosaic/features/scoring/screens/hand_evidence_review_screen.dart';
import 'package:mosaic/features/scoring/widgets/hand_photo_preview.dart';
import 'package:mosaic/features/scoring/widgets/tile_keyboard.dart';

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
    expect(find.text("Ben's winning hand"), findsNothing);
    expect(find.textContaining('Table A'), findsOneWidget);
    expect(find.textContaining('Ava'), findsOneWidget);
    expect(find.textContaining('Declared 3 fan'), findsOneWidget);
    expect(find.textContaining('Taken'), findsNothing);
    expect(find.text('Needs tiles'), findsNothing);
    expect(find.text('No tiles'), findsOneWidget);
    expect(find.text('Flagged'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Needs review'), findsNothing);
    expect(find.text('Unreviewed'), findsNothing);
    expect(find.text('Matched'), findsNothing);
    expect(find.text('Under-declared'), findsNothing);
    expect(find.text('Resolved'), findsNothing);
  });

  testWidgets('filters review queue by status tabs', (tester) async {
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
                winnerName: 'No Tile Ava',
              ),
              _reviewRecord(
                id: 'photo_02',
                handResultId: 'hand_02',
                clientPhotoId: 'client_photo_02',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 45),
                winnerName: 'Unreviewed Ben',
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
                winnerName: 'Flagged Cam',
                tileEntry: _tileEntry(
                  handResultId: 'hand_03',
                  reviewStatus: HandTileReviewStatus.flagged,
                ),
              ),
              _reviewRecord(
                id: 'photo_04',
                handResultId: 'hand_04',
                clientPhotoId: 'client_photo_04',
                capturedAt: DateTime.utc(2026, 6, 25, 19, 15),
                winnerName: 'Matched Dee',
                tileEntry: _tileEntry(
                  handResultId: 'hand_04',
                  reviewStatus: HandTileReviewStatus.matched,
                ),
              ),
              _reviewRecord(
                id: 'photo_05',
                handResultId: 'hand_05',
                clientPhotoId: 'client_photo_05',
                capturedAt: DateTime.utc(2026, 6, 25, 19, 30),
                winnerName: 'Under Eli',
                tileEntry: _tileEntry(
                  handResultId: 'hand_05',
                  reviewStatus: HandTileReviewStatus.underDeclared,
                ),
              ),
              _reviewRecord(
                id: 'photo_06',
                handResultId: 'hand_06',
                clientPhotoId: 'client_photo_06',
                capturedAt: DateTime.utc(2026, 6, 25, 19, 45),
                winnerName: 'Resolved Fran',
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

    expect(find.text('No tiles'), findsOneWidget);
    expect(find.text('Flagged'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text("No Tile Ava's winning hand"), findsOneWidget);
    expect(find.text("Unreviewed Ben's winning hand"), findsNothing);
    expect(find.text("Flagged Cam's winning hand"), findsNothing);
    expect(find.text("Under Eli's winning hand"), findsNothing);

    await _tapStatusTab(tester, 'Flagged');
    await tester.pumpAndSettle();

    expect(find.text("Unreviewed Ben's winning hand"), findsOneWidget);
    expect(find.text("No Tile Ava's winning hand"), findsNothing);
    expect(find.text("Flagged Cam's winning hand"), findsOneWidget);
    expect(find.text("Under Eli's winning hand"), findsNothing);

    await _tapStatusTab(tester, 'Done');
    await tester.pumpAndSettle();

    expect(find.text("Unreviewed Ben's winning hand"), findsNothing);
    expect(find.text("No Tile Ava's winning hand"), findsNothing);
    expect(find.text("Flagged Cam's winning hand"), findsNothing);
    expect(find.text("Matched Dee's winning hand"), findsOneWidget);
    expect(find.text("Under Eli's winning hand"), findsOneWidget);
    expect(find.text("Resolved Fran's winning hand"), findsOneWidget);
    expect(find.text('Matched'), findsOneWidget);
    expect(find.text('Under'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);

    await _tapStatusTab(tester, 'No tiles');
    await tester.pumpAndSettle();

    expect(find.text("No Tile Ava's winning hand"), findsOneWidget);
    expect(find.text("Flagged Cam's winning hand"), findsNothing);
  });

  testWidgets('does not show needs tiles chip for normal missing tile entries',
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
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs tiles'), findsNothing);

    await tester.tap(find.text('Hand 7'));
    await tester.pumpAndSettle();

    expect(find.text('Needs tiles'), findsNothing);
    expect(find.text('Review Hand 7'), findsNothing);
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

    expect(find.text('Photo 1'), findsOneWidget);
    expect(find.textContaining('11:30 AM'), findsOneWidget);
    expect(find.textContaining('Taken'), findsNothing);
    expect(find.text('Captured winning hand'), findsNothing);
    expect(find.textContaining(handResultId), findsNothing);
    expect(find.textContaining(clientPhotoId), findsNothing);
  });

  testWidgets('uses event hand ledger labels when review metadata is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEvidenceReviewScreen(
          eventId: 'evt_01',
          mosaicProfileRepository: _FakeMosaicProfileRepository(
            records: [
              _reviewRecord(
                id: 'photo_01',
                handResultId: 'hand_07',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
            ],
          ),
          handLedgerLoader: (_) async => [
            _ledgerEntry(
              handId: 'hand_07',
              tableLabel: '5',
              sessionNumberForTable: 2,
              handNumber: 7,
              fanCount: 5,
              winType: HandWinType.selfDraw,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Table 5 · Session 2 · Hand 7'),
      findsOneWidget,
    );
    expect(find.textContaining('South Player'), findsOneWidget);
    expect(find.textContaining('Winner'), findsNothing);
    expect(find.textContaining('5 fan self-draw'), findsOneWidget);
    expect(find.textContaining('11:30 AM'), findsOneWidget);
    expect(find.textContaining('Taken'), findsNothing);
    expect(find.text('Photo 1'), findsNothing);
  });

  testWidgets(
      'uses table session hand title on mobile editor when ledger exists',
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
                handResultId: 'hand_07',
                clientPhotoId: 'client_photo_01',
                capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
              ),
            ],
          ),
          handLedgerLoader: (_) async => [
            _ledgerEntry(
              handId: 'hand_07',
              tableLabel: '5',
              sessionNumberForTable: 2,
              handNumber: 7,
              fanCount: 5,
              winType: HandWinType.selfDraw,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Table 5 · Session 2 · Hand 7'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('glassTitlePill-Table 5 · Session 2 · Hand 7')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('glassTitlePill-Photo 1')), findsNothing);
  });

  testWidgets('uses separate queue and editor pages on mobile', (tester) async {
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
              ),
              _reviewRecord(
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

    expect(find.text('Photo 1'), findsOneWidget);
    expect(find.text('Photo 2'), findsOneWidget);
    expect(find.text('Select a hand to review.'), findsNothing);
    expect(find.text('Save Tiles'), findsNothing);

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Incomplete Hand'), findsOneWidget);
    expect(find.text('Selected (0)'), findsOneWidget);
  });

  testWidgets('returns to mobile queue after successful save', (tester) async {
    tester.view.physicalSize = const Size(390, 840);
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
          handNumber: 1,
          tableLabel: 'Table 2',
          declaredFanCount: 4,
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

    await _showAllHands(tester);
    await tester.tap(find.text('Hand 1'));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedHandResultId, 'hand_01');
    expect(find.text('Hand Review'), findsOneWidget);
    expect(find.text('Save Tiles'), findsNothing);
    expect(find.text('Hand 1'), findsOneWidget);
  });

  testWidgets('opens editor when tapping queue row', (tester) async {
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

    expect(find.text('Incomplete Hand'), findsOneWidget);
    expect(find.text('Selected (0)'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(HandPhotoPreview.previewKey)).height,
      128,
    );
    final previewTopBefore =
        tester.getTopLeft(find.byKey(HandPhotoPreview.previewKey)).dy;
    expect(
      tester.getCenter(find.text('Incomplete Hand')).dy,
      greaterThan(tester.getTopLeft(find.byKey(TileKeyboard.tileListKey)).dy),
    );

    final trayTopBefore =
        tester.getTopLeft(find.byKey(TileKeyboard.selectedTrayKey)).dy;
    await tester.drag(
        find.byKey(TileKeyboard.tileListKey), const Offset(0, -120));
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(TileKeyboard.selectedTrayKey)).dy,
        trayTopBefore);
    expect(
      tester.getTopLeft(find.byKey(HandPhotoPreview.previewKey)).dy,
      previewTopBefore,
    );
    expect(find.text('Characters'), findsOneWidget);
  });

  testWidgets('keeps calculated desktop photo height instead of mobile 128',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
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
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(HandPhotoPreview.previewKey)).height,
      289.68,
    );
  });

  testWidgets('disables save while hand is incomplete', (tester) async {
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
                declaredFanCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Incomplete Hand'), findsOneWidget);
    expect(find.text('Incomplete hand'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);
  });

  testWidgets('disables save when 14 core tiles are invalid', (tester) async {
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
                declaredFanCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    for (final label in [
      '1M',
      '1M',
      '1M',
      '2M',
      '2M',
      '2M',
      '4M',
      '5M',
      '7M',
      '1D',
      '2D',
      '4D',
      'East',
      'South',
    ]) {
      await _tapTile(tester, label);
    }

    expect(find.text('Invalid Hand'), findsOneWidget);
    expect(find.text('Invalid tile grouping'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);
  });

  testWidgets('enables save when 14 core tiles form a valid hand',
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
                declaredFanCount: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);

    expect(find.text('Save Tiles'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNotNull);
  });

  testWidgets('shows special hands as saveable without invalid grouping',
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
                declaredFanCount: 13,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    await _enterThirteenOrphans(tester);

    expect(find.text('Thirteen Orphans'), findsOneWidget);
    expect(find.text('Invalid tile grouping'), findsNothing);
    expect(find.text('Save Tiles'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNotNull);
  });

  testWidgets('shows declaration and fan breakdown in tile editor',
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
                winnerName: 'Ava',
                declaredFanCount: 3,
                winType: 'self_draw',
                winBonuses: const [HandWinBonus.moonUnderTheSea],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ava's winning hand"));
    await tester.pumpAndSettle();

    expect(find.text('Declared 3 fan self-draw'), findsOneWidget);
    expect(find.text('Self-Pick'), findsOneWidget);
    expect(find.text('Moon Under the Sea'), findsOneWidget);
    expect(find.text('+1'), findsNWidgets(2));
    expect(find.text('Incomplete hand'), findsOneWidget);
  });

  testWidgets('final review shows declared-null discard context',
      (tester) async {
    await _pumpWinContextEditor(
      tester,
      winType: 'discard',
    );

    expect(find.text('Declared fan not recorded'), findsOneWidget);
    expect(find.text('Discard win'), findsOneWidget);
  });

  testWidgets('final review shows declared-null self-draw context and fan',
      (tester) async {
    await _pumpWinContextEditor(
      tester,
      winType: 'self_draw',
    );

    expect(find.text('Declared fan not recorded'), findsOneWidget);
    expect(find.text('Self-Pick'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('final review shows known empty win bonuses', (tester) async {
    await _pumpWinContextEditor(
      tester,
      winBonuses: const [],
    );

    expect(find.text('Win bonuses: None'), findsOneWidget);
    expect(find.text('Win bonuses not recorded'), findsNothing);
  });

  testWidgets('final review shows null win bonuses as not recorded',
      (tester) async {
    await _pumpWinContextEditor(
      tester,
      winBonuses: null,
    );

    expect(find.text('Win bonuses not recorded'), findsOneWidget);
    expect(find.text('Win bonuses: None'), findsNothing);
  });

  testWidgets('final review keeps non-empty logged win bonuses visible',
      (tester) async {
    await _pumpWinContextEditor(
      tester,
      winBonuses: const [HandWinBonus.moonUnderTheSea],
    );

    expect(find.text('Moon Under the Sea'), findsOneWidget);
    expect(find.text('Win bonuses not recorded'), findsNothing);
    expect(find.text('Win bonuses: None'), findsNothing);
  });

  testWidgets('keeps logged win bonuses visible after saving tiles',
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
                winnerName: 'Ava',
                winBonuses: const [HandWinBonus.moonUnderTheSea],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ava's winning hand"));
    await tester.pumpAndSettle();
    expect(find.text('Moon Under the Sea'), findsOneWidget);
    expect(find.text('Moon Under the Sea +1F'), findsNothing);

    await _enterValidHand(tester);
    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(find.text('Moon Under the Sea'), findsOneWidget);
    expect(find.text('Moon Under the Sea +1F'), findsNothing);
    expect(find.text('Win bonuses not recorded'), findsNothing);
  });

  testWidgets('shows not recorded for historical unknown win bonuses',
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
                winnerName: 'Ava',
                winBonuses: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ava's winning hand"));
    await tester.pumpAndSettle();

    expect(find.text('Declared fan not recorded'), findsOneWidget);
    expect(find.text('Win bonuses not recorded'), findsOneWidget);
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
    expect(find.text('Incomplete Hand'), findsOneWidget);
    expect(find.text('Selected (0)'), findsOneWidget);
  });

  testWidgets('keeps compact wide editor usable with long metadata',
      (tester) async {
    tester.view.physicalSize = const Size(800, 480);
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
    expect(find.text('Incomplete Hand'), findsOneWidget);
    expect(find.text('Selected (0)'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(HandPhotoPreview.previewKey)).height,
      132,
    );
  });

  testWidgets('hydrates existing valid tile entry without creating changes',
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
              'tiles': [
                'man_1',
                'man_2',
                'man_3',
                'dot_4',
                'dot_5',
                'dot_6',
                'bamboo_1',
                'bamboo_2',
                'bamboo_3',
                'east',
                'east',
                'east',
                'south',
                'south',
              ],
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Selected (15)'), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('man_1', 0)), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('man_2', 1)), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('man_3', 2)), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('plum_1', 14)), findsOneWidget);

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);
    expect(repository.savedTilesJson, isNull);
  });

  testWidgets('saved valid hand enables save only for semantic changes',
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
            tilesJson: _validSavedHandTilesJson,
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
    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);

    await _tapTile(tester, 'Plum');

    expect(find.text('Save Tiles'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNotNull);
    final staleSave = _lastFilledButton(tester).onPressed;

    await tester.tap(
      find.byKey(TileKeyboard.selectedTileKey('plum_1', 14)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);

    await tester.tap(
      find.byKey(TileKeyboard.selectedTileKey('man_1', 0)),
    );
    await tester.pumpAndSettle();
    await _tapTile(tester, '1M');

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);

    staleSave?.call();
    await tester.pumpAndSettle();
    expect(repository.savedTilesJson, isNull);
  });

  testWidgets('shows saved confirmation after successful tile save',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);

    expect(find.text('Save Tiles'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedTilesJson?['tiles'], [
      'man_1',
      'man_2',
      'man_3',
      'dot_4',
      'dot_5',
      'dot_6',
      'bamboo_1',
      'bamboo_2',
      'bamboo_3',
      'east',
      'east',
      'east',
      'south',
      'south',
    ]);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Save Tiles'), findsNothing);
    expect(_lastFilledButton(tester).onPressed, isNull);

    await _tapTile(tester, 'Plum');

    expect(find.text('Save Tiles'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('hydrates valid legacy array tile entry without creating changes',
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
            tilesJson: const [
              'man_1',
              'man_2',
              'man_3',
              'dot_4',
              'dot_5',
              'dot_6',
              'bamboo_1',
              'bamboo_2',
              'bamboo_3',
              'east',
              'east',
              'east',
              'south',
              'south',
            ],
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Selected (14)'), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('man_1', 0)), findsOneWidget);
    expect(find.byKey(TileKeyboard.selectedTileKey('east', 9)), findsOneWidget);

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);
    expect(repository.savedTilesJson, isNull);
  });

  testWidgets('splits valid legacy array flowers without creating changes',
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
            tilesJson: const [
              'man_1',
              'man_2',
              'man_3',
              'dot_4',
              'dot_5',
              'dot_6',
              'bamboo_1',
              'bamboo_2',
              'bamboo_3',
              'east',
              'east',
              'east',
              'south',
              'south',
              'plum_1',
            ],
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Selected (15)'), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('man_1', 0)), findsOneWidget);
    expect(
        find.byKey(TileKeyboard.selectedTileKey('plum_1', 14)), findsOneWidget);

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);
    expect(repository.savedTilesJson, isNull);
  });

  _testWidgetsWithImageHttpClient(
      'requests and renders signed hand photo when row is selected',
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
    await _waitForPhotoReady(tester);

    expect(repository.requestedPhotoIds, ['photo_01']);
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Open'), findsNothing);
    expect(find.byKey(const Key('hand-photo-preview')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, 'https://example.com/photo.jpg');
  });

  testWidgets('waits for signed photo response to decode before controls show',
      (tester) async {
    final pendingResponse = Completer<HttpClientResponse>();
    debugNetworkImageHttpClientProvider = () => _TestImageHttpClient(
          response: pendingResponse.future,
        );
    try {
      final repository = _FakeMosaicProfileRepository(
        signedPhotoUrl: Uri.parse('https://example.com/delayed-photo.jpg'),
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
      await _showAllHands(tester);
      await tester.tap(find.text('Photo 1'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Loading photo'), findsOneWidget);
      expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
      expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);

      pendingResponse.complete(_TestImageHttpClientResponse());
      await _waitForPhotoReady(tester);

      expect(find.text('Loading photo'), findsNothing);
      expect(find.byKey(HandPhotoPreview.recenterKey), findsOneWidget);
      expect(find.byKey(HandPhotoPreview.expandKey), findsOneWidget);
    } finally {
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });

  _testWidgetsWithImageHttpClient(
      'saves reviewed photo rotation with tile entry', (tester) async {
    final repository = _FakeMosaicProfileRepository(
      signedPhotoUrl: Uri.parse('https://example.com/photo.jpg'),
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await _waitForPhotoReady(tester);
    expect(find.text('Open photo'), findsNothing);
    expect(find.text('Open'), findsNothing);
    await tester.tap(find.byKey(const Key('hand-photo-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate right'));
    await tester.pumpAndSettle();
    await _tapStatusTab(tester, 'Done');
    await tester.pumpAndSettle();

    await _enterValidHand(tester);
    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedTilesJson?['photoRotationQuarterTurns'], 1);
  });

  _testWidgetsWithImageHttpClient(
      'full-screen Reset restores transform and rotation', (tester) async {
    final repository = _FakeMosaicProfileRepository(
      signedPhotoUrl: Uri.parse('https://example.com/photo.jpg'),
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          tileEntry: _tileEntry(
            handResultId: 'hand_01',
            reviewStatus: HandTileReviewStatus.unreviewed,
            tilesJson: _validSavedHandTilesJson,
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
    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await _waitForPhotoReady(tester);
    await tester.tap(find.byKey(HandPhotoPreview.expandKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate right'));
    await tester.pump();

    final viewerFinder = find.byType(InteractiveViewer);
    expect(viewerFinder, findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    viewer.transformationController!.value = Matrix4.identity()
      ..scaleByDouble(2.0, 2.0, 2.0, 1.0);
    await tester.pump();
    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();

    expect(
      viewer.transformationController!.value.storage,
      orderedEquals(Matrix4.identity().storage),
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('No Changes'), findsOneWidget);
  });

  testWidgets('clear disables save for an existing saved tile entry',
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
              'tiles': [
                'man_1',
                'man_2',
                'man_3',
                'dot_4',
                'dot_5',
                'dot_6',
                'bamboo_1',
                'bamboo_2',
                'bamboo_3',
                'east',
                'east',
                'east',
                'south',
                'south',
              ],
              'flowers': [],
              'winningTileKnown': false,
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('No Changes'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Incomplete Hand'), findsOneWidget);
    expect(find.text('Selected (0)'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNull);
    expect(repository.savedTilesJson, isNull);
  });

  _testWidgetsWithImageHttpClient(
      're-entering a valid hand after clear keeps reviewed photo rotation',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      signedPhotoUrl: Uri.parse('https://example.com/photo.jpg'),
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
              'tiles': ['man_1'],
              'flowers': [],
              'winningTileKnown': false,
              'photoRotationQuarterTurns': 0,
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

    await _showAllHands(tester);
    await tester.tap(find.text('Photo 1'));
    await _waitForPhotoReady(tester);
    await tester.tap(find.byKey(const Key('hand-photo-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate right'));
    await tester.pumpAndSettle();
    await _tapStatusTab(tester, 'Done');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);
    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedTilesJson?['tiles'], hasLength(14));
    expect(repository.savedTilesJson?['photoRotationQuarterTurns'], 1);
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

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(
      find.text('The captured photo could not be opened.'),
      findsOneWidget,
    );
    expect(find.text('client_photo_01'), findsNothing);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);
  });

  _testWidgetsWithImageHttpClient(
      'keeps tile entry usable while photo URL is pending', (tester) async {
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

    await tester.tap(find.text('Photo 1'));
    await tester.pump();

    expect(find.text('Loading photo'), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);
    await _tapTile(tester, '1M', settle: false);

    await _showSelectedTileCount(tester, 1, settle: false);
    expect(find.text('Selected (1)'), findsOneWidget);

    pendingPhotoUrl.complete(Uri.parse('https://example.com/photo.jpg'));
    await _waitForPhotoReady(tester);

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

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Photo could not be loaded'), findsOneWidget);
    expect(find.textContaining('signed URL denied'), findsOneWidget);
    expect(find.byKey(HandPhotoPreview.recenterKey), findsNothing);
    expect(find.byKey(HandPhotoPreview.expandKey), findsNothing);
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
      'Plum',
    ]) {
      await _tapTile(tester, label);
    }

    expect(find.text('Seat Flower / Season'), findsWidgets);
    expect(find.text('Seat Wind'), findsOneWidget);
    expect(find.text('Round Wind'), findsOneWidget);
    expect(find.text('Red Dragon'), findsOneWidget);

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
    expect(repository.savedReviewStatus, HandTileReviewStatus.underDeclared);
    expect(repository.savedCalculationVersion, handTileCalculationVersion);
    await _tapStatusTab(tester, 'Done');
    await tester.pumpAndSettle();

    expect(find.text("Ava's winning hand"), findsOneWidget);
    expect(find.text('Under'), findsOneWidget);
  });

  testWidgets('saves historical unknown win bonus mismatch as unreviewed',
      (tester) async {
    final repository = _FakeMosaicProfileRepository(
      records: [
        _reviewRecord(
          id: 'photo_01',
          handResultId: 'hand_01',
          clientPhotoId: 'client_photo_01',
          capturedAt: DateTime.utc(2026, 6, 25, 18, 30),
          winnerName: 'Ava',
          declaredFanCount: 2,
          winBonuses: null,
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

    await tester.tap(find.text("Ava's winning hand"));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);
    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(repository.savedCalculatedFanCount, 3);
    expect(repository.savedReviewStatus, HandTileReviewStatus.unreviewed);
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

    await tester.tap(find.text('Photo 1'));
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

    expect(repository.savedCalculatedFanCount, 2);
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

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);
    await _showSelectedTileCount(tester, 14);

    await tester.tap(find.text('Save Tiles'));
    await tester.pump();

    await _tapTile(tester, '2M', settle: false);
    await _showSelectedTileCount(tester, 14, settle: false);
    expect(find.text('Selected (14)'), findsOneWidget);

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
    await _enterValidHand(tester);
    await _showSelectedTileCount(tester, 14);

    await tester.tap(find.text('Save Tiles'));
    await tester.pump();

    await tester.tap(find.text('Hand 2'));
    await tester.pump();

    expect(find.text('Selected (14)'), findsOneWidget);

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

    await tester.tap(find.text('Photo 1'));
    await tester.pumpAndSettle();
    await _enterValidHand(tester);
    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to save tiles.'), findsOneWidget);
    expect(find.textContaining('save denied'), findsOneWidget);
    expect(find.text('Photo 1'), findsWidgets);
    expect(find.text('Save Tiles'), findsOneWidget);
    expect(_lastFilledButton(tester).onPressed, isNotNull);
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
    await _enterValidHand(tester);
    await _showSelectedTileCount(tester, 14);
    expect(find.text('Selected (14)'), findsOneWidget);

    await tester.tap(find.text('Save Tiles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to save tiles.'), findsOneWidget);

    await tester.tap(find.text('Hand 2'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to save tiles.'), findsNothing);
    await _showSelectedTileCount(tester, 0);
    expect(find.text('Selected (0)'), findsOneWidget);
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
  HandTileReviewStatus? savedReviewStatus;
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
    required HandTileReviewStatus reviewStatus,
    required String calculationVersion,
  }) async {
    savedHandResultId = handResultId;
    savedTilesJson = tilesJson;
    savedCalculatedFanCount = calculatedFanCount;
    savedReviewStatus = reviewStatus;
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
      reviewStatus: reviewStatus,
      calculatedFanCount: calculatedFanCount,
    );
  }
}

EventHandLedgerEntry _ledgerEntry({
  required String handId,
  required String tableLabel,
  required int sessionNumberForTable,
  required int handNumber,
  required int fanCount,
  required HandWinType winType,
}) {
  return EventHandLedgerEntry(
    eventId: 'evt_01',
    tableId: 'table_01',
    tableLabel: tableLabel,
    sessionId: 'session_01',
    sessionNumberForTable: sessionNumberForTable,
    handId: handId,
    handNumber: handNumber,
    enteredAt: DateTime.utc(2026, 6, 25, 18, 25),
    resultType: HandResultType.win,
    status: HandResultStatus.recorded,
    winType: winType,
    fanCount: fanCount,
    hasSettlements: true,
    cells: const [
      EventHandLedgerCell(
        wind: SeatWind.east,
        seatIndex: 0,
        eventGuestId: 'guest_east',
        displayName: 'East Player',
        pointsDelta: 0,
      ),
      EventHandLedgerCell(
        wind: SeatWind.south,
        seatIndex: 1,
        eventGuestId: 'guest_south',
        displayName: 'South Player',
        pointsDelta: 48,
      ),
      EventHandLedgerCell(
        wind: SeatWind.west,
        seatIndex: 2,
        eventGuestId: 'guest_west',
        displayName: 'West Player',
        pointsDelta: -24,
      ),
      EventHandLedgerCell(
        wind: SeatWind.north,
        seatIndex: 3,
        eventGuestId: 'guest_north',
        displayName: 'North Player',
        pointsDelta: -24,
      ),
    ],
  );
}

const _validSavedHandTilesJson = {
  'schemaVersion': 1,
  'tiles': [
    'man_1',
    'man_2',
    'man_3',
    'dot_4',
    'dot_5',
    'dot_6',
    'bamboo_1',
    'bamboo_2',
    'bamboo_3',
    'east',
    'east',
    'east',
    'south',
    'south',
  ],
  'flowers': <String>[],
  'winningTileKnown': false,
  'photoRotationQuarterTurns': 0,
  'groups': <Object>[],
};

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
  List<HandWinBonus>? winBonuses = const [],
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
    winBonuses: winBonuses,
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

Future<void> _tapTile(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  Future<void> pumpAfterAction() {
    return settle ? tester.pumpAndSettle() : tester.pump();
  }

  final scrollTarget = find.byKey(TileKeyboard.tileListKey);
  final finder = scrollTarget.evaluate().isEmpty
      ? find.widgetWithText(OutlinedButton, label)
      : find.descendant(
          of: scrollTarget,
          matching: find.widgetWithText(OutlinedButton, label),
        );
  if (finder.evaluate().isEmpty && scrollTarget.evaluate().isNotEmpty) {
    for (var attempt = 0; attempt < 4; attempt += 1) {
      await tester.drag(scrollTarget, const Offset(0, 320));
      await pumpAfterAction();
    }
  }
  for (var attempt = 0;
      attempt < 8 && finder.evaluate().isEmpty;
      attempt += 1) {
    if (scrollTarget.evaluate().isNotEmpty) {
      await tester.drag(scrollTarget, const Offset(0, -260));
    } else {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
    }
    await pumpAfterAction();
  }
  expect(finder, findsOneWidget,
      reason: 'Could not find tile button "$label".');
  await tester.ensureVisible(finder);
  await pumpAfterAction();
  await tester.tap(finder);
  await pumpAfterAction();
}

Future<void> _enterValidHand(WidgetTester tester) async {
  await _enterTileFixture(tester, [
    '1M',
    '2M',
    '3M',
    '4D',
    '5D',
    '6D',
    '1B',
    '2B',
    '3B',
    'East',
    'East',
    'East',
    'South',
    'South',
  ]);
}

Future<void> _enterThirteenOrphans(WidgetTester tester) async {
  await _enterTileFixture(tester, [
    '1M',
    '9M',
    '1D',
    '9D',
    '1B',
    '9B',
    'East',
    'South',
    'West',
    'North',
    'Red',
    'Green',
    'White',
    'East',
  ]);
}

Future<void> _enterTileFixture(
  WidgetTester tester,
  List<String> labels,
) async {
  final tileList = find.byKey(TileKeyboard.tileListKey);
  final callbacks = <String, VoidCallback>{};
  for (final label in labels.toSet()) {
    final button = tester.widget<OutlinedButton>(
      find.descendant(
        of: tileList,
        matching: find.widgetWithText(OutlinedButton, label),
      ),
    );
    callbacks[label] = button.onPressed!;
  }
  for (final label in labels) {
    callbacks[label]!();
  }
  await tester.pumpAndSettle();
}

Future<void> _showAllHands(WidgetTester tester) async {
  await _tapStatusTab(tester, 'All');
}

Future<void> _pumpWinContextEditor(
  WidgetTester tester, {
  String? winType,
  int? declaredFanCount,
  List<HandWinBonus>? winBonuses = const [],
}) async {
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
              winnerName: 'Ava',
              winType: winType,
              declaredFanCount: declaredFanCount,
              winBonuses: winBonuses,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text("Ava's winning hand"));
  await tester.pumpAndSettle();
}

Future<void> _waitForPhotoReady(WidgetTester tester) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byKey(HandPhotoPreview.recenterKey).evaluate().isNotEmpty) {
      return;
    }
  }
  expect(find.byKey(HandPhotoPreview.recenterKey), findsOneWidget);
}

FilledButton _lastFilledButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.byType(FilledButton).last);
}

Future<void> _tapStatusTab(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _showSelectedTileCount(
  WidgetTester tester,
  int count, {
  bool settle = true,
}) async {
  final finder = find.text('Selected ($count)');
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

void _testWidgetsWithImageHttpClient(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (tester) async {
    debugNetworkImageHttpClientProvider = _TestImageHttpClient.new;
    try {
      await callback(tester);
    } finally {
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });
}

class _TestImageHttpClient implements HttpClient {
  _TestImageHttpClient({Future<HttpClientResponse>? response})
      : _response = response ?? Future.value(_TestImageHttpClientResponse());

  final Future<HttpClientResponse> _response;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _TestImageHttpClientRequest(_response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestImageHttpClientRequest implements HttpClientRequest {
  _TestImageHttpClientRequest(this.response);

  final Future<HttpClientResponse> response;

  @override
  Future<HttpClientResponse> close() => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestImageHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  static final _bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
