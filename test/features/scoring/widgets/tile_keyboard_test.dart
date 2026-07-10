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
    VoidCallback? onClearWinningTile,
    double? keyboardWidth,
    double? keyboardHeight,
  }) {
    final keyboard = TileKeyboard(
      draft: draft ?? HandTileEntryDraft(),
      onAddTile: onAddTile ?? (_) {},
      onRemoveTile: onRemoveTile ?? (_) {},
      onClear: onClear ?? () {},
      onSetWinningTile: onSetWinningTile ?? (_) {},
      onClearWinningTile: onClearWinningTile ?? () {},
    );

    return MaterialApp(
      home: Scaffold(
        body: keyboardWidth == null && keyboardHeight == null
            ? keyboard
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: keyboardWidth ?? 390,
                  height: keyboardHeight,
                  child: keyboard,
                ),
              ),
      ),
    );
  }

  double selectedTileBorderWidth(
    WidgetTester tester,
    String tileId,
    int index,
  ) {
    final button = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(TileKeyboard.selectedTileKey(tileId, index)),
        matching: find.byType(OutlinedButton),
      ),
    );
    return button.style?.side?.resolve(const <WidgetState>{})?.width ?? 0;
  }

  List<int> winningBorderIndices(
    WidgetTester tester,
    String tileId,
    int count,
  ) =>
      [
        for (var index = 0; index < count; index += 1)
          if (selectedTileBorderWidth(tester, tileId, index) == 2) index,
      ];

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
      tester.getSize(find.byKey(TileKeyboard.selectedTrayKey)).height,
      156,
    );
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

  testWidgets('selected tray shows unknown winning tile by default',
      (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
    ));

    expect(find.text('Winning tile'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.byKey(TileKeyboard.setWinningTileModeKey), findsOneWidget);
  });

  testWidgets('set winning tile is disabled without selected tiles',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    final setButton = tester.widget<TextButton>(
      find.byKey(TileKeyboard.setWinningTileModeKey),
    );
    expect(setButton.onPressed, isNull);
  });

  testWidgets('set enters and cancel leaves winning tile mode', (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
    ));

    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    expect(find.text('Tap the winning tile below'), findsOneWidget);

    await tester.tap(find.byKey(TileKeyboard.cancelWinningTileModeKey));
    await tester.pump();
    expect(find.text('Tap the winning tile below'), findsNothing);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('change enters winning tile mode for a known tile',
      (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileId: 'man_1',
        winningTileKnown: true,
      ),
    ));

    await tester.tap(find.byKey(TileKeyboard.changeWinningTileKey));
    await tester.pump();

    expect(find.text('Tap the winning tile below'), findsOneWidget);
    expect(find.byKey(TileKeyboard.cancelWinningTileModeKey), findsOneWidget);
  });

  testWidgets('choosing mode sets instead of removing selected tile',
      (tester) async {
    final winningTiles = <String>[];
    final removedTiles = <String>[];
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
      onRemoveTile: removedTiles.add,
      onSetWinningTile: winningTiles.add,
    ));

    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_1', 0)));
    await tester.pump();

    expect(winningTiles, ['man_1']);
    expect(removedTiles, isEmpty);
    expect(find.text('Tap the winning tile below'), findsNothing);
  });

  testWidgets('known winning tile can be cleared to unknown', (tester) async {
    var clearCount = 0;
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileId: 'man_1',
        winningTileKnown: true,
      ),
      onClearWinningTile: () => clearCount += 1,
    ));

    await tester.tap(find.byKey(TileKeyboard.clearWinningTileKey));

    expect(clearCount, 1);
  });

  testWidgets('empty parent draft exits winning tile mode', (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    expect(find.text('Tap the winning tile below'), findsOneWidget);

    await tester.pumpWidget(buildSubject(draft: HandTileEntryDraft()));
    await tester.pump();

    expect(find.text('Tap the winning tile below'), findsNothing);
    final setButton = tester.widget<TextButton>(
      find.byKey(TileKeyboard.setWinningTileModeKey),
    );
    expect(setButton.onPressed, isNull);
  });

  testWidgets('shrunken tray scrolls every selected tile into reach',
      (tester) async {
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
    final winningTiles = <String>[];
    final removedTiles = <String>[];
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: selectedTileIds),
      onSetWinningTile: winningTiles.add,
      onRemoveTile: removedTiles.add,
      keyboardHeight: 180,
    ));

    expect(find.byKey(TileKeyboard.selectedTrayScrollerKey), findsOneWidget);
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();

    final lastTile = find.byKey(TileKeyboard.selectedTileKey('dot_2', 23));
    await tester.ensureVisible(lastTile);
    await tester.pumpAndSettle();
    await tester.tap(lastTile);

    expect(winningTiles, ['dot_2']);
    expect(removedTiles, isEmpty);
  });

  testWidgets(
      'compact 370 by 180 choose mode reaches the last tile with a drag',
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
    ];
    final winningTiles = <String>[];
    final removedTiles = <String>[];

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: selectedTileIds),
      onSetWinningTile: winningTiles.add,
      onRemoveTile: removedTiles.add,
      keyboardWidth: 370,
      keyboardHeight: 180,
    ));

    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.drag(
      find.byKey(TileKeyboard.selectedTileKey('man_1', 0)),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(TileKeyboard.selectedTileKey('dot_2', 21)),
    );
    await tester.pump();

    expect(winningTiles, ['dot_2']);
    expect(removedTiles, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(TileKeyboard.selectedTrayKey),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'compact 370 by 180 ordinary removal reaches the last tile with a drag',
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
    final winningTiles = <String>[];
    final removedTiles = <String>[];

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: selectedTileIds),
      onSetWinningTile: winningTiles.add,
      onRemoveTile: removedTiles.add,
      keyboardWidth: 370,
      keyboardHeight: 180,
    ));

    await tester.drag(
      find.byKey(TileKeyboard.selectedTileKey('man_1', 0)),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(TileKeyboard.selectedTileKey('dot_2', 23)),
    );
    await tester.pump();

    expect(removedTiles, ['dot_2']);
    expect(winningTiles, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(TileKeyboard.selectedTrayKey),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'choose-winning-tile mode reaches the last of twenty two tiles at 370 point keyboard width',
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
    ];
    final winningTiles = <String>[];
    final removedTiles = <String>[];

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: selectedTileIds),
      onSetWinningTile: winningTiles.add,
      onRemoveTile: removedTiles.add,
      keyboardWidth: 370,
      keyboardHeight: 640,
    ));

    expect(find.byKey(TileKeyboard.selectedTrayScrollerKey), findsNothing);

    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();

    final lastTile = find.byKey(TileKeyboard.selectedTileKey('dot_2', 21));
    await tester.ensureVisible(lastTile);
    await tester.pumpAndSettle();
    await tester.tap(lastTile);
    await tester.pump();

    expect(winningTiles, ['dot_2']);
    expect(removedTiles, isEmpty);
  });

  testWidgets(
      'ordinary removal reaches the last of twenty four tiles at 370 point keyboard width',
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
    final winningTiles = <String>[];
    final removedTiles = <String>[];

    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: selectedTileIds),
      onSetWinningTile: winningTiles.add,
      onRemoveTile: removedTiles.add,
      keyboardWidth: 370,
      keyboardHeight: 640,
    ));

    expect(find.byKey(TileKeyboard.selectedTrayScrollerKey), findsNothing);

    final lastTile = find.byKey(TileKeyboard.selectedTileKey('dot_2', 23));
    await tester.ensureVisible(lastTile);
    await tester.pumpAndSettle();
    await tester.tap(lastTile);
    await tester.pump();

    expect(removedTiles, ['dot_2']);
    expect(winningTiles, isEmpty);
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

  testWidgets('left aligns honors with the other tile sections',
      (tester) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject());

    final charactersLeft = tester.getTopLeft(find.text('Characters')).dx;
    final honorsLeft = tester.getTopLeft(find.text('Honors')).dx;
    final oneManLeft =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, '1M')).dx;
    final eastLeft =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'East')).dx;

    expect(honorsLeft, charactersLeft);
    expect(eastLeft, oneManLeft);
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

  testWidgets('disabled flower button grays glyph number and short name',
      (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        flowerTileIds: const ['chrysanthemum_3'],
      ),
    ));
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Chrys'));
    await tester.pumpAndSettle();

    final characterText = tester.widget<Text>(find.text('菊 3'));
    final shortNameText = tester.widget<Text>(find.text('Chrys'));

    expect(characterText.style?.color, isNotNull);
    expect(shortNameText.style?.color, characterText.style?.color);
  });

  testWidgets('hydrated flower aliases disable canonical styled buttons',
      (tester) async {
    const cases = [
      (
        alias: 'bamboo_flower_3',
        characterAndNumber: '菊 3',
        shortName: 'Chrys',
      ),
      (
        alias: 'chrysanthemum_4',
        characterAndNumber: '竹 4',
        shortName: 'Bam',
      ),
    ];

    for (final tileCase in cases) {
      await tester.pumpWidget(buildSubject(
        draft: HandTileEntryDraft(flowerTileIds: [tileCase.alias]),
      ));
      final buttonFinder =
          find.widgetWithText(OutlinedButton, tileCase.shortName);
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(buttonFinder);
      final disabledColor = Theme.of(
        tester.element(find.byType(TileKeyboard)),
      ).disabledColor;
      final characterText =
          tester.widget<Text>(find.text(tileCase.characterAndNumber));
      final shortNameText = tester.widget<Text>(find.text(tileCase.shortName));

      expect(button.onPressed, isNull, reason: tileCase.alias);
      expect(
        [characterText.style?.color, shortNameText.style?.color],
        [disabledColor, disabledColor],
        reason: tileCase.alias,
      );
    }
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

  testWidgets('choosing a duplicate highlights only the exact tapped copy',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
      ),
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 2)));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [2]);
  });

  testWidgets('hydrated duplicate winner highlights only the first copy',
      (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
        winningTileId: 'man_2',
        winningTileKnown: true,
      ),
    ));

    expect(winningBorderIndices(tester, 'man_2', 4), [0]);
  });

  testWidgets('clearing a duplicate winner removes its highlight',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
      ),
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 2)));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.clearWinningTileKey));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), isEmpty);
  });

  testWidgets('changing a duplicate winner moves the highlight',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
      ),
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 1)));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.changeWinningTileKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 3)));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [3]);
  });

  testWidgets('removing a duplicate keeps one winning occurrence',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
      ),
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 2)));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 3)));
    await tester.pump();

    expect(find.text('Selected (3)'), findsOneWidget);
    expect(winningBorderIndices(tester, 'man_2', 3), [1]);
  });

  testWidgets('rejected winning tile change preserves the prior highlight',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
        winningTileId: 'man_2',
        winningTileKnown: true,
      ),
      onSetWinningTile: (_) {},
    ));
    await tester.tap(find.byKey(TileKeyboard.changeWinningTileKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 3)));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [0]);
  });

  testWidgets(
      'rejected winning tile change does not commit after unrelated draft update',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
        winningTileId: 'man_2',
        winningTileKnown: true,
      ),
      onSetWinningTile: (_) {},
    ));
    await tester.tap(find.byKey(TileKeyboard.changeWinningTileKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 3)));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [0]);

    await tester.tap(find.text('3M'));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [0]);
  });

  testWidgets('rejected duplicate removal preserves the prior highlight',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
      ),
      onRemoveTile: (_) {},
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 2)));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 3)));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [2]);
  });

  testWidgets('rejected winning tile clear preserves the exact highlight',
      (tester) async {
    await tester.pumpWidget(_DuplicateWinningTileHost(
      initialDraft: HandTileEntryDraft(
        coreTileIds: const ['man_2', 'man_2', 'man_2', 'man_2'],
      ),
      onClearWinningTile: () {},
    ));
    await tester.tap(find.byKey(TileKeyboard.setWinningTileModeKey));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.selectedTileKey('man_2', 2)));
    await tester.pump();
    await tester.tap(find.byKey(TileKeyboard.clearWinningTileKey));
    await tester.pump();

    expect(winningBorderIndices(tester, 'man_2', 4), [2]);
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

