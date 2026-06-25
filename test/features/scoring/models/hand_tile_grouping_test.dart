import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/models/hand_tile_grouping.dart';

void main() {
  test('groups a standard winning hand into four melds and pair', () {
    final result = groupStandardWinningHand([
      'bamboo_2',
      'bamboo_3',
      'bamboo_4',
      'dot_4',
      'dot_5',
      'dot_6',
      'east',
      'east',
      'east',
      'man_7',
      'man_8',
      'man_9',
      'south',
      'south',
    ]);

    expect(result.isValid, isTrue);
    expect(result.groups.where((group) => group.type == HandTileGroupType.meld),
        hasLength(4));
    expect(result.groups.where((group) => group.type == HandTileGroupType.pair),
        hasLength(1));
  });

  test('returns invalid result for incomplete hand', () {
    final result = groupStandardWinningHand(['east', 'east', 'east']);

    expect(result.isValid, isFalse);
    expect(result.groups, isEmpty);
  });

  test('groups hand when first sorted tile is the pair', () {
    final result = groupStandardWinningHand([
      'man_1',
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'dot_2',
      'dot_3',
      'dot_4',
      'bamboo_2',
      'bamboo_3',
      'bamboo_4',
      'east',
      'east',
      'east',
    ]);

    expect(result.isValid, isTrue);
    expect(
      result.groups
          .where((group) => group.type == HandTileGroupType.pair)
          .single
          .tileIds,
      ['man_1', 'man_1'],
    );
  });

  test('serializes reviewer approved groups', () {
    final result = groupStandardWinningHand([
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'man_5',
      'man_6',
      'man_7',
      'man_8',
      'man_9',
      'red',
      'red',
      'red',
      'white',
      'white',
    ]);

    expect(result.groups.first.toJson(), {
      'type': 'meld',
      'tiles': ['man_1', 'man_2', 'man_3'],
    });
  });

  test('unknown tile id throws format exception', () {
    expect(
      () => groupStandardWinningHand([
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'man_7',
        'man_8',
        'man_9',
        'red',
        'red',
        'red',
        'moon_1',
        'moon_1',
      ]),
      throwsFormatException,
    );
  });

  test('flower or season in core tiles returns invalid', () {
    final result = groupStandardWinningHand([
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'man_5',
      'man_6',
      'man_7',
      'man_8',
      'man_9',
      'red',
      'red',
      'red',
      'plum_1',
      'plum_1',
    ]);

    expect(result.isValid, isFalse);
    expect(result.groups, isEmpty);
  });

  test('honors cannot form sequences', () {
    final result = groupStandardWinningHand([
      'east',
      'south',
      'west',
      'east',
      'south',
      'west',
      'east',
      'south',
      'west',
      'east',
      'south',
      'west',
      'red',
      'red',
    ]);

    expect(result.isValid, isFalse);
    expect(result.groups, isEmpty);
  });

  test('result and group lists are unmodifiable', () {
    final result = groupStandardWinningHand([
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'man_5',
      'man_6',
      'man_7',
      'man_8',
      'man_9',
      'red',
      'red',
      'red',
      'white',
      'white',
    ]);

    expect(
      () => result.groups.add(HandTileGroup(
        type: HandTileGroupType.pair,
        tileIds: ['east', 'east'],
      )),
      throwsUnsupportedError,
    );
    expect(
        () => result.groups.first.tileIds.add('east'), throwsUnsupportedError);
  });

  test('hand with too many copies of a tile returns invalid', () {
    final result = groupStandardWinningHand([
      'man_1',
      'man_1',
      'man_1',
      'man_1',
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'man_5',
      'man_6',
      'man_7',
      'man_8',
      'man_9',
      'red',
    ]);

    expect(result.isValid, isFalse);
    expect(result.groups, isEmpty);
  });

  test('groups ambiguous suited hand deterministically by tile order', () {
    final result = groupStandardWinningHand([
      'man_1',
      'man_1',
      'man_1',
      'man_2',
      'man_2',
      'man_2',
      'man_3',
      'man_3',
      'man_3',
      'man_4',
      'man_4',
      'man_4',
      'man_5',
      'man_5',
    ]);

    expect(result.isValid, isTrue);
    expect(result.toJson(), [
      {
        'type': 'meld',
        'tiles': ['man_1', 'man_1', 'man_1'],
      },
      {
        'type': 'meld',
        'tiles': ['man_2', 'man_3', 'man_4'],
      },
      {
        'type': 'meld',
        'tiles': ['man_3', 'man_4', 'man_5'],
      },
      {
        'type': 'meld',
        'tiles': ['man_3', 'man_4', 'man_5'],
      },
      {
        'type': 'pair',
        'tiles': ['man_2', 'man_2'],
      },
    ]);
  });
}
