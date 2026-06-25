import 'package:meta/meta.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';

const Object _notProvided = Object();

dynamic _copyJsonLikeValue(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String: _copyJsonLikeValue(entry.value),
    };
  }

  if (value is List) {
    return [for (final item in value) _copyJsonLikeValue(item)];
  }

  return value;
}

@immutable
class HandTileEntryDraft {
  factory HandTileEntryDraft({
    List<String> coreTileIds = const [],
    List<String> flowerTileIds = const [],
    String? winningTileId,
    bool winningTileKnown = false,
  }) {
    final normalizedWinningTileId = winningTileKnown ? winningTileId : null;
    _validate(
      coreTileIds: coreTileIds,
      flowerTileIds: flowerTileIds,
      winningTileId: normalizedWinningTileId,
      winningTileKnown: winningTileKnown,
    );

    return HandTileEntryDraft._(
      coreTileIds: coreTileIds,
      flowerTileIds: flowerTileIds,
      winningTileId: normalizedWinningTileId,
      winningTileKnown: winningTileKnown,
    );
  }

  HandTileEntryDraft._({
    required List<String> coreTileIds,
    required List<String> flowerTileIds,
    required this.winningTileId,
    required this.winningTileKnown,
  })  : coreTileIds = List.unmodifiable(coreTileIds),
        flowerTileIds = List.unmodifiable(flowerTileIds);

  final List<String> coreTileIds;
  final List<String> flowerTileIds;
  final String? winningTileId;
  final bool winningTileKnown;

  int get selectedCount => coreTileIds.length + flowerTileIds.length;

  bool canAddTile(String tileId) {
    final tile = MahjongTile.byId(tileId);
    return _selectedCount(tileId) < tile.maxCopies;
  }

  HandTileEntryDraft addTile(String tileId) {
    final tile = MahjongTile.byId(tileId);
    if (!canAddTile(tileId)) {
      throw StateError('No copies remain for mahjong tile id: $tileId');
    }

    if (tile.category == MahjongTileCategory.flowerSeason) {
      return copyWith(flowerTileIds: [...flowerTileIds, tileId]);
    }

    return copyWith(coreTileIds: [...coreTileIds, tileId]);
  }

  HandTileEntryDraft removeTile(String tileId) {
    MahjongTile.byId(tileId);

    if (flowerTileIds.contains(tileId)) {
      return _withoutTile(flowerTileIds: _removeOne(flowerTileIds, tileId));
    }

    if (coreTileIds.contains(tileId)) {
      return _withoutTile(coreTileIds: _removeOne(coreTileIds, tileId));
    }

    return this;
  }

  HandTileEntryDraft setWinningTile(String tileId) {
    MahjongTile.byId(tileId);
    if (_selectedCount(tileId) == 0) {
      throw StateError('Winning tile must already be selected: $tileId');
    }

    return copyWith(winningTileId: tileId, winningTileKnown: true);
  }

  HandTileEntryDraft clearWinningTile() {
    return copyWith(winningTileId: null, winningTileKnown: false);
  }

  Map<String, dynamic> toJson({required List<Map<String, dynamic>> groups}) {
    return {
      'schemaVersion': 1,
      'tiles': [...coreTileIds],
      'flowers': [...flowerTileIds],
      if (winningTileKnown && winningTileId != null)
        'winningTile': winningTileId,
      'winningTileKnown': winningTileKnown,
      'groups': [
        for (final group in groups)
          _copyJsonLikeValue(group) as Map<String, dynamic>,
      ],
    };
  }

  HandTileEntryDraft copyWith({
    List<String>? coreTileIds,
    List<String>? flowerTileIds,
    Object? winningTileId = _notProvided,
    bool? winningTileKnown,
  }) {
    return HandTileEntryDraft(
      coreTileIds: coreTileIds ?? this.coreTileIds,
      flowerTileIds: flowerTileIds ?? this.flowerTileIds,
      winningTileId: winningTileId == _notProvided
          ? this.winningTileId
          : winningTileId as String?,
      winningTileKnown: winningTileKnown ?? this.winningTileKnown,
    );
  }

  int _selectedCount(String tileId) {
    return coreTileIds.where((id) => id == tileId).length +
        flowerTileIds.where((id) => id == tileId).length;
  }

  HandTileEntryDraft _withoutTile({
    List<String>? coreTileIds,
    List<String>? flowerTileIds,
  }) {
    final nextCoreTileIds = coreTileIds ?? this.coreTileIds;
    final nextFlowerTileIds = flowerTileIds ?? this.flowerTileIds;
    final currentWinningTileId = winningTileId;
    final lastWinningTileOccurrenceWasRemoved = currentWinningTileId != null &&
        winningTileKnown &&
        _selectedCount(currentWinningTileId) > 0 &&
        _selectedCountIn(
              tileId: currentWinningTileId,
              coreTileIds: nextCoreTileIds,
              flowerTileIds: nextFlowerTileIds,
            ) ==
            0;

    return HandTileEntryDraft(
      coreTileIds: nextCoreTileIds,
      flowerTileIds: nextFlowerTileIds,
      winningTileId:
          lastWinningTileOccurrenceWasRemoved ? null : currentWinningTileId,
      winningTileKnown:
          lastWinningTileOccurrenceWasRemoved ? false : winningTileKnown,
    );
  }

  static List<String> _removeOne(List<String> tileIds, String tileId) {
    final next = [...tileIds];
    next.remove(tileId);
    return next;
  }

  static int _selectedCountIn({
    required String tileId,
    required List<String> coreTileIds,
    required List<String> flowerTileIds,
  }) {
    return coreTileIds.where((id) => id == tileId).length +
        flowerTileIds.where((id) => id == tileId).length;
  }

  static void _validate({
    required List<String> coreTileIds,
    required List<String> flowerTileIds,
    required String? winningTileId,
    required bool winningTileKnown,
  }) {
    final counts = <String, int>{};

    for (final tileId in coreTileIds) {
      final tile = MahjongTile.byId(tileId);
      if (tile.category == MahjongTileCategory.flowerSeason) {
        throw StateError(
            'Flower or season tile cannot be a core tile: $tileId');
      }
      counts[tileId] = (counts[tileId] ?? 0) + 1;
    }

    for (final tileId in flowerTileIds) {
      final tile = MahjongTile.byId(tileId);
      if (tile.category != MahjongTileCategory.flowerSeason) {
        throw StateError('Core tile cannot be a flower tile: $tileId');
      }
      counts[tileId] = (counts[tileId] ?? 0) + 1;
    }

    for (final entry in counts.entries) {
      final tile = MahjongTile.byId(entry.key);
      if (entry.value > tile.maxCopies) {
        throw StateError('Too many copies selected for mahjong tile id: '
            '${entry.key}');
      }
    }

    if (!winningTileKnown) {
      return;
    }

    final knownWinningTileId = winningTileId;
    if (knownWinningTileId == null) {
      throw StateError('Known winning tile must include a tile id.');
    }

    MahjongTile.byId(knownWinningTileId);
    if ((counts[knownWinningTileId] ?? 0) == 0) {
      throw StateError(
        'Known winning tile must already be selected: $knownWinningTileId',
      );
    }
  }
}
