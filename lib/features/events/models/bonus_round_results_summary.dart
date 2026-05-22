import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';

@immutable
class BonusRoundResultsSummary {
  const BonusRoundResultsSummary({
    this.finalChampion,
    this.redemptionWinner,
  });

  final BonusRoundResult? finalChampion;
  final BonusRoundResult? redemptionWinner;

  bool get hasResults => finalChampion != null || redemptionWinner != null;
}

@immutable
class BonusRoundResult {
  const BonusRoundResult({
    required this.displayName,
    required this.detailLabel,
  });

  final String displayName;
  final String detailLabel;
}

BonusRoundResultsSummary buildBonusRoundResultsSummary({
  required List<EventHandLedgerEntry> ledgerEntries,
  required List<LeaderboardEntry> leaderboardEntries,
}) {
  return BonusRoundResultsSummary(
    finalChampion: _finalChampionResult(
      ledgerEntries: ledgerEntries,
      leaderboardEntries: leaderboardEntries,
    ),
    redemptionWinner: _redemptionWinnerResult(ledgerEntries),
  );
}

BonusRoundResult? _finalChampionResult({
  required List<EventHandLedgerEntry> ledgerEntries,
  required List<LeaderboardEntry> leaderboardEntries,
}) {
  for (final entry in ledgerEntries) {
    if (entry.rowType != EventHandLedgerRowType.adjustment ||
        entry.adjustmentType != 'finals_champion_award') {
      continue;
    }

    final displayName = entry.adjustmentDisplayName;
    if (displayName == null) {
      return null;
    }

    int? totalPoints;
    for (final leaderboardEntry in leaderboardEntries) {
      if (leaderboardEntry.eventGuestId == entry.adjustmentEventGuestId) {
        totalPoints = leaderboardEntry.totalPoints;
        break;
      }
    }

    return BonusRoundResult(
      displayName: displayName,
      detailLabel: totalPoints == null
          ? 'Award ${_signedPoints(entry.adjustmentAmountPoints ?? 0)}'
          : '$totalPoints pts total',
    );
  }

  return null;
}

BonusRoundResult? _redemptionWinnerResult(List<EventHandLedgerEntry> entries) {
  final totalsByGuest = <String, _BonusGuestTotal>{};

  for (final entry in entries) {
    if (entry.rowType != EventHandLedgerRowType.hand ||
        entry.bonusTableRole != 'table_of_redemption' ||
        entry.status != HandResultStatus.recorded) {
      continue;
    }

    for (final cell in entry.cells) {
      final total = totalsByGuest[cell.eventGuestId] ??
          _BonusGuestTotal(
            displayName: cell.displayName,
            points: 0,
          );
      totalsByGuest[cell.eventGuestId] = total.add(cell.pointsDelta);
    }
  }

  if (totalsByGuest.isEmpty) {
    return null;
  }

  final totals = totalsByGuest.values.toList(growable: false)
    ..sort((left, right) {
      final pointsCompare = right.points.compareTo(left.points);
      if (pointsCompare != 0) {
        return pointsCompare;
      }
      return left.displayName.compareTo(right.displayName);
    });
  final winner = totals.first;
  return BonusRoundResult(
    displayName: winner.displayName,
    detailLabel: 'Score ${_signedPoints(winner.points)}',
  );
}

String _signedPoints(int points) {
  if (points > 0) {
    return '+$points';
  }
  return '$points';
}

@immutable
class _BonusGuestTotal {
  const _BonusGuestTotal({
    required this.displayName,
    required this.points,
  });

  final String displayName;
  final int points;

  _BonusGuestTotal add(int delta) {
    return _BonusGuestTotal(
      displayName: displayName,
      points: points + delta,
    );
  }
}
