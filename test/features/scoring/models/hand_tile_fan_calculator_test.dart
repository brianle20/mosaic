import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';

void main() {
  test('returns incomplete context before 14 core tiles are selected', () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(coreTileIds: const ['east', 'east']),
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: true,
      winBonuses: const [HandWinBonus.moonUnderTheSea],
    );

    expect(result.isComplete, isFalse);
    expect(result.canSave, isFalse);
    expect(result.calculatedFanCount, isNull);

    final labels = result.breakdown.map((item) => item.label);
    expect(
        labels, containsAll(['Declared', 'Self-Pick', 'Moon Under the Sea']));
  });

  test('returns invalid complete context when 14 core tiles are unsupported',
      () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'east',
          'east',
          'east',
          'south',
          'south',
          'south',
          'west',
          'west',
          'west',
          'north',
          'north',
          'red',
          'green',
          'white',
        ],
      ),
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.isComplete, isTrue);
    expect(result.canSave, isFalse);
    expect(result.calculatedFanCount, isNull);
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
    expect(result.grouping.isValid, isFalse);
  });

  test('seven pairs can save and scores special shape plus no flowers', () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_1',
          'man_1',
          'man_3',
          'man_3',
          'dot_2',
          'dot_2',
          'dot_8',
          'dot_8',
          'bamboo_4',
          'bamboo_4',
          'bamboo_9',
          'bamboo_9',
          'red',
          'red',
        ],
      ),
      declaredFanCount: 5,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.canSave, isTrue);
    expect(result.calculatedFanCount, 5);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
    expect(_fanValueFor(result, 'Seven Pairs'), 4);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
  });

  test('thirteen orphans can save and scores special shape plus no flowers',
      () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_1',
          'man_9',
          'dot_1',
          'dot_9',
          'bamboo_1',
          'bamboo_9',
          'east',
          'south',
          'west',
          'north',
          'red',
          'green',
          'white',
          'east',
        ],
      ),
      declaredFanCount: 13,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.canSave, isTrue);
    expect(result.grouping.isValid, isFalse);
    expect(result.calculatedFanCount, 13);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
    expect(_fanValueFor(result, 'Thirteen Orphans'), 13);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
  });

  test('nine gates can save and scores special shape plus no flowers', () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_1',
          'man_1',
          'man_1',
          'man_2',
          'man_3',
          'man_4',
          'man_5',
          'man_5',
          'man_6',
          'man_7',
          'man_8',
          'man_9',
          'man_9',
          'man_9',
        ],
      ),
      declaredFanCount: 13,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.canSave, isTrue);
    expect(result.calculatedFanCount, 13);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
    expect(_fanValueFor(result, 'Nine Gates'), 13);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_tileRuleLabelsFor(result), isNot(contains('Full Flush')));
  });

  test('non-special invalid complete hand still cannot save', () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_1',
          'man_1',
          'man_1',
          'man_2',
          'man_2',
          'dot_3',
          'dot_3',
          'dot_3',
          'bamboo_4',
          'bamboo_4',
          'bamboo_4',
          'east',
          'green',
          'white',
        ],
      ),
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.isComplete, isTrue);
    expect(result.canSave, isFalse);
    expect(result.calculatedFanCount, isNull);
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
  });

  test('returns unreviewed when grouping is invalid', () {
    final result = calculateHandTileFanReview(
      draft: HandTileEntryDraft(coreTileIds: const ['east', 'east', 'east']),
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: true,
    );

    expect(result.calculatedFanCount, isNull);
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
  });

  test('scores only no flowers or the matching seat flower bonus', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'dot_1',
        'dot_2',
        'dot_3',
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'south',
        'south',
      ],
      flowerTileIds: const ['spring_1', 'chrysanthemum_3'],
    );

    final eastResult = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 2,
      seatWindTileId: 'east',
      roundWindTileId: 'west',
      isSelfDraw: false,
    );
    final southResult = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 1,
      seatWindTileId: 'south',
      roundWindTileId: 'west',
      isSelfDraw: false,
    );

    expect(_fanValueFor(eastResult, 'Seat Flower / Season'), 1);
    expect(
        _tileRuleLabelsFor(eastResult), isNot(contains('Flowers / Seasons')));
    expect(
      _tileRuleLabelsFor(southResult),
      isNot(contains('Seat Flower / Season')),
    );
    expect(
        _tileRuleLabelsFor(southResult), isNot(contains('Flowers / Seasons')));
  });

  test('legacy flower aliases award one matching West or North seat fan', () {
    const cases = [
      (alias: 'bamboo_flower_3', seatWindTileId: 'west'),
      (alias: 'chrysanthemum_4', seatWindTileId: 'north'),
    ];
    const coreTileIds = [
      'man_1',
      'man_2',
      'man_3',
      'man_4',
      'man_5',
      'man_6',
      'dot_1',
      'dot_2',
      'dot_3',
      'bamboo_1',
      'bamboo_2',
      'bamboo_3',
      'south',
      'south',
    ];

    for (final tileCase in cases) {
      final result = calculateHandTileFanReview(
        draft: HandTileEntryDraft(
          coreTileIds: coreTileIds,
          flowerTileIds: [tileCase.alias],
        ),
        declaredFanCount: 2,
        seatWindTileId: tileCase.seatWindTileId,
        roundWindTileId: 'east',
        isSelfDraw: false,
      );
      final seatFlowerFans = result.breakdown
          .where((item) => item.label == 'Seat Flower / Season')
          .map((item) => item.fanValue)
          .toList();

      expect(seatFlowerFans, [1], reason: tileCase.alias);
    }
  });

  test('marks under declared when calculated fan is higher than declared', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'east',
        'east',
        'east',
        'red',
        'red',
        'red',
        'man_1',
        'man_2',
        'man_3',
        'dot_4',
        'dot_5',
        'dot_6',
        'south',
        'south',
      ],
      flowerTileIds: const ['plum_1'],
      winningTileId: 'dot_6',
      winningTileKnown: true,
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: true,
    );

    expect(result.calculatedFanCount, greaterThan(3));
    expect(result.reviewStatus, HandTileReviewStatus.underDeclared);
    expect(
      result.breakdown.map((item) => item.label),
      containsAll([
        'Seat Flower / Season',
        'Seat Wind',
        'Round Wind',
        'Red Dragon',
      ]),
    );
    expect(_fanValueFor(result, 'Seat Flower / Season'), 1);
    expect(_fanValueFor(result, 'Seat Wind'), 1);
    expect(_fanValueFor(result, 'Round Wind'), 1);
    expect(_fanValueFor(result, 'Red Dragon'), 1);
  });

  test('marks flagged when calculated fan is lower than declared', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'dot_1',
        'dot_2',
        'dot_3',
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'south',
        'south',
      ],
      winningTileId: 'bamboo_3',
      winningTileKnown: true,
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 8,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, lessThan(8));
    expect(result.reviewStatus, HandTileReviewStatus.flagged);
  });

  test('marks matched when calculated fan equals declared', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'east',
        'east',
        'east',
        'man_1',
        'man_2',
        'man_3',
        'dot_4',
        'dot_5',
        'dot_6',
        'bamboo_2',
        'bamboo_3',
        'bamboo_4',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: true,
    );

    expect(result.calculatedFanCount, 3);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
  });

  test('calculates fan while unreviewed when declared fan is null', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'dot_1',
        'dot_2',
        'dot_3',
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: null,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 2);
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
    expect(result.grouping.isValid, isTrue);
  });

  test('counts same seat and round wind triplet twice', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'east',
        'east',
        'east',
        'man_1',
        'man_2',
        'man_3',
        'dot_4',
        'dot_5',
        'dot_6',
        'bamboo_2',
        'bamboo_3',
        'bamboo_4',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 3);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
  });

  test('counts dragon triplets individually', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'red',
        'red',
        'red',
        'man_1',
        'man_2',
        'man_3',
        'dot_4',
        'dot_5',
        'dot_6',
        'bamboo_2',
        'bamboo_3',
        'bamboo_4',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 2,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 2);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
    expect(
      result.breakdown.map((item) => item.label),
      contains('Red Dragon'),
    );
    expect(_fanValueFor(result, 'Red Dragon'), 1);
    expect(_tileRuleLabelsFor(result), isNot(contains('Green Dragon')));
    expect(_tileRuleLabelsFor(result), isNot(contains('White Dragon')));
  });

  test('full flush replaces mixed flush for a one-suit sequence hand', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_2',
        'man_3',
        'man_4',
        'man_4',
        'man_5',
        'man_6',
        'man_7',
        'man_8',
        'man_9',
        'man_5',
        'man_5',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 9,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 9);
    expect(
        _tileRuleLabelsFor(result),
        containsAll([
          'No Flowers or Seasons',
          'All Sequences',
          'Full Flush',
        ]));
    expect(_tileRuleLabelsFor(result), isNot(contains('Mixed Flush')));
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_fanValueFor(result, 'All Sequences'), 1);
    expect(_fanValueFor(result, 'Full Flush'), 7);
  });

  test('ambiguous sequence counts include all sequences tile rule', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_1',
        'man_1',
        'man_1',
        'man_2',
        'man_2',
        'man_2',
        'man_2',
        'man_3',
        'man_3',
        'man_3',
        'man_3',
        'man_5',
        'man_5',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 9,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 9);
    expect(_fanValueFor(result, 'All Sequences'), 1);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_fanValueFor(result, 'Full Flush'), 7);
  });

  test('mixed flush all sequences no flowers and self-pick score six fan', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'bamboo_2',
        'bamboo_3',
        'bamboo_4',
        'bamboo_4',
        'bamboo_5',
        'bamboo_6',
        'bamboo_7',
        'bamboo_8',
        'bamboo_9',
        'east',
        'east',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 6,
      seatWindTileId: 'south',
      roundWindTileId: 'west',
      isSelfDraw: true,
    );

    expect(result.calculatedFanCount, 6);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
    expect(_fanValueFor(result, 'Self-Pick'), 1);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_fanValueFor(result, 'All Sequences'), 1);
    expect(_fanValueFor(result, 'Mixed Flush'), 3);
  });

  test('big three dragons replaces individual dragon rows', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'red',
        'red',
        'red',
        'green',
        'green',
        'green',
        'white',
        'white',
        'white',
        'man_1',
        'man_2',
        'man_3',
        'south',
        'south',
      ],
      flowerTileIds: const ['plum_1'],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 12,
      seatWindTileId: 'east',
      roundWindTileId: 'north',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 12);
    expect(_fanValueFor(result, 'Big Three Dragons'), 8);
    expect(_fanValueFor(result, 'Mixed Flush'), 3);
    expect(_fanValueFor(result, 'Seat Flower / Season'), 1);
    expect(_tileRuleLabelsFor(result), isNot(contains('Red Dragon')));
    expect(_tileRuleLabelsFor(result), isNot(contains('Green Dragon')));
    expect(_tileRuleLabelsFor(result), isNot(contains('White Dragon')));
  });

  test('jade hand scores jewel fan and replaces lower tile rows', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'bamboo_2',
        'bamboo_2',
        'bamboo_2',
        'bamboo_3',
        'bamboo_3',
        'bamboo_3',
        'bamboo_4',
        'bamboo_4',
        'bamboo_4',
        'green',
        'green',
        'green',
        'bamboo_8',
        'bamboo_8',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 13,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 13);
    expect(_fanValueFor(result, 'Jade'), 13);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_tileRuleLabelsFor(result), isNot(contains('All Triplets')));
    expect(_tileRuleLabelsFor(result), isNot(contains('Mixed Flush')));
    expect(_tileRuleLabelsFor(result), isNot(contains('Green Dragon')));
  });

  test('ambiguous jade counts score jewel even when grouping uses sequences',
      () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'bamboo_1',
        'bamboo_1',
        'bamboo_1',
        'bamboo_2',
        'bamboo_2',
        'bamboo_2',
        'bamboo_3',
        'bamboo_3',
        'bamboo_3',
        'green',
        'green',
        'green',
        'bamboo_4',
        'bamboo_4',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 13,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 13);
    expect(_fanValueFor(result, 'Jade'), 13);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_tileRuleLabelsFor(result), isNot(contains('All Triplets')));
    expect(_tileRuleLabelsFor(result), isNot(contains('Mixed Flush')));
    expect(_tileRuleLabelsFor(result), isNot(contains('Green Dragon')));
  });

  test('pearl and ruby hands score jewel fan', () {
    final pearl = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'dot_2',
          'dot_2',
          'dot_2',
          'dot_3',
          'dot_3',
          'dot_3',
          'dot_4',
          'dot_4',
          'dot_4',
          'white',
          'white',
          'white',
          'dot_8',
          'dot_8',
        ],
      ),
      declaredFanCount: 13,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );
    final ruby = calculateHandTileFanReview(
      draft: HandTileEntryDraft(
        coreTileIds: const [
          'man_2',
          'man_2',
          'man_2',
          'man_3',
          'man_3',
          'man_3',
          'man_4',
          'man_4',
          'man_4',
          'red',
          'red',
          'red',
          'man_8',
          'man_8',
        ],
      ),
      declaredFanCount: 13,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: false,
    );

    expect(pearl.calculatedFanCount, 13);
    expect(_fanValueFor(pearl, 'Pearl'), 13);
    expect(_tileRuleLabelsFor(pearl), isNot(contains('White Dragon')));

    expect(ruby.calculatedFanCount, 13);
    expect(_fanValueFor(ruby, 'Ruby'), 13);
    expect(_tileRuleLabelsFor(ruby), isNot(contains('Red Dragon')));
  });

  test('ambiguous all-triplets counts include all triplets tile rule', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
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
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 11,
      seatWindTileId: 'south',
      roundWindTileId: 'west',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 11);
    expect(_fanValueFor(result, 'All Triplets'), 3);
    expect(_fanValueFor(result, 'No Flowers or Seasons'), 1);
    expect(_fanValueFor(result, 'Full Flush'), 7);
  });

  test('small three dragons replaces individual dragon rows', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'red',
        'red',
        'red',
        'green',
        'green',
        'green',
        'white',
        'white',
        'man_1',
        'man_2',
        'man_3',
        'dot_4',
        'dot_5',
        'dot_6',
      ],
      flowerTileIds: const ['plum_1'],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 6,
      seatWindTileId: 'east',
      roundWindTileId: 'north',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 6);
    expect(_fanValueFor(result, 'Small Three Dragons'), 5);
    expect(_fanValueFor(result, 'Seat Flower / Season'), 1);
    expect(_tileRuleLabelsFor(result), isNot(contains('Red Dragon')));
    expect(_tileRuleLabelsFor(result), isNot(contains('Green Dragon')));
    expect(_tileRuleLabelsFor(result), isNot(contains('White Dragon')));
  });

  test('adds known win bonus fan to calculated fan', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'dot_1',
        'dot_2',
        'dot_3',
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 4,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
      winBonuses: const [HandWinBonus.winByKongReplacement],
    );

    expect(result.calculatedFanCount, 4);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
  });

  test('double kong replacement replaces win by kong replacement bonus', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'dot_1',
        'dot_2',
        'dot_3',
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 11,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
      winBonuses: const [
        HandWinBonus.winByKongReplacement,
        HandWinBonus.doubleKongReplacement,
      ],
    );

    expect(result.calculatedFanCount, 11);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
    expect(_fanValueFor(result, 'Double Kong Replacement'), 9);
    expect(
      result.breakdown.map((item) => item.label),
      isNot(contains('Win by Kong Replacement')),
    );
  });

  test('unknown historical win bonuses avoid flagged when declared is higher',
      () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'man_1',
        'man_2',
        'man_3',
        'man_4',
        'man_5',
        'man_6',
        'dot_1',
        'dot_2',
        'dot_3',
        'bamboo_1',
        'bamboo_2',
        'bamboo_3',
        'south',
        'south',
      ],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 8,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
      winBonuses: null,
    );

    expect(result.calculatedFanCount, 2);
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
  });

  test('unknown historical win bonuses keep mismatches unreviewed', () {
    final draft = HandTileEntryDraft(
      coreTileIds: const [
        'east',
        'east',
        'east',
        'red',
        'red',
        'red',
        'man_1',
        'man_2',
        'man_3',
        'dot_4',
        'dot_5',
        'dot_6',
        'south',
        'south',
      ],
      flowerTileIds: const ['plum_1'],
    );

    final result = calculateHandTileFanReview(
      draft: draft,
      declaredFanCount: 3,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: true,
      winBonuses: null,
    );

    expect(result.calculatedFanCount, greaterThan(3));
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
  });

  test('exposes calculation version constant', () {
    expect(handTileCalculationVersion, 'hk_tile_review_v2');
  });
}

int? _fanValueFor(HandTileFanReviewResult result, String label) {
  return result.breakdown.singleWhere((item) => item.label == label).fanValue;
}

List<String> _tileRuleLabelsFor(HandTileFanReviewResult result) {
  return [
    for (final item in result.breakdown)
      if (item.source == HandTileFanBreakdownSource.tileRule) item.label,
  ];
}
