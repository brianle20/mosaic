import 'package:flutter/material.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';

class TileKeyboard extends StatefulWidget {
  const TileKeyboard({
    super.key,
    required this.draft,
    required this.onAddTile,
    required this.onRemoveTile,
    required this.onClear,
    required this.onSetWinningTile,
    required this.onClearWinningTile,
  });

  static const selectedTrayScrollerKey =
      Key('tileKeyboardSelectedTrayScroller');
  static const selectedTrayKey = Key('tileKeyboardSelectedTray');
  static const tileListKey = Key('tileKeyboardTileList');
  static const setWinningTileModeKey = Key('tileKeyboardSetWinningTileMode');
  static const cancelWinningTileModeKey =
      Key('tileKeyboardCancelWinningTileMode');
  static const clearWinningTileKey = Key('tileKeyboardClearWinningTile');
  static const changeWinningTileKey = Key('tileKeyboardChangeWinningTile');
  static Key selectedTileKey(String tileId, int index) =>
      ValueKey('tileKeyboardSelectedTile.$index.$tileId');

  final HandTileEntryDraft draft;
  final ValueChanged<String> onAddTile;
  final ValueChanged<String> onRemoveTile;
  final VoidCallback onClear;
  final ValueChanged<String> onSetWinningTile;
  final VoidCallback onClearWinningTile;

  @override
  State<TileKeyboard> createState() => _TileKeyboardState();
}

class _TileKeyboardState extends State<TileKeyboard> {
  bool _choosingWinningTile = false;
  String? _winningTileOccurrenceTileId;
  int? _winningTileOccurrence;
  String? _pendingWinningTileOccurrenceTileId;
  int? _pendingWinningTileOccurrence;
  bool _pendingClearWinningTile = false;
  String? _pendingRemovalTileId;
  int? _pendingRemovalCount;
  int _nextPendingRequestGeneration = 0;
  int? _pendingRequestGeneration;

  int get _effectiveWinningTileOccurrence =>
      _winningTileOccurrenceTileId == widget.draft.winningTileId
          ? _winningTileOccurrence ?? 0
          : 0;

  int _startPendingRequest() {
    final generation = ++_nextPendingRequestGeneration;
    _pendingRequestGeneration = generation;
    return generation;
  }