class _DuplicateWinningTileHost extends StatefulWidget {
  const _DuplicateWinningTileHost({
    required this.initialDraft,
    this.onRemoveTile,
    this.onSetWinningTile,
    this.onClearWinningTile,
  });

  final HandTileEntryDraft initialDraft;
  final ValueChanged<String>? onRemoveTile;
  final ValueChanged<String>? onSetWinningTile;
  final VoidCallback? onClearWinningTile;

  @override
  State<_DuplicateWinningTileHost> createState() =>
      _DuplicateWinningTileHostState();
}

class _DuplicateWinningTileHostState extends State<_DuplicateWinningTileHost> {
  late HandTileEntryDraft draft = widget.initialDraft;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: TileKeyboard(
          draft: draft,
          onAddTile: (tileId) => setState(() => draft = draft.addTile(tileId)),
          onRemoveTile: widget.onRemoveTile ??
              (tileId) => setState(() => draft = draft.removeTile(tileId)),
          onClear: () => setState(() => draft = HandTileEntryDraft()),
          onSetWinningTile: widget.onSetWinningTile ??
              (tileId) => setState(() => draft = draft.setWinningTile(tileId)),
          onClearWinningTile: widget.onClearWinningTile ??
              () => setState(() => draft = draft.clearWinningTile()),
        ),
      ),
    );
  }
}
