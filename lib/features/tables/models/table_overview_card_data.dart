import 'package:meta/meta.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';

@immutable
class TableOverviewCardData {
  const TableOverviewCardData({
    required this.table,
    this.liveSummary,
    this.currentRoundSummary,
    this.currentRoundHandCount = 0,
  });

  final EventTableRecord table;
  final LiveTableSummary? liveSummary;
  final TournamentRoundTableSummary? currentRoundSummary;
  final int currentRoundHandCount;

  bool get isLive => liveSummary != null;

  bool get isCurrentRound => currentRoundSummary != null;
}

@immutable
class LiveTableSummary {
  const LiveTableSummary({
    required this.sessionId,
    required this.status,
    required this.seats,
    required this.handCount,
    required this.roundWindLabel,
    required this.dealerLabel,
    required this.progressLabel,
    required this.showRoundTimer,
    required this.roundTimeLabel,
    required this.isRoundExpired,
    required this.isRoundEndingSoon,
    required this.lastHand,
  });

  final String sessionId;
  final SessionStatus status;
  final List<SeatSummary> seats;
  final int handCount;
  final String roundWindLabel;
  final String dealerLabel;
  final String progressLabel;
  final bool showRoundTimer;
  final String roundTimeLabel;
  final bool isRoundExpired;
  final bool isRoundEndingSoon;
  final LastHandSummary lastHand;
}

@immutable
class SeatSummary {
  const SeatSummary({
    required this.seatIndex,
    required this.windLabel,
    required this.guestName,
    required this.isDealer,
  });

  final int seatIndex;
  final String windLabel;
  final String guestName;
  final bool isDealer;
}

@immutable
class LastHandSummary {
  const LastHandSummary({
    required this.title,
    this.detail,
  });

  final String title;
  final String? detail;
}
