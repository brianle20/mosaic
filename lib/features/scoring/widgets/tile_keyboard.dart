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

  final HandTileEntryDraft draft;
  final ValueChanged<String> onAddTile;
  final ValueChanged<String> onRemoveTile;
  final VoidCallback onClear;
  final ValueChanged<String> onSetWinningTile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SelectedTileTray(
          draft: draft,
          onClear: onClear,
          onRemoveTile: onRemoveTile,
          onSetWinningTile: onSetWinningTile,
        ),
        const SizedBox(height: 16),
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
        ),
        _TileSection(
          title: 'Flowers / Seasons',
          tiles: flowerSeasonTiles,
          draft: draft,
          onAddTile: onAddTile,
        ),
      ],
    );
  }
}

class _SelectedTileTray extends StatelessWidget {
  const _SelectedTileTray({
    required this.draft,
    required this.onClear,
    required this.onRemoveTile,
    required this.onSetWinningTile,
  });

  final HandTileEntryDraft draft;
  final VoidCallback onClear;
  final ValueChanged<String> onRemoveTile;
  final ValueChanged<String> onSetWinningTile;

  @override
  Widget build(BuildContext context) {
    final selectedTileIds = [
      ...draft.coreTileIds,
      ...draft.flowerTileIds,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Selected tiles (${draft.selectedCount})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedTileIds.isEmpty)
          Text(
            'No tiles selected',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tileId in selectedTileIds)
                InputChip(
                  label: Text(MahjongTile.byId(tileId).label),
                  selected:
                      draft.winningTileKnown && draft.winningTileId == tileId,
                  onPressed: () => onSetWinningTile(tileId),
                  onDeleted: () => onRemoveTile(tileId),
                ),
            ],
          ),
      ],
    );
  }
}

class _TileSection extends StatelessWidget {
  const _TileSection({
    required this.title,
    required this.tiles,
    required this.draft,
    required this.onAddTile,
  });

  final String title;
  final List<MahjongTile> tiles;
  final HandTileEntryDraft draft;
  final ValueChanged<String> onAddTile;

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
          Wrap(
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
          ),
        ],
      ),
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
  static const _wideSize = Size(112, 48);

  final MahjongTile tile;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = tile.category == MahjongTileCategory.flowerSeason
        ? _wideSize
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
        child: Text(
          tile.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
