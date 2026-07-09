import 'package:meta/meta.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/features/scoring/models/hand_tile_entry_draft.dart';
import 'package:mosaic/features/scoring/models/hand_tile_grouping.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';
import 'package:mosaic/features/scoring/models/mahjong_tile.dart';

const String handTileCalculationVersion = 'hk_tile_review_v2';

const Set<String> _dragonTileIds = {
  'red',
  'green',
  'white',
};

const Set<String> _windTileIds = {
  'east',
  'south',
  'west',
  'north',
};

enum HandTileFanBreakdownSource {
  declared,
  winType,
  winBonus,
  tileRule,
  status,
}

@immutable
class HandTileFanBreakdownItem {
  const HandTileFanBreakdownItem({
    required this.label,
    required this.source,
    this.fanValue,
  });

  final String label;
  final HandTileFanBreakdownSource source;
  final int? fanValue;
}

@immutable
class HandTileFanReviewResult {
  HandTileFanReviewResult({
    required this.calculatedFanCount,
    required this.reviewStatus,
    required this.grouping,
    required this.isComplete,
    required this.canSave,
    required List<HandTileFanBreakdownItem> breakdown,
  }) : breakdown = List.unmodifiable(breakdown);

  final int? calculatedFanCount;
  final HandTileReviewStatus reviewStatus;
  final HandTileGroupingResult grouping;
  final bool isComplete;
  final bool canSave;
  final List<HandTileFanBreakdownItem> breakdown;
}

@immutable
class _AppliedFanRule {
  const _AppliedFanRule({
    required this.id,
    required this.label,
    required this.fanValue,
  });

  final String id;
  final String label;
  final int fanValue;
}

HandTileFanReviewResult calculateHandTileFanReview({
  required HandTileEntryDraft draft,
  required int? declaredFanCount,
  required String seatWindTileId,
  required String roundWindTileId,
  required bool isSelfDraw,
  List<HandWinBonus>? winBonuses = const [],
}) {
  final breakdown = _contextBreakdownItems(
    declaredFanCount: declaredFanCount,
    isSelfDraw: isSelfDraw,
    winBonuses: winBonuses,
  );
  final isComplete = draft.coreTileIds.length == 14;
  final grouping = groupStandardWinningHand(draft.coreTileIds);
  final specialHandRule = _specialHandRule(draft.coreTileIds);

  if (specialHandRule != null) {
    final fullBreakdown = [
      ...breakdown,
      ..._specialHandBreakdownItems(
        draft: draft,
        seatWindTileId: seatWindTileId,
        specialHandRule: specialHandRule,
      ),
    ];
    final calculatedFanCount = _calculatedFanCount(fullBreakdown);

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
      isComplete: true,
      canSave: true,
      breakdown: fullBreakdown,
    );
  }

  if (!grouping.isValid) {
    return HandTileFanReviewResult(
      calculatedFanCount: null,
      reviewStatus: HandTileReviewStatus.unreviewed,
      grouping: grouping,
      isComplete: isComplete,
      canSave: false,
      breakdown: breakdown,
    );
  }

  final tileRuleBreakdown = _tileRuleBreakdownItems(
    draft: draft,
    grouping: grouping,
    seatWindTileId: seatWindTileId,
    roundWindTileId: roundWindTileId,
  );
  final fullBreakdown = [...breakdown, ...tileRuleBreakdown];
  final calculatedFanCount = _calculatedFanCount(fullBreakdown);

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
    isComplete: true,
    canSave: true,
    breakdown: fullBreakdown,
  );
}

