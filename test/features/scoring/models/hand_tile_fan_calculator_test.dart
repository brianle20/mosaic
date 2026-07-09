import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_fan_calculator.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';

void main() {
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
      declaredFanCount: 2,
      seatWindTileId: 'east',
      roundWindTileId: 'south',
      isSelfDraw: true,
    );

    expect(result.calculatedFanCount, 2);
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

    expect(result.calculatedFanCount, 0);
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
      declaredFanCount: 2,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
    );

    expect(result.calculatedFanCount, 2);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
  });

  test('counts dragon triplets individually', () {
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
      declaredFanCount: 2,
      seatWindTileId: 'east',
      roundWindTileId: 'east',
      isSelfDraw: false,
      winBonuses: const [HandWinBonus.winByKongReplacement],
    );

    expect(result.calculatedFanCount, 2);
    expect(result.reviewStatus, HandTileReviewStatus.matched);
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

    expect(result.calculatedFanCount, 0);
    expect(result.reviewStatus, HandTileReviewStatus.unreviewed);
  });

  test('unknown historical win bonuses still mark under declared', () {
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
    expect(result.reviewStatus, HandTileReviewStatus.underDeclared);
  });

  test('exposes calculation version constant', () {
    expect(handTileCalculationVersion, 'hk_tile_review_v1');
  });
}
