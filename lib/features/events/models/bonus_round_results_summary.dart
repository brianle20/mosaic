import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';

@immutable
class BonusRoundResultsSummary {
  const BonusRoundResultsSummary({
    this.finalChampion,
    this.redemptionWinner,
    this.redemptionWinners = const [],
    this.suddenDeathStatus,
  });

  final BonusRoundResult? finalChampion;
  final BonusRoundResult? redemptionWinner;
  final List<BonusRoundResult> redemptionWinners;
  final BonusRoundSuddenDeathStatus? suddenDeathStatus;

  List<BonusRoundResult> get allRedemptionWinners =>
      redemptionWinners.isNotEmpty
          ? redemptionWinners
          : [if (redemptionWinner case final winner?) winner];

  bool get hasResults =>
      finalChampion != null ||
      allRedemptionWinners.isNotEmpty ||
      suddenDeathStatus != null;
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

@immutable
class BonusRoundSuddenDeathStatus {
  const BonusRoundSuddenDeathStatus({
    required this.statusLabel,
    required this.detailLabel,
  });

  final String statusLabel;
  final String detailLabel;
}

BonusRoundResultsSummary buildBonusRoundResultsSummary({
  required List<EventHandLedgerEntry> ledgerEntries,
  required List<LeaderboardEntry> leaderboardEntries,
  BonusRoundState? bonusRoundState,
}) {
  final finalChampion = _finalChampionResult(
    ledgerEntries: ledgerEntries,
    leaderboardEntries: leaderboardEntries,
    bonusRoundState: bonusRoundState,
  );
  final redemptionWinners = _redemptionWinnerResults(ledgerEntries);
  return BonusRoundResultsSummary(
    finalChampion: finalChampion,
    redemptionWinner: redemptionWinners.firstOrNull,
    redemptionWinners: redemptionWinners,
    suddenDeathStatus: _suddenDeathStatusResult(
      bonusRoundState: bonusRoundState,
      finalChampion: finalChampion,
    ),
  );
}

BonusRoundResult? _finalChampionResult({
  required List<EventHandLedgerEntry> ledgerEntries,
  required List<LeaderboardEntry> leaderboardEntries,
  required BonusRoundState? bonusRoundState,
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

    final detailLabel = totalPoints == null
        ? 'Award ${_signedPoints(entry.adjustmentAmountPoints ?? 0)}'
        : '$totalPoints pts total';

    return BonusRoundResult(
      displayName: displayName,
      detailLabel: _isSuddenDeathResolved(bonusRoundState)
          ? '$detailLabel, sudden death'
          : detailLabel,
    );
  }

  final championGuestId = bonusRoundState?.championEventGuestId;
  if (championGuestId != null) {
    for (final leaderboardEntry in leaderboardEntries) {
      if (leaderboardEntry.eventGuestId != championGuestId) {
        continue;
      }
      return BonusRoundResult(
        displayName: leaderboardEntry.displayName,
        detailLabel: _isSuddenDeathResolved(bonusRoundState)
            ? '${leaderboardEntry.totalPoints} pts total, sudden death'
            : '${leaderboardEntry.totalPoints} pts total',
      );
    }
  }

  return null;
}

BonusRoundSuddenDeathStatus? _suddenDeathStatusResult({
  required BonusRoundState? bonusRoundState,
  required BonusRoundResult? finalChampion,
}) {
  if (finalChampion != null || !_isSuddenDeathResolution(bonusRoundState)) {
    return null;
  }

  final status = bonusRoundState?.suddenDeathStatus;
  final statusLabel = switch (status) {
    'required' => 'Sudden death required',
    'active' => 'Sudden death active',
    _ => null,
  };
  if (statusLabel == null) {
    return null;
  }

  final tiedPlayers = _formatTiedPlayers(
    bonusRoundState?.tiedTopPlayers ?? const [],
  );
  return BonusRoundSuddenDeathStatus(
    statusLabel: statusLabel,
    detailLabel: tiedPlayers.isEmpty
        ? 'Top finalists are tied.'
        : 'Tied finalists: $tiedPlayers',
  );
}

bool _isSuddenDeathResolution(BonusRoundState? bonusRoundState) {
  return bonusRoundState?.championResolutionMethod == 'sudden_death';
}

bool _isSuddenDeathResolved(BonusRoundState? bonusRoundState) {
  return _isSuddenDeathResolution(bonusRoundState) &&
      bonusRoundState?.suddenDeathStatus == 'completed';
}

String _formatTiedPlayers(List<BonusRoundTiedPlayer> players) {
  return players
      .map((player) {
        final name = player.displayName;
        if (name == null) {
          return null;
        }
        final score = player.bonusScorePoints;
        return score == null ? name : '$name ($score pts)';
      })
      .nonNulls
      .join(', ');
}

List<BonusRoundResult> _redemptionWinnerResults(
  List<EventHandLedgerEntry> entries,
) {
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
    return const [];
  }

  final totals = totalsByGuest.values.toList(growable: false)
    ..sort((left, right) {
      final pointsCompare = right.points.compareTo(left.points);
      if (pointsCompare != 0) {
        return pointsCompare;
      }
      return left.displayName.compareTo(right.displayName);
    });
  final winningScore = totals.first.points;
  return List.unmodifiable([
    for (final winner in totals)
      if (winner.points == winningScore)
        BonusRoundResult(
          displayName: winner.displayName,
          detailLabel: 'Score ${_signedPoints(winner.points)}',
        ),
  ]);
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