  void _schedulePendingRequestExpiration(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingRequestGeneration != generation) {
        return;
      }
      _clearPendingRequest();
    });
  }

  void _clearPendingRequest() {
    _pendingWinningTileOccurrenceTileId = null;
    _pendingWinningTileOccurrence = null;
    _pendingClearWinningTile = false;
    _pendingRemovalTileId = null;
    _pendingRemovalCount = null;
    _pendingRequestGeneration = null;
  }

  void _enterWinningTileMode() {
    if (widget.draft.selectedCount == 0) {
      return;
    }
    setState(() {
      _choosingWinningTile = true;
    });
  }

  void _cancelWinningTileMode() {
    setState(() {
      _choosingWinningTile = false;
    });
  }

  void _setWinningTile(String tileId, int occurrence) {
    widget.onSetWinningTile(tileId);
    if (!mounted) {
      return;
    }
    final generation = _startPendingRequest();
    setState(() {
      _choosingWinningTile = false;
      _pendingWinningTileOccurrenceTileId = tileId;
      _pendingWinningTileOccurrence = occurrence;
      _pendingClearWinningTile = false;
    });
    _schedulePendingRequestExpiration(generation);
  }

  void _removeTile(String tileId) {
    final matchingCount = _matchingTileCount(widget.draft, tileId);
    widget.onRemoveTile(tileId);
    if (!mounted) {
      return;
    }
    final generation = _startPendingRequest();
    setState(() {
      _pendingRemovalTileId = tileId;
      _pendingRemovalCount = matchingCount;
    });
    _schedulePendingRequestExpiration(generation);
  }

  void _clearWinningTile() {
    widget.onClearWinningTile();
    if (!mounted) {
      return;
    }
    final generation = _startPendingRequest();
    setState(() {
      _choosingWinningTile = false;
      _pendingWinningTileOccurrenceTileId = null;
      _pendingWinningTileOccurrence = null;
      _pendingClearWinningTile = true;
    });
    _schedulePendingRequestExpiration(generation);
  }

  @override
  void didUpdateWidget(covariant TileKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draftChanged = !identical(oldWidget.draft, widget.draft);
    if (draftChanged) {
      final pendingWinningTileId = _pendingWinningTileOccurrenceTileId;
      if (pendingWinningTileId != null) {
        if (widget.draft.winningTileKnown &&
            widget.draft.winningTileId == pendingWinningTileId) {
          _winningTileOccurrenceTileId = pendingWinningTileId;
          _winningTileOccurrence = _pendingWinningTileOccurrence;
        }
      }

      if (_pendingClearWinningTile) {
        if (!widget.draft.winningTileKnown ||
            widget.draft.winningTileId == null) {
          _winningTileOccurrenceTileId = null;
          _winningTileOccurrence = null;
        }
      }

      final pendingRemovalTileId = _pendingRemovalTileId;
      final pendingRemovalCount = _pendingRemovalCount;
      if (pendingRemovalTileId != null && pendingRemovalCount != null) {
        final matchingCount =
            _matchingTileCount(widget.draft, pendingRemovalTileId);
        if (matchingCount < pendingRemovalCount &&
            _winningTileOccurrenceTileId == pendingRemovalTileId) {
          final occurrence = _winningTileOccurrence;
          if (occurrence != null && occurrence > 0) {
            _winningTileOccurrence = occurrence - 1;
          }
        }
      }
      _clearPendingRequest();
    }
    if (widget.draft.selectedCount == 0) {
      _choosingWinningTile = false;
    }
    final winningTileId = widget.draft.winningTileId;
    if (!widget.draft.winningTileKnown || winningTileId == null) {
      _winningTileOccurrenceTileId = null;
      _winningTileOccurrence = null;
      return;
    }
    if (_winningTileOccurrenceTileId != winningTileId) {
      _winningTileOccurrenceTileId = null;
      _winningTileOccurrence = null;
      return;
    }
    final matchingCount = _matchingTileCount(widget.draft, winningTileId);
    final occurrence = _winningTileOccurrence;
    if (matchingCount == 0) {
      _winningTileOccurrenceTileId = null;
      _winningTileOccurrence = null;
    } else if (occurrence != null && occurrence >= matchingCount) {
      _winningTileOccurrence = matchingCount - 1;
    }
  }

  int _matchingTileCount(HandTileEntryDraft draft, String tileId) {
    return [
      ...draft.coreTileIds,
      ...draft.flowerTileIds,
    ].where((selectedTileId) => selectedTileId == tileId).length;
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      _TileSection(
        title: 'Characters',
        tiles: manTiles,
        draft: widget.draft,
        onAddTile: widget.onAddTile,
      ),
      _TileSection(
        title: 'Dots',
        tiles: dotTiles,
        draft: widget.draft,
        onAddTile: widget.onAddTile,
      ),
      _TileSection(
        title: 'Bamboo',
        tiles: bambooTiles,
        draft: widget.draft,
        onAddTile: widget.onAddTile,
      ),
      _TileSection(
        title: 'Honors',
        tiles: honorTiles,
        draft: widget.draft,
        onAddTile: widget.onAddTile,
        layout: _TileSectionLayout.honorRows,
      ),
      _TileSection(
        title: 'Flowers / Seasons',
        tiles: flowerSeasonTiles,
        draft: widget.draft,
        onAddTile: widget.onAddTile,
        layout: _TileSectionLayout.bonusGrid,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final trayHeight =
            constraints.maxHeight < _SelectedTileTray.defaultHeight + 96
                ? (constraints.maxHeight <= 72
                    ? constraints.maxHeight
                    : (constraints.maxHeight * 0.55)
                        .clamp(72.0, _SelectedTileTray.defaultHeight)
                        .toDouble())
                : _SelectedTileTray.defaultHeight;

        return Column(
          children: [
            _SelectedTileTray(
              draft: widget.draft,
              height: trayHeight,
              choosingWinningTile: _choosingWinningTile,
              onClear: widget.onClear,
              onRemoveTile: _removeTile,
              onEnterWinningTileMode: _enterWinningTileMode,
              onCancelWinningTileMode: _cancelWinningTileMode,
              onSetWinningTile: _setWinningTile,
              onClearWinningTile: _clearWinningTile,
              winningTileOccurrence: _effectiveWinningTileOccurrence,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: TileKeyboard.tileListKey,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sections,
                ),
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
    required this.height,
    required this.choosingWinningTile,
    required this.onClear,
    required this.onRemoveTile,
    required this.onEnterWinningTileMode,
    required this.onCancelWinningTileMode,
    required this.onSetWinningTile,
    required this.onClearWinningTile,
    required this.winningTileOccurrence,
  });

  final HandTileEntryDraft draft;
  final double height;
  final bool choosingWinningTile;
  final VoidCallback onClear;
  final ValueChanged<String> onRemoveTile;
  final VoidCallback onEnterWinningTileMode;
  final VoidCallback onCancelWinningTileMode;
  final void Function(String tileId, int occurrence) onSetWinningTile;
  final VoidCallback onClearWinningTile;
  final int winningTileOccurrence;

  static const defaultHeight = 156.0;
  static const _tileSize = Size(40, 25);

  Widget _buildWinningTileRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (choosingWinningTile) {
      return SizedBox(
        height: 28,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Tap the winning tile below',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              key: TileKeyboard.cancelWinningTileModeKey,
              onPressed: onCancelWinningTileMode,
              style: _trayActionStyle(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    final winningTileId = draft.winningTileId;
    final winningTileLabel = draft.winningTileKnown && winningTileId != null
        ? _selectedTileLabel(MahjongTile.byId(winningTileId))
        : 'Unknown';

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Text(
            'Winning tile',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              winningTileLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium,
            ),
          ),
          if (draft.winningTileKnown) ...[
            TextButton(
              key: TileKeyboard.clearWinningTileKey,
              onPressed: onClearWinningTile,
              style: _trayActionStyle(context),
              child: const Text('Unknown'),
            ),
            TextButton(
              key: TileKeyboard.changeWinningTileKey,
              onPressed:
                  draft.selectedCount == 0 ? null : onEnterWinningTileMode,
              style: _trayActionStyle(context),
              child: const Text('Change'),
            ),
          ] else
            TextButton(
              key: TileKeyboard.setWinningTileModeKey,
              onPressed:
                  draft.selectedCount == 0 ? null : onEnterWinningTileMode,
              style: _trayActionStyle(context),
              child: const Text('Set'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTileIds = [
      ...draft.coreTileIds,
      ...draft.flowerTileIds,
    ];
    final colorScheme = Theme.of(context).colorScheme;
    final compact = height < defaultHeight;
    final content = _buildContent(
      context,
      selectedTileIds,
      scrollSelectedTiles: !compact,
    );

    return SizedBox(
      key: TileKeyboard.selectedTrayKey,
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.82),
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: compact
            ? SingleChildScrollView(
                key: TileKeyboard.selectedTrayScrollerKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: defaultHeight),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<String> selectedTileIds, {
    required bool scrollSelectedTiles,
  }) {
    final selectedTiles = selectedTileIds.isEmpty
        ? Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No tiles selected',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        : Wrap(
            spacing: 4,
            runSpacing: 3,
            children: [
              ...selectedTileIds.indexed.map((indexedTile) {
                final index = indexedTile.$1;
                final tileId = indexedTile.$2;
                final occurrence = selectedTileIds
                    .take(index)
                    .where((selectedTileId) => selectedTileId == tileId)
                    .length;
                return _SelectedTileButton(
                  key: TileKeyboard.selectedTileKey(
                    tileId,
                    index,
                  ),
                  tileId: tileId,
                  selected: draft.winningTileKnown &&
                      draft.winningTileId == tileId &&
                      winningTileOccurrence == occurrence,
                  choosing: choosingWinningTile,
                  size: _tileSize,
                  onPressed: () {
                    if (choosingWinningTile) {
                      onSetWinningTile(tileId, occurrence);
                      return;
                    }
                    onRemoveTile(tileId);
                  },
                );
              }),
            ],
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        mainAxisSize: scrollSelectedTiles ? MainAxisSize.max : MainAxisSize.min,
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
          _buildWinningTileRow(context),
          const SizedBox(height: 4),
          if (scrollSelectedTiles)
            Expanded(
              child: selectedTileIds.isEmpty
                  ? selectedTiles
                  : SingleChildScrollView(
                      primary: false,
                      child: selectedTiles,
                    ),
            )
          else
            selectedTiles,
        ],
      ),
    );
  }
}

class _SelectedTileButton extends StatelessWidget {
  const _SelectedTileButton({
    super.key,
    required this.tileId,
    required this.selected,
    required this.choosing,
    required this.size,
    required this.onPressed,
  });

  final String tileId;
  final bool selected;
  final bool choosing;
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
            if (choosing) {
              return BorderSide(color: colorScheme.primary, width: 1.5);
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

ButtonStyle _trayActionStyle(BuildContext context) {
  return TextButton.styleFrom(
    minimumSize: const Size(44, 24),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: Theme.of(context).textTheme.labelMedium,
  );
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
        child: _TileButtonLabel(tile: tile, enabled: enabled),
      ),
    );
  }
}

class _TileButtonLabel extends StatelessWidget {
  const _TileButtonLabel({
    required this.tile,
    required this.enabled,
  });

  final MahjongTile tile;
  final bool enabled;

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

    final disabledColor = Theme.of(context).disabledColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          bonusLabel.characterAndNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: enabled ? null : disabledColor,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          bonusLabel.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: enabled ? null : TextStyle(color: disabledColor),
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
