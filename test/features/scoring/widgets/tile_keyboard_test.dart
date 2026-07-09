import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/widgets/tile_keyboard.dart';

void main() {
  Widget buildSubject({
    HandTileEntryDraft? draft,
    ValueChanged<String>? onAddTile,
    ValueChanged<String>? onRemoveTile,
    VoidCallback? onClear,
    ValueChanged<String>? onSetWinningTile,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TileKeyboard(
          draft: draft ?? HandTileEntryDraft(),
          onAddTile: onAddTile ?? (_) {},
          onRemoveTile: onRemoveTile ?? (_) {},
          onClear: onClear ?? () {},
          onSetWinningTile: onSetWinningTile ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders suits honors and flowers', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Dots'), findsOneWidget);
    expect(find.text('Bamboo'), findsOneWidget);
    expect(find.text('Honors'), findsOneWidget);
    expect(find.text('Flowers / Seasons'), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('9D'), findsOneWidget);
    expect(find.text('9B'), findsOneWidget);
    expect(find.text('East'), findsOneWidget);
    expect(find.text('Plum'), findsOneWidget);
    expect(find.text('梅 1'), findsOneWidget);
    expect(find.text('Orch'), findsOneWidget);
    expect(find.text('蘭 2'), findsOneWidget);
    expect(find.text('Chrys'), findsOneWidget);
    expect(find.text('菊 3'), findsOneWidget);
    expect(find.text('Bam'), findsOneWidget);
    expect(find.text('竹 4'), findsOneWidget);
    expect(find.text('Spr'), findsOneWidget);
    expect(find.text('春 1'), findsOneWidget);
    expect(find.text('Chrysanthemum 4'), findsNothing);
    expect(find.text('Bamboo 3'), findsNothing);
  });

  testWidgets('tile buttons use stable fixed constraints', (tester) async {
    await tester.pumpWidget(buildSubject());

    final oneManSize =
        tester.getSize(find.widgetWithText(OutlinedButton, '1M'));
    final eastSize =
        tester.getSize(find.widgetWithText(OutlinedButton, 'East'));

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Plum'));
    await tester.pumpAndSettle();
    final plumSize =
        tester.getSize(find.widgetWithText(OutlinedButton, 'Plum'));

    expect(oneManSize.width, 52);
    expect(oneManSize.height, 48);
    expect(eastSize.width, 52);
    expect(eastSize.height, 48);
    expect(plumSize.width, 72);
    expect(plumSize.height, 52);
  });

  testWidgets('selects and clears tiles', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(buildSubject(
      onAddTile: selected.add,
      onClear: selected.clear,
    ));

    await tester.tap(find.text('1M'));
    expect(selected, ['man_1']);

    await tester.tap(find.text('Clear'));

    expect(selected, isEmpty);
  });

  testWidgets('renders selected tray count', (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['man_1', 'east'],
        flowerTileIds: const ['plum_1'],
      ),
    ));

    expect(find.text('Selected (3)'), findsOneWidget);
  });

  testWidgets('selected tray keeps a fixed height as selected tiles change',
      (tester) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_1',
          'man_2',
          'man_3',
          'man_4',
          'dot_1',
          'dot_2',
          'dot_3',
          'dot_4',
          'bamboo_1',
          'bamboo_2',
          'east',
          'south',
        ],
      ),
    ));

    expect(find.byKey(TileKeyboard.selectedTrayScrollerKey), findsNothing);
    expect(find.byKey(TileKeyboard.selectedTrayKey), findsOneWidget);
    expect(find.byKey(TileKeyboard.tileListKey), findsOneWidget);

    final trayHeightBefore =
        tester.getSize(find.byKey(TileKeyboard.selectedTrayKey)).height;

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_1',
          'man_2',
          'man_3',
          'man_4',
          'dot_1',
          'dot_2',
          'dot_3',
          'dot_4',
          'bamboo_1',
          'bamboo_2',
          'east',
          'south',
          'red',
          'white',
        ],
      ),
    ));

    final trayHeightAfter =
        tester.getSize(find.byKey(TileKeyboard.selectedTrayKey)).height;
    expect(trayHeightAfter, trayHeightBefore);
    expect(find.byType(InputChip), findsNothing);
    expect(
      tester
          .getBottomRight(
            find.byKey(TileKeyboard.selectedTileKey('white', 13)),
          )
          .dy,
      lessThanOrEqualTo(
        tester.getBottomRight(find.byKey(TileKeyboard.selectedTrayKey)).dy,
      ),
    );
  });

  testWidgets('selected tray fits twenty four tiles in three fixed rows',
      (tester) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const selectedTileIds = [
      'man_1',
      'man_1',
      'man_1',
      'man_1',
      'man_2',
      'man_2',
      'man_2',
      'man_2',
      'man_3',
      'man_3',
      'man_3',
      'man_3',
      'man_4',
      'man_4',
      'man_4',
      'man_4',
      'dot_1',
      'dot_1',
      'dot_1',
      'dot_1',
      'dot_2',
      'dot_2',
      'dot_2',
      'dot_2',
    ];

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: selectedTileIds),
    ));

    expect(find.text('Selected (24)'), findsOneWidget);
    expect(
        tester.getSize(find.byKey(TileKeyboard.selectedTrayKey)).height, 124);
    expect(
      tester
          .getBottomRight(
            find.byKey(TileKeyboard.selectedTileKey('dot_2', 23)),
          )
          .dy,
      lessThanOrEqualTo(
        tester.getBottomRight(find.byKey(TileKeyboard.selectedTrayKey)).dy,
      ),
    );
  });

  testWidgets('honors render as winds row over colors row', (tester) async {
    await tester.pumpWidget(buildSubject());

    final eastTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'East'));
    final southTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'South'));
    final westTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'West'));
    final northTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'North'));
    final redTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'Red'));
    final greenTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'Green'));
    final whiteTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'White'));

    expect(southTop.dy, eastTop.dy);
    expect(westTop.dy, eastTop.dy);
    expect(northTop.dy, eastTop.dy);
    expect(redTop.dy, greaterThan(eastTop.dy));
    expect(greenTop.dy, redTop.dy);
    expect(whiteTop.dy, redTop.dy);
  });

  testWidgets('exhausted tile button is disabled', (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['east', 'east', 'east', 'east'],
      ),
    ));

    final eastButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'East'),
    );
    expect(eastButton.onPressed, isNull);
  });

  testWidgets('tapping selected tile removes it without a delete icon',
      (tester) async {
    final removed = <String>[];
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
      onRemoveTile: removed.add,
    ));

    expect(find.byType(InputChip), findsNothing);
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_1', 0)));

    expect(removed, ['man_1']);
  });

  testWidgets('tapping selected tile does not set winning tile',
      (tester) async {
    final winningTiles = <String>[];
    final removed = <String>[];
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
      onRemoveTile: removed.add,
      onSetWinningTile: winningTiles.add,
    ));

    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_1', 0)));

    expect(removed, ['man_1']);
    expect(winningTiles, isEmpty);
  });

  testWidgets('known winning tile selected tile has selected semantics',
      (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileId: 'man_1',
        winningTileKnown: true,
      ),
    ));

    final selectedTile = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(TileKeyboard.selectedTileKey('man_1', 0)),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(selectedTile.style?.side?.resolve({WidgetState.selected})?.width, 2);
  });
}
