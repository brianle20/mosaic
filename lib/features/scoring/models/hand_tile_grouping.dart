import 'package:meta/meta.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';

enum HandTileGroupType {
  meld,
  pair,
}

@immutable
class HandTileGroup {
  HandTileGroup({
    required this.type,
    required List<String> tileIds,
  }) : tileIds = List.unmodifiable(tileIds);

  final HandTileGroupType type;
  final List<String> tileIds;

  Map<String, Object> toJson() {
    return {
      'type': _groupTypeToJson(type),
      'tiles': List<String>.unmodifiable(tileIds),
    };
  }
}

@immutable
class HandTileGroupingResult {
  HandTileGroupingResult({
    required List<HandTileGroup> groups,
    required this.isValid,
  }) : groups = List.unmodifiable(groups);

  const HandTileGroupingResult.invalid()
      : groups = const [],
        isValid = false;

  final List<HandTileGroup> groups;
  final bool isValid;

  List<Map<String, Object>> toJson() {
    return [
      for (final group in groups) group.toJson(),
    ];
  }
}

HandTileGroupingResult groupStandardWinningHand(List<String> coreTileIds) {
  final tiles = [
    for (final tileId in coreTileIds) MahjongTile.byId(tileId),
  ];

  if (tiles.length != 14) {
    return HandTileGroupingResult.invalid();
  }

  if (tiles.any((tile) => !tile.isCore)) {
    return HandTileGroupingResult.invalid();
  }

  final counts = <String, int>{
    for (final tile in allMahjongTiles.where((tile) => tile.isCore)) tile.id: 0,
  };

  for (final tile in tiles) {
    final nextCount = (counts[tile.id] ?? 0) + 1;
    if (nextCount > tile.maxCopies) {
      return HandTileGroupingResult.invalid();
    }

    counts[tile.id] = nextCount;
  }

  final groups = _findStandardGroups(counts);
  if (groups == null) {
    return HandTileGroupingResult.invalid();
  }

  return HandTileGroupingResult(
    groups: groups,
    isValid: true,
  );
}

List<HandTileGroup>? _findStandardGroups(Map<String, int> counts) {
  for (final tile in allMahjongTiles.where((tile) => tile.isCore)) {
    if ((counts[tile.id] ?? 0) < 2) {
      continue;
    }

    counts[tile.id] = (counts[tile.id] ?? 0) - 2;
    final melds = _findMeldGroups(counts);
    counts[tile.id] = (counts[tile.id] ?? 0) + 2;

    if (melds != null) {
      return [
        ...melds,
        HandTileGroup(
          type: HandTileGroupType.pair,
          tileIds: [tile.id, tile.id],
        ),
      ];
    }
  }

  return null;
}

List<HandTileGroup>? _findMeldGroups(Map<String, int> counts) {
  final remainingTileCount = counts.values.fold<int>(
    0,
    (total, count) => total + count,
  );

  if (remainingTileCount == 0) {
    return [];
  }

  final tileId = _firstTileIdWithCount(counts);
  if (tileId == null) {
    return [];
  }

  if ((counts[tileId] ?? 0) >= 3) {
    final triplet = [tileId, tileId, tileId];
    final result = _tryMeld(counts, triplet);
    if (result != null) {
      return [
        HandTileGroup(type: HandTileGroupType.meld, tileIds: triplet),
        ...result,
      ];
    }
  }

  final sequence = _sequenceStartingAt(tileId, counts);
  if (sequence != null) {
    final result = _tryMeld(counts, sequence);
    if (result != null) {
      return [
        HandTileGroup(type: HandTileGroupType.meld, tileIds: sequence),
        ...result,
      ];
    }
  }

  return null;
}

List<HandTileGroup>? _tryMeld(Map<String, int> counts, List<String> tileIds) {
  for (final tileId in tileIds) {
    counts[tileId] = (counts[tileId] ?? 0) - 1;
  }

  final result = _findMeldGroups(counts);

  for (final tileId in tileIds) {
    counts[tileId] = (counts[tileId] ?? 0) + 1;
  }

  return result;
}

List<String>? _sequenceStartingAt(String tileId, Map<String, int> counts) {
  final tile = MahjongTile.byId(tileId);
  if (tile.category != MahjongTileCategory.suit ||
      tile.suit == null ||
      tile.rank == null ||
      tile.rank! > 7) {
    return null;
  }

  final secondTileId = '${tile.suit}_${tile.rank! + 1}';
  final thirdTileId = '${tile.suit}_${tile.rank! + 2}';

  if ((counts[secondTileId] ?? 0) == 0 || (counts[thirdTileId] ?? 0) == 0) {
    return null;
  }

  return [tileId, secondTileId, thirdTileId];
}

String? _firstTileIdWithCount(Map<String, int> counts) {
  for (final tile in allMahjongTiles) {
    final count = counts[tile.id] ?? 0;
    if (tile.isCore && count > 0) {
      return tile.id;
    }
  }

  return null;
}

String _groupTypeToJson(HandTileGroupType type) {
  switch (type) {
    case HandTileGroupType.meld:
      return 'meld';
    case HandTileGroupType.pair:
      return 'pair';
  }
}