List<HandTileFanBreakdownItem> _contextBreakdownItems({
  required int? declaredFanCount,
  required bool isSelfDraw,
  required List<HandWinBonus>? winBonuses,
}) {
  final items = <HandTileFanBreakdownItem>[];

  if (declaredFanCount != null) {
    items.add(
      HandTileFanBreakdownItem(
        label: 'Declared',
        source: HandTileFanBreakdownSource.declared,
        fanValue: declaredFanCount,
      ),
    );
  }

  items.add(
    HandTileFanBreakdownItem(
      label: isSelfDraw ? 'Self-Pick' : 'Discard win',
      source: HandTileFanBreakdownSource.winType,
      fanValue: isSelfDraw ? 1 : null,
    ),
  );

  for (final bonus in _effectiveWinBonuses(winBonuses)) {
    items.add(
      HandTileFanBreakdownItem(
        label: bonus.label,
        source: HandTileFanBreakdownSource.winBonus,
        fanValue: bonus.fanValue,
      ),
    );
  }

  return items;
}

List<HandWinBonus> _effectiveWinBonuses(List<HandWinBonus>? winBonuses) {
  if (winBonuses == null) {
    return const [];
  }

  final hasDoubleKongReplacement = winBonuses.contains(
    HandWinBonus.doubleKongReplacement,
  );
  if (!hasDoubleKongReplacement) {
    return winBonuses;
  }

  return [
    for (final bonus in winBonuses)
      if (bonus != HandWinBonus.winByKongReplacement) bonus,
  ];
}

List<HandTileFanBreakdownItem> _tileRuleBreakdownItems({
  required HandTileEntryDraft draft,
  required HandTileGroupingResult grouping,
  required String seatWindTileId,
  required String roundWindTileId,
}) {
  final rules = _applyRuleReplacements(
    _appliedTileRules(
      draft: draft,
      grouping: grouping,
      seatWindTileId: seatWindTileId,
      roundWindTileId: roundWindTileId,
    ),
  );

  return [
    for (final rule in rules)
      HandTileFanBreakdownItem(
        label: rule.label,
        source: HandTileFanBreakdownSource.tileRule,
        fanValue: rule.fanValue,
      ),
  ];
}

List<_AppliedFanRule> _appliedTileRules({
  required HandTileEntryDraft draft,
  required HandTileGroupingResult grouping,
  required String seatWindTileId,
  required String roundWindTileId,
}) {
  final rules = <_AppliedFanRule>[];
  final flowerSeasonRule = _flowerSeasonRule(
    draft: draft,
    seatWindTileId: seatWindTileId,
  );
  if (flowerSeasonRule != null) {
    rules.add(flowerSeasonRule);
  }

  if (_canFormAllSequencesFromCounts(draft.coreTileIds)) {
    rules.add(
      const _AppliedFanRule(
        id: 'allSequences',
        label: 'All Sequences',
        fanValue: 1,
      ),
    );
  }

  if (_canFormAllTripletsFromCounts(draft.coreTileIds)) {
    rules.add(
      const _AppliedFanRule(
        id: 'allTriplets',
        label: 'All Triplets',
        fanValue: 3,
      ),
    );
  }

  final flushRule = _flushRule(draft.coreTileIds);
  if (flushRule != null) {
    rules.add(flushRule);
  }

  final terminalHonorRule = _terminalHonorRule(draft.coreTileIds);
  if (terminalHonorRule != null) {
    rules.add(terminalHonorRule);
  }

  if (_hasTriplet(grouping, seatWindTileId)) {
    rules.add(
      const _AppliedFanRule(
        id: 'seatWind',
        label: 'Seat Wind',
        fanValue: 1,
      ),
    );
  }

  if (_hasTriplet(grouping, roundWindTileId)) {
    rules.add(
      const _AppliedFanRule(
        id: 'roundWind',
        label: 'Round Wind',
        fanValue: 1,
      ),
    );
  }

  for (final dragonTileId in _dragonTileIds) {
    if (_hasTriplet(grouping, dragonTileId)) {
      rules.add(
        _AppliedFanRule(
          id: '${dragonTileId}Dragon',
          label: _dragonLabel(dragonTileId),
          fanValue: 1,
        ),
      );
    }
  }

  final dragonUpgrade = _dragonUpgradeRule(grouping);
  if (dragonUpgrade != null) {
    rules.add(dragonUpgrade);
  }

  final windUpgrade = _windUpgradeRule(grouping);
  if (windUpgrade != null) {
    rules.add(windUpgrade);
  }

  final jewelRule = _jewelRule(draft.coreTileIds);
  if (jewelRule != null) {
    rules.add(jewelRule);
  }

  return rules;
}

