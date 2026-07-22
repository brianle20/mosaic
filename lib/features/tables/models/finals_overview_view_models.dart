import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/finals_state_models.dart';

@immutable
class FinalsOverviewSummary {
  FinalsOverviewSummary({
    required this.overallStatus,
    required List<FinalsContestOverview> contests,
    required this.blockingReason,
    required this.championName,
    required this.redemptionWinnerName,
  }) : contests = List.unmodifiable(contests);

  factory FinalsOverviewSummary.fromState(FinalsState state) {
    return FinalsOverviewSummary(
      overallStatus: state.overallStatus,
      contests: [
        for (final contest in state.contests)
          FinalsContestOverview.fromContest(contest, state: state),
      ],
      blockingReason: state.blockingReason,
      championName: state.champion?.displayName,
      redemptionWinnerName: state.redemptionWinner?.displayName,
    );
  }

  final FinalsOverallStatus overallStatus;
  final List<FinalsContestOverview> contests;
  final String? blockingReason;
  final String? championName;
  final String? redemptionWinnerName;

  int get completeCount =>
      contests.where((contest) => contest.isComplete).length;
  int get activeCount => contests.where((contest) => contest.isActive).length;
  int get notStartedCount =>
      contests.where((contest) => contest.isReady || contest.isPending).length;

  List<FinalsContestOverview> get readyContests =>
      contests.where((contest) => contest.isReady).toList(growable: false);
  List<FinalsContestOverview> get activeContests =>
      contests.where((contest) => contest.isActive).toList(growable: false);
  List<FinalsContestOverview> get completedContests =>
      contests.where((contest) => contest.isComplete).toList(growable: false);
}

@immutable
class FinalsContestOverview {
  FinalsContestOverview({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.tableLabel,
    required this.sessionId,
    required List<String> participantNames,
    required this.resultLabel,
    required this.startedAt,
    required this.completedAt,
  }) : participantNames = List.unmodifiable(participantNames);

  factory FinalsContestOverview.fromContest(
    FinalsContest contest, {
    required FinalsState state,
  }) {
    final winnerNames = contest.participants
        .where(
          (participant) =>
              participant.outcome == FinalsParticipantOutcome.winner ||
              participant.outcome == FinalsParticipantOutcome.runnerUp ||
              participant.outcome == FinalsParticipantOutcome.advanced,
        )
        .map((participant) => participant.displayName)
        .toList(growable: false);
    final resultLabel = switch (contest.type) {
      FinalsContestType.tableOfChampions ||
      FinalsContestType.championsSuddenDeath =>
        state.champion == null
            ? _winnerLabel(winnerNames)
            : 'Champion: ${state.champion!.displayName}',
      FinalsContestType.tableOfRedemption ||
      FinalsContestType.redemptionWinnerTiebreak =>
        _redemptionResultLabel(contest, state, winnerNames),
      _ => _winnerLabel(winnerNames),
    };

    return FinalsContestOverview(
      id: contest.id,
      type: contest.type,
      title: contest.title,
      status: contest.status,
      tableLabel: contest.tableLabel,
      sessionId: contest.tableSessionId,
      participantNames: [
        for (final participant in contest.participants) participant.displayName,
      ],
      resultLabel: resultLabel,
      startedAt: contest.startedAt,
      completedAt: contest.completedAt,
    );
  }

  final String id;
  final FinalsContestType type;
  final String title;
  final FinalsContestStatus status;
  final String? tableLabel;
  final String? sessionId;
  final List<String> participantNames;
  final String? resultLabel;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isPending => status == FinalsContestStatus.pending;
  bool get isReady => status == FinalsContestStatus.ready;
  bool get isActive => status == FinalsContestStatus.active;
  bool get isComplete => status == FinalsContestStatus.complete;
}

String? _winnerLabel(List<String> winnerNames) {
  if (winnerNames.isEmpty) return null;
  return winnerNames.length == 1
      ? 'Winner: ${winnerNames.single}'
      : 'Advanced: ${winnerNames.join(', ')}';
}

String? _redemptionResultLabel(
  FinalsContest contest,
  FinalsState state,
  List<String> winnerNames,
) {
  final winnerName = contest.participants
          .where(
            (participant) =>
                participant.outcome == FinalsParticipantOutcome.winner,
          )
          .map((participant) => participant.displayName)
          .firstOrNull ??
      state.redemptionWinner?.displayName;
  final advancingRunnerUp = contest.participants
      .where(
        (participant) =>
            participant.outcome == FinalsParticipantOutcome.runnerUp &&
            participant.advancedChampionsSlot != null,
      )
      .map((participant) => participant.displayName)
      .firstOrNull;
  if (winnerName == null) return _winnerLabel(winnerNames);
  if (advancingRunnerUp == null) return 'Redemption winner: $winnerName';
  return 'Redemption winner: $winnerName • Runner-up: $advancingRunnerUp';
}
