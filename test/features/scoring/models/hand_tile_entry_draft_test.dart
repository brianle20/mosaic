import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';

void main() {
  test('adds core tiles and flowers separately', () {
    final draft = HandTileEntryDraft()
        .addTile('man_1')
        .addTile('man_1')
        .addTile('plum_1');

    expect(draft.coreTileIds, ['man_1', 'man_1']);
    expect(draft.flowerTileIds, ['plum_1']);
    expect(draft.selectedCount, 3);
  });

  test('blocks selection past tile multiplicity', () {
    var draft = HandTileEntryDraft();
    draft =
        draft.addTile('east').addTile('east').addTile('east').addTile('east');

    expect(draft.canAddTile('east'), isFalse);
    expect(() => draft.addTile('east'), throwsStateError);
  });

  test('validates unknown tile ids before adding or counting', () {
    expect(
      () => HandTileEntryDraft().addTile('moon_1'),
      throwsFormatException,
    );
    expect(
      () => HandTileEntryDraft().canAddTile('moon_1'),
      throwsFormatException,
    );
  });

  test('constructor rejects core tiles in flower list', () {
    expect(
      () => HandTileEntryDraft(flowerTileIds: const ['east']),
      throwsStateError,
    );
  });

  test('constructor rejects unknown tile ids in selected lists', () {
    expect(
      () => HandTileEntryDraft(coreTileIds: const ['moon_1']),
      throwsFormatException,
    );
    expect(
      () => HandTileEntryDraft(flowerTileIds: const ['moon_1']),
      throwsFormatException,
    );
  });

  test('constructor rejects flower tiles in core list', () {
    expect(
      () => HandTileEntryDraft(coreTileIds: const ['plum_1']),
      throwsStateError,
    );
  });

  test('constructor rejects too many core tile copies', () {
    expect(
      () => HandTileEntryDraft(
        coreTileIds: const ['east', 'east', 'east', 'east', 'east'],
      ),
      throwsStateError,
    );
  });

  test('constructor rejects duplicate flower tile copies', () {
    expect(
      () => HandTileEntryDraft(
        flowerTileIds: const ['plum_1', 'plum_1'],
      ),
      throwsStateError,
    );
  });

  test('constructor rejects invalid known winning tile state', () {
    expect(
      () => HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileKnown: true,
      ),
      throwsStateError,
    );
    expect(
      () => HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileId: 'man_2',
        winningTileKnown: true,
      ),
      throwsStateError,
    );
    expect(
      () => HandTileEntryDraft(
        coreTileIds: const ['man_1'],
        winningTileId: 'moon_1',
        winningTileKnown: true,
      ),
      throwsFormatException,
    );
  });

  test('sets and clears winning tile', () {
    final draft = HandTileEntryDraft().addTile('man_9').setWinningTile('man_9');

    expect(draft.winningTileId, 'man_9');
    expect(draft.winningTileKnown, isTrue);
    expect(draft.clearWinningTile().winningTileKnown, isFalse);
    expect(draft.clearWinningTile().winningTileId, isNull);
  });

  test('serializes versioned tile json', () {
    final draft = HandTileEntryDraft()
        .addTile('bamboo_2')
        .addTile('bamboo_3')
        .addTile('bamboo_4')
        .addTile('plum_1')
        .setWinningTile('bamboo_4');

    expect(draft.toJson(groups: const []), {
      'schemaVersion': 1,
      'tiles': ['bamboo_2', 'bamboo_3', 'bamboo_4'],
      'flowers': ['plum_1'],
      'winningTile': 'bamboo_4',
      'winningTileKnown': true,
      'photoRotationQuarterTurns': 0,
      'groups': const [],
    });
  });

  test('to json defensively copies groups', () {
    final tiles = ['man_1', 'man_2', 'man_3'];
    final group = <String, dynamic>{'type': 'sequence', 'tiles': tiles};
    final groups = [group];
    final json = HandTileEntryDraft().toJson(groups: groups);

    groups.clear();
    group['type'] = 'pair';
    tiles.add('man_4');

    expect(json['groups'], [
      {
        'type': 'sequence',
        'tiles': ['man_1', 'man_2', 'man_3'],
      },
    ]);
  });

  test('remove tile removes flowers', () {
    final draft = HandTileEntryDraft(
      flowerTileIds: const ['plum_1'],
    ).removeTile('plum_1');

    expect(draft.flowerTileIds, isEmpty);
    expect(draft.coreTileIds, isEmpty);
  });

  test('remove tile clears winning tile after last occurrence is removed', () {
    final draft = HandTileEntryDraft()
        .addTile('man_1')
        .addTile('man_1')
        .setWinningTile('man_1')
        .removeTile('man_1');

    expect(draft.winningTileId, 'man_1');
    expect(draft.winningTileKnown, isTrue);

    final withoutWinningTile = draft.removeTile('man_1');

    expect(withoutWinningTile.winningTileId, isNull);
    expect(withoutWinningTile.winningTileKnown, isFalse);
  });

  test('set winning tile requires selected tile', () {
    expect(
      () => HandTileEntryDraft().setWinningTile('man_1'),
      throwsStateError,
    );
  });

  test('unknown winning tile state omits winning tile from json', () {
    final draft = HandTileEntryDraft()
        .addTile('man_1')
        .copyWith(winningTileId: 'man_1', winningTileKnown: false);

    expect(draft.winningTileId, isNull);
    expect(draft.toJson(groups: const []), {
      'schemaVersion': 1,
      'tiles': ['man_1'],
      'flowers': <String>[],
      'winningTileKnown': false,
      'photoRotationQuarterTurns': 0,
      'groups': const [],
    });
  });

  test('copy with can intentionally clear winning tile id', () {
    final draft = HandTileEntryDraft().copyWith(
      coreTileIds: const ['man_1'],
      winningTileId: 'man_1',
      winningTileKnown: true,
    ).copyWith(winningTileId: null, winningTileKnown: false);

    expect(draft.winningTileId, isNull);
    expect(draft.winningTileKnown, isFalse);
  });

  test('copy with enforces constructor invariants', () {
    expect(
      () => HandTileEntryDraft().copyWith(coreTileIds: const ['plum_1']),
      throwsStateError,
    );
  });

  test('list fields are unmodifiable', () {
    final draft = HandTileEntryDraft().copyWith(
      coreTileIds: const ['man_1'],
      flowerTileIds: const ['plum_1'],
    );

    expect(() => draft.coreTileIds.add('man_2'), throwsUnsupportedError);
    expect(() => draft.flowerTileIds.add('orchid_2'), throwsUnsupportedError);
  });

  test('public constructor exposes unmodifiable list fields', () {
    final draft = HandTileEntryDraft(
      coreTileIds: ['man_1'],
      flowerTileIds: ['plum_1'],
    );

    expect(() => draft.coreTileIds.add('man_2'), throwsUnsupportedError);
    expect(() => draft.flowerTileIds.add('orchid_2'), throwsUnsupportedError);
  });

  test('flower tiles respect one-copy multiplicity', () {
    final draft = HandTileEntryDraft().addTile('plum_1');

    expect(draft.canAddTile('plum_1'), isFalse);
    expect(() => draft.addTile('plum_1'), throwsStateError);
  });

  test('legacy flower aliases hydrate and serialize as canonical ids', () {
    const cases = [
      (
        alias: 'bamboo_flower_3',
        canonical: 'chrysanthemum_3',
      ),
      (
        alias: 'chrysanthemum_4',
        canonical: 'bamboo_flower_4',
      ),
    ];

    for (final tileCase in cases) {
      final draft = HandTileEntryDraft(
        flowerTileIds: [tileCase.alias],
        winningTileId: tileCase.alias,
        winningTileKnown: true,
      );
      final json = draft.toJson(groups: const []);

      expect(
        draft.flowerTileIds,
        [tileCase.canonical],
        reason: tileCase.alias,
      );
      expect(draft.winningTileId, tileCase.canonical, reason: tileCase.alias);
      expect(json['flowers'], [tileCase.canonical], reason: tileCase.alias);
      expect(json['winningTile'], tileCase.canonical, reason: tileCase.alias);
    }
  });

  test('legacy flower aliases share canonical physical copy identity', () {
    const cases = [
      (
        alias: 'bamboo_flower_3',
        canonical: 'chrysanthemum_3',
      ),
      (
        alias: 'chrysanthemum_4',
        canonical: 'bamboo_flower_4',
      ),
    ];

    for (final tileCase in cases) {
      final added = HandTileEntryDraft().addTile(tileCase.alias);

      expect(added.flowerTileIds, [tileCase.canonical]);
      expect(added.canAddTile(tileCase.alias), isFalse);
      expect(added.canAddTile(tileCase.canonical), isFalse);
      expect(
        () => HandTileEntryDraft(
          flowerTileIds: [tileCase.alias, tileCase.canonical],
        ),
        throwsStateError,
        reason: tileCase.alias,
      );

      final withWinningTile = added.setWinningTile(tileCase.alias);
      expect(withWinningTile.winningTileId, tileCase.canonical);
      expect(
        withWinningTile.removeTile(tileCase.alias).flowerTileIds,
        isEmpty,
      );
      expect(
        withWinningTile.removeTile(tileCase.canonical).flowerTileIds,
        isEmpty,
      );
    }
  });

  test('editable comparison treats alias reorder and revert as unchanged', () {
    const cases = [
      (
        alias: 'bamboo_flower_3',
        canonical: 'chrysanthemum_3',
        companion: 'plum_1',
      ),
      (
        alias: 'chrysanthemum_4',
        canonical: 'bamboo_flower_4',
        companion: 'orchid_2',
      ),
    ];

    for (final tileCase in cases) {
      final baseline = HandTileEntryDraft(
        flowerTileIds: [tileCase.canonical, tileCase.companion],
        winningTileId: tileCase.canonical,
        winningTileKnown: true,
      );
      final reverted = HandTileEntryDraft(
        flowerTileIds: [tileCase.companion, tileCase.alias],
        winningTileId: tileCase.alias,
        winningTileKnown: true,
      );

      expect(
        baseline.hasSameEditableContentAs(reverted),
        isTrue,
        reason: tileCase.alias,
      );
    }
  });

  test('editable content comparison ignores tile list ordering', () {
    final first = HandTileEntryDraft(
      coreTileIds: const ['man_1', 'man_2', 'man_1'],
      flowerTileIds: const ['plum_1', 'orchid_2'],
      winningTileId: 'man_2',
      winningTileKnown: true,
      photoRotationQuarterTurns: 1,
    );
    final reordered = HandTileEntryDraft(
      coreTileIds: const ['man_1', 'man_1', 'man_2'],
      flowerTileIds: const ['orchid_2', 'plum_1'],
      winningTileId: 'man_2',
      winningTileKnown: true,
      photoRotationQuarterTurns: 1,
    );

    expect(first.hasSameEditableContentAs(reordered), isTrue);
  });

  test('editable content comparison detects every persisted edit field', () {
    final baseline = HandTileEntryDraft(
      coreTileIds: const ['man_1', 'man_1', 'man_2'],
      flowerTileIds: const ['plum_1'],
      winningTileId: 'man_2',
      winningTileKnown: true,
      photoRotationQuarterTurns: 1,
    );

    expect(
      baseline.hasSameEditableContentAs(
        baseline.copyWith(coreTileIds: const ['man_1', 'man_2', 'man_2']),
      ),
      isFalse,
    );
    expect(
      baseline.hasSameEditableContentAs(
        baseline.copyWith(flowerTileIds: const ['orchid_2']),
      ),
      isFalse,
    );
    expect(
      baseline.hasSameEditableContentAs(baseline.clearWinningTile()),
      isFalse,
    );
    expect(
      baseline.hasSameEditableContentAs(
        baseline.copyWith(winningTileId: 'man_1', winningTileKnown: true),
      ),
      isFalse,
    );
    expect(
      baseline.hasSameEditableContentAs(
        baseline.copyWith(photoRotationQuarterTurns: 2),
      ),
      isFalse,
    );
  });
}
