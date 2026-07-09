import 'package:meta/meta.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_grouping.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';

const String handTileCalculationVersion = 'hk_tile_review_v1';

const Set<String> _dragonTileIds = {
  'red',
  'green',
  'white',
};

@immutable
class HandTileFanReviewResult {
  const HandTileFanReviewResult({
    required this.calculatedFanCount,
    required this.reviewStatus,
    required this.grouping,
  });

  final int? calculatedFanCount;
  final HandTileReviewStatus reviewStatus;
  final HandTileGroupingResult grouping;
}

HandTileFanReviewResult calculateHandTileFanReview({
  required HandTileEntryDraft draft,
  required int? declaredFanCount,
  required String seatWindTileId,
  required String roundWindTileId,
  required bool isSelfDraw,
  List<HandWinBonus>? winBonuses = const [],
}) {
  final grouping = groupStandardWinningHand(draft.coreTileIds);

  if (!grouping.isValid) {
    return HandTileFanReviewResult(
      calculatedFanCount: null,
      reviewStatus: HandTileReviewStatus.unreviewed,
      grouping: grouping,
    );
  }

  final calculatedFanCount = _calculateConservativeFanCount(
        draft: draft,
        grouping: grouping,
        seatWindTileId: seatWindTileId,
        roundWindTileId: roundWindTileId,
        isSelfDraw: isSelfDraw,
      ) +
      handWinBonusFanTotal(winBonuses ?? const []);

  return HandTileFanReviewResult(
    calculatedFanCount: calculatedFanCount,
    reviewStatus: declaredFanCount == null
        ? HandTileReviewStatus.unreviewed
        : _reviewStatusFor(
            calculatedFanCount: calculatedFanCount,
            declaredFanCount: declaredFanCount,
            winBonusesKnown: winBonuses != null,
          ),
    grouping: grouping,
  );
}

int _calculateConservativeFanCount({
  required HandTileEntryDraft draft,
  required HandTileGroupingResult grouping,
  required String seatWindTileId,
  required String roundWindTileId,
  required bool isSelfDraw,
}) {
  var fanCount = 0;

  if (isSelfDraw) {
    fanCount += 1;
  }

  fanCount += draft.flowerTileIds.length;

  if (_hasTriplet(grouping, seatWindTileId)) {
    fanCount += 1;
  }

  if (_hasTriplet(grouping, roundWindTileId)) {
    fanCount += 1;
  }

  for (final dragonTileId in _dragonTileIds) {
    if (_hasTriplet(grouping, dragonTileId)) {
      fanCount += 1;
    }
  }

  return fanCount;
}

HandTileReviewStatus _reviewStatusFor({
  required int calculatedFanCount,
  required int declaredFanCount,
  required bool winBonusesKnown,
}) {
  if (!winBonusesKnown && calculatedFanCount <= declaredFanCount) {
    return HandTileReviewStatus.unreviewed;
  }

  if (calculatedFanCount == declaredFanCount) {
    return HandTileReviewStatus.matched;
  }

  if (calculatedFanCount > declaredFanCount) {
    return HandTileReviewStatus.underDeclared;
  }

  return HandTileReviewStatus.flagged;
}

bool _hasTriplet(HandTileGroupingResult grouping, String tileId) {
  return grouping.groups.any(
    (group) =>
        group.type == HandTileGroupType.meld &&
        group.tileIds.length == 3 &&
        group.tileIds.every((groupTileId) => groupTileId == tileId),
  );
}
