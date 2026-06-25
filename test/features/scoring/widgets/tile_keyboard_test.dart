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
    expect(find.text('Plum 1'), findsOneWidget);
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

    expect(find.text('Selected tiles (3)'), findsOneWidget);
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

  testWidgets('selected chip delete removes tile', (tester) async {
    final removed = <String>[];
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
      onRemoveTile: removed.add,
    ));

    tester
        .widget<InputChip>(find.widgetWithText(InputChip, '1M'))
        .onDeleted
        ?.call();

    expect(removed, ['man_1']);
  });

  testWidgets('selected chip tap sets winning tile', (tester) async {
    final winningTiles = <String>[];
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(coreTileIds: const ['man_1']),
      onSetWinningTile: winningTiles.add,
    ));

    await tester.tap(find.widgetWithText(InputChip, '1M'));

    expect(winningTiles, ['man_1']);
  });

  testWidgets('known winning tile chip is selected', (tester) async {
    await tester.pumpWidget(buildSubject(
      draft: HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileId: 'man_1',
        winningTileKnown: true,
      ),
    ));

    final chip = tester.widget<InputChip>(
      find.widgetWithText(InputChip, '1M'),
    );
    expect(chip.selected, isTrue);
  });
}