List<HandTileFanBreakdownItem> _specialHandBreakdownItems({
  required HandTileEntryDraft draft,
  required String seatWindTileId,
  required _AppliedFanRule specialHandRule,
}) {
  final flowerSeasonRule = _flowerSeasonRule(
    draft: draft,
    seatWindTileId: seatWindTileId,
  );
  return [
    for (final rule in [
      if (flowerSeasonRule != null) flowerSeasonRule,
      specialHandRule,
    ])
      HandTileFanBreakdownItem(
        label: rule.label,
        source: HandTileFanBreakdownSource.tileRule,
        fanValue: rule.fanValue,
      ),
  ];
}

_AppliedFanRule? _flowerSeasonRule({
  required HandTileEntryDraft draft,
  required String seatWindTileId,
}) {
  if (draft.flowerTileIds.isEmpty) {
    return const _AppliedFanRule(
      id: 'noFlowers',
      label: 'No Flowers or Seasons',
      fanValue: 1,
    );
  }

  final seatFlowerSeasonTileIds = _seatFlowerSeasonTileIds(seatWindTileId);
  if (draft.flowerTileIds.any(seatFlowerSeasonTileIds.contains)) {
    return const _AppliedFanRule(
      id: 'seatFlowerSeason',
      label: 'Seat Flower / Season',
      fanValue: 1,
    );
  }

  return null;
}

Set<String> _seatFlowerSeasonTileIds(String seatWindTileId) {
  return switch (seatWindTileId) {
    'east' => const {'plum_1', 'spring_1'},
    'south' => const {'orchid_2', 'summer_2'},
    'west' => const {'chrysanthemum_3', 'autumn_3'},
    'north' => const {'bamboo_flower_4', 'winter_4'},
    _ => const <String>{},
  };
}

List<_AppliedFanRule> _applyRuleReplacements(List<_AppliedFanRule> rules) {
  final idsToRemove = <String>{};
  final ruleIds = rules.map((rule) => rule.id).toSet();

  if (ruleIds.contains('fullFlush')) {
    idsToRemove.add('mixedFlush');
  }

  if (ruleIds.contains('mixedTerminals') ||
      ruleIds.contains('allTerminals') ||
      ruleIds.contains('allHonours')) {
    idsToRemove.add('allTriplets');
  }

  if (ruleIds.contains('allTerminals') || ruleIds.contains('allHonours')) {
    idsToRemove.add('mixedTerminals');
  }

  if (ruleIds.contains('smallThreeDragons')) {
    idsToRemove.addAll(_dragonTileIds.map((tileId) => '${tileId}Dragon'));
  }

  if (ruleIds.contains('bigThreeDragons')) {
    idsToRemove
      ..add('smallThreeDragons')
      ..addAll(_dragonTileIds.map((tileId) => '${tileId}Dragon'));
  }

  if (ruleIds.contains('smallFourWinds')) {
    idsToRemove
      ..add('seatWind')
      ..add('roundWind');
  }

  if (ruleIds.contains('bigFourWinds')) {
    idsToRemove
      ..add('smallFourWinds')
      ..add('seatWind')
      ..add('roundWind');
  }

  if (ruleIds.contains('jade')) {
    idsToRemove
      ..add('allTriplets')
      ..add('mixedFlush')
      ..add('greenDragon');
  }

  if (ruleIds.contains('pearl')) {
    idsToRemove
      ..add('allTriplets')
      ..add('mixedFlush')
      ..add('whiteDragon');
  }

  if (ruleIds.contains('ruby')) {
    idsToRemove
      ..add('allTriplets')
      ..add('mixedFlush')
      ..add('redDragon');
  }

  return [
    for (final rule in rules)
      if (!idsToRemove.contains(rule.id)) rule,
  ];
}

