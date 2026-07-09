import 'package:flutter/material.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';

class TileKeyboard extends StatelessWidget {
  const TileKeyboard({
    super.key,
    required this.draft,
    required this.onAddTile,
    required this.onRemoveTile,
    required this.onClear,
    required this.onSetWinningTile,
  });

  static const selectedTrayScrollerKey =
      Key('tileKeyboardSelectedTrayScroller');
  static const selectedTrayKey = Key('tileKeyboardSelectedTray');
  static const tileListKey = Key('tileKeyboardTileList');
  static Key selectedTileKey(String tileId, int index) =>
      ValueKey('tileKeyboardSelectedTile.$index.$tileId');

  final HandTileEntryDraft draft;
  final ValueChanged<String> onAddTile;
  final ValueChanged<String> onRemoveTile;
  final VoidCallback onClear;
  final ValueChanged<String> onSetWinningTile;

  @override
  Widget build(BuildContext context) {
    final tray = _SelectedTileTray(
      draft: draft,
      onClear: onClear,
      onRemoveTile: onRemoveTile,
    );
    final sections = [
      _TileSection(
        title: 'Characters',
        tiles: manTiles,
        draft: draft,
        onAddTile: onAddTile,
      ),
      _TileSection(
        title: 'Dots',
        tiles: dotTiles,
        draft: draft,
        onAddTile: onAddTile,
      ),
      _TileSection(
        title: 'Bamboo',
        tiles: bambooTiles,
        draft: draft,
        onAddTile: onAddTile,
      ),
      _TileSection(
        title: 'Honors',
        tiles: honorTiles,
        draft: draft,
        onAddTile: onAddTile,
        layout: _TileSectionLayout.honorRows,
      ),
      _TileSection(
        title: 'Flowers / Seasons',
        tiles: flowerSeasonTiles,
        draft: draft,
        onAddTile: onAddTile,
        layout: _TileSectionLayout.bonusGrid,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 260) {
          return ListView(
            key: tileListKey,
            padding: EdgeInsets.zero,
            children: [
              tray,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(children: sections),
              ),
            ],
          );
        }

        return Column(
          children: [
            tray,
            Expanded(
              child: ListView(
                key: tileListKey,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: sections,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectedTileTray extends StatelessWidget {
  const _SelectedTileTray({
    required this.draft,
    required this.onClear,
    required this.onRemoveTile,
  });

  final HandTileEntryDraft draft;
  final VoidCallback onClear;
  final ValueChanged<String> onRemoveTile;

  static const _height = 124.0;
  static const _tileSize = Size(40, 25);

  @override
  Widget build(BuildContext context) {
    final selectedTileIds = [
      ...draft.coreTileIds,
      ...draft.flowerTileIds,
    ];

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      key: TileKeyboard.selectedTrayKey,
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.82),
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 22,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selected (${draft.selectedCount})',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 22),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: selectedTileIds.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No tiles selected',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ClipRect(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: [
                            for (final indexedTile in selectedTileIds.indexed)
                              _SelectedTileButton(
                                key: TileKeyboard.selectedTileKey(
                                  indexedTile.$2,
                                  indexedTile.$1,
                                ),
                                tileId: indexedTile.$2,
                                selected: draft.winningTileKnown &&
                                    draft.winningTileId == indexedTile.$2,
                                size: _tileSize,
                                onPressed: () => onRemoveTile(indexedTile.$2),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTileButton extends StatelessWidget {
  const _SelectedTileButton({
    super.key,
    required this.tileId,
    required this.selected,
    required this.size,
    required this.onPressed,
  });

  final String tileId;
  final bool selected;
  final Size size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(size),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (selected || states.contains(WidgetState.selected)) {
              return BorderSide(color: colorScheme.primary, width: 2);
            }
            return BorderSide(color: colorScheme.outlineVariant);
          }),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onSurface),
        ),
        child: Text(
          _selectedTileLabel(MahjongTile.byId(tileId)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
        ),
      ),
    );
  }
}

String _selectedTileLabel(MahjongTile tile) {
  return switch (tile.id) {
    'east' => 'E',
    'south' => 'S',
    'west' => 'W',
    'north' => 'N',
    'red' => 'R',
    'green' => 'G',
    'white' => 'Wh',
    'plum_1' => 'Plm1',
    'orchid_2' => 'Orc2',
    'chrysanthemum_3' => 'Chr3',
    'bamboo_flower_4' => 'Bam4',
    'spring_1' => 'Spr1',
    'summer_2' => 'Sum2',
    'autumn_3' => 'Aut3',
    'winter_4' => 'Win4',
    _ => tile.label,
  };
}

enum _TileSectionLayout {
  wrap,
  honorRows,
  bonusGrid,
}

class _TileSection extends StatelessWidget {
  const _TileSection({
    required this.title,
    required this.tiles,
    required this.draft,
    required this.onAddTile,
    this.layout = _TileSectionLayout.wrap,
  });

  final String title;
  final List<MahjongTile> tiles;
  final HandTileEntryDraft draft;
  final ValueChanged<String> onAddTile;
  final _TileSectionLayout layout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _buildTiles(),
        ],
      ),
    );
  }

