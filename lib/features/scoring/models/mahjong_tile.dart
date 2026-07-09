import 'package:meta/meta.dart';

enum MahjongTileCategory {
  suit,
  honor,
  flowerSeason,
}

@immutable
class MahjongTile {
  const MahjongTile({
    required this.id,
    required this.label,
    required this.category,
    required this.maxCopies,
    this.suit,
    this.rank,
  });

  final String id;
  final String label;
  final MahjongTileCategory category;
  final int maxCopies;
  final String? suit;
  final int? rank;

  bool get isCore => category != MahjongTileCategory.flowerSeason;

  static MahjongTile byId(String id) {
    final tile = tilesById[id] ?? tilesById[_legacyTileIdAliases[id]];
    if (tile == null) {
      throw FormatException('Unknown mahjong tile id: $id', id);
    }

    return tile;
  }
}

const manTiles = [
  MahjongTile(
    id: 'man_1',
    label: '1M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 1,
  ),
  MahjongTile(
    id: 'man_2',
    label: '2M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 2,
  ),
  MahjongTile(
    id: 'man_3',
    label: '3M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 3,
  ),
  MahjongTile(
    id: 'man_4',
    label: '4M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 4,
  ),
  MahjongTile(
    id: 'man_5',
    label: '5M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 5,
  ),
  MahjongTile(
    id: 'man_6',
    label: '6M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 6,
  ),
  MahjongTile(
    id: 'man_7',
    label: '7M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 7,
  ),
  MahjongTile(
    id: 'man_8',
    label: '8M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 8,
  ),
  MahjongTile(
    id: 'man_9',
    label: '9M',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'man',
    rank: 9,
  ),
];

const dotTiles = [
  MahjongTile(
    id: 'dot_1',
    label: '1D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 1,
  ),
  MahjongTile(
    id: 'dot_2',
    label: '2D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 2,
  ),
  MahjongTile(
    id: 'dot_3',
    label: '3D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 3,
  ),
  MahjongTile(
    id: 'dot_4',
    label: '4D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 4,
  ),
  MahjongTile(
    id: 'dot_5',
    label: '5D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 5,
  ),
  MahjongTile(
    id: 'dot_6',
    label: '6D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 6,
  ),
  MahjongTile(
    id: 'dot_7',
    label: '7D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 7,
  ),
  MahjongTile(
    id: 'dot_8',
    label: '8D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 8,
  ),
  MahjongTile(
    id: 'dot_9',
    label: '9D',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'dot',
    rank: 9,
  ),
];

const bambooTiles = [
  MahjongTile(
    id: 'bamboo_1',
    label: '1B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 1,
  ),
  MahjongTile(
    id: 'bamboo_2',
    label: '2B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 2,
  ),
  MahjongTile(
    id: 'bamboo_3',
    label: '3B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 3,
  ),
  MahjongTile(
    id: 'bamboo_4',
    label: '4B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 4,
  ),
  MahjongTile(
    id: 'bamboo_5',
    label: '5B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 5,
  ),
  MahjongTile(
    id: 'bamboo_6',
    label: '6B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 6,
  ),
  MahjongTile(
    id: 'bamboo_7',
    label: '7B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 7,
  ),
  MahjongTile(
    id: 'bamboo_8',
    label: '8B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 8,
  ),
  MahjongTile(
    id: 'bamboo_9',
    label: '9B',
    category: MahjongTileCategory.suit,
    maxCopies: 4,
    suit: 'bamboo',
    rank: 9,
  ),
];

const honorTiles = [
  MahjongTile(
    id: 'east',
    label: 'East',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
  MahjongTile(
    id: 'south',
    label: 'South',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
  MahjongTile(
    id: 'west',
    label: 'West',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
  MahjongTile(
    id: 'north',
    label: 'North',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
  MahjongTile(
    id: 'red',
    label: 'Red',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
  MahjongTile(
    id: 'green',
    label: 'Green',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
  MahjongTile(
    id: 'white',
    label: 'White',
    category: MahjongTileCategory.honor,
    maxCopies: 4,
  ),
];

const flowerSeasonTiles = [
  MahjongTile(
    id: 'plum_1',
    label: 'Plum 1',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'orchid_2',
    label: 'Orchid 2',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'chrysanthemum_3',
    label: 'Chrysanthemum 3',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'bamboo_flower_4',
    label: 'Bamboo 4',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'spring_1',
    label: 'Spring 1',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'summer_2',
    label: 'Summer 2',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'autumn_3',
    label: 'Autumn 3',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
  MahjongTile(
    id: 'winter_4',
    label: 'Winter 4',
    category: MahjongTileCategory.flowerSeason,
    maxCopies: 1,
  ),
];

const allMahjongTiles = [
  ...manTiles,
  ...dotTiles,
  ...bambooTiles,
  ...honorTiles,
  ...flowerSeasonTiles,
];

final Map<String, MahjongTile> tilesById = Map.unmodifiable({
  for (final tile in allMahjongTiles) tile.id: tile,
});

const _legacyTileIdAliases = {
  'bamboo_flower_3': 'chrysanthemum_3',
  'chrysanthemum_4': 'bamboo_flower_4',
};