_AppliedFanRule? _flushRule(List<String> coreTileIds) {
  final tiles = coreTileIds.map(MahjongTile.byId);
  final suits = <String>{};
  var hasHonors = false;

  for (final tile in tiles) {
    if (tile.category == MahjongTileCategory.honor) {
      hasHonors = true;
    } else if (tile.category == MahjongTileCategory.suit && tile.suit != null) {
      suits.add(tile.suit!);
    }
  }

  if (suits.length != 1) {
    return null;
  }

  if (hasHonors) {
    return const _AppliedFanRule(
      id: 'mixedFlush',
      label: 'Mixed Flush',
      fanValue: 3,
    );
  }

  return const _AppliedFanRule(
    id: 'fullFlush',
    label: 'Full Flush',
    fanValue: 7,
  );
}

_AppliedFanRule? _terminalHonorRule(List<String> coreTileIds) {
  final tiles = coreTileIds.map(MahjongTile.byId).toList();
  final allHonors = tiles.every(
    (tile) => tile.category == MahjongTileCategory.honor,
  );
  if (allHonors) {
    return const _AppliedFanRule(
      id: 'allHonours',
      label: 'All Honours',
      fanValue: 10,
    );
  }

  final allTerminals = tiles.every(_isTerminalSuitTile);
  if (allTerminals) {
    return const _AppliedFanRule(
      id: 'allTerminals',
      label: 'All Terminals',
      fanValue: 13,
    );
  }

  final mixedTerminals = tiles.every(
    (tile) =>
        tile.category == MahjongTileCategory.honor || _isTerminalSuitTile(tile),
  );
  if (mixedTerminals) {
    return const _AppliedFanRule(
      id: 'mixedTerminals',
      label: 'Mixed Terminals',
      fanValue: 4,
    );
  }

  return null;
}

_AppliedFanRule? _dragonUpgradeRule(HandTileGroupingResult grouping) {
  final dragonTripletCount =
      _dragonTileIds.where((tileId) => _hasTriplet(grouping, tileId)).length;

  if (dragonTripletCount == 3) {
    return const _AppliedFanRule(
      id: 'bigThreeDragons',
      label: 'Big Three Dragons',
      fanValue: 8,
    );
  }

  if (dragonTripletCount == 2 &&
      _dragonTileIds.any((tileId) => _pairTileId(grouping) == tileId)) {
    return const _AppliedFanRule(
      id: 'smallThreeDragons',
      label: 'Small Three Dragons',
      fanValue: 5,
    );
  }

  return null;
}

_AppliedFanRule? _windUpgradeRule(HandTileGroupingResult grouping) {
  final windTripletCount =
      _windTileIds.where((tileId) => _hasTriplet(grouping, tileId)).length;

  if (windTripletCount == 4) {
    return const _AppliedFanRule(
      id: 'bigFourWinds',
      label: 'Big Four Winds',
      fanValue: 13,
    );
  }

  if (windTripletCount == 3 &&
      _windTileIds.any((tileId) => _pairTileId(grouping) == tileId)) {
    return const _AppliedFanRule(
      id: 'smallFourWinds',
      label: 'Small Four Winds',
      fanValue: 6,
    );
  }

  return null;
}

_AppliedFanRule? _jewelRule(List<String> coreTileIds) {
  if (_isJewelHandFromCounts(
    coreTileIds: coreTileIds,
    suit: 'bamboo',
    dragonTileId: 'green',
  )) {
    return const _AppliedFanRule(id: 'jade', label: 'Jade', fanValue: 13);
  }

  if (_isJewelHandFromCounts(
    coreTileIds: coreTileIds,
    suit: 'dot',
    dragonTileId: 'white',
  )) {
    return const _AppliedFanRule(id: 'pearl', label: 'Pearl', fanValue: 13);
  }

  if (_isJewelHandFromCounts(
    coreTileIds: coreTileIds,
    suit: 'man',
    dragonTileId: 'red',
  )) {
    return const _AppliedFanRule(id: 'ruby', label: 'Ruby', fanValue: 13);
  }

  return null;
}

