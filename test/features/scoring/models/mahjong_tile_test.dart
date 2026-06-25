import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';

void main() {
  test('defines suited tile labels and multiplicity', () {
    final tile = MahjongTile.byId('man_1');

    expect(tile.id, 'man_1');
    expect(tile.label, '1M');
    expect(tile.category, MahjongTileCategory.suit);
    expect(tile.maxCopies, 4);
  });

  test('defines honor labels', () {
    expect(MahjongTile.byId('east').label, 'East');
    expect(MahjongTile.byId('red').label, 'Red');
    expect(MahjongTile.byId('white').maxCopies, 4);
  });

  test('defines flower and season labels with one copy each', () {
    expect(MahjongTile.byId('plum_1').label, 'Plum 1');
    expect(MahjongTile.byId('summer_2').label, 'Summer 2');
    expect(MahjongTile.byId('winter_4').category,
        MahjongTileCategory.flowerSeason);
    expect(MahjongTile.byId('winter_4').maxCopies, 1);
  });

  test('keyboard groups stay in display order', () {
    expect(manTiles.map((tile) => tile.label).toList(), [
      '1M',
      '2M',
      '3M',
      '4M',
      '5M',
      '6M',
      '7M',
      '8M',
      '9M',
    ]);
    expect(honorTiles.map((tile) => tile.id).toList(), [
      'east',
      'south',
      'west',
      'north',
      'red',
      'green',
      'white',
    ]);
    expect(flowerSeasonTiles, hasLength(8));
  });

  test('defines dot tiles in display order', () {
    expect(_tileSummaries(dotTiles), [
      ['dot_1', '1D', 4],
      ['dot_2', '2D', 4],
      ['dot_3', '3D', 4],
      ['dot_4', '4D', 4],
      ['dot_5', '5D', 4],
      ['dot_6', '6D', 4],
      ['dot_7', '7D', 4],
      ['dot_8', '8D', 4],
      ['dot_9', '9D', 4],
    ]);
  });

  test('defines bamboo tiles in display order', () {
    expect(_tileSummaries(bambooTiles), [
      ['bamboo_1', '1B', 4],
      ['bamboo_2', '2B', 4],
      ['bamboo_3', '3B', 4],
      ['bamboo_4', '4B', 4],
      ['bamboo_5', '5B', 4],
      ['bamboo_6', '6B', 4],
      ['bamboo_7', '7B', 4],
      ['bamboo_8', '8B', 4],
      ['bamboo_9', '9B', 4],
    ]);
  });

  test('defines flower and season tiles in display order', () {
    expect(_tileSummaries(flowerSeasonTiles), [
      ['plum_1', 'Plum 1', 1],
      ['orchid_2', 'Orchid 2', 1],
      ['bamboo_flower_3', 'Bamboo 3', 1],
      ['chrysanthemum_4', 'Chrysanthemum 4', 1],
      ['spring_1', 'Spring 1', 1],
      ['summer_2', 'Summer 2', 1],
      ['autumn_3', 'Autumn 3', 1],
      ['winter_4', 'Winter 4', 1],
    ]);
  });

  test('suited tiles include suit and rank metadata', () {
    _expectSuitRanks(manTiles, 'man');
    _expectSuitRanks(dotTiles, 'dot');
    _expectSuitRanks(bambooTiles, 'bamboo');
  });

  test('honors and flowers do not include suit or rank metadata', () {
    for (final tile in [...honorTiles, ...flowerSeasonTiles]) {
      expect(tile.suit, isNull);
      expect(tile.rank, isNull);
    }
  });

  test('core tiles exclude flowers and seasons', () {
    expect(MahjongTile.byId('man_1').isCore, isTrue);
    expect(MahjongTile.byId('east').isCore, isTrue);
    expect(MahjongTile.byId('plum_1').isCore, isFalse);
    expect(MahjongTile.byId('winter_4').isCore, isFalse);
  });

  test('all tile and lookup collections include every tile exactly once', () {
    final expectedTileIds = [
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'man_5',
      'man_6',
      'man_7',
      'man_8',
      'man_9',
      'dot_1',
      'dot_2',
      'dot_3',
      'dot_4',
      'dot_5',
      'dot_6',
      'dot_7',
      'dot_8',
      'dot_9',
      'bamboo_1',
      'bamboo_2',
      'bamboo_3',
      'bamboo_4',
      'bamboo_5',
      'bamboo_6',
      'bamboo_7',
      'bamboo_8',
      'bamboo_9',
      'east',
      'south',
      'west',
      'north',
      'red',
      'green',
      'white',
      'plum_1',
      'orchid_2',
      'bamboo_flower_3',
      'chrysanthemum_4',
      'spring_1',
      'summer_2',
      'autumn_3',
      'winter_4',
    ];

    expect(allMahjongTiles.map((tile) => tile.id).toList(), expectedTileIds);
    expect(allMahjongTiles.map((tile) => tile.id).toSet(),
        hasLength(expectedTileIds.length));
    expect(tilesById.keys.toList(), expectedTileIds);

    for (final tile in allMahjongTiles) {
      expect(tilesById[tile.id], same(tile));
    }
  });

  test('tile lookup cannot be mutated by callers', () {
    expect(
      () => tilesById['moon_1'] = const MahjongTile(
        id: 'moon_1',
        label: 'Moon 1',
        category: MahjongTileCategory.flowerSeason,
        maxCopies: 1,
      ),
      throwsUnsupportedError,
    );
  });

  test('unknown tile ids throw format exception', () {
    expect(() => MahjongTile.byId('moon_1'), throwsFormatException);
  });
}

void _expectSuitRanks(List<MahjongTile> tiles, String expectedSuit) {
  for (var index = 0; index < tiles.length; index += 1) {
    final tile = tiles[index];
    expect(tile.suit, expectedSuit);
    expect(tile.rank, index + 1);
  }
}

List<List<Object>> _tileSummaries(List<MahjongTile> tiles) {
  return [
    for (final tile in tiles) [tile.id, tile.label, tile.maxCopies],
  ];
}