  Widget _buildTiles() {
    switch (layout) {
      case _TileSectionLayout.honorRows:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileButtonRow(
              tiles: honorTiles.take(4).toList(),
              draft: draft,
              onAddTile: onAddTile,
            ),
            const SizedBox(height: 8),
            _TileButtonRow(
              tiles: honorTiles.skip(4).toList(),
              draft: draft,
              onAddTile: onAddTile,
            ),
          ],
        );
      case _TileSectionLayout.bonusGrid:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              _TileButton(
                tile: tile,
                enabled: draft.canAddTile(tile.id),
                onPressed: () => onAddTile(tile.id),
              ),
          ],
        );
      case _TileSectionLayout.wrap:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              _TileButton(
                tile: tile,
                enabled: draft.canAddTile(tile.id),
                onPressed: () => onAddTile(tile.id),
              ),
          ],
        );
    }
  }
}

class _TileButtonRow extends StatelessWidget {
  const _TileButtonRow({
    required this.tiles,
    required this.draft,
    required this.onAddTile,
  });

  final List<MahjongTile> tiles;
  final HandTileEntryDraft draft;
  final ValueChanged<String> onAddTile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tile in tiles) ...[
          _TileButton(
            tile: tile,
            enabled: draft.canAddTile(tile.id),
            onPressed: () => onAddTile(tile.id),
          ),
          if (tile != tiles.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.tile,
    required this.enabled,
    required this.onPressed,
  });

  static const _standardSize = Size(52, 48);
  static const _flowerSeasonSize = Size(72, 52);

  final MahjongTile tile;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = tile.category == MahjongTileCategory.flowerSeason
        ? _flowerSeasonSize
        : _standardSize;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _TileButtonLabel(tile: tile),
      ),
    );
  }
}

class _TileButtonLabel extends StatelessWidget {
  const _TileButtonLabel({required this.tile});

  final MahjongTile tile;

  @override
  Widget build(BuildContext context) {
    final bonusLabel = _bonusTileButtonLabel(tile);
    if (bonusLabel == null) {
      return Text(
        tile.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          bonusLabel.characterAndNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          bonusLabel.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

({String characterAndNumber, String shortName})? _bonusTileButtonLabel(
  MahjongTile tile,
) {
  if (tile.category != MahjongTileCategory.flowerSeason) {
    return null;
  }

  return switch (tile.id) {
    'plum_1' => (characterAndNumber: '梅 1', shortName: 'Plum'),
    'orchid_2' => (characterAndNumber: '蘭 2', shortName: 'Orch'),
    'chrysanthemum_3' => (characterAndNumber: '菊 3', shortName: 'Chrys'),
    'bamboo_flower_4' => (characterAndNumber: '竹 4', shortName: 'Bam'),
    'spring_1' => (characterAndNumber: '春 1', shortName: 'Spr'),
    'summer_2' => (characterAndNumber: '夏 2', shortName: 'Sum'),
    'autumn_3' => (characterAndNumber: '秋 3', shortName: 'Aut'),
    'winter_4' => (characterAndNumber: '冬 4', shortName: 'Win'),
    _ => null,
  };
}