_AppliedFanRule? _specialHandRule(List<String> coreTileIds) {
  if (_isThirteenOrphans(coreTileIds)) {
    return const _AppliedFanRule(
      id: 'thirteenOrphans',
      label: 'Thirteen Orphans',
      fanValue: 13,
    );
  }

  if (_isNineGates(coreTileIds)) {
    return const _AppliedFanRule(
      id: 'nineGates',
      label: 'Nine Gates',
      fanValue: 13,
    );
  }

  if (_isSevenPairs(coreTileIds)) {
    return const _AppliedFanRule(
      id: 'sevenPairs',
      label: 'Seven Pairs',
      fanValue: 4,
    );
  }

  return null;
}

bool _canFormAllSequencesFromCounts(List<String> coreTileIds) {
  if (coreTileIds.length != 14) {
    return false;
  }

  final counts = _tileCounts(coreTileIds);
  for (final tileId in counts.keys) {
    final count = counts[tileId] ?? 0;
    if (count < 2) {
      continue;
    }

    final candidateCounts = Map<String, int>.from(counts);
    candidateCounts[tileId] = count - 2;
    if (_canConsumeOnlySequences(candidateCounts)) {
      return true;
    }
  }

  return false;
}

bool _canFormAllTripletsFromCounts(List<String> coreTileIds) {
  final counts = _tileCounts(coreTileIds);
  var pairCount = 0;
  var tripletCount = 0;

  for (final count in counts.values) {
    if (count == 2) {
      pairCount += 1;
    } else if (count == 3) {
      tripletCount += 1;
    } else if (count != 0) {
      return false;
    }
  }

  return pairCount == 1 && tripletCount == 4;
}

bool _isSevenPairs(List<String> coreTileIds) {
  if (coreTileIds.length != 14) {
    return false;
  }

  final counts = _tileCounts(coreTileIds);
  return counts.length == 7 && counts.values.every((count) => count == 2);
}

bool _isThirteenOrphans(List<String> coreTileIds) {
  if (coreTileIds.length != 14) {
    return false;
  }

  final counts = _tileCounts(coreTileIds);
  const requiredTileIds = {
    'man_1',
    'man_9',
    'dot_1',
    'dot_9',
    'bamboo_1',
    'bamboo_9',
    ..._windTileIds,
    ..._dragonTileIds,
  };

  if (!counts.keys.every(requiredTileIds.contains)) {
    return false;
  }

  return requiredTileIds.every((tileId) => (counts[tileId] ?? 0) >= 1) &&
      counts.values.where((count) => count == 2).length == 1 &&
      counts.values.every((count) => count == 1 || count == 2);
}

bool _isNineGates(List<String> coreTileIds) {
  if (coreTileIds.length != 14) {
    return false;
  }

  final rankCounts = <int, int>{};
  String? suit;

  for (final tileId in coreTileIds) {
    final tile = MahjongTile.byId(tileId);
    if (tile.category != MahjongTileCategory.suit ||
        tile.suit == null ||
        tile.rank == null) {
      return false;
    }

    suit ??= tile.suit;
    if (tile.suit != suit) {
      return false;
    }

    rankCounts[tile.rank!] = (rankCounts[tile.rank!] ?? 0) + 1;
  }

  if ((rankCounts[1] ?? 0) < 3 || (rankCounts[9] ?? 0) < 3) {
    return false;
  }

  for (var rank = 2; rank <= 8; rank += 1) {
    if ((rankCounts[rank] ?? 0) < 1) {
      return false;
    }
  }

  return true;
}

bool _isJewelHandFromCounts({
  required List<String> coreTileIds,
  required String suit,
  required String dragonTileId,
}) {
  final counts = _tileCounts(coreTileIds);
  var pairCount = 0;
  var tripletCount = 0;
  var hasDragonTriplet = false;

  for (final entry in counts.entries) {
    final count = entry.value;
    if (count == 0) {
      continue;
    }

    final tileId = entry.key;
    final tile = MahjongTile.byId(tileId);
    final matchesJewelTile = tileId == dragonTileId ||
        (tile.category == MahjongTileCategory.suit && tile.suit == suit);

    if (count == 2) {
      if (!matchesJewelTile) {
        return false;
      }

      pairCount += 1;
    } else if (count == 3) {
      if (!matchesJewelTile) {
        return false;
      }

      tripletCount += 1;
      hasDragonTriplet = hasDragonTriplet || tileId == dragonTileId;
    } else {
      return false;
    }
  }

  return pairCount == 1 && tripletCount == 4 && hasDragonTriplet;
}

int _calculatedFanCount(List<HandTileFanBreakdownItem> breakdown) {
  final fanCount = breakdown
      .where((item) => item.source != HandTileFanBreakdownSource.declared)
      .fold<int>(0, (total, item) => total + (item.fanValue ?? 0));
  return fanCount > 13 ? 13 : fanCount;
}

String _dragonLabel(String tileId) {
  return switch (tileId) {
    'red' => 'Red Dragon',
    'green' => 'Green Dragon',
    'white' => 'White Dragon',
    _ => tileId,
  };
}

HandTileReviewStatus _reviewStatusFor({
  required int calculatedFanCount,
  required int declaredFanCount,
  required bool winBonusesKnown,
}) {
  if (!winBonusesKnown && calculatedFanCount != declaredFanCount) {
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
        _isTripletMeld(group) &&
        group.tileIds.every((groupTileId) => groupTileId == tileId),
  );
}

String? _pairTileId(HandTileGroupingResult grouping) {
  for (final group in grouping.groups) {
    if (group.type == HandTileGroupType.pair &&
        group.tileIds.length == 2 &&
        group.tileIds.first == group.tileIds.last) {
      return group.tileIds.first;
    }
  }

  return null;
}

Map<String, int> _tileCounts(List<String> coreTileIds) {
  final counts = <String, int>{};
  for (final tileId in coreTileIds) {
    counts[tileId] = (counts[tileId] ?? 0) + 1;
  }

  return counts;
}

bool _canConsumeOnlySequences(Map<String, int> counts) {
  final tileId = _firstCountedCoreTileId(counts);
  if (tileId == null) {
    return true;
  }

  final tile = MahjongTile.byId(tileId);
  if (tile.category != MahjongTileCategory.suit ||
      tile.suit == null ||
      tile.rank == null ||
      tile.rank! > 7) {
    return false;
  }

  final secondTileId = '${tile.suit}_${tile.rank! + 1}';
  final thirdTileId = '${tile.suit}_${tile.rank! + 2}';
  if ((counts[secondTileId] ?? 0) == 0 || (counts[thirdTileId] ?? 0) == 0) {
    return false;
  }

  counts[tileId] = (counts[tileId] ?? 0) - 1;
  counts[secondTileId] = (counts[secondTileId] ?? 0) - 1;
  counts[thirdTileId] = (counts[thirdTileId] ?? 0) - 1;
  final canConsumeRemaining = _canConsumeOnlySequences(counts);
  counts[tileId] = (counts[tileId] ?? 0) + 1;
  counts[secondTileId] = (counts[secondTileId] ?? 0) + 1;
  counts[thirdTileId] = (counts[thirdTileId] ?? 0) + 1;

  return canConsumeRemaining;
}

String? _firstCountedCoreTileId(Map<String, int> counts) {
  for (final tile in allMahjongTiles) {
    if (tile.isCore && (counts[tile.id] ?? 0) > 0) {
      return tile.id;
    }
  }

  return null;
}

bool _isTripletMeld(HandTileGroup group) {
  return group.type == HandTileGroupType.meld &&
      group.tileIds.length == 3 &&
      group.tileIds.every((tileId) => tileId == group.tileIds.first);
}

bool _isTerminalSuitTile(MahjongTile tile) {
  return tile.category == MahjongTileCategory.suit &&
      (tile.rank == 1 || tile.rank == 9);
}
